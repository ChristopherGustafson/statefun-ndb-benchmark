#!/bin/bash

# User configs
export STATE_BACKEND="${1:-"ndb"}"
export CRASH=${2:-0}
export RECOVERY_METHOD="${3:-"eager"}"
export FUNCTION_TYPE="${4:-"embedded"}"

echo "Running local benchmark with $STATE_BACKEND backend, crashing=$CRASH, $RECOVERY_METHOD recovery and $FUNCTION_TYPE functions"

if [ "$STATE_BACKEND" = "rocksdb" ];
then
  echo "Setting state backend to RocksDB"
  ./deployment/local/set-rocksdb-backend.sh
fi
if [ "$STATE_BACKEND" = "ndb" ];
then
  echo "Setting state backend to NDB"
  ./deployment/local/set-ndb-backend.sh
  if [ "$RECOVERY_METHOD" = "lazy" ];
  then
    echo "
      state.backend.ndb.lazyrecovery: true
      " >> deployment/flink/build/conf/flink-conf.yaml
  fi
fi

# Stop any running Flink Cluster components
./deployment/flink/build/bin/stop-cluster.sh
# Stop any running kafka/zookeeper containers
docker stop kafka
docker rm kafka
docker stop zookeeper
docker rm zookeeper
# Clear old Flink cluster logs

export BenchmarkJobName="BenchmarkJob: "

echo "${BenchmarkJobName}Starting Kafka..."
./kafka-cluster-tools/setup-kafka.sh
# Wait for startup
echo "${BenchmarkJobName}Waiting for Kafka startup..."
sleep 10

# Start Flink Cluster, expects Flink build to available at /deployment/flink/build
echo "${BenchmarkJobName}Starting Flink Cluster..."
./deployment/flink/build/bin/start-cluster.sh
# Wait for startup
echo "${BenchmarkJobName}Waiting for Flink startup..."
sleep 20

# Start StateFun-runtime
echo "${BenchmarkJobName}Starting StateFun runtime with ${FUNCTION_TYPE} functions..."

if [ "$FUNCTION_TYPE" = "embedded" ];
then
  ./deployment/flink/build/bin/flink run -c org.apache.flink.statefun.flink.core.StatefulFunctionsJob shoppingcart-embedded/target/shoppingcart-embedded-1.0-SNAPSHOT-jar-with-dependencies.jar &
else
  ./deployment/flink/build/bin/flink run -c org.apache.flink.statefun.flink.core.StatefulFunctionsJob shoppingcart-remote-module/target/shoppingcart-remote-module-1.0-SNAPSHOT-jar-with-dependencies.jar &
  java -cp shoppingcart-remote/target/shoppingcart-remote-1.0-SNAPSHOT-jar-with-dependencies.jar shoppingcart.remote.Expose &
fi

# Wait for startup
echo "${BenchmarkJobName}Waiting for StateFun startup..."
sleep 20

# Start data-stream-generator
echo "${BenchmarkJobName}Starting data-stream-generator..."
cd data-utils
python produce_events.py &
cd ..

# Let it run for 160 seconds
sleep 80

if [ $CRASH -eq 1 ]
then
  # Kill one task manager
  #./deployment/flink/build/bin/taskmanager.sh start
  echo "Killing one TaskManager..."
  #./deployment/flink/build/bin/taskmanager.sh stop
  tm_pid=`ps -ef | grep TaskManagerRunner | awk '{ print $2 }' | head -n 1`
  kill -9 $tm_pid
fi

sleep 80

# Stop data generator
echo "Stopping data stream generator"
pkill -f produce_events.py

echo "Stopping flink runtime"
# Stop Flink-runtime
./deployment/flink/build/bin/stop-cluster.sh
remote_pid=`ps -ef | grep shoppingcart.remote.Expose | awk '{ print $2 }' | head -n 1`
kill -9 $remote_pid

# Run output consumer
# Start data-stream-generator
echo "${BenchmarkJobName}Starting output consumer..."
cd data-utils
python output_consumer.py &
cd ..

# Run for 30 seconds
sleep 30

echo "${BenchmarkJobName}Stopping output consumer..."
# Stop output consumer
pkill -f output_consumer.py



