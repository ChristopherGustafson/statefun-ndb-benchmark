#!/bin/bash

rm -v build/log/*
mv flink-conf.yaml build/conf/flink-conf.yaml
./build/bin/taskmanager.sh start