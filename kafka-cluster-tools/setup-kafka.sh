#! /bin/bash

# Start up Zookeeper
docker run -d \
--name zookeeper \
-p 2181:2181 \
jplock/zookeeper

# Start up Kafka
export IP_ADDR=$(hostname -I | head -n1 | awk '{print $1;}')
docker run -d \
  --name kafka \
	-p 9092:9092 \
	-e KAFKA_ADVERTISED_HOST_NAME=$IP_ADDR \
  	-e KAFKA_ADVERTISED_PORT="9092" \
	-e KAFKA_ZOOKEEPER_CONNECT=${IP_ADDR}:2181 \
	wurstmeister/kafka:2.12-2.1.1

sleep 10

docker run --rm -it \
	wurstmeister/kafka:2.12-2.1.1 ./opt/kafka_2.12-2.1.1/bin/kafka-topics.sh \
	--create --topic "add-to-cart" --partitions 4 --zookeeper ${IP_ADDR}:2181 \
  --replication-factor 1
docker run --rm -it \
	wurstmeister/kafka:2.12-2.1.1 ./opt/kafka_2.12-2.1.1/bin/kafka-topics.sh \
	--create --topic "checkout" --partitions 4 --zookeeper ${IP_ADDR}:2181 \
  --replication-factor 1
docker run --rm -it \
	wurstmeister/kafka:2.12-2.1.1 ./opt/kafka_2.12-2.1.1/bin/kafka-topics.sh \
	--create --topic "restock"  --partitions 4 --zookeeper ${IP_ADDR}:2181 \
  --replication-factor 1
docker run --rm -it \
	wurstmeister/kafka:2.12-2.1.1 ./opt/kafka_2.12-2.1.1/bin/kafka-topics.sh \
	--create --topic "add-confirm"  --partitions 4 --zookeeper ${IP_ADDR}:2181 \
  --replication-factor 1
docker run --rm -it \
	wurstmeister/kafka:2.12-2.1.1 ./opt/kafka_2.12-2.1.1/bin/kafka-topics.sh \
	--create --topic "receipts"  --partitions 4 --zookeeper ${IP_ADDR}:2181 \
	--replication-factor 1