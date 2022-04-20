#!/bin/bash

sudo su
/srv/hops/mysql-cluster/ndb/scripts/mysql-client.sh -e "source init_db.sql;"