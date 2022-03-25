#!/bin/bash

# Stop Flink cluster
./deployment/flink/build/bin/stop-cluster.sh

# Stop kafka containers
docker stop kafka
docker rm kafka
docker stop zookeeper
docker rm zookeeper

