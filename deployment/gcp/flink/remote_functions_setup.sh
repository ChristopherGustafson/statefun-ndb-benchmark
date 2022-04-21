#!/bin/bash

# Setup java
sudo apt-get update
sudo apt-get -y install openjdk-8-jre
sudo apt-get clean

# Run Remote functions
nohup java -cp shoppingcart-remote-1.0-SNAPSHOT-jar-with-dependencies.jar shoppingcart.remote.Expose &



