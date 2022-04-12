# RonDB installation
The RonDB installation scripts has some outdated GH branches, gcp images and so on. To use it, run the script as
usual, but make the following changes to the file ``cluster-defns/rondb-installation.yml`` at the rondb head node:
* Change the hopsworks cookbook repo to ``logicalclocks/hopsworks-chef`` and branch to ``2.5``
* Since they are not needed, comment out the config for ``hopsmonitor`` and ``consul``, see
[the example config file](rondb-installation.yml) for an example

Then, rerun the installation script from the head node:
```shell
nohup ./karamel-0.6/bin/karamel -headless -launch ../cluster-defns/rondb-installation.yml > ../installation.log &
```

To interact with the cluster mysql client, ssh to the API node and run
```shell
sudo su
/srv/hops/mysql-cluster/ndb/scripts/mysql-client.sh
```

To initialize the necessary database and tables for this benchmark, run the following.

```shell
gcloud compute scp deployment/gcp/rondb/init_db.sql $RONDB_API_NAME:~
gcloud compute ssh $RONDB_API_NAME
ssh> sudo su
ssh> /srv/hops/mysql-cluster/ndb/scripts/mysql-client.sh
mysql> source init_db.sql;
```
 