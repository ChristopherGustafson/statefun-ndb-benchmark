#!/bin/bash

# Config variables
export JOBMANAGER_NAME=statefun-benchmark-jobmanager
export TASKMANAGER_NAME=statefun-benchmark-taskmanager
export N_WORKERS="${1:-1}"
export GCP_IMAGE=ubuntu-minimal-2004-focal-v20220325
export GCP_IMAGE_PROJECT=ubuntu-os-cloud
export GCP_MACHINE_TYPE=e2-standard-2


echo "Running StateFun Rondb benchmark with $N_WORKERS TaskManagers"

# ************** RONDB SETUP **************
# echo "Running and setting up RonDB cluster"
# RONDB_ADDRESS=`gcloud compute instances describe statefun-benchmark-rondbhead --format='get(networkInterfaces[0].networkIP)'`

# ************** KAFKA SETUP **************

#KAFKA_ADDRESS="localhost:9092"
#
## Set kafka address in StateFun Job
#echo "bootstrap.servers=$KAFKA_ADDRESS" > shoppingcart-embedded/src/main/resources/config.properties

echo "Creating VM for JobManager"
gcloud compute instances create $JOBMANAGER_NAME --image=$GCP_IMAGE --image-project=$GCP_IMAGE_PROJECT --machine-type=$GCP_MACHINE_TYPE --tags http-server,https-server
JOBMANAGER_ADDRESS=`gcloud compute instances describe $JOBMANAGER_NAME --format='get(networkInterfaces[0].networkIP)'`

echo "Packaging Flink Build"
cp deployment/gcp/flink-utils/rocksdb_flink-conf.yaml.tmpl deployment/flink/build/conf/flink-conf.yaml
echo "
jobmanager.rpc.address: $JOBMANAGER_ADDRESS
parallelism.default: $N_WORKERS
state.savepoints.dir: file:///tmp/flinksavepoints
state.checkpoints.dir: file:///tmp/flinkcheckpoints
" >> deployment/flink/build/conf/flink-conf.yaml
tar -C deployment/flink -czvf flink.tar.gz build

echo "Setting up Flink JobManager"
sleep 10
gcloud compute scp flink.tar.gz $JOBMANAGER_NAME:~
gcloud compute ssh $JOBMANAGER_NAME -- bash -s < deployment/gcp/flink-utils/jobmanager_setup.sh

echo "Creating VMs for TaskManagers"
for i in $(seq 1 $N_WORKERS);
do
  WORKER_NAME="$TASKMANAGER_NAME-$i"
  echo "Setting up $WORKER_NAME"
  gcloud compute instances create $WORKER_NAME --image=$GCP_IMAGE --image-project=$GCP_IMAGE_PROJECT --machine-type=$GCP_MACHINE_TYPE --tags http-server,https-server
  # Sleep to let vm start properly
  sleep 10
  gcloud compute scp flink.tar.gz $WORKER_NAME:~
  gcloud compute ssh $WORKER_NAME -- bash -s < deployment/gcp/flink-utils/taskmanager_setup.sh
done

echo "Running StateFun runtime"
gcloud compute scp shoppingcart-embedded/target/shoppingcart-embedded-1.0-SNAPSHOT-jar-with-dependencies.jar $JOBMANAGER_NAME:~
gcloud compute ssh $JOBMANAGER_NAME -- bash -s < deployment/gcp/flink-utils/run_statefun.sh




