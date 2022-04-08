#!/bin/bash

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
echo "${BenchmarkJobName}Starting StateFun runtime..."
./deployment/flink/build/bin/flink run -c org.apache.flink.statefun.flink.core.StatefulFunctionsJob shoppingcart-embedded/target/shoppingcart-embedded-1.0-SNAPSHOT-jar-with-dependencies.jar &
# Wait for startup
echo "${BenchmarkJobName}Waiting for StateFun startup..."
sleep 20

# Start data-stream-generator
echo "${BenchmarkJobName}Starting data-stream-generator..."
cd data-utils
python produce_events.py &
cd ..

# Let it run for 80 seconds
sleep 80

# Kill one task manager
#./deployment/flink/build/bin/taskmanager.sh start
echo "Killing one TaskManager..."
#./deployment/flink/build/bin/taskmanager.sh stop
tm_pid=`ps -ef | grep TaskManagerRunner | awk '{ print $2 }' | head -n 1`
kill -9 $tm_pid

# Run another 60 seconds
sleep 80

# Stop data generator
pkill -f produce_events.py

# Stop Flink-runtime
./deployment/flink/build/bin/stop-cluster.sh

# Run output consumer
# Start data-stream-generator
echo "${BenchmarkJobName}Starting data-stream-generator..."
cd data-utils
python output_consumer.py &
cd ..

# Run for 60 seconds
# Stop output consumer
pkill -f output_consumer.py



