#!/bin/bash

# Setup java
sudo apt-get update
sudo apt-get -y install openjdk-8-jre
sudo apt-get clean

# Download kafka
wget https://dlcdn.apache.org/kafka/3.1.0/kafka_2.13-3.1.0.tgz
tar -xzf kafka_2.13-3.1.0.tgz
cd kafka_2.13-3.1.0

# Start ZK and Kafka
export KAFKA_ADDRESS=$(hostname -I | head -n1 | awk '{print $1;}'):9092

bin/zookeeper-server-start.sh config/zookeeper.properties &
bin/kafka-server-start.sh config/server.properties --override advertised.listeners=PLAINTEXT://$KAFKA_ADDRESS --override listeners=PLAINTEXT://$KAFKA_ADDRESS &

bin/kafka-topics.sh --create --topic "add-to-cart" --bootstrap-server $KAFKA_ADDRESS --partitions 8
bin/kafka-topics.sh --create --topic "checkout" --bootstrap-server $KAFKA_ADDRESS --partitions 8
bin/kafka-topics.sh --create --topic "restock" --bootstrap-server $KAFKA_ADDRESS --partitions 8
bin/kafka-topics.sh --create --topic "add-confirm" --bootstrap-server $KAFKA_ADDRESS --partitions 8
bin/kafka-topics.sh --create --topic "receipts" --bootstrap-server $KAFKA_ADDRESS --partitions 8
exit 0


