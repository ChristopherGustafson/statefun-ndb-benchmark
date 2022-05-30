#!/bin/bash

rm -v build/log/*
./build/bin/jobmanager.sh stop
mv flink-conf.yaml build/conf/flink-conf.yaml
./build/bin/jobmanager.sh start