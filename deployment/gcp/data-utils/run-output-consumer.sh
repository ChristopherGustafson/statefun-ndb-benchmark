#!/bin/bash

cd data-utils
nohup python3 -u output_consumer.py > output_consumer.log &

exit 0
