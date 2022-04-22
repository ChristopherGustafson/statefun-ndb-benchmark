#!/bin/bash

# USAGE: run.sh <N_FLINK_WORKERS> <ndb OR rocksdb> <N_RONDB_WORKERS> <eager OR lazy> <embedded OR remote>

# Config variables

# General Config
export NAME_PREFIX=statefun-benchmark-

# GCP config
export GCP_IMAGE=ubuntu-minimal-2004-focal-v20220406
export GCP_IMAGE_PROJECT=ubuntu-os-cloud
export GCP_MACHINE_TYPE=n2-standard-4

# RonDB config
export HEAD_INSTANCE_TYPE=n2-standard-2
export DATA_NODE_INSTANCE_TYPE=n2-standard-2
export API_NODE_INSTANCE_TYPE=n2-standard-2
# Kafka config
export KAFKA_NAME=${NAME_PREFIX}kafka
export KAFKA_DOCKER_IMAGE=wurstmeister/kafka:2.12-2.1.1

# Flink config
export JOBMANAGER_NAME=${NAME_PREFIX}jobmanager
export TASKMANAGER_NAME=${NAME_PREFIX}taskmanager
export REMOTE_FUNCTIONS_NAME=${NAME_PREFIX}remote-functions

# Data utils config
export DATA_UTILS_NAME=${NAME_PREFIX}data-utils

# User defined config
export FLINK_WORKERS="${1:-1}"
export STATE_BACKEND="${2:-"rocksdb"}"
export RONDB_WORKERS="${3:-2}"
export RECOVERY_METHOD="${4:-""}"
export FUNCTION_TYPE="${5:-"embedded"}"
export EVENTS_PER_SEC="${6:-"1000"}"

echo "Running StateFun Rondb benchmark with $FLINK_WORKERS TaskManagers, $STATE_BACKEND backend ($RONDB_WORKERS RonDB workers if used), ($RECOVERY_METHOD recovery if used)"

# *
# ************** RONDB SETUP **************
# *
if [ "$STATE_BACKEND" = "ndb" ];
then
#  echo "Running and setting up RonDB cluster"
#  ./deployment/gcp/rondb/rondb-cloud-installer.sh \
#  --non-interactive \
#  --cloud gcp \
#  --install-action cluster \
#  --vm-name-prefix $NAME_PREFIX \
#  --gcp-head-instance-type $HEAD_INSTANCE_TYPE \
#  --gcp-data-node-instance-type $DATA_NODE_INSTANCE_TYPE \
#  --gcp-api-node-instance-type $API_NODE_INSTANCE_TYPE \
#  --num-data-nodes RONDB_WORKERS \
#  --num-api-nodes 1 \
#  --num-replicas 2 \
#  --availability-zone 3 \
#  --database-node-boot-size 256

  RONDB_HEAD_NAME=${NAME_PREFIX}head
  RONDB_API_NAME=${NAME_PREFIX}api00
  RONDB_DATA_NAME=${NAME_PREFIX}cpu00

  RONDB_HEAD_ADDRESS=`gcloud compute instances describe $RONDB_HEAD_NAME --format='get(networkInterfaces[0].networkIP)'`
  RONDB_API_ADDRESS=`gcloud compute instances describe $RONDB_API_NAME --format='get(networkInterfaces[0].networkIP)'`
  RONDB_DATA_ADDRESS=`gcloud compute instances describe $RONDB_DATA_NAME --format='get(networkInterfaces[0].networkIP)'`
#
#  sleep 300
#  gcloud compute scp deployment/gcp/rondb/init_db.sql $RONDB_API_NAME:~
#  gcloud compute scp deployment/gcp/rondb/init_db.sql $RONDB_API_NAME:~
#  gcloud compute ssh $RONDB_API_NAME -- bash < deployment/gcp/rondb/initialize-tables.sh

fi

# *
# ************** KAFKA SETUP **************
# *
echo "Creating VM for Kafka"

gcloud compute instances create $KAFKA_NAME --image=$GCP_IMAGE --image-project=$GCP_IMAGE_PROJECT --machine-type=$GCP_MACHINE_TYPE --tags http-server,https-server
echo "Waiting for Kafka VM startup"
sleep 40

