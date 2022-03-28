#!/bin/bash

cp deployment/flink/rocksdb_flink-conf.yaml deployment/flink/build/conf/flink-conf.yaml
echo "Flink state backend set to RocksDB"
