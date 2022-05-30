#!/bin/bash

gcloud compute ssh statefun-benchmark-jobmanager -- -D 8081 -N &
/usr/bin/google-chrome --proxy-server="socks5://localhost:8081" --user-data-dir=/tmp/statefun-benchmark-jobmanager "http://statefun-benchmark-jobmanager:8081"