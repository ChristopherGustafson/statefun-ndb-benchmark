#!/bin/bash

# Script for running and initializing RonDB

# Install rondb on gcp
# High performance
#HEAD_INSTANCE_TYPE=n2-highcpu-16
#DATA_NODE_INSTANCE_TYPE=n2-highmem-16
#API_INSTANCE_TYPE=n2-highcpu-16
# Low performance
HEAD_INSTANCE_TYPE=n2-standard-4
DATA_NODE_INSTANCE_TYPE=n2-standard-4
API_NODE_INSTANCE_TYPE=n2-standard-4
NUM_DATA_NODES="${1:-2}"
NUM_API_NODES=1
NUM_REPLICAS=2
VM_NAME=statefun-benchmark-
CLOUD=gcp
INSTALL_ACTION=cluster
DATA_NODE_BOOT_SIZE=64
OS_IMAGE=centos-7-v20220406
ZONE=3
./deployment/gcp/rondb/rondb-cloud-installer.sh \
--non-interactive \
--cloud $CLOUD \
--install-action $INSTALL_ACTION \
--vm-name-prefix $VM_NAME \
--gcp-head-instance-type $HEAD_INSTANCE_TYPE \
--gcp-data-node-instance-type $DATA_NODE_INSTANCE_TYPE \
--gcp-api-node-instance-type $API_NODE_INSTANCE_TYPE \
--num-data-nodes $NUM_DATA_NODES \
--num-api-nodes $NUM_API_NODES \
--num-replicas $NUM_REPLICAS \
--availability-zone $ZONE \
--database-node-boot-size $DATA_NODE_BOOT_SIZE
#--debug \

sleep 300
gcloud compute scp deployment/gcp/rondb/init_db.sql ${VM_NAME}api00:~
gcloud compute ssh ${VM_NAME}api00 -- bash -s < deployment/gcp/rondb/initialize-tables.sh

