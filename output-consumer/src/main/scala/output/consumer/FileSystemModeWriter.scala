package output.consumer

import java.sql.Timestamp
import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.functions._
import org.slf4j.LoggerFactory

import java.text.{DateFormat, SimpleDateFormat}
import collection.JavaConverters._

/**
 * Writes to local file system.
 */
object FileSystemModeWriter {
  
  val logger = LoggerFactory.getLogger(this.getClass)

  def run = {
    val sparkSession = SparkSession.builder
      .master("local[*]")
      .appName("output-consumer")
      .getOrCreate()
    import sparkSession.implicits._

    val configUtils = new FileSystemConfigUtils

    val inputData = sparkSession.read
      .format("kafka")
      .option("kafka.bootstrap.servers", configUtils.kafkaBootstrapServers)
      .option("kafka.isolation.level", "read_committed")
      .option("subscribe", configUtils.kafkaTopic)
      .option("includeTimestamp", true)
      .option("startingOffsets", "earliest")
      .option("endingOffsets", "latest")
      .option("maxOffsetsPerTrigger", 1000000)
      .load()

    val sample = if (configUtils.mode == "constant-rate" & inputData.count() > 1000000000) {
      inputData.sample(0.01)
    } else if (configUtils.mode == "constant-rate" & inputData.count() > 100000000) {
      inputData.sample(0.1)
    } else if (configUtils.mode == "constant-rate" & inputData.count() > 10000000) {
      inputData.sample(0.1)
    } else inputData

    val schema = schema_of_json(lit(inputData.select("value").as[String].first))
    val timeUDF = udf((time: Timestamp) => time.getTime)

    val inputDataWithTimestampColumn = sample
      .selectExpr("CAST(key AS STRING)", "CAST(value AS STRING)", "timestamp")
      .withColumn(
        "inputKafkaTimestamp",
        from_json(col("value"), schema, Map[String, String]().asJava).getItem("publishTimestamp")
      )
      // .withColumn(
      //   "key",
      //   from_json(col("value"), schema, Map[String, String]().asJava).getItem("jobProfile")
      // )
      .select(
        // col("key"),
        col("inputKafkaTimestamp"),
        timeUDF(col("timestamp")).as("outputKafkaTimestamp")
      )

    val dateFormat: DateFormat = new SimpleDateFormat("dd-MM-yyyy_HH:mm")
    val currentTimeString: String = dateFormat.format(new Timestamp(1000 * Math.round(System.currentTimeMillis()/1000.0)))

    inputDataWithTimestampColumn
      .write
      .json(configUtils.path + "/" + currentTimeString)

    sparkSession.stop()

  }
}