gcloud compute ssh $KAFKA_NAME -- bash -s < deployment/gcp/kafka/kafka-startup.sh &
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
events_per_sec = $EVENTS_PER_SEC
" > data-utils/config.properties
tar -czvf data-utils.tar.gz data-utils
gcloud compute scp data-utils.tar.gz $DATA_UTILS_NAME:~
gcloud compute ssh $DATA_UTILS_NAME -- bash -s < deployment/gcp/data-utils/data-utils-startup.sh

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

echo "
jobmanager.rpc.address: $JOBMANAGER_ADDRESS
parallelism.default: $FLINK_WORKERS
state.savepoints.dir: file:///tmp/flinksavepoints
state.checkpoints.dir: file:///tmp/flinkcheckpoints
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
  gcloud compute instances create $WORKER_NAME --image=$GCP_IMAGE --image-project=$GCP_IMAGE_PROJECT --machine-type=$GCP_MACHINE_TYPE --tags http-server,https-server
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
  gcloud compute instances create $REMOTE_FUNCTIONS_NAME --image=$GCP_IMAGE --image-project=$GCP_IMAGE_PROJECT --machine-type=$GCP_MACHINE_TYPE --tags http-server,https-server
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
  properties:
    - transaction.timeout.ms: 7200000
---
kind: io.statefun.kafka.v1/egress
spec:
  id: shoppingcart-remote/receipt
  address: $KAFKA_ADDRESS:9092
  deliverySemantic:
    type: exactly-once
    transactionTimeout: 15min
  properties:
    - transaction.timeout.ms: 7200000
" > shoppingcart-remote-module/src/main/resources/module.yaml
  (cd shoppingcart-remote/;mvn clean package)
  (cd shoppingcart-remote-module/;mvn clean package)

  echo "Running remote functions"
  gcloud compute scp shoppingcart-remote/target/shoppingcart-remote-1.0-SNAPSHOT-jar-with-dependencies.jar $REMOTE_FUNCTIONS_NAME:~
  gcloud compute ssh $REMOTE_FUNCTIONS_NAME -- bash -s < deployment/gcp/flink/remote_functions_setup.sh &

  echo "Running StateFun runtime"
  gcloud compute scp shoppingcart-remote-module/target/shoppingcart-remote-module-1.0-SNAPSHOT-jar-with-dependencies.jar $JOBMANAGER_NAME:~
  gcloud compute ssh $JOBMANAGER_NAME -- bash -s < deployment/gcp/flink/run_statefun_remote.sh &
fi

echo "Waiting for StateFun runtime startup"
sleep 30

# *
# ************** BENCHMARK RUN **************
# *
echo "Starting Data Generator"
gcloud compute ssh $DATA_UTILS_NAME -- bash -s < deployment/gcp/data-utils/run-data-generator.sh
echo "Data Generator Finished"

echo "Starting Output Consumer"
gcloud compute ssh $DATA_UTILS_NAME -- bash -s < deployment/gcp/data-utils/run-output-consumer.sh
echo "Output Consumer Finished"

# Copy data file to local
NOW="$(date +'%d-%m-%Y_%H:%M')"
mkdir -p output-data/$NOW/${STATE_BACKEND}${RECOVERY_METHOD}-${FLINK_WORKERS}-workers-${FUNCTION_TYPE}/
gcloud compute scp $DATA_UTILS_NAME:~/data-utils/output-data/data.json output-data/$NOW/${STATE_BACKEND}-${RECOVERY_METHOD}-${FLINK_WORKERS}-workers-${FUNCTION_TYPE}


# Clean up
echo "Deleting VM instances"
gcloud compute instances delete $JOBMANAGER_NAME --quiet
gcloud compute instances delete $KAFKA_NAME --quiet
gcloud compute instances delete $DATA_UTILS_NAME --quiet
gcloud compute instances delete $REMOTE_FUNCTIONS_NAME --quiet
for i in $(seq 1 $FLINK_WORKERS);
do
 WORKER_NAME="$TASKMANAGER_NAME-$i"
 gcloud compute instances delete $WORKER_NAME --quiet
done
