#!/bin/bash

cd data-utils
python3 output_consumer.py &
sleep 120
pkill -f output_consumer.py

exit 0