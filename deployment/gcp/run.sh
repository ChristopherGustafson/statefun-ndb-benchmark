#!/bin/bash

# Config variables

# GCP config
export GCP_IMAGE=ubuntu-minimal-2004-focal-v20220406
export GCP_IMAGE_PROJECT=ubuntu-os-cloud
export GCP_MACHINE_TYPE=e2-standard-2

# Kafka config
export KAFKA_NAME=kafka
export KAFKA_DOCKER_IMAGE=wurstmeister/kafka:2.12-2.1.1

# Flink config
export JOBMANAGER_NAME=jobmanager
export TASKMANAGER_NAME=taskmanager
# Set state backend, should be either 'ndb' or 'rocksdb'
export N_WORKERS="${1:-1}"
export STATE_BACKEND="${2:-"rocksdb"}"


# Other config
export DATA_UTILS_NAME=data-utils

echo "Running StateFun Rondb benchmark with $N_WORKERS TaskManagers"

# *
# ************** RONDB SETUP **************
# *
# echo "Running and setting up RonDB cluster"
# RONDB_ADDRESS=`gcloud compute instances describe statefun-benchmark-rondbhead --format='get(networkInterfaces[0].networkIP)'`

# *
# ************** KAFKA SETUP **************
# *
echo "Creating VM for Kafka"

gcloud compute instances create $KAFKA_NAME --image=$GCP_IMAGE --image-project=$GCP_IMAGE_PROJECT --machine-type=$GCP_MACHINE_TYPE --tags http-server,https-server
echo "Waiting for Kafka VM startup"
sleep 40

gcloud compute ssh $KAFKA_NAME -- bash -s < deployment/gcp/kafka-startup.sh &
export KAFKA_ADDRESS=`gcloud compute instances describe $KAFKA_NAME --format='get(networkInterfaces[0].networkIP)'`

# *
# ************** DATA UTILS SETUP **************
# *

echo "Creating VM for data utils"
gcloud compute instances create $DATA_UTILS_NAME --image=$GCP_IMAGE --image-project=$GCP_IMAGE_PROJECT --machine-type=$GCP_MACHINE_TYPE --tags http-server,https-server
echo "Waiting for Data Utils VM startup"
sleep 40

echo "[Config]
bootstrap.servers = $KAFKA_ADDRESS:9092
" > data-utils/config.properties
tar -czvf data-utils.tar.gz data-utils
gcloud compute scp data-utils.tar.gz $DATA_UTILS_NAME:~
gcloud compute ssh $DATA_UTILS_NAME -- bash -s < deployment/gcp/data-utils-startup.sh

# *
# ************** FLINK SETUP **************
# *

echo "Creating VM for JobManager"
gcloud compute instances create $JOBMANAGER_NAME --image=$GCP_IMAGE --image-project=$GCP_IMAGE_PROJECT --machine-type=$GCP_MACHINE_TYPE --tags http-server,https-server
JOBMANAGER_ADDRESS=`gcloud compute instances describe $JOBMANAGER_NAME --format='get(networkInterfaces[0].networkIP)'`
echo "Waiting for JobManager VM startup..."
sleep 40

echo "Packaging Flink Build"

if [ "$STATE_BACKEND" = "rocksdb" ];
then
  echo "Setting state backend to RocksDB"
  ./deployment/local/set-rocksdb-backend.sh
fi
if [ "$STATE_BACKEND" = "ndb" ];
then
  echo "Setting state backend to NDB"
  ./deployment/local/set-rocksdb-backend.sh
  echo "
  state.backend.ndb.connectionstring: $RONDB_ADDRESS
  " >> deployment/flink/build/conf/flink-conf.yaml
fi

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
  WORKER_NAME="$TASKMANAGER_NAME-$i"
  gcloud compute scp flink.tar.gz $WORKER_NAME:~
  gcloud compute ssh $WORKER_NAME -- bash -s < deployment/gcp/flink-utils/taskmanager_setup.sh
done

echo "Building StateFun job"
echo "bootstrap.servers=$KAFKA_ADDRESS:9092" > shoppingcart-embedded/src/main/resources/config.properties
(cd shoppingcart-embedded/;mvn clean package)

echo "Running StateFun runtime"
gcloud compute scp shoppingcart-embedded/target/shoppingcart-embedded-1.0-SNAPSHOT-jar-with-dependencies.jar $JOBMANAGER_NAME:~
gcloud compute ssh $JOBMANAGER_NAME -- bash -s < deployment/gcp/flink-utils/run_statefun.sh &
echo "Waiting for StateFun runtime startup"
sleep 30

# *
# ************** BENCHMARK RUN **************
# *
echo "Starting Data Generator"
gcloud compute ssh $DATA_UTILS_NAME -- bash -s < deployment/gcp/run-data-generator.sh
echo "Data Generator Finished"
#gcloud compute ssh $DATA_UTILS_NAME --command 'cd data-utils && nohup python3 produce_events.py &'
## Let it run for 60 seconds
#sleep 60
#echo "Stopping Data Generator"
#gcloud compute ssh $DATA_UTILS_NAME --command 'pkill -f produce_events.py'

echo "Starting Output Consumer"
gcloud compute ssh $DATA_UTILS_NAME -- bash -s < deployment/gcp/run-output-consumer.sh
echo "Output Consumer Finished"

#gcloud compute ssh $DATA_UTILS_NAME --command 'cd data-utils && python3 output_consumer.py' &
## Let it run for 60 seconds
#sleep 60
#echo "Stopping Output Consumer"
#gcloud compute ssh $DATA_UTILS_NAME --command 'pkill -f output_consumer.py'

# Copy data file to local
NOW="$(date +'%d-%m-%Y_%H_%M')"
mkdir -p output-data/$NOW/$STATE_BACKEND/
gcloud compute scp $DATA_UTILS_NAME:~/data-utils/output-data/data.json output-data/$NOW/$STATE_BACKEND/


# Clean up
echo "Deleting VM instances"
gcloud compute instances delete $JOBMANAGER_NAME --quiet
gcloud compute instances delete $KAFKA_NAME --quiet
gcloud compute instances delete $DATA_UTILS_NAME --quiet
for i in $(seq 1 $N_WORKERS);
do
  WORKER_NAME="$TASKMANAGER_NAME-$i"
  gcloud compute instances delete $WORKER_NAME --quiet
done
