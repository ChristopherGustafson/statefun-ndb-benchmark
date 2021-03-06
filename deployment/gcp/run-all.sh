#!/bin/bash

# Script for running all different configurations of the benchmark

# USAGE: run.sh <N_FLINK_WORKERS> <ndb OR rocksdb> <N_RONDB_WORKERS> <eager OR lazy> <embedded OR remote> <N_EVENTS_PER_SEC> <FAILURE 0/1>

# ROCKSDB PERFORMANCE PLOTS
#./deployment/gcp/run.sh 3 rocksdb 3 lazy embedded 2000 0
#
#./deployment/gcp/run.sh 3 rocksdb 3 lazy remote 2000 0

# RONDB
./deployment/gcp/rondb/run-rondb.sh

#./deployment/gcp/run.sh 3 ndb 3 eager embedded 10000 0
#gcloud compute ssh statefun-benchmark-api00 -- bash -s < deployment/gcp/rondb/clear-tables.sh

./deployment/gcp/run.sh 3 ndb 3 lazy embedded 2000 0
gcloud compute ssh statefun-benchmark-api00 -- bash -s < deployment/gcp/rondb/clear-tables.sh

#./deployment/gcp/run.sh 3 ndb 3 eager remote 2000 0
#gcloud compute ssh statefun-benchmark-api00 -- bash -s < deployment/gcp/rondb/clear-tables.sh
#
#./deployment/gcp/run.sh 3 ndb 3 lazy remote 2000 0
#gcloud compute ssh statefun-benchmark-api00 -- bash -s < deployment/gcp/rondb/clear-tables.sh

# Clean up RonDB
#gcloud compute instances delete statefun-benchmark-cpu00 --quiet
#gcloud compute instances delete statefun-benchmark-cpu01 --quiet
#gcloud compute instances delete statefun-benchmark-head --quiet
#gcloud compute instances delete statefun-benchmark-api00 --quiet

