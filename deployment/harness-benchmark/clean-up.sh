#!/bin/bash

NOW="$(date +'%d-%m-%Y_%H:%M')"
mkdir -p output-data/$NOW/
gcloud compute scp statefun-benchmark:~/output.log output-data/$NOW/output.log

#gcloud compute instances delete statefun-benchmark --quiet
#gcloud compute instances delete statefun-benchmark-cpu00 --quiet
#gcloud compute instances delete statefun-benchmark-cpu01 --quiet
#gcloud compute instances delete statefun-benchmark-head --quiet
#gcloud compute instances delete statefun-benchmark-api00 --quiet