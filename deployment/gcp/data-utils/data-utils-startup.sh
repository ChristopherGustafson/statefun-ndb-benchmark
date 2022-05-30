#!/bin/bash

# Setup java
sudo apt-get update
sudo apt-get -y install python3-pip
sudo apt-get clean

gsutil cp gs://statefun-benchmark/builds/data-utils.tar.gz .

tar -xvzf data-utils.tar.gz
mv config.properties data-utils/config.properties

cd data-utils
pip install -r requirements.txt
cd ..