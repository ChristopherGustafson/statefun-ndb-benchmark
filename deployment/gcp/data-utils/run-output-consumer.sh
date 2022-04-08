#!/bin/bash

cd data-utils
python3 output_consumer.py &
sleep 60
pkill -f output_consumer.py

exit 0
