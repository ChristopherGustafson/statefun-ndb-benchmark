#!/bin/bash

NOW="$(date +'%d-%m-%Y_%H:%M')"
mkdir -p output-data/$NOW

./deployment/local/run.sh rocksdb 1 eager embedded
mkdir -p output-data/$NOW/rocksdb-embedded/
mv data-utils/output-data/ output-data/$NOW/rocksdb-embedded/

./deployment/local/run.sh rocksdb 1 eager remote
mkdir -p output-data/$NOW/rocksdb-remote/
mv data-utils/output-data/ output-data/$NOW/rocksdb-remote/

./deployment/local/run.sh ndb 1 eager embedded
mkdir -p output-data/$NOW/ndb-eager-embedded/
mv data-utils/output-data/ output-data/$NOW/ndb-eager-embedded/

./deployment/local/run.sh ndb 1 eager remote
mkdir -p output-data/$NOW/ndb-eager-remote/
mv data-utils/output-data/ output-data/$NOW/ndb-eager-remote/

./deployment/local/run.sh ndb 1 lazy embedded
mkdir -p output-data/$NOW/ndb-lazy-embedded/
mv data-utils/output-data/ output-data/$NOW/ndb-lazy-embedded/

./deployment/local/run.sh ndb 1 lazy remote
mkdir -p output-data/$NOW/ndb-lazy-remote/
mv data-utils/output-data/ output-data/$NOW/ndb-lazy-remote/
