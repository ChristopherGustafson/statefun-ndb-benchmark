#!/bin/bash

cd data-utils
nohup python3 -u produce_events.py > event_producer.log &
sleep 180
pkill -f produce_events.py

exit 0
