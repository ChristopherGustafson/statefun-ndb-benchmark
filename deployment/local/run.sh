#!/bin/bash

# User configs
export STATE_BACKEND="${1:-"ndb"}"
export CRASH=${2:-0}
export RECOVERY_METHOD="${3:-"eager"}"
export FUNCTION_TYPE="${4:-"embedded"}"

echo "Running local benchmark with $STATE_BACKEND backend, crashing=$CRASH, $RECOVERY_METHOD recovery and $FUNCTION_TYPE functions"
touch crashed.txt

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
rm -v deployment/flink/build/log/*

# Stop any running Flink Cluster components
./deployment/flink/build/bin/stop-cluster.sh
# Stop any running kafka/zookeeper containers
./deployment/local/stop-services.sh
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

echo "${BenchmarkJobName}Building StateFun Job..."
if [ "$FUNCTION_TYPE" = "embedded" ];
then
  echo "Building embedded StateFun job..."
  (cd shoppingcart-embedded-simple/;mvn clean package)
else
  echo "Building remote StateFun Module..."
  (cd shoppingcart-remote-module/;mvn clean package)

  echo "Building remote StateFun Functions..."
  (cd shoppingcart-remote/;mvn clean package)
fi


# Start StateFun-runtime
echo "${BenchmarkJobName}Starting StateFun runtime with ${FUNCTION_TYPE} functions..."

if [ "$FUNCTION_TYPE" = "embedded" ];
then
  ./deployment/flink/build/bin/flink run -c org.apache.flink.statefun.flink.core.StatefulFunctionsJob shoppingcart-embedded-simple/target/shoppingcart-embedded-1.0-SNAPSHOT-jar-with-dependencies.jar &
else
  ./deployment/flink/build/bin/flink run -c org.apache.flink.statefun.flink.core.StatefulFunctionsJob shoppingcart-remote-module/target/shoppingcart-remote-module-1.0-SNAPSHOT-jar-with-dependencies.jar &
  rm nohup.out
  nohup java -cp shoppingcart-remote/target/shoppingcart-remote-1.0-SNAPSHOT-jar-with-dependencies.jar shoppingcart.remote.Expose &
fi

# Wait for startup
echo "${BenchmarkJobName}Waiting for StateFun startup..."
sleep 20

# Start data-stream-generator
echo "${BenchmarkJobName}Starting data-stream-generator..."
cd data-utils
rm event_producer.log
nohup python3 -u produce_events.py > event_producer.log &
cd ..

# Start output-consumer
echo "${BenchmarkJobName}Starting output consumer..."
cd data-utils
rm -rf output-data
rm output_consumer.log
nohup python3 -u output_consumer_confluent.py > output_consumer.log &
cd ..

# Let it run for 160 seconds
sleep 130

if [ $CRASH -eq 1 ]
then
  # Kill one task manager
  #./deployment/flink/build/bin/taskmanager.sh start
  echo "Killing one TaskManager..."
  #./deployment/flink/build/bin/taskmanager.sh stop
  tm_pid=`ps -ef | grep TaskManagerRunner | awk '{ print $2 }' | head -n 1`
  kill -9 $tm_pid
fi

sleep 30

# Stop data generator
echo "Stopping data stream generator"
pkill -f produce_events.py

echo "Waiting to process last messages"
sleep 100

echo "Stopping flink runtime"
# Stop Flink-runtime
./deployment/flink/build/bin/stop-cluster.sh
remote_pid=`ps -ef | grep shoppingcart.remote.Expose | awk '{ print $2 }' | head -n 1`
kill -9 $remote_pid

echo "${BenchmarkJobName}Stopping output consumer..."
# Stop output consumer
pkill -f output_consumer.py


NOW="$(date +'%d-%m-%Y_%H:%M')"
mkdir -p output-data/local/$NOW/${STATE_BACKEND}-${RECOVERY_METHOD}-${FUNCTION_TYPE}
mv data-utils/output-data/data.json output-data/local/$NOW/${STATE_BACKEND}-${RECOVERY_METHOD}-${FUNCTION_TYPE}
./output-data/trim-last-line.sh output-data/local/$NOW/${STATE_BACKEND}-${RECOVERY_METHOD}-${FUNCTION_TYPE}/data.json
