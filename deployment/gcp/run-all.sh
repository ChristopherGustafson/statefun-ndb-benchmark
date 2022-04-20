#!/bin/bash

# Script for running all different configurations of the benchmark


# Run script usage. ./deployment/gcp/run.sh <NUM_FLINK_WORKERS> <BACKEND> <NUM_RONDB_WORKERS> <RECOVERY_METHOD>

# ROCKSDB
./deployment/gcp/run.sh 3 rocksdb 3 lazy embedded

./deployment/gcp/run.sh 3 rocksdb 3 lazy remote

# FLINK EAGER
./deployment/gcp/run.sh 3 ndb 3 eager embedded

./deployment/gcp/run.sh 3 ndb 3 eager remote

# FLINK LAZY
./deployment/gcp/run.sh 3 ndb 3 lazy embedded

./deployment/gcp/run.sh 3 ndb 3 lazy remote


