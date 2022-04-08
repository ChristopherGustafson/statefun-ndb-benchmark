#!/bin/bash

# Setup java
sudo apt-get update
sudo apt-get -y install python3-pip
sudo apt-get clean

tar -xvzf data-utils.tar.gz
cd data-utils
pip install -r requirements.txt
cd ..