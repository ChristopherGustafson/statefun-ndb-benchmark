#!/bin/bash

# Stop Flink cluster
./deployment/flink/build/bin/stop-cluster.sh

# Stop kafka containers
docker stop kafka
docker rm kafka
docker stop zookeeper
docker rm zookeeper

pkill -f produce_events.py
pkill -f output_consumer.py
pkill -f output_consumer_confluent.py

remote_pid=`ps -ef | grep shoppingcart.remote.Expose | awk '{ print $2 }' | head -n 1`
kill -9 $remote_pid