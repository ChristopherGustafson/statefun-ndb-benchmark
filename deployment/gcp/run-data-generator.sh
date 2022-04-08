#!/bin/bash

cd data-utils
python3 produce_events.py &
sleep 60
pkill -f produce_events.py

exit 0
