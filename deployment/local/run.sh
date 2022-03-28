#!/bin/bash

# Stop any running Flink Cluster components
./deployment/flink/build/bin/stop-cluster.sh
# Stop any running kafka/zookeeper containers
docker stop kafka
docker rm kafka
docker stop zookeeper
docker rm zookeeper

export BenchmarkJobName="BenchmarkJob: "

echo "${BenchmarkJobName}Starting Kafka..."
./kafka-cluster-tools/setup-kafka.sh

# Start Flink Cluster, expects Flink build to available at /deployment/flink/build
echo "${BenchmarkJobName}Starting Flink Cluster..."
./deployment/flink/build/bin/start-cluster.sh
# Wait for startup
sleep 10

# Start StateFun-runtime
echo "${BenchmarkJobName}Starting StateFun runtime..."
./deployment/flink/build/bin/flink run -c org.apache.flink.statefun.flink.core.StatefulFunctionsJob shoppingcart-embedded/target/shoppingcart-embedded-1.0-SNAPSHOT-jar-with-dependencies.jar &
# Wait for startup
sleep 10

# Start data-stream-generator
echo "${BenchmarkJobName}Starting data-stream-generator..."
cd data-stream-generator
source ./setEnvVariables.sh
sbt run
cd ..

# Stop Flink-runtime
./deployment/flink/build/bin/stop-cluster.sh

# Run output consumer
echo "${BenchmarkJobName}Starting output consumer..."
cd output-consumer
source ./setEnvVariables.sh
sbt run


