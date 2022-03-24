export FRAMEWORK=STATEFUN # one of the following SPARK/FLINK/KAFKASTREAMS/STRUCTUREDSTREAMING
export JOBUUID=TEST # unique identifier of the job
export MODE=constant-rate # the workload which was being executed: constant-rate/latency-constant-rate/single-burst/periodic-burst/worker-failure/master-failure/faulty-event
export KAFKA_BOOTSTRAP_SERVERS=$(hostname -I | head -n1 | awk '{print $1;}'):9092  # list of Kafka brokers in the form of "host1:port1,host2:port2"
# export JAR_NAME= # the name of the jar of the output consumer
export SPARK_DEFAULT_PARALLELISM=1 # number of total cores over all executors
