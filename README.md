# Statefun NDB Benchmark
Benchmark for my Thesis *Highly Available Stateful Serverless Functions in Apache Flink*.

This benchmark is based on [OSPBench](https://github.com/Klarrio/open-stream-processing-benchmark), 
and adapted to fit Stateful Serverless functions.

## Deployment
Deployment scripts can be found in [``deployment``](/deployment).

### Deployment Prerequisites
The following prerequisites are necessary for both local and cloud deployment.

Before running the benchmark the input data must be generated. You can generate the data yourself by running:
```shell
python data-utils/generate_data.py
```
The benchmark requires a packaged Flink build to run. Copy your own Flink build into the folder [``deployment/flink``](/deployment/flink), and name the folder `build`.
Instructions of how to build Flink can be found [here](https://github.com/apache/flink).
```shell
cp -r <path-to-flink-build> /deployment/flink/build/
```


### Local Deployment

The local benchmark assumes that a RonDB cluster is running at ``localhost:3306``.

Set the state backend to ndb or rocksdb by either of the following commands
```shell
./deployment/local/set-ndb-backend.sh
```
```shell
./deployment/local/set-rocksdb-backend.sh
```
Run the benchmark
```shell
./deployment/local/run.sh
```

### GCP Deployment
Before running the benchmark in GCP [install the GCP CLI](https://cloud.google.com/sdk/gcloud) and initialize your environment using:
```shell
gcloud init
```
Then, run the benchmarks in GCP using:
```shell
./deployment/gcp/run.sh
```

## Full Benchmark Setup
The following is a description of the complete benchmark. This workflow is automated by the ``run.sh`` scripts above.

### Prerequisites 
For this benchmark pipeline, you will need:
* Java
* Maven
* Jupyter Notebook (for evaluation)
* Docker

The following is all the procedures necessary to run the StateFun NDB Benchmark:
1. Set up a RonDB cluster, make sure it is listening to the default port of 3306.
2. Initialize the database and the tables using [ndb-utils/init_db.sql](deployment/ndb-utils/init_db.sql).
3. Download the NDB lib files and make sure that the environment variable ``LD_LIBRARY_PATH`` points to the directory containing the files.
```shell
curl https://repo.hops.works/master/lib-ndb-6.1.0.tgz > lib-ndb.tgz
tar -xvzf lib-ndb.tgz
cd lib-ndb-6.1.0
export LD_LIBRARY_PATH=`pwd`
```
4. Set up Kafka to listen to port 9092. The topics that need to be created are:
   * "add-to-cart"
   * "add-confirm"
   * "checkout"
   * "restock"
   * "receipts"
5. Build Flink by cloning: [``senorcarbone/flink-rondb``](https://github.com/senorcarbone/flink-rondb) and running the following command in the project (this might take a while):
```shell
mvn clean install -DskipTests -Dscala-2.12
```
6. Copy the build folder ``flink-rondb/flink-dist/target/flink-1.14.3-SNAPSHOT-bin/flink-1.14.3-SNAPSHOT`` into a the folder ``deployment/flink`` and rename it to ``build``
7. Configure the Flink cluster by making sure that the following fields are set in 
[``deployment/flink/build/conf/flink-conf.yaml``](deployment/flink/build/conf/flink-conf.yaml):
```yaml
# For NDB:
state.backend: ndb
state.backend.ndb.dbname: flinkndb
state.backend.ndb.truncatetableonstart: false
state.backend.ndb.connectionstring: <address to rondb cluster>

# For RocksDB:
state.backend: rocksdb
state.backend.incremental: true

# For both:
execution.checkpointing.interval: 10sec
execution.checkpointing.mode: EXACTLY_ONCE
state.savepoints.dir: <path in filesystem or gcp bucket>
state.checkpoints.dir: <path in filesystem or gcp bucket>
classloader.parent-first-patterns.additional: org.apache.flink.statefun;org.apache.kafka;com.google.protobuf
jobmanager.rpc.address: <address to Flink JobManager>
jobmanager.rpc.port: <port to Flink JobManager>

```
8. Run the JobManager
```shell
./deployment/builds/flink-build/bin/jobmanager.sh start
```
9. Run one or more TaskManagers
```shell
./deployment/builds/flink-build/bin/taskmanager.sh start
```

10. Build StateFun job
```shell
./deployment/local/build.sh
```

10. Run the StateFun Runtime + Job;
```shell
./deployment/flink/build/bin/flink run -c org.apache.flink.statefun.flink.core.StatefulFunctionsJob shoppingcart-embedded/target/shoppingcart-embedded-1.0-SNAPSHOT-jar-with-dependencies.jar
```

11. Generate input events:
```shell
python data-utils/generate_data.py
```

12. Run Data Stream Generator
```shell
python data-utils/produce_events.py
```

13. When job has finished, run output-consumer:
```shell
python data-utils/output_consumer.py
```

14. Produce output plots using the Jupyter Notebook in the ``evaluator`` folder, setting the correct filepaths at the top of the notebook.