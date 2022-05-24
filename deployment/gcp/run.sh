#!/bin/bash

# USAGE: run.sh <N_FLINK_WORKERS> <ndb OR rocksdb> <N_RONDB_WORKERS> <eager OR lazy> <embedded OR remote> <N_EVENTS_PER_SEC> <CRASH 0 or 1>

# Config variables

# General Config
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

FLINK_TASK_SLOTS=8

# User defined config
FLINK_WORKERS="${1:-1}"
STATE_BACKEND="${2:-"rocksdb"}"
RONDB_WORKERS="${3:-2}"
RECOVERY_METHOD="${4:-""}"
FUNCTION_TYPE="${5:-"embedded"}"
EVENTS_PER_SEC="${6:-"2000"}"
CRASH=${7:-0}

echo "Running StateFun Rondb benchmark with $FLINK_WORKERS TaskManagers, $STATE_BACKEND backend, $FUNCTION_TYPE functions ($RONDB_WORKERS RonDB workers if used), ($RECOVERY_METHOD recovery if used), $EVENTS_PER_SEC events per second, failure=$CRASH"

# *
# ************** KAFKA SETUP **************
# *
echo "Creating VM for Kafka"

gcloud compute instances create $KAFKA_NAME --image=$GCP_IMAGE --image-project=$GCP_IMAGE_PROJECT --machine-type=$GCP_MACHINE_TYPE --tags http-server,https-server --scopes=storage-full,cloud-platform --service-account=$GCP_SERVICE_ACCOUNT
echo "Waiting for Kafka VM startup"
sleep 40

gcloud compute ssh $KAFKA_NAME -- bash -s < deployment/gcp/kafka/kafka-startup.sh &
KAFKA_ADDRESS=`gcloud compute instances describe $KAFKA_NAME --format='get(networkInterfaces[0].networkIP)'`

# *
# ************** DATA UTILS SETUP **************
# *

echo "Creating VM for data utils"
gcloud compute instances create $DATA_UTILS_NAME --image=$GCP_IMAGE --image-project=$GCP_IMAGE_PROJECT --machine-type=$GCP_MACHINE_TYPE --tags http-server,https-server --scopes=storage-full,cloud-platform --service-account=$GCP_SERVICE_ACCOUNT
echo "Waiting for Data Utils VM startup"
sleep 40

rm -rf data-utils/output-data/
echo "[Config]
bootstrap.servers = $KAFKA_ADDRESS:9092
events_per_sec = $EVENTS_PER_SEC
" > data-utils/config.properties
tar -czvf data-utils.tar.gz data-utils
gcloud compute scp data-utils.tar.gz $DATA_UTILS_NAME:~
gcloud compute ssh $DATA_UTILS_NAME -- bash -s < deployment/gcp/data-utils/data-utils-startup.sh

# *
# ************** FLINK SETUP **************
# *

echo "Creating VM for JobManager"
gcloud compute instances create $JOBMANAGER_NAME --image=$GCP_IMAGE --image-project=$GCP_IMAGE_PROJECT --machine-type=$FLINK_MACHINE_TYPE --tags http-server,https-server --scopes=storage-full,cloud-platform --service-account=$GCP_SERVICE_ACCOUNT
JOBMANAGER_ADDRESS=`gcloud compute instances describe $JOBMANAGER_NAME --format='get(networkInterfaces[0].networkIP)'`
echo "Waiting for JobManager VM startup..."
sleep 40

echo "Packaging Flink Build"

if [ "$STATE_BACKEND" = "rocksdb" ];
then
  echo "Setting state backend to RocksDB"
  cp deployment/gcp/flink/rocksdb_flink-conf.yaml.tmpl deployment/flink/build/conf/flink-conf.yaml
fi
if [ "$STATE_BACKEND" = "ndb" ];
then
  echo "Setting state backend to NDB"
  cp deployment/gcp/flink/ndb_flink-conf.yaml.tmpl deployment/flink/build/conf/flink-conf.yaml
  echo "
state.backend.ndb.connectionstring: $RONDB_HEAD_ADDRESS
  " >> deployment/flink/build/conf/flink-conf.yaml
  if [ "$RECOVERY_METHOD" = "lazy" ];
  then
    echo "
state.backend.ndb.lazyrecovery: true
" >> deployment/flink/build/conf/flink-conf.yaml
  fi
fi

# For setting checkpoints directories, not setting will set flink to use JobManager Storage

PARALELLISM=$((FLINK_WORKERS * FLINK_TASK_SLOTS))

# CHANGE BACK MEMORY IF NEEDED
echo "
jobmanager.rpc.address: $JOBMANAGER_ADDRESS
taskmanager.numberOfTaskSlots: $FLINK_TASK_SLOTS
jobmanager.scheduler: adaptive
jobmanager.memory.process.size: 32g
taskmanager.memory.process.size: 32g
taskmanager.memory.task.off-heap.size: 1g
taskmanager.memory.framework.off-heap.size: 1g
parallelism.default: $PARALELLISM
state.savepoints.dir: gs://statefun-benchmark/savepoints
state.checkpoints.dir: gs://statefun-benchmark/checkpoints
execution.checkpointing.interval: 20sec
" >> deployment/flink/build/conf/flink-conf.yaml
tar -C deployment/flink -czvf flink.tar.gz build

