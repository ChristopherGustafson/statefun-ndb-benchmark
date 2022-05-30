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
GCP_BUCKET_ADDRESS=gs://statefun-benchmark

FLINK_MACHINE_TYPE=e2-standard-2

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
# ************** FLINK SETUP **************
# *

echo "Creating VM for JobManager"
gcloud compute instances create $JOBMANAGER_NAME --image=$GCP_IMAGE --image-project=$GCP_IMAGE_PROJECT --machine-type=$FLINK_MACHINE_TYPE --tags http-server,https-server --scopes=storage-full,cloud-platform --service-account=$GCP_SERVICE_ACCOUNT
JOBMANAGER_ADDRESS=`gcloud compute instances describe $JOBMANAGER_NAME --format='get(networkInterfaces[0].networkIP)'`
echo "Waiting for JobManager VM startup..."
sleep 50

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
#jobmanager.memory.process.size: 16g
#taskmanager.memory.process.size: 16g
jobmanager.memory.process.size: 1600m
taskmanager.memory.process.size: 1728m
#taskmanager.memory.task.off-heap.size: 1g
#taskmanager.memory.framework.off-heap.size: 1g
parallelism.default: $PARALELLISM
state.savepoints.dir: gs://statefun-benchmark/savepoints
state.checkpoints.dir: gs://statefun-benchmark/checkpoints
execution.checkpointing.interval: 20sec
execution.checkpointing.min-pause: 20sec
metrics.reporter.slf4j.factory.class: org.apache.flink.metrics.slf4j.Slf4jReporterFactory
metrics.reporter.slf4j.interval: 1 SECONDS
" >> deployment/flink/build/conf/flink-conf.yaml
tar -C deployment/flink -czvf flink.tar.gz build

# Upload flink build to gs bucket
gsutil rm gs://statefun-benchmark/builds/flink.tar.gz
gsutil cp flink.tar.gz  gs://statefun-benchmark/builds/

echo "Setting up Flink JobManager"
#gcloud compute scp flink.tar.gz $JOBMANAGER_NAME:~
gcloud compute scp deployment/flink/build/conf/flink-conf.yaml $JOBMANAGER_NAME:~
gcloud compute ssh $JOBMANAGER_NAME -- bash -s < deployment/gcp/flink/jobmanager_setup.sh
