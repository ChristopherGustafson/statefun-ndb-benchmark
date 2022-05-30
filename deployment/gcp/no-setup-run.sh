#!/bin/bash

# USAGE: run.sh <N_FLINK_WORKERS> <ndb OR rocksdb> <N_RONDB_WORKERS> <eager OR lazy> <embedded OR remote> <N_EVENTS_PER_SEC> <CRASH 0 or 1>

# Config variables

# General Config
NAME_PREFIX=statefun-benchmark-

USER=`whoami`

# GCP config
GCP_IMAGE=ubuntu-minimal-2004-focal-v20220419a
GCP_IMAGE_PROJECT=ubuntu-os-cloud
GCP_MACHINE_TYPE=e2-standard-4
GCP_SERVICE_ACCOUNT=christopher@hops-20.iam.gserviceaccount.com
GCP_BUCKET_ADDRESS=gs://statefun-benchmark

FLINK_MACHINE_TYPE=n2-standard-4

REMOTE_MACHINE_TYPE=n2-standard-16

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

FLINK_TASK_SLOTS=2

# User defined config
FLINK_WORKERS="${1:-1}"
STATE_BACKEND="${2:-"rocksdb"}"
RONDB_WORKERS="${3:-2}"
RECOVERY_METHOD="${4:-""}"
FUNCTION_TYPE="${5:-"embedded"}"
EVENTS_PER_SEC="${6:-"2000"}"
CRASH=${7:-0}

if [ "$STATE_BACKEND" = "ndb" ];
then
  RONDB_HEAD_NAME=${NAME_PREFIX}head
  RONDB_API_NAME=${NAME_PREFIX}api00
  RONDB_DATA_NAME=${NAME_PREFIX}cpu00

  RONDB_HEAD_ADDRESS=`gcloud compute instances describe $RONDB_HEAD_NAME --format='get(networkInterfaces[0].networkIP)'`
  RONDB_API_ADDRESS=`gcloud compute instances describe $RONDB_API_NAME --format='get(networkInterfaces[0].networkIP)'`
  RONDB_DATA_ADDRESS=`gcloud compute instances describe $RONDB_DATA_NAME --format='get(networkInterfaces[0].networkIP)'`
fi

# *
# ************** BENCHMARK RUN **************
# *

echo "Starting Output Consumer"
gcloud compute ssh $DATA_UTILS_NAME -- bash -s < deployment/gcp/data-utils/run-output-consumer.sh &

echo "Starting Data Generator"
gcloud compute ssh $DATA_UTILS_NAME -- bash -s < deployment/gcp/data-utils/run-data-generator.sh
echo "Data Generator Finished"


echo "Waiting to make sure all events are consumed"
sleep 300
echo "Output Consumer Finished"

# Copy data file to local, clean up last line in case it is malformed
NOW="$(date +'%d-%m-%Y_%H:%M')"
CURRENT_PATH=`pwd`
mkdir -p output-data/$NOW/
gcloud compute scp $DATA_UTILS_NAME:~/data-utils/output-data/data.json output-data/$NOW/${STATE_BACKEND}-${RECOVERY_METHOD}-${FLINK_WORKERS}-workers-${FUNCTION_TYPE}-${EVENTS_PER_SEC}.json
gcloud compute scp $JOBMANAGER_NAME:~/build/log/flink-$USER-standalonesession-0-statefun-benchmark-jobmanager.log output-data/$NOW/jobmanager.log
gcloud compute scp $DATA_UTILS_NAME:~/data-utils/event_producer.log output-data/$NOW/event_producer.log
gcloud compute scp $DATA_UTILS_NAME:~/data-utils/output_consumer.log output-data/$NOW/output_consumer.log
./output-data/trim-last-line.sh output-data/$NOW/${STATE_BACKEND}-${RECOVERY_METHOD}-${FLINK_WORKERS}-workers-${FUNCTION_TYPE}-${EVENTS_PER_SEC}.json

# Clean up
echo "Deleting VM instances"
gcloud compute instances delete $JOBMANAGER_NAME --quiet
gcloud compute instances delete $KAFKA_NAME --quiet
gcloud compute instances delete $DATA_UTILS_NAME --quiet
gcloud compute instances delete $REMOTE_FUNCTIONS_NAME --quiet
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

#mv output-data/$NOW/ /media/farah/ce8e52bc-a47a-4fb7-b504-390efd9006ff/christopher/benchmark-data/