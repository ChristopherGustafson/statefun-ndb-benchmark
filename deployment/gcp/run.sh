#!/bin/bash

# Config variables
export JOBMANAGER_NAME=statefun-benchmark-jobmanager
export TASKMANAGER_NAME=statefun-benchmark-taskmanager
export KAFKA_NAME=statefun-benchmark-kafka
export KAFKA_DOCKER_IMAGE=wurstmeister/kafka:2.12-2.1.1
export ZK_DOCKER_IMAGE=jplock/zookeeper
export N_WORKERS="${1:-1}"
export GCP_IMAGE=ubuntu-minimal-2004-focal-v20220406
export GCP_IMAGE_PROJECT=ubuntu-os-cloud
export GCP_MACHINE_TYPE=e2-standard-2

export COS_IMAGE=cos-stable-97-16919-29-5
export COS_IMAGE_PROJECT=cos-project

echo "Running StateFun Rondb benchmark with $N_WORKERS TaskManagers"

# ************** RONDB SETUP **************
# echo "Running and setting up RonDB cluster"
# RONDB_ADDRESS=`gcloud compute instances describe statefun-benchmark-rondbhead --format='get(networkInterfaces[0].networkIP)'`

# ************** KAFKA SETUP **************
echo "Creating VM for Kafka"

gcloud compute instances create $KAFKA_NAME --image=$GCP_IMAGE --image-project=$GCP_IMAGE_PROJECT --machine-type=$GCP_MACHINE_TYPE --tags http-server,https-server
echo "Waiting for Kafka VM startup"
sleep 40

gcloud compute ssh $KAFKA_NAME -- bash -s < deployment/gcp/kafka-startup.sh &

# ************** FLINK SETUP **************
echo "Creating VM for JobManager"
gcloud compute instances create $JOBMANAGER_NAME --image=$GCP_IMAGE --image-project=$GCP_IMAGE_PROJECT --machine-type=$GCP_MACHINE_TYPE --tags http-server,https-server
JOBMANAGER_ADDRESS=`gcloud compute instances describe $JOBMANAGER_NAME --format='get(networkInterfaces[0].networkIP)'`
echo "Waiting for JobManager VM startup..."
sleep 40

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
gcloud compute scp flink.tar.gz $JOBMANAGER_NAME:~
gcloud compute ssh $JOBMANAGER_NAME -- bash -s < deployment/gcp/flink-utils/jobmanager_setup.sh

echo "Creating VMs for TaskManagers"
for i in $(seq 1 $N_WORKERS)
do
  WORKER_NAME="$TASKMANAGER_NAME-$i"
  echo "Setting up $WORKER_NAME"
  gcloud compute instances create $WORKER_NAME --image=$GCP_IMAGE --image-project=$GCP_IMAGE_PROJECT --machine-type=$GCP_MACHINE_TYPE --tags http-server,https-server
done

# Sleep to let vm start properly
sleep 40
echo "Initializing TaskManagers"
for i in $(seq 1 $N_WORKERS)
do
  gcloud compute scp flink.tar.gz $WORKER_NAME:~
  gcloud compute ssh $WORKER_NAME -- bash -s < deployment/gcp/flink-utils/taskmanager_setup.sh
done

export KAFKA_ADDRESS=`gcloud compute instances describe $KAFKA_NAME --format='get(networkInterfaces[0].networkIP)'`
echo "Building StateFun job"
echo "bootstrap.servers=$KAFKA_ADDRESS:9092" > shoppingcart-embedded/src/main/resources/config.properties
(cd shoppingcart-embedded/;mvn clean package)

echo "Running StateFun runtime"
gcloud compute scp shoppingcart-embedded/target/shoppingcart-embedded-1.0-SNAPSHOT-jar-with-dependencies.jar $JOBMANAGER_NAME:~
gcloud compute ssh $JOBMANAGER_NAME -- bash -s < deployment/gcp/flink-utils/run_statefun.sh

# Clean up
#echo "Deleting VM instances"
#gcloud compute instances delete $JOBMANAGER_NAME
#for i in $(seq 1 $N_WORKERS);
#do
#  WORKER_NAME="$TASKMANAGER_NAME-$i"
#  gcloud compute instances delete $WORKER_NAME
#end
