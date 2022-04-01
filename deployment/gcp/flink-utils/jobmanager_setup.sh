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

# Setup and run Flink and StateFun runtime
tar -xvzf flink.tar.gz
./build/bin/jobmanager.sh start



