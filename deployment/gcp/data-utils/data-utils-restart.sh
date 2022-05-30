#!/bin/bash

# Set new config file
mv config.properties data-utils/config.properties

# Remove data and kill any running processes
cd data-utils
rm -rf output-data
pkill -f produce_events.py
pkill -f output_consumer.py