echo "Setting up Flink JobManager"
gcloud compute scp flink.tar.gz $JOBMANAGER_NAME:~
gcloud compute ssh $JOBMANAGER_NAME -- bash -s < deployment/gcp/flink/jobmanager_setup.sh

echo "Creating VMs for TaskManagers"
for i in $(seq 1 $FLINK_WORKERS)
do
  WORKER_NAME="$TASKMANAGER_NAME-$i"
  echo "Setting up $WORKER_NAME"
  gcloud compute instances create $WORKER_NAME --image=$GCP_IMAGE --image-project=$GCP_IMAGE_PROJECT --machine-type=$FLINK_MACHINE_TYPE --tags http-server,https-server --scopes=storage-full,cloud-platform --service-account=$GCP_SERVICE_ACCOUNT
done

# Sleep to let vm start properly
sleep 40
echo "Initializing TaskManagers"
for i in $(seq 1 $FLINK_WORKERS)
do
  WORKER_NAME="$TASKMANAGER_NAME-$i"
  gcloud compute scp flink.tar.gz $WORKER_NAME:~
  gcloud compute ssh $WORKER_NAME -- bash -s < deployment/gcp/flink/taskmanager_setup.sh
done

echo "Building StateFun job using $FUNCTION_TYPE functions"
if [ "$FUNCTION_TYPE" = "embedded" ];
then
  echo "bootstrap.servers=$KAFKA_ADDRESS:9092" > shoppingcart-embedded/src/main/resources/config.properties
  (cd shoppingcart-embedded/;mvn clean package)

  echo "Running StateFun runtime"
  gcloud compute scp shoppingcart-embedded/target/shoppingcart-embedded-1.0-SNAPSHOT-jar-with-dependencies.jar $JOBMANAGER_NAME:~
  gcloud compute ssh $JOBMANAGER_NAME -- bash -s < deployment/gcp/flink/run_statefun_embedded.sh &
else
  echo "Creating VM for remote functions"
  gcloud compute instances create $REMOTE_FUNCTIONS_NAME --image=$GCP_IMAGE --image-project=$GCP_IMAGE_PROJECT --machine-type=$FLINK_MACHINE_TYPE --tags http-server,https-server
  sleep 40
  REMOTE_FUNCTIONS_ADDRESS=`gcloud compute instances describe $REMOTE_FUNCTIONS_NAME --format='get(networkInterfaces[0].networkIP)'`

  echo "bootstrap.servers=$KAFKA_ADDRESS:9092" > shoppingcart-remote/src/main/resources/config.properties
  echo "bootstrap.servers=$KAFKA_ADDRESS:9092" > shoppingcart-remote-module/src/main/resources/config.properties
  echo "kind: io.statefun.endpoints.v2/http
spec:
  functions: shoppingcart-remote/*
  urlPathTemplate: http://$REMOTE_FUNCTIONS_ADDRESS:1108/
  transport:
    type: io.statefun.transports.v1/async
---
kind: io.statefun.kafka.v1/egress
spec:
  id: shoppingcart-remote/add-confirm
  address: $KAFKA_ADDRESS:9092
  deliverySemantic:
    type: exactly-once
    transactionTimeout: 15min
#  properties:
#    - transaction.timeout.ms: 7200000
---
kind: io.statefun.kafka.v1/egress
spec:
  id: shoppingcart-remote/receipt
  address: $KAFKA_ADDRESS:9092
  deliverySemantic:
    type: exactly-once
    transactionTimeout: 15min
#  properties:
#    - transaction.timeout.ms: 7200000
" > shoppingcart-remote-module/src/main/resources/module.yaml
  (cd shoppingcart-remote/;mvn clean package)
  (cd shoppingcart-remote-module/;mvn clean package)

  echo "Running remote functions"
  gcloud compute scp shoppingcart-remote/target/shoppingcart-remote-1.0-SNAPSHOT-jar-with-dependencies.jar $REMOTE_FUNCTIONS_NAME:~
  gcloud compute ssh $REMOTE_FUNCTIONS_NAME -- bash -s < deployment/gcp/flink/remote_functions_setup.sh &
  sleep 30

  echo "Running StateFun runtime"
  gcloud compute scp shoppingcart-remote-module/target/shoppingcart-remote-module-1.0-SNAPSHOT-jar-with-dependencies.jar $JOBMANAGER_NAME:~
  gcloud compute ssh $JOBMANAGER_NAME -- bash -s < deployment/gcp/flink/run_statefun_remote.sh &
fi
echo "Waiting for StateFun runtime startup"
sleep 30


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

mv output-data/$NOW/ /media/farah/ce8e52bc-a47a-4fb7-b504-390efd9006ff/christopher/benchmark-data/