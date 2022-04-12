# RonDB installation
The RonDB installation scripts has some outdated GH branches, gcp images and so on. To use it, run the script as
usual, but make the following changes to the file ``cluster-defns/rondb-installation.yml`` at the rondb head node:
* Change the hopsworks cookbook repo to ``logicalclocks/hopsworks-chef`` and branch to ``2.5``
* Since they are not needed, comment out the config for ``hopsmonitor`` and ``consul``, see
[the example config file](rondb-installation.yml) for an example

Then, rerun the installation script from the head node:
```shell
nohup ./bin/karamel -headless -launch ../cluster-defns/rondb-installation.yml > ../installation.log &
```