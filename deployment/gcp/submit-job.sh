#!/bin/bash

# Script for submitting StateFun Job to running Flink Cluster.

NAME_PREFIX=statefun-benchmark-

USER=`whoami`

# GCP config
GCP_IMAGE=ubuntu-minimal-2004-focal-v20220419a
GCP_IMAGE_PROJECT=ubuntu-os-cloud
GCP_MACHINE_TYPE=n2-standard-4
GCP_SERVICE_ACCOUNT=christopher@hops-20.iam.gserviceaccount.com

FLINK_MACHINE_TYPE=n2-standard-16

# RonDB config
HEAD_INSTANCE_TYPE=n2-standard-2
DATA_NODE_INSTANCE_TYPE=n2-standard-2
API_NODE_INSTANCE_TYPE=n2-standard-2

# Kafka config
KAFKA_NAME=${NAME_PREFIX}kafka

# Flink config
JOBMANAGER_NAME=${NAME_PREFIX}jobmanager
TASKMANAGER_NAME=${NAME_PREFIX}taskmanager
REMOTE_FUNCTIONS_NAME=${NAME_PREFIX}remote-functions

# Data utils config
DATA_UTILS_NAME=${NAME_PREFIX}data-utils

# User defined config
FLINK_WORKERS="${1:-1}"
STATE_BACKEND="${2:-"rocksdb"}"
RONDB_WORKERS="${3:-2}"
RECOVERY_METHOD="${4:-""}"
FUNCTION_TYPE="${5:-"embedded"}"
EVENTS_PER_SEC="${6:-"2000"}"
CRASH=${7:-0}

KAFKA_ADDRESS=`gcloud compute instances describe $KAFKA_NAME --format='get(networkInterfaces[0].networkIP)'`


#echo "Building StateFun job using $FUNCTION_TYPE functions"
#if [ "$FUNCTION_TYPE" = "embedded" ];
#then
#  echo "bootstrap.servers=$KAFKA_ADDRESS:9092" > shoppingcart-embedded/src/main/resources/config.properties
#  (cd shoppingcart-embedded/;mvn clean package)
#
#  echo "Running StateFun runtime"
#  gcloud compute scp shoppingcart-embedded/target/shoppingcart-embedded-1.0-SNAPSHOT-jar-with-dependencies.jar $JOBMANAGER_NAME:~
#  gcloud compute ssh $JOBMANAGER_NAME -- bash -s < deployment/gcp/flink/run_statefun_embedded.sh &
#else
#  echo "Creating VM for remote functions"
#  gcloud compute instances create $REMOTE_FUNCTIONS_NAME --image=$GCP_IMAGE --image-project=$GCP_IMAGE_PROJECT --machine-type=$FLINK_MACHINE_TYPE --tags http-server,https-server
#  sleep 40
#  REMOTE_FUNCTIONS_ADDRESS=`gcloud compute instances describe $REMOTE_FUNCTIONS_NAME --format='get(networkInterfaces[0].networkIP)'`
#
#  echo "bootstrap.servers=$KAFKA_ADDRESS:9092" > shoppingcart-remote/src/main/resources/config.properties
#  echo "bootstrap.servers=$KAFKA_ADDRESS:9092" > shoppingcart-remote-module/src/main/resources/config.properties
#  echo "kind: io.statefun.endpoints.v2/http
#spec:
#  functions: shoppingcart-remote/*
#  urlPathTemplate: http://$REMOTE_FUNCTIONS_ADDRESS:1108/
#  transport:
#    type: io.statefun.transports.v1/async
#---
#kind: io.statefun.kafka.v1/egress
#spec:
#  id: shoppingcart-remote/add-confirm
#  address: $KAFKA_ADDRESS:9092
#  deliverySemantic:
#    type: exactly-once
#    transactionTimeout: 15min
##  properties:
##    - transaction.timeout.ms: 7200000
#---
#kind: io.statefun.kafka.v1/egress
#spec:
#  id: shoppingcart-remote/receipt
#  address: $KAFKA_ADDRESS:9092
#  deliverySemantic:
#    type: exactly-once
#    transactionTimeout: 15min
##  properties:
##    - transaction.timeout.ms: 7200000
#" > shoppingcart-remote-module/src/main/resources/module.yaml
#  (cd shoppingcart-remote/;mvn clean package)
#  (cd shoppingcart-remote-module/;mvn clean package)
#
#  echo "Running remote functions"
#  gcloud compute scp shoppingcart-remote/target/shoppingcart-remote-1.0-SNAPSHOT-jar-with-dependencies.jar $REMOTE_FUNCTIONS_NAME:~
#  gcloud compute ssh $REMOTE_FUNCTIONS_NAME -- bash -s < deployment/gcp/flink/remote_functions_setup.sh &
#  sleep 30
#
#  echo "Running StateFun runtime"
#  gcloud compute scp shoppingcart-remote-module/target/shoppingcart-remote-module-1.0-SNAPSHOT-jar-with-dependencies.jar $JOBMANAGER_NAME:~
#  gcloud compute ssh $JOBMANAGER_NAME -- bash -s < deployment/gcp/flink/run_statefun_remote.sh &
#fi
#echo "Waiting for StateFun runtime startup"
#sleep 30

