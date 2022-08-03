#!/bin/bash

# USAGE: run.sh <N_FLINK_WORKERS> <ndb OR rocksdb> <N_RONDB_WORKERS> <eager OR lazy> <embedded OR remote> <N_EVENTS_PER_SEC> <CRASH 0 or 1>

# Config variables

# General Config

USER=`whoami`

# GCP config
GCP_IMAGE=ubuntu-minimal-2004-focal-v20220419a
GCP_IMAGE_PROJECT=ubuntu-os-cloud
GCP_MACHINE_TYPE=n2-standard-16
#GCP_SERVICE_ACCOUNT=376111349699-compute@developer.gserviceaccount.com
GCP_SERVICE_ACCOUNT=christopher@hops-20.iam.gserviceaccount.com
GCP_BUCKET_ADDRESS=gs://statefun-benchmark

VM_NAME=statefun-benchmark

# User defined config
STATE_BACKEND="${1:-"rocksdb"}"
RECOVERY_METHOD="${2:-"lazy"}"
EVENTS_BEFORE_CRASH="${3:-"8000000"}"

echo "Running StateFun Rondb benchmark with $STATE_BACKEND backend, processing $EVENTS_BEFORE_CRASH events before crashing"

if [ "$STATE_BACKEND" = "ndb" ];
then
  ./deployment/gcp/rondb/run-rondb.sh
  RONDB_HEAD_NAME=statefun-benchmark-head
  RONDB_HEAD_ADDRESS=`gcloud compute instances describe $RONDB_HEAD_NAME --format='get(networkInterfaces[0].networkIP)'`
fi
echo "
backend=$STATE_BACKEND
events=$EVENTS_BEFORE_CRASH
ndb.connectionstring=$RONDB_HEAD_ADDRESS
gcp.bucket.name=$GCP_BUCKET_ADDRESS
recovery=$RECOVERY_METHOD
"
echo "
backend=$STATE_BACKEND
events=$EVENTS_BEFORE_CRASH
ndb.connectionstring=$RONDB_HEAD_ADDRESS
gcp.bucket.name=$GCP_BUCKET_ADDRESS
recovery=$RECOVERY_METHOD
" > harness-benchmark/src/main/resources/config.properties

# *
# ************** PACKAGE BUILD **************
# *
(cd harness-benchmark/;mvn clean package -o)

# *
# ************** VM SETUP **************
# *
gcloud compute instances create $VM_NAME --image=$GCP_IMAGE --image-project=$GCP_IMAGE_PROJECT --machine-type=$GCP_MACHINE_TYPE --tags http-server,https-server --scopes=storage-full,cloud-platform --service-account=$GCP_SERVICE_ACCOUNT --boot-disk-size=64G
sleep 50

# *
# ************** STATEFUN SETUP **************
# *
gcloud compute scp harness-benchmark/target/harness-benchmark-1.0-SNAPSHOT-jar-with-dependencies.jar $VM_NAME:~
gcloud compute ssh $VM_NAME -- bash -s < deployment/harness-benchmark/vm-setup.sh


#sleep 100
#VM_NAME=statefun-benchmark
## Copy data file to local
#NOW="$(date +'%d-%m-%Y_%H:%M')"
#CURRENT_PATH=`pwd`
#mkdir -p output-data/$NOW/
#gcloud compute scp $VM_NAME:~/output.log output-data/$NOW/output.log

## Clean up VM
#gcloud compute instances delete $VM_NAME --quiet
#
#
