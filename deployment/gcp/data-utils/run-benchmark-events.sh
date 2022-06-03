#!/bin/bash

cd data-utils
rm -rf output-data/
nohup python3 -u output_consumer_confluent.py > output_consumer.log &
sleep 10
nohup python3 -u produce_events.py > event_producer.log &

exit 1