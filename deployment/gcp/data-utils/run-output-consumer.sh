#!/bin/bash

cd data-utils
nohup python3 -u output_consumer.py > output_consumer.log &
sleep 300
pkill -f output_consumer.py

exit 0
