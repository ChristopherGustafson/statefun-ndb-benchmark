#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "Illegal number of parameters. Usage: ./set-flink-config.sh <state-backebnd (ndb or rocksdb)> <number of taskmanagers>"
fi