# *
# ************** BENCHMARK RUN **************
# *
#
echo "Starting benchmark run"
gcloud compute ssh $DATA_UTILS_NAME -- bash -s < deployment/gcp/data-utils/run-benchmark-events.sh &
sleep 10
echo "Letting benchmark run for 600 seconds"
sleep 600
echo "Stopping event producer and waiting for final messages to be processed"
gcloud compute ssh $DATA_UTILS_NAME -- pkill -f produce_events.py
sleep 30
gcloud compute ssh $DATA_UTILS_NAME -- pkill -f output_consumer_confluent.py


# Copy data file to local, clean up last line in case it is malformed
NOW="$(date +'%d-%m-%Y_%H:%M')"
CURRENT_PATH=`pwd`
mkdir -p output-data/$NOW/
gcloud compute scp $DATA_UTILS_NAME:~/data-utils/output-data/data.json output-data/$NOW/${STATE_BACKEND}-${RECOVERY_METHOD}-${FLINK_WORKERS}-workers-${FUNCTION_TYPE}-${EVENTS_PER_SEC}.json
gcloud compute scp $JOBMANAGER_NAME:~/build/log/flink-$USER-standalonesession-0-statefun-benchmark-jobmanager.log output-data/$NOW/jobmanager.log
gcloud compute scp $DATA_UTILS_NAME:~/data-utils/event_producer.log output-data/$NOW/event_producer.log
gcloud compute scp $DATA_UTILS_NAME:~/data-utils/output_consumer.log output-data/$NOW/output_consumer.log
./output-data/trim-last-line.sh output-data/$NOW/${STATE_BACKEND}-${RECOVERY_METHOD}-${FLINK_WORKERS}-workers-${FUNCTION_TYPE}-${EVENTS_PER_SEC}.json

for i in $(seq 1 $FLINK_WORKERS);
do
 WORKER_NAME="$TASKMANAGER_NAME-$i"
 gcloud compute scp $WORKER_NAME:~/build/log/flink-$USER-taskexecutor-0-statefun-benchmark-taskmanager-${i}.out output-data/$NOW/taskmanager-${i}.out
 gcloud compute scp $WORKER_NAME:~/builfd/log/flink-$USER-taskexecutor-0-statefun-benchmark-taskmanager-${i}.log output-data/$NOW/taskmanager-${i}.log
 gcloud compute scp $WORKER_NAME:~/build/log/flink-$USER-taskexecutor-0-statefun-benchmark-taskmanager-${i}.log.1 output-data/$NOW/taskmanager-${i}.log.1
 gcloud compute scp $WORKER_NAME:~/build/log/flink-$USER-taskexecutor-0-statefun-benchmark-taskmanager-${i}.log.2 output-data/$NOW/taskmanager-${i}.log.2
 gcloud compute scp $WORKER_NAME:~/build/log/flink-$USER-taskexecutor-0-statefun-benchmark-taskmanager-${i}.log.3 output-data/$NOW/taskmanager-${i}.log.3
 gcloud compute instances delete $WORKER_NAME --quiet
done
