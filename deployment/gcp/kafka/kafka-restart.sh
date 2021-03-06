#!/bin/bash

# Stop running Kafka Session
cd kafka_2.13-3.1.0
bin/zookeeper-server-stop.sh
bin/kafka-server-stop.sh
cd ..

# Delete old kafka folder
sudo su
rm -r kafka_2.13-3.1.0
rm kafka_2.13-3.1.0.tgz
rm -rf /tmp/kafka-logs

# Download new kafka
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