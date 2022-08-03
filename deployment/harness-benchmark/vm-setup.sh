#!/bin/bash

# Setup java
sudo apt-get update
sudo apt-get -y install openjdk-8-jre
sudo apt-get clean

# Setup ndb lib
curl https://repo.hops.works/master/lib-ndb-6.1.0.tgz > lib-ndb.tgz
tar -xvzf lib-ndb.tgz
cd lib-ndb-6.1.0
export LD_LIBRARY_PATH=`pwd`
cd ..

nohup java -Djava.libary.path=/home/christopher/lib-ndb-6.1.0 -cp harness-benchmark-1.0-SNAPSHOT-jar-with-dependencies.jar harness.Main > output.log &
