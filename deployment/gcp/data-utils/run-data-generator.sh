#!/bin/bash

cd data-utils
nohup python3 -u produce_events.py > event_producer.log &
sleep 600
pkill -f produce_events.py


