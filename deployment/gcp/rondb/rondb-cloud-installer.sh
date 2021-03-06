#!/bin/bash

email="blah"
###################################################################################################
#                                                                                                 #
# This code is released under the GNU General Public License, Version 3, see for details:         #
# http://www.gnu.org/licenses/gpl-3.0.txt                                                         #
#                                                                                                 #
#                                                                                                 #
# Copyright (c) Logical Clocks AB, 2021.                                                          #
# All Rights Reserved.                                                                            #
#                                                                                                 #
###################################################################################################

###################################################################################################
# ______  __                                           ______                                     #
# ___  / / /_______________________      _________________  /_________                            #
# __  /_/ /_  __ \__  __ \_  ___/_ | /| / /  __ \_  ___/_  //_/_  ___/                            #
# _  __  / / /_/ /_  /_/ /(__  )__ |/ |/ // /_/ /  /   _  ,<  _(__  )                             #
# /_/ /_/  \____/_  .___//____/ ____/|__/ \____//_/    /_/|_| /____/                              #
# /_/                                                                                             # 
# ______________            _________                                                             #
# __  ____/__  /_________  _______  /                                                             #
# _  /    __  /_  __ \  / / /  __  /                                                              #
# / /___  _  / / /_/ / /_/ // /_/ /                                                               #
# \____/  /_/  \____/\__,_/ \__,_/                                                                #
#                                                                                                 #
# ________             _____       ___________                                                    #
# ____  _/_______________  /______ ___  /__  /____________                                        #
#  __  / __  __ \_  ___/  __/  __ `/_  /__  /_  _ \_  ___/                                        #            
# __/ /  _  / / /(__  )/ /_ / /_/ /_  / _  / /  __/  /                                            #
# /___/  /_/ /_//____/ \__/ \__,_/ /_/  /_/  \___//_/                                             #
#                                                                                                 #
###################################################################################################

HOPSWORKS_INSTALLER_VERSION=rondb_v2
CLUSTER_DEFINITION_VERSION=$HOPSWORKS_INSTALLER_VERSION
HOPSWORKS_INSTALLER_BRANCH=https://raw.githubusercontent.com/logicalclocks/karamel-chef/$HOPSWORKS_INSTALLER_VERSION
CLUSTER_DEFINITION_BRANCH=https://raw.githubusercontent.com/logicalclocks/karamel-chef/$CLUSTER_DEFINITION_VERSION

DEBUG=0

declare -a CPU
declare -a GPU

declare -a PRIVATE_CPU
declare -a PRIVATE_GPU

SCRIPTNAME=$0

DO_LISTING=0
RM_TYPE=

INSTALL_ACTION=
HOPSWORKS_VERSION=enterprise
DOWNLOAD_URL=
PREFIX=
host_ip=
INSTALL_CPU=0
INSTALL_GPU=1
INSTALL_CLUSTER=2

NON_INTERACT=0
DRY_RUN=0
DRY_RUN_CREATE_VMS=0

HEAD_VM_TYPE=head_cpu

CLUSTER_DEFINITIONS_DIR="cluster-defns"
INPUT_YML="rondb-head.yml"
WORKER_YML="rondb-data-node.yml"
WORKER_GPU_YML="rondb-api-node.yml"
YML_FILE="rondb-installation.yml"

WORKER_LIST=
WORKER_IP=
WORKER_DEFAULTS=
CPU_WORKER_ID=0
GPU_WORKER_ID=0

SKIP_CREATE=0

NUM_GPUS_PER_VM=
GPU_TYPE=

NUM_WORKERS_CPU=0
NUM_WORKERS_GPU=0

CLOUD=
VM_DELETE=

NUM_NVME_DRIVES_PER_WORKER=0

HEAD_INSTANCE_TYPE=

ENTERPRISE_DOWNLOAD_URL=https://nexus.hops.works/repository

NUM_GPUS_PER_VM=1


NUM_REPLICAS=1

#################
# GCP Config
#################
REGION=us-east1
ZONE=us-east1-c
CENTOS_IMAGE=centos-7-v20210401
GCP_IMAGE=centos-7-v20220406
GCP_IMAGE_PROJECT=centos-cloud
MACHINE_TYPE=n1-standard-8
NAME=
PROJECT=
SUBNET=default
NETWORK_TIER=PREMIUM
MAINTENANCE_POLICY=TERMINATE
SERVICE_ACCOUNT=--no-service-account
RESERVATION_AFFINITY=any
#SHIELD="--no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring"
SHIELD=""

BOOT_DISK=pd-ssd
BOOT_SIZE_GBS=30

HEAD_NODE_BOOT_SIZE=40
DATA_NODE_BOOT_SIZE=250
API_NODE_BOOT_SIZE=100

GCP_HEAD_INSTANCE_TYPE=n2-standard-2
GCP_WORKER_INSTANCE_TYPE=n2-standard-4
GCP_API_INSTANCE_TYPE=n2-standard-8

RAW_SSH_KEY="${USER}:$(cat ~/.ssh/id_rsa.pub)"
ESCAPED_SSH_KEY="$RAW_SSH_KEY"
TAGS=http-server,https-server,karamel,grafana

ACTION=

###################
# Azure Config
###################
SUBSCRIPTION=
RESOURCE_GROUP=
VIRTUAL_NETWORK=

# We call Azure's LOCATION "REGION" to make this script more generic
# az vm create -n ghead --vnet-name hops --size Standard_NC6 --location westeurope --image UbuntuLTS --subnet default --public-ip-address ""
AZ_ZONE=3
SUBNET=default
DNS_PRIVATE_ZONE=h.w
DNS_VN_LINK=hopslink
VM_HEAD=hd
VM_WORKER=cpu
VM_GPU=gpu

# 1 CPU, 1 GB Ram for Mgmt Server
#HEAD_INSTANCE_TYPE=Standard_D2s_v3
# 4 CPUs, 32 GB Ram for NDBD 
#WORKER_INSTANCE_TYPE=Standard_E8s_v4
# Bit less for MySQL Server
#API_INSTANCE_TYPE=Standard_D8s_v4
#ACCELERATOR_VM=Standard_D8s_v4

AZ_HEAD_INSTANCE_TYPE=Standard_D2s_v3
AZ_WORKER_INSTANCE_TYPE=Standard_E8s_v4
AZ_API_INSTANCE_TYPE=Standard_D8s_v4

AZ_IMAGE=Canonical:UbuntuServer:18.04-LTS:latest
OS_VERSION=18

#AZ_IMAGE=OpenLogic:CentOS:7.5:latest
#AZ_IMAGE=OpenLogic:CentOS:7.7:latest
#
AZ_NETWORKING="--accelerated-networking true"
#AZ_NETWORKING="--accelerated-networking false"
#GPUs on Azure
# GPUs are often limited to a particular zone in a region, so only enter a value here if you know the zone where the GPUs are located
ACCELERATOR_ZONE=3

ADDRESS_PREFIXES="10.0.0.0/16"
SUBNET_PREFIXES="10.0.0.0/24"

DATA_DISK_SIZES_GB=100
LOCAL_DISK=
ACCELERATED_NETWORKING=false
PRIORITY=spot
PRICE=0.06


#################
# AWS Config
#################

AWS_VM_SIZE=t3.2xlarge
VPC=
AWS_SUBNET=
AMI=


# $1 = String describing error
exit_error()
{
    #CleanUpTempFiles

    echo "" $ECHO_OUT
    echo "Error: $1"
    echo "Exiting Hopsworks cloud installer."
    echo ""
    exit 1
}

# called if interrupt signal is handled
TrapBreak()
{
    trap "" HUP INT TERM
    echo -e "\n\nInstallation cancelled by user!"
    exit_error $EXIT_SIGNAL_CAUGHT
}

clear_screen()
{
    if [ $NON_INTERACT -eq 0 ] ; then
	echo ""
	echo "Press ENTER to continue"
	read cont < /dev/tty
    fi
    clear
}


check_linux()
{

    UNAME=$(uname | tr \"[:upper:]\" \"[:lower:]\")
    # If Linux, try to determine specific distribution
    if [ \"$UNAME\" == \"linux\" ]; then
	# If available, use LSB to identify distribution
	if [ -f /etc/lsb-release -o -d /etc/lsb-release.d ]; then
	    DISTRO=$(lsb_release -i | cut -d: -f2 | sed s/'^\t'//)
	    # Otherwise, use release info file
	else
	    DISTRO=$(ls -d /etc/[A-Za-z]*[_-][rv]e[lr]* | grep -v \"lsb\" | cut -d'/' -f3 | cut -d'-' -f1 | cut -d'_' -f1 | head -1)
	    if [[ "$DISTRO" =~ "Ubuntu" ]] ; then
		sudo apt install lsb-core -y
	    elif [[ "$DISTRO" =~ "centos" ]] || [[ "$DISTRO" == "os" ]] ; then
		sudo yum install redhat-lsb-core -y
	    else
		echo "Could not recognize Linux distro: $DISTRO"
		exit_error
	    fi
	fi
    else
        exit_error "This script only works for Linux."
    fi
}

splash_screen()
{
    clear
    echo ""
    echo "RonDB Cloud Installer, Copyright(C) 2020 Logical Clocks AB. All rights reserved."
    echo ""
    echo "This program creates virtual machines (VMs) on cloud infrastructure and installs RonDB on the VMs."
    echo ""
    echo "To cancel installation at any time, press CONTROL-C"
    echo ""

    if [ ! -w `pwd` ]; then
	echo ""
	echo "WARNING!"
	echo "The current directory is not writable and needs to be writeable by this script: $(PWD)"
	echo "Suggested fix:"
	echo "sudo chown $USER . && chmod +w ."
	echo ""
    fi
    if [ ! -e ~/.ssh/id_rsa.pub ] ; then
	echo "ATTENTION."
	echo "A public ssh key cannot be found at your home directory (~/)"
	echo "To continue, you need to create one at that path. Is that ok (y/n)?"
	read ACCEPT
	if [ "$ACCEPT" == "y" ] ; then
            if [[ $(AZ_IMAGE) =~ "Ubuntu" ]] && [[ $OS_VERSION -gt 18 ]] ; then            
	        cat /dev/zero | ssh-keygen -m PEM -q -N "" > /dev/null
            else
                cat /dev/zero | ssh-keygen -q -N "" > /dev/null                
            fi
	else
	    echo "Exiting...."
	    exit 99
	fi
    fi

    clear_screen
}


display_license()
{
    echo ""
    echo "This code is released under the GNU General Public License, Version 3, see:"
    echo "http://www.gnu.org/licenses/gpl-3.0.txt"
    echo ""
    echo "Copyright(C) 2020 Logical Clocks AB. All rights reserved."
    echo "Logical Clocks AB is furnishing this item \"as is\". Logical Clocks AB does not provide any"
    echo "warranty of the item whatsoever, whether express, implied, or statutory,"
    echo "including, but not limited to, any warranty of merchantability or fitness"
    echo "for a particular purpose or any warranty that the contents of the item will"
    echo "be error-free. In no respect shall Logical Clocks AB incur any liability for any"
    echo "damages, including, but limited to, direct, indirect, special, or consequential"
    echo "damages arising out of, resulting from, or any way connected to the use of the"
    echo "item, whether or not based upon warranty, contract, tort, or otherwise; "
    echo "whether or not injury was sustained by persons or property or otherwise;"
    echo "and whether or not loss was sustained from, or arose out of, the results of,"
    echo "the item, or any services that may be provided by Logical Clocks AB."
    echo ""
    printf 'Do you accept these terms and conditions? [ yes or no ] '
}

accept_license ()
{
    read ACCEPT
    case $ACCEPT in
	yes | Yes | YES)
        ;;
	no | No | NO)
            echo ""
            exit 0
            ;;
	*)
            echo ""
            echo "Please enter either 'yes' or 'no'."
	    printf 'Do you accept these terms and conditions? [ yes or no ] '
            accept_license
	    ;;
    esac
}

accept_enterprise()
{
    echo ""
    echo "You are installing a time-limited version of Hopsworks Enterprise."
    echo "The license for this version is valid for 60 days from now."
    echo "Hopsworks  Terms and conditions: https://www.logicalclocks.com/hopsworks-terms-and-conditions "
    printf "Do you agree to Hopsworks terms and conditions (y/n)? "
    read ACCEPT
    case $ACCEPT in
	y|yes)
	    echo "Continuing..."
	    echo ""
	    ;;
	n|no)
	    ;;
	*)
	    echo "Next time, enter 'y' or 'yes' to continue."
	    echo "Exiting..."
	    exit 3
	    ;;
    esac
}


clear_screen_no_skipline()
{
    if [ $NON_INTERACT -eq 0 ] ; then
	echo "Press ENTER to continue"
	read cont < /dev/tty
    fi
    clear
}


install_action()
{
    if [ "$INSTALL_ACTION" == "" ] ; then

        echo "-------------------- Installation Options --------------------"
	echo ""
        echo "What would you like to do?"
	echo ""
	echo "(1) Install RonDB on a single server (localhost)."
	echo ""
	echo "(2) Install clustered RonDB (multiple hosts)."
	echo ""
	printf 'Please enter your choice '1', '2', 'q' \(quit\), or 'h' \(help\) :  '
        read ACCEPT
        case $ACCEPT in
            1)
		INSTALL_ACTION=$INSTALL_CPU
		ACTION="localhost"
                GCP_HEAD_INSTANCE_TYPE=n2-standard-8
                AZ_HEAD_INSTANCE_TYPE=Standard_D8s_v4                
		;;
            2)
		INSTALL_ACTION=$INSTALL_CLUSTER
		ACTION="cluster"
		;;
            h | H)
		clear
		get_install_option_help
		echo -e $INSTALL_OPTION_HELP
		clear_screen_no_skipline
		install_action
		;;
            q | Q)
		exit_error
		;;
            *)
		echo ""
		echo "Invalid Choice: $ACCEPT"
		echo "Please enter your choice '1', '2', 'q', or 'h'."
		clear_screen
		install_action
		;;
        esac
	clear_screen
    fi
}


error_download_url()
{
    echo ""
    echo "Error. You need to export the following environment variable to run this script:"
    echo "export DOWNLOAD_URL=https://path/to/hopsworks/enterprise/binaries"
    echo ""    
    exit
}

get_ips()
{
    if [ "$CLOUD" == "gcp" ] ; then
	gcloud_get_ips
    elif [ "$CLOUD" == "azure" ] ; then
	az_get_ips
    elif [ "$CLOUD" == "aws" ] ; then
	aws_get_ips
    fi    
    
}

cpus_gpus()
{
    if [ "$CLOUD" == "gcp" ] ; then
	CPUS=$(gcloud compute instances list | awk '{ print $1 }' | grep "^${PREFIX}" | grep -e "cpu[0-99]" |  wc -l)
	GPUS=$(gcloud compute instances list | awk '{ print $1 }' | grep "^${PREFIX}" | grep -e "api[0-99]" |  wc -l)
	if [ $DEBUG -eq 1 ] ; then
	    echo "FOUND CPUS: $CPUS"
	    echo "FOUND GPUS: $GPUS"
        fi		
    elif [ "$CLOUD" == "azure" ] ; then
	CPUS=$(az vm list-ip-addresses -g $RESOURCE_GROUP -o table | grep "^${PREFIX}" | grep -e "cpu[0-99]" |  wc -l)
	GPUS=$(az vm list-ip-addresses -g $RESOURCE_GROUP -o table | grep "^${PREFIX}" | grep -e "api[0-99]" |  wc -l)
	if [ $DEBUG -eq 1 ] ; then
	    echo "FOUND CPUS: $CPUS"
	    echo "FOUND GPUS: $GPUS"
        fi		

    elif [ "$CLOUD" == "aws" ] ; then
	echo ""	
    fi
}


clear_known_hosts()
{
    if [ "$host_ip" == "" ] ; then
        echo "Could not resolve the host_ip: $host_ip"
        exit 23
    fi
    echo "ssh-keygen -R $host_ip -f \"~/.ssh/known_hosts\""
    ssh-keygen -R $host_ip -f ~/.ssh/known_hosts
    if [ $? -ne 0 ] ; then
	echo ""	
	echo "WARN: Could not clean up known_hosts file"
	echo ""
    fi
}    

enter_email()
{
    if [ "$email" == "" ] ; then
	printf "Please enter your email address to continue: "
	read email

	if [[ $email =~ .*@.* ]]
	then
	    echo "Registering...."
	    echo "{\"id\": \"$rand\", \"name\":\"$email\"}" > .details
	else
	    echo "Exiting. Invalid email address."
	    exit 1
	fi

	CREDENTIALS=$(curl -H "Content-type:application/json" --data @.details http://karamel.io:8443/keyword --connect-timeout 10)
	ENTERPRISE_USERNAME=$(echo $CREDENTIALS | cut -d ":" -f1)	
	ENTERPRISE_PASSWORD=$(echo $CREDENTIALS | cut -d ":" -f2)
	clear_screen
    fi
}

enter_cloud()
{
    if [ "$CLOUD" == "" ] ; then
        echo "-------------------- Where are you installing RonDB? --------------------"
	echo ""
        echo "On what platform are you installing RonDB?"
	echo ""
	# echo "(1) On-premises or private cloud."
	# echo ""
	# echo "(2) AWS."
	# echo ""
	echo "(1) GCP."
	echo ""
	echo "(2) Azure."
	echo ""
        #	printf 'Please enter your choice '1', '2', '3', '4' :  '
	printf 'Please enter your choice '1', '2' :  '        
        read ACCEPT
        case $ACCEPT in
            # 1)
	    #     CLOUD="on-premises"
	    #     ;;
            # 2)
	    #     CLOUD="aws"
	    #     ;;
            1)
   		CLOUD="gcp"
		;;
            2)
       		CLOUD="azure"
		;;
            *)
		echo ""
		echo "Invalid Choice: $ACCEPT"
                #		echo "Please enter your choice '1', '2', '3', '4'."
		echo "Please enter your choice '1', '2'."                
		clear_screen
		enter_cloud
		;;
        esac
	clear_screen
    fi
}


enter_prefix()
{
    if [ "$PREFIX" == "" ] ; then
	echo ""
	printf "The VM names will be prefixed with the string you enter here. Enter the prefix (default: $USER): "
	read PREFIX

	if [ "$PREFIX" == "" ] ; then
            PREFIX=$USER
	fi

	echo "VM name prefix: $PREFIX"

	clear_screen
    fi
}

download_installer() {

    rm -rf .tmp
    mkdir -p .tmp
    cd .tmp

    if [ ! -e ../../hopsworks-installer.sh ] ; then
        curl --silent --show-error -C - ${HOPSWORKS_INSTALLER_BRANCH}/hopsworks-installer.sh -o ./rondb-installer.sh 2>&1 > /dev/null
        if [ $? -ne 0 ] ; then
	    echo "Could not download rondb-installer.sh"
	    echo "WARNING: There could be a problem with your proxy server settings."	  
            echo "You need to export either the http_proxy or https_proxy enviornment variables."
	    echo "Current settings:"
	    echo "http_proxy=$http_proxy"
	    echo "https_proxy=$https_proxy"
	    echo "PROXY=$PROXY"
	    exit 3
        fi
    else
        cp -f ../../hopsworks-installer.sh rondb-installer.sh
    fi
    chmod +x rondb-installer.sh

    mkdir -p $CLUSTER_DEFINITIONS_DIR
    cd $CLUSTER_DEFINITIONS_DIR

    if [ ! -d ../../../cluster-defns ] ; then
        # Don't overwrite the YML files, so that users can customize them
        curl --silent --show-error -C - ${CLUSTER_DEFINITION_BRANCH}/${CLUSTER_DEFINITIONS_DIR}/$INPUT_YML -o ./$INPUT_YML 2>&1 > /dev/null
        if [ $? -ne 0 ] ; then
	    exit 12
        fi
        curl --silent --show-error -C - ${CLUSTER_DEFINITION_BRANCH}/${CLUSTER_DEFINITIONS_DIR}/$WORKER_YML -o ./$WORKER_YML 2>&1 > /dev/null
        if [ $? -ne 0 ] ; then
	    exit 13
        fi
        curl --silent --show-error -C - ${CLUSTER_DEFINITION_BRANCH}/${CLUSTER_DEFINITIONS_DIR}/$WORKER_GPU_YML -o ./$WORKER_GPU_YML 2>&1 > /dev/null    
        if [ $? -ne 0 ] ; then
	    exit 14
        fi
    else
        cp -f ../../../cluster-defns/rondb*.yml .
        if [ $? -ne 0 ] ; then
            echo "Error. It looks like you are doing development in karamle-chef, but i can't find the rondb-*.yml cluster defn files"
            echo "Found directory: ../../../cluster-defns "
            echo "But could not find rondb*-.yml files in this directory."
            echo ""
	    exit 155
        fi
        
    fi       
    cd ../..
}




add_worker()
{
    WORKER_GPUS=$1
    id=$2

    if [ $WORKER_GPUS -gt 0 ] ; then
	if [ $id -lt 10 ] ; then
	    set_name "api0${GPU_WORKER_ID}"
	else
	    set_name "api${GPU_WORKER_ID}"
	fi
        create_vm_gpu "worker"
        GPU_WORKER_ID=$((GPU_WORKER_ID+1))
    else
	if [ $id -lt 10 ] ; then
	    set_name "cpu0${CPU_WORKER_ID}"
	else
	    set_name "cpu${CPU_WORKER_ID}"
	fi
	create_vm_cpu "worker"
        CPU_WORKER_ID=$((CPU_WORKER_ID+1))		
    fi
}


cpu_worker_size()
{
    if [ $NON_INTERACT -eq 0 ] ; then	    
	if [ $NUM_WORKERS_CPU -eq 0 ] ; then
            clear_screen
	    printf 'Please enter the number of database nodes you want to add: '
	    read NUM_WORKERS_CPU
	    if [ "$NUM_WORKERS_CPU" == "" ] ; then
		NUM_WORKERS_CPU=0
	    fi
	fi
    fi
    i=0
    while [ $i -lt $NUM_WORKERS_CPU ] ;
    do
	if [ $DEBUG -eq 1 ] ; then
	    echo "Adding CPU worker ${i}"
	    echo ""
	fi
	add_worker 0 $i
	i=$((i+1))
    done
}


gpu_worker_size()
{
    if [ $NON_INTERACT -eq 0 ] ; then    
	if [ $NUM_WORKERS_GPU -eq 0 ] ; then
            clear_screen
	    printf 'Please enter the number of API nodes (MySQL servers) you want to add (default: 0): '
	    read NUM_WORKERS_GPU
	    if [ "$NUM_WORKERS_GPU" == "" ] ; then
		NUM_WORKERS_GPU=0
	    fi
	fi
    fi

    if [ "$NUM_WORKERS_GPU" == "" ] ; then
	NUM_WORKERS_GPU=0
    fi
    
    i=0
    while [ $i -lt $NUM_WORKERS_GPU ] ;
    do
	if [ $DEBUG -eq 1 ] ; then	
	    echo "Adding GPU worker $i"
	    echo ""
	fi
	add_worker $NUM_GPUS_PER_VM $i
	i=$((i+1))
    done
}



set_name()
{
    NAME="${PREFIX}$1"
}

_check_deletion()
{
    if [ $? -ne 0 ] ; then
	echo "Problem deleting instance: $NAME"
    fi
}


###################################################################
#  GCLOUD VM OPERATIONS                                           #
###################################################################

gcloud_get_ips()
{
    MY_IPS=$(gcloud compute instances list | grep "$PREFIX")
    if [ $DEBUG -eq 1 ] ; then
	echo "MY_IPS: "
	echo "$MY_IPS"
    fi
    set_name "head"
    if [ $INSTALL_ACTION -eq $INSTALL_CPU ] ; then
	set_name "cpu"
    elif [ $INSTALL_ACTION -eq $INSTALL_GPU ] ; then
	set_name "api"
    fi
    
    IP=$(echo $MY_IPS | sed -e "s/.*${NAME}/${NAME}/" | sed -e "s/RUNNING.*//"| awk '{ print $5 }')

    sleep 3
    cpus_gpus

    gc_i=0
    while [ $gc_i -lt $CPUS ] ;
    do
	if [ $gc_i -lt 10 ] ; then
	    set_name "cpu0${gc_i}"
	else
	    set_name "cpu${gc_i}"
	fi
	CPU[$gc_i]=$(echo $MY_IPS | sed -e "s/.*${NAME}/${NAME}/" | sed -e "s/RUNNING.*//"| awk '{ print $5 }')
	PRIVATE_CPU[$gc_i]=$(echo $MY_IPS | sed -e "s/.*${NAME}/${NAME}/" | sed -e "s/RUNNING.*//" | awk '{ print $4 }')
	if [ $DEBUG -eq 1 ] ; then
            echo -e "${NAME}\t Public IP: ${CPU[${gc_i}]} \t Private IP: ${PRIVATE_CPU[${gc_i}]}"
	fi	    
        gc_i=$((gc_i+1))
    done

    gc_i=0
    while [ $gc_i -lt $GPUS ] ;
    do
	if [ $gc_i -lt 10 ] ; then
	    set_name "api0${gc_i}"
	else
	    set_name "api${gc_i}"
	fi
	GPU[$gc_i]=$(echo $MY_IPS | sed -e "s/.*${NAME}/${NAME}/" | sed -e "s/RUNNING.*//"| awk '{ print $5 }')
	PRIVATE_GPU[$gc_i]=$(echo $MY_IPS | sed -e "s/.*${NAME}/${NAME}/" | sed -e "s/RUNNING.*//" | awk '{ print $4 }')
	if [ $DEBUG -eq 1 ] ; then	
	    echo "Worker gpu${gc_i} : GPU[$gc_i]"
            echo -e "${NAME}\t Public IP: ${GPU[${gc_i}]} \t Private IP: ${PRIVATE_GPU[${gc_i}]}"
	fi
	gc_i=$((gc_i+1))
    done
}    


check_gcp_tools()
{    
    which gcloud > /dev/null
    if [ $? -ne 0 ] ; then
	echo "gcloud does not appear to be installed"
	printf 'Do you want to install gcloud tools? Enter: 'yes' or 'no' (default: yes): '
	read INSTALL_GCLOUD
	if [ "$INSTALL_GCLOUD" == "yes" ] || [ "$INSTALL_GCLOUD" == "" ] ; then
            echo "Installing google-cloud-sdk"
	else
	    echo "Exiting...."
	    exit 44
	fi

	if [[ "$DISTRO" =~ "Ubuntu" ]] ; then
            echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
            sudo apt-get install apt-transport-https ca-certificates gnupg
            curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
            sudo apt-get update -y && sudo apt-get install google-cloud-sdk
	elif [[ "$DISTRO" =~ "centos" ]] || [[ "$DISTRO" =~ "os" ]] ; then
            sudo tee -a /etc/yum.repos.d/google-cloud-sdk.repo << EOM
[google-cloud-sdk]
name=Google Cloud SDK
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOM
	    yum install google-cloud-sdk -y
        fi
	gcloud init
    fi
}

gcloud_set_env()
{
    PROJECT=$(gcloud config get-value core/project 2> /dev/null)
    REGION=$(gcloud config get-value compute/region 2> /dev/null)
    ZONE=$(gcloud config get-value compute/zone 2> /dev/null)        
}

gcloud_enter_region()
{
    if [ $NON_INTERACT -eq 0 ] ; then
        echo ""
	printf "Current active region: "        
	gcloud config get-value compute/region
	printf "Do you want to use the current active region (y/n)? (default: y) "
	read KEEP_REGION

	if [ "$KEEP_REGION" == "" ] || [ "$KEEP_REGION" == "y" ] ; then
	    echo ""
	else
	    gcloud compute regions list | awk '{ print $1 }'
	    echo ""
	    printf "Enter the REGION: "
	    read KEEP_REGION
	    gcloud config set compute/region $KEEP_REGION  > /dev/null 2>&1
	fi
    fi
    REGION=$(gcloud config get-value compute/region 2> /dev/null)    
    echo "Active region is: $REGION"

}

gcloud_enter_zone()
{
    if [ $NON_INTERACT -eq 0 ] ; then
        echo ""
	printf "Current active zone: "        
	gcloud config get-value compute/zone
	printf "Do you want to use the current active zone (y/n)? (default: y) "
	read KEEP_ZONE

	if [ "$KEEP_ZONE" == "" ] || [ "$KEEP_ZONE" == "y" ] ; then
	    echo ""
	else
	    gcloud compute zones list | grep $REGION  | awk '{ print $1 }'
	    echo ""
	    printf "Enter the ZONE: "
	    read KEEP_ZONE
	    gcloud config set compute/zone $KEEP_ZONE > /dev/null 2>&1
	fi
    fi
    ZONE=$(gcloud config get-value compute/zone 2> /dev/null)    
    echo "Active zone is: $ZONE"
}


gcloud_enter_project()
{
    if [ $NON_INTERACT -eq 0 ] ; then
        echo ""
	printf "Current active project: "        
	gcloud config get-value project
	printf "Do you want to use the current active project (y/n)? (default: y) "
	read KEEP_PROJECT

	if [ "$KEEP_PROJECT" == "" ] || [ "$KEEP_PROJECT" == "y" ] ; then
	    echo ""
	else
	    gcloud projects list --sort-by=projectId
	    echo ""
	    printf "Enter the PROJECT_ID: "
	    read KEEP_PROJECT
	    gcloud config set core/project $KEEP_PROJECT > /dev/null 2>&1
	fi
    fi
    PROJECT=$(gcloud config get-value core/project 2> /dev/null)
    echo "Active project is: $PROJECT"

}

gcloud_setup()
{
    if [ $NON_INTERACT -eq 0 ] ; then
	check_gcp_tools
    fi
    
    SUBNET=default
    NETWORK_TIER=PREMIUM
    MAINTENANCE_POLICY=TERMINATE
    SERVICE_ACCOUNT=--no-service-account
    BOOT_DISK=pd-ssd
    RESERVATION_AFFINITY=any
    #SHIELD="--no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring"
    SHIELD=""

    GCP_USER=$USER

    gcloud_enter_project
    if [ $NON_INTERACT -eq 0 ] ; then
	clear_screen
    fi
    
    gcloud_enter_region
    if [ $NON_INTERACT -eq 0 ] ; then
	clear_screen
    fi

    gcloud_enter_zone    
    
    if [ $NON_INTERACT -eq 0 ] ; then
	clear_screen
    fi

    if [ $NON_INTERACT -eq 0 ] ; then    
	printf "Select IMAGE/IMAGE_PROJECT (centos/ubuntu/custom)? (default: centos) "
	read SELECT_IMAGE

	if [ "$SELECT_IMAGE" == "" ] || [ "$SELECT_IMAGE" == "centos" ] ; then
	    GCP_IMAGE=$CENTOS_IMAGE
	    GCP_IMAGE_PROJECT=centos-cloud
	elif [ "$SELECT_IMAGE" == "ubuntu" ] ; then
	    GCP_IMAGE=ubuntu-1804-bionic-v20200716
	    GCP_IMAGE_PROJECT=ubuntu-os-cloud
	else
	    echo "Examples of IMAGE are:"
	    echo "GCP_IMAGE=$CENTOS_IMAGE"
	    echo "GCP_IMAGE=ubuntu-1804-bionic-v20200716"
	    echo ""
	    printf "Enter the IMAGE: "
	    read IMAGE
	    echo "Examples of IMAGE/IMAGE_PROJECT are:"
	    echo "GCP_IMAGE_PROJECT=centoos-cloud"
	    echo "GCP_IMAGE_PROJECT=ubuntu-os-cloud"
	    printf "Enter the IMAGE_PROJECT: "
	    read GCP_IMAGE_PROJECT
	fi
	echo
	echo "Active IMAGE is: $GCP_IMAGE"
	echo "Active GCP_IMAGE_PROJECT is: $GCP_IMAGE_PROJECT"
	echo ""    
	clear_screen
    fi
}

gcloud_list_public_ips()
{    
    gcloud compute instances list 
}


_gcloud_precreate()
{
    VM_IP=$(gcloud compute instances list | grep $NAME | awk '{ print $5 }')
    if [ "$VM_IP" != "" ] ; then
	echo ""
	echo "WARNING:"	
	echo "VM already exists with name: $NAME"
	echo ""	
    fi
    if [ $NON_INTERACT -eq 0 ] ; then    
	echo ""
	echo "For the $1 VM:"
	echo "Image type: $MACHINE_TYPE"
	printf "Is the default image type OK (y/n)? (default: y) "
	read KEEP_IMAGE
	if [ "$KEEP_IMAGE" == "y" ] || [ "$KEEP_IMAGE" == "" ] ; then
	    echo ""
	else
	    echo ""
	    echo "Example image types: n1-standard-8, n1-standard-16, n1-standard-32"
	    printf "Enter the image type: "
	    read MACHINE_TYPE
	fi
	echo "Image type selected: $MACHINE_TYPE"

	echo ""
	echo "Boot disk size: $BOOT_SIZE_GBS"
	printf "Is the default boot disk size (GBs) OK (y/n)? (default: y) "
	read KEEP_SIZE
	if [ "$KEEP_SIZE" == "y" ] || [ "$KEEP_SIZE" == "" ] ; then
	    echo ""
	else
	    echo ""
	    printf "Enter the boot disk size in GBs: "
	    read BOOT_SIZE_GBS
	fi

	echo ""
	printf "How many NVMe local disks do you want to add to this host (max: 24)? (default: 0) "
	read NUM_NVME_DRIVES_PER_WORKER
        echo ""
	if [ "$NUM_NVME_DRIVES_PER_WORKER" == "" ] ; then
	    NUM_NVME_DRIVES_PER_WORKER=0
	fi
	LOCAL_DISK=
        for (( ctr=1; ctr<=${NUM_NVME_DRIVES_PER_WORKER}; ctr++ ))
	do
	    LOCAL_DISK="$LOCAL_DISK --local-ssd=interface=NVME"
	done
	gcloud_enter_zone
    fi
    BOOT_SIZE="${BOOT_SIZE_GBS}GB"
}

gcloud_create_gpu()
{
#    GCP_GPU_TYPE=nvidia-tesla-${GPU_TYPE}
    #    ACCELERATOR="--accelerator=type=${GCP_GPU_TYPE},count=${NUM_GPUS_PER_VM} "
    #GCP_IMAGE=ACCELERATOR_VM
    _gcloud_create_vm $1
}

gcloud_create_cpu()
{
    ACCELERATOR=""    
    _gcloud_create_vm $1 
}


_gcloud_create_vm()
{
    _gcloud_precreate $1
    if [ $DEBUG -eq 1 ] ; then
	echo "    gcloud compute --project=$PROJECT instances create $NAME --zone=$ZONE --machine-type=$MACHINE_TYPE --subnet=$SUBNET--maintenance-policy=$MAINTENANCE_POLICY $SERVICE_ACCOUNT --no-scopes $ACCELERATOR --tags=$TAGS --image=$GCP_IMAGE --image-project=$GCP_IMAGE_PROJECT --boot-disk-size=$BOOT_SIZE --boot-disk-type=$BOOT_DISK $LOCAL_DISK --boot-disk-device-name=$NAME --metadata=ssh-keys=\"$ESCAPED_SSH_KEY\""
    fi

    #  --network-tier=$NETWORK_TIER
    #  --reservation-affinity=$RESERVATION_AFFINITY
    
    gcloud compute --project=$PROJECT instances create $NAME --zone=$ZONE --machine-type=$MACHINE_TYPE --subnet=$SUBNET --maintenance-policy=$MAINTENANCE_POLICY $SERVICE_ACCOUNT --no-scopes $ACCELERATOR --tags=$TAGS --image=$GCP_IMAGE --image-project=$GCP_IMAGE_PROJECT --boot-disk-size=$BOOT_SIZE --boot-disk-type=$BOOT_DISK $LOCAL_DISK --boot-disk-device-name=$NAME --metadata=ssh-keys="$ESCAPED_SSH_KEY"
    if [ $? -ne 0 ] ; then
	echo "Problem creating VM. Exiting ..."
	exit 12
    fi
    sleep 4
}

gcloud_delete_vm()
{
    nohup gcloud compute instances delete -q $VM_DELETE > gcp-installer.log 2>&1  & 
    RES=$?
    echo "Deleting in the background."
    exit $RES
}

###################################################################
#  AZURE VM OPERATIONS                                            #
###################################################################

az_get_ips()
{
    echo "Azure get_ips"
    set_name "head"
    if [ $INSTALL_ACTION -eq $INSTALL_CPU ] ; then
	set_name "cpu"
    elif [ $INSTALL_ACTION -eq $INSTALL_GPU ] ; then
	set_name "api"
    fi
    
    IP=$(az vm list-ip-addresses -g $RESOURCE_GROUP -o table | tail -n +3 | grep ^$NAME | awk '{ print $2 }')
    echo "$NAME : $IP"
    ssh -t -o StrictHostKeyChecking=no $IP "sudo hostname ${NAME}.${DNS_PRIVATE_ZONE}"
    
    sleep 3

    cpus_gpus

    az_i=0
    while [ $az_i -lt $CPUS ] ; 
    do
        echo "CPUS: $CPUS   i: $az_i"	
	if [ $az_i -lt 10 ] ; then
	    set_name "cpu0${az_i}"
	else
	    set_name "cpu${az_i}"
	fi
	MY_IPS=$(az vm list-ip-addresses -g $RESOURCE_GROUP -o table | tail -n +3  | grep ^$NAME | awk '{ print $3, $2 }')
        if [ $DEBUG -eq 1 ] ; then
          echo "MY_IPS: "
          echo "$MY_IPS"
        fi
	CPU[$az_i]=$(echo "$MY_IPS" | awk '{ print $2 }')
	PRIVATE_CPU[$az_i]=$(echo "$MY_IPS" | awk '{ print $1 }')
	if [ $DEBUG -eq 1 ] ; then	
            echo -e "${NAME}\t Public IP: ${CPU[${az_i}]} \t Private IP: ${PRIVATE_CPU[${az_i}]}"
	fi
        ssh -t -o StrictHostKeyChecking=no ${CPU[${az_i}]}  "sudo hostname ${NAME}.${DNS_PRIVATE_ZONE}"
	az_i=$((az_i+1))
        if [ $DEBUG -eq 1 ] ; then
            echo "CPU${az_i} : $PRIVATE_CPU[$az_i] "
        fi
    done

    az_i=0
    while [ $az_i -lt $GPUS ] ;     
    do
	if [ $az_i -lt 10 ] ; then
	    set_name "api0${az_i}"
	else
	    set_name "api${az_i}"
	fi
	MY_IPS=$(az vm list-ip-addresses -g $RESOURCE_GROUP -o table | tail -n +3 | grep ^$NAME | awk '{ print $3, $2 }')
        if [ $DEBUG -eq 1 ] ; then
          echo "MY_IPS: "
          echo "$MY_IPS"
        fi        
	GPU[$az_i]=$(echo "$MY_IPS" | awk '{ print $2 }')
	PRIVATE_GPU[$az_i]=$(echo "$MY_IPS" | awk '{ print $1 }')
	if [ $DEBUG -eq 1 ] ; then	
            echo -e "${NAME}\t Public IP: ${GPU[${az_i}]} \t Private IP: ${PRIVATE_GPU[${az_i}]}"
	fi
        ssh -t -o StrictHostKeyChecking=no ${GPU[${az_i}]} "sudo hostname ${NAME}.${DNS_PRIVATE_ZONE}"
        if [ $? -ne 0 ] ; then
            echo "Could not ssh to ${GPU[${az_i}]}"
            echo "Trying again...."
            ssh -t -o StrictHostKeyChecking=no ${GPU[${az_i}]} "sudo hostname ${NAME}.${DNS_PRIVATE_ZONE}"
        fi
	az_i=$((az_i+1))
        if [ $DEBUG -eq 1 ] ; then
            echo "GPU${az_i} : $PRIVATE_GPU[$az_i] "
        fi
    done
}    

_az_set_subscription()
{
    SUBSCRIPTION=$(az account list -o table | grep True | sed -e 's/\s*AzureCloud.*//')
}

_az_enter_subscription()
{
    _az_set_subscription
    if [ $NON_INTERACT -eq 0 ] ; then    
	echo ""
	printf "Do you want to use the current subscription $SUBSCRIPTION (y/n) (default: y)? "
	read KEEP_SUBSCRIPTION

	if [ "$KEEP_SUBSCRIPTION" == "y" ] || [ "$KEEP_SUBSCRIPTION" == "" ] ; then
	    echo ""
	else
            az account list -o table
	    echo ""
	    printf "Enter the Subscription: "
	    read SUBSCRIPTION
	    az account set --subscription "$SUBSCRIPTION"
	    if [ $? -ne 0 ] ; then
		echo "Invalid subscription name: $SUBSCRIPTION"
		echo "Enter a valid subscription name."
		echo ""
		_az_enter_subscription
		return
	    fi
	fi
    fi
    echo "Subscription is: $SUBSCRIPTION"
}

_az_set_location()
{
    REGION=$(az configure -o table -l | tail -n +3 | tail -n +1 | grep ^location | awk '{ print $3 }')
}

_az_enter_location()
{
    _az_set_location
    if [ $NON_INTERACT -eq 0 ] ; then    
	CHANGE=0
	if [ "$REGION" != "" ] ; then
 	    echo ""
  	    printf "Do you want to keep the current Location $REGION (y/n) (default: y)? "
 	    read KEEP_LOCATION
	    if [ "$KEEP_LOCATION" == "n" ] || [ "$KEEP_LOCATION" == "no" ] ; then
		CHANGE=1
	    fi
        else
	    CHANGE=1
	fi
	if [ $CHANGE -eq 1 ] ; then
            az account list-locations -o table | sed -e 's/.*[0-9]*\.[0-9]*.*[0-9]*\.[0-9]*\s*//' | tail -n +3 | tail -n +1
	    echo ""
	    printf "Enter the Location: "
	    read REGION
	    az configure --defaults location=$REGION
	    if [ $? -ne 0 ] ; then
		echo "Invalid location name: $REGION"
		echo ""	
		_az_enter_location
                return		
	    fi
	fi
    fi
    echo "Location is: $REGION"
}    


_az_set_resource_group()
{

    if [ "$RESOURCE_GROUP" = "" ] ; then
        RESOURCE_GROUP=$(az configure -o table -l | tail -n +3 | tail -n +1 | grep ^group | awk '{ print $3 }')
    fi
}

_az_enter_resource_group()
{
    _az_set_resource_group
    if [ $NON_INTERACT -eq 0 ] ; then    
	echo ""
	CHANGE=0
	if [ "$RESOURCE_GROUP" != "" ] ; then
  	    printf "Do you want to keep the Resource Group $RESOURCE_GROUP (y/n) (default: y)? "
	    read KEEP_GROUP
            if [ "$KEEP_GROUP" == "n" ] || [ "$KEEP_GROUP" == "no" ] ; then
		CHANGE=1
	    fi
        else
	    CHANGE=1
	fi
	if [ $CHANGE -eq 1 ] ; then
	    az group list
	    echo ""
	    printf "Enter the Resource Group: "
	    read RESOURCE_GROUP
	fi
    fi
    az group exists -n $RESOURCE_GROUP | tail -1 | grep -i False
    if [ $? -eq 0 ] ; then
	echo "Creating ResourceGroup: $RESOURCE_GROUP in $RESOURCE_GROUP"
	az group create --name $RESOURCE_GROUP --location $REGION
	if [ $? -ne 0 ] ; then
	    echo "Problem creating resource group: $RESOURCE_GROUP"
	    echo "Exiting..."
	    exit 12
	fi

	
	az configure --defaults group=$RESOURCE_GROUP
	if [ $? -ne 0 ] ; then
	    echo "Invalid resource group: $RESOURCE_GROUP"
	    echo "Enter a valid resource group name."
	    echo ""	
	    _az_enter_resource_group
            return		    
	fi
    else
	echo "Found Resource Group: $RESOURCE_GROUP"
    fi
}    


_az_set_virtual_network()
{

    if [ "$VIRTUAL_NETWORK" == "" ] ; then    
      VIRTUAL_NETWORK_DEFAULT=$(az network vnet list -g $RESOURCE_GROUP -o table | tail -n +3 | awk '{ print $1 }' | tail -1)
      if [ "$VIRTUAL_NETWORK_DEFAULT" != "" ] ; then
  	VIRTUAL_NETWORK=$VIRTUAL_NETWORK_DEFAULT
      fi
    fi
}

_az_enter_virtual_network()
{
    _az_set_virtual_network
    if [ $NON_INTERACT -eq 0 ] ; then    
	echo ""
	CHANGE=0
	
	if [ "$VIRTUAL_NETWORK" != "" ] ; then
  	    printf "Do you want to keep the virtual network $VIRTUAL_NETWORK (y/n) (default: y)? "
	    read KEEP_GROUP
            if [ "$KEEP_GROUP" == "n" ] || [ "$KEEP_GROUP" == "no" ] ; then
		CHANGE=1
	    fi
        else
	    CHANGE=1
	fi
	if [ $CHANGE -eq 1 ] ; then
            az network vnet list -g $RESOURCE_GROUP -o table | tail -n +3 | awk '{ print $1 }'	    
	    echo ""
	    printf "Enter the Virtual Network: "
	    read VIRTUAL_NETWORK
	fi
    fi
    az network vnet show -g $RESOURCE_GROUP -n $VIRTUAL_NETWORK 2>&1 > /dev/null
    if [ $? -ne 0 ] ; then
        echo "az network vnet create -g $RESOURCE_GROUP -n $VIRTUAL_NETWORK --address-prefixes $ADDRESS_PREFIXES --subnet-name $SUBNET --subnet-prefixes $SUBNET_PREFIXES --location $REGION"
        az network vnet create -g $RESOURCE_GROUP -n $VIRTUAL_NETWORK --address-prefixes $ADDRESS_PREFIXES --subnet-name $SUBNET \
	   --subnet-prefixes $SUBNET_PREFIXES --location $REGION		
	if [ $? -ne 0 ] ; then
	    echo "Problem creating virtual network: $VIRTUAL_NETWORK in resource group: $RESOURCE_GROUP"
	    echo "Exiting..."
	    exit 22
	fi
    else
	echo "Found virtual network: $VIRTUAL_NETWORK in Resource Group $RESOURCE_GROUP"
    fi
}    


_az_set_private_dns_zone()
{
    if [ "$DNS_PRIVATE_ZONE" == "" ] ; then
        DNS_PRIVATE_ZONE_DEFAULT=$(az network private-dns zone list -g $RESOURCE_GROUP |  grep "$RESOURCE_GROUP" | awk '{ print $1 }')
        if [ "$DNS_PRIVATE_ZONE_DEFAULT" != "" ] ; then
	    DNS_PRIVATE_ZONE=$DNS_PRIVATE_ZONE_DEFAULT
        fi
    fi
    if [ "$DNS_VN_LINK" == "" ] ; then
      DNS_VN_LINK_DEFAULT=$(az network private-dns link vnet list -g $RESOURCE_GROUP -z $DNS_PRIVATE_ZONE |  grep "$RESOURCE_GROUP" | awk '{ print $1 }')
      if [ "$DNS_VN_LINK_DEFAULT" != "" ] ; then
        DNS_VN_LINK=$DNS_VN_LINK_DEFAULT
      fi
    fi
}

_az_enter_private_dns_zone()
{
    _az_set_private_dns_zone
    if [ $NON_INTERACT -eq 0 ] ; then    
	echo ""
	DNS_CHANGE=0
	if [ "$DNS_PRIVATE_ZONE" != "" ] ; then
  	    printf "Do you want to keep the DNS private zone ${DNS_PRIVATE_ZONE} (y/n) (default: y)? "
	    read CHANGE
            if [ "$CHANGE" == "n" ] || [ "$CHANGE" == "no" ] ; then
		DNS_CHANGE=1
	    fi
        else
	    DNS_CHANGE=1
	fi

	
	if [ $DNS_CHANGE -eq 1 ] ; then
	    az network private-dns zone list -g $RESOURCE_GROUP
	    echo ""
	    printf "Enter the name for the private DNS Zone (if it does not exist, it will be created): "
	    read DNS_PRIVATE_ZONE
	fi
	if [ "$DNS_PRIVATE_ZONE" == "" ] ; then
	    echo "Error: Private DNS Zone cannot be empty"
	    _az_enter_private_dns_zone
	    return	    
	fi
	
	LINK_CHANGE=0
	if [ "$DNS_VN_LINK" != "" ] ; then
  	    printf "Do you want to keep the DNS virtual network link ${DNS_VN_LINK} (${DNS_PRIVATE_ZONE} to ${VIRTUAL_NETWORK})) (y/n) (default: y)?"
	    read KEEP_LINK
            if [ "$KEEP_LINK" == "n" ] || [ "$KEEP_LINK" == "no" ] ; then
		LINK_CHANGE=1
	    fi
        else
	    LINK_CHANGE=1
	fi

	if [ $LINK_CHANGE -eq 1 ] ; then
	    echo ""
	    printf "Enter the name for the private DNS Zone to Virtual Network link: "
	    read DNS_VN_LINK
	fi

	if [ "$DNS_VN_LINK" == "" ] ; then
	    echo "Error: Private DNS Zone virtual Network link cannot be empty"
	    _az_enter_private_dns_zone
	    return
	fi
	
    fi

    az network private-dns zone show -g $RESOURCE_GROUP -n $DNS_PRIVATE_ZONE 2>&1 > /dev/null
	
    if [ $? -ne 0 ] ; then
	echo ""
	echo "Could not find DNS private zone, creating...."
	echo "az network private-dns zone create -g $RESOURCE_GROUP -n $DNS_PRIVATE_ZONE"
	az network private-dns zone create -g $RESOURCE_GROUP -n $DNS_PRIVATE_ZONE
	if [ $? -ne 0 ] ; then
	    echo "Problem creating the DNS private zone: $DNS_PRIVATE_ZONE in resource group $RESOURCE_GROUP"
	    echo "Exiting..."
	    exit 33
	fi
    else
	echo "Found DNS_PRIVATE_ZONE $DNS_PRIVATE_ZONE in Resource Group  $RESOURCE_GROUP"
    fi

    
    az network private-dns link vnet show -n $DNS_VN_LINK -g $RESOURCE_GROUP -z $DNS_PRIVATE_ZONE 2>&1 > /dev/null
    if [ $? -ne 0 ] ; then
	echo ""
	echo "Could not find DNS private zone Virtual Network Link, creating...."
        echo "az network private-dns link vnet create -g $RESOURCE_GROUP -n $DNS_VN_LINK -z $DNS_PRIVATE_ZONE -v $VIRTUAL_NETWORK -e true"
	az network private-dns link vnet create -g $RESOURCE_GROUP -n $DNS_VN_LINK -z $DNS_PRIVATE_ZONE -v $VIRTUAL_NETWORK -e true
	if [ $? -ne 0 ] ; then
	    echo "Problem creating the DNS private zone - virtual network link: $DNS_VN_LINK  in resource group $RESOURCE_GROUP"
	    echo "Exiting..."
	    exit 44
        fi
    else
	echo "Found DNS_VN_LINK ${DNS_PRIVATE_ZONE}/${DNS_VN_LINK} in Resource Group  $RESOURCE_GROUP"
    fi
}    



az_setup()
{
    which az 2>&1 > /dev/null
    if [ $? -ne 0 ] ; then

	echo "Azure CLI tools does not appear to be installed"
	printf 'Do you want to install Azure CLI tools?  (y/n) (default: y): '
	read 
	if [ "$INSTALL_AZ" == "y" ] || [ "$INSTALL_AZ" == "" ] ; then
            echo "Installing Azure CLI tools"
	else
	    echo "Exiting...."
	    exit 45
	fi

	if [ "$DISTRO" =~ "Ubuntu" ] ; then
	    sudo apt-get update -y
	    sudo apt-get install ca-certificates curl apt-transport-https lsb-release gnupg -y
	    curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
	    AZ_REPO=$(lsb_release -cs)
	    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
	    sudo apt-get update -y
	    sudo apt-get install azure-cli -y
	elif [[ "$DISTRO" =~ "centos" ]] || [[ "$DISTRO" == "os" ]] ; then
            sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
	    sudo sh -c 'echo -e "[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/azure-cli.repo'
	    sudo yum install azure-cli -y
        fi

	az login -o table
	if [ $? -ne 0 ] ; then
	    echo "Problem logging in to Azure"
	    echo "Exiting..."
	    exit 88
	fi

    fi

    _az_enter_subscription
    if [ $NON_INTERACT -eq 0 ] ; then
	clear_screen
    fi
    _az_enter_location
    if [ $NON_INTERACT -eq 0 ] ; then
	clear_screen
    fi
    _az_enter_resource_group
    if [ $NON_INTERACT -eq 0 ] ; then
	clear_screen
    fi
    _az_enter_virtual_network
    if [ $NON_INTERACT -eq 0 ] ; then
	clear_screen
    fi
    _az_enter_private_dns_zone
    if [ $NON_INTERACT -eq 0 ] ; then
	clear_screen
    fi

}


az_list_public_ips()
{
    _az_set_resource_group    
    az vm list-ip-addresses -g $RESOURCE_GROUP --output table #--show-details 
}

_az_precreate()
{
    az vm list-ip-addresses -g $RESOURCE_GROUP -n $NAME 2>&1 > /dev/null
    if [ $? -ne 0 ] ; then
	echo ""
	echo "WARNING:"	
	echo "VM already exists with name: $NAME"
	echo ""
	exit 12
    fi

    if [ $NON_INTERACT -eq 0 ] ; then    
	
	echo ""
	echo "For the $1 VM:"
	echo "VM type (size): $VM_TYPE"
	printf "Is the default VM type OK (y/n)? (default: y) "
	read KEEP_IMAGE
	if [ "$KEEP_IMAGE" == "y" ] || [ "$KEEP_IMAGE" == "" ] ; then
	    echo ""
	else
	    echo ""
	    echo "Example image types: Standard_E4as_v4, Standard_NV6_Promo, etc"
	    printf "Enter the VM type: "
	    read VM_TYPE
	fi
	echo "VM type selected: $VM_TYPE"

	
	echo ""
	echo "For the $1 VM:"
	echo "OS Image: $AZ_IMAGE"
	printf "Is the default image type OK (y/n)? (default: y) "
	read KEEP_IMAGE
	if [ "$KEEP_IMAGE" == "n" ] || [ "$KEEP_IMAGE" == "no" ] ; then
	    echo ""
	    echo "Example OS image types: UbuntuLTS, CentoS"
	    printf "Enter the OS image type: "
	    read AZ_IMAGE
	fi
	echo "OS Image selected: $AZ_IMAGE"
	
	echo ""
	echo "Boot disk size: $BOOT_SIZE_GBS"
	printf "Is the default boot disk size (GBs) OK (y/n)? (default: y) "
	read KEEP_SIZE
	if [ "$KEEP_SIZE" == "y" ] || [ "$KEEP_SIZE" == "" ] ; then
	    echo ""
	else
	    echo ""
	    printf "Enter the boot disk size in GBs: "
	    read BOOT_SIZE_GBS
	fi
	
	# echo ""
	# echo "Data disk size: $DATA_DISK_SIZES_GB"
	# printf "Is the additional data disk size (GBs) OK (y/n)? (default: y) "
	# read KEEP_SIZE
	# if [ "$KEEP_SIZE" == "y" ] || [ "$KEEP_SIZE" == "" ] ; then
	#     echo ""
	# else
	#     echo ""
	#     printf "Enter the data disk size in GBs: "
	#     read DATA_DISK_SIZES_GB
	# fi
    fi
    BOOT_SIZE=$BOOT_SIZE_GBS
}

az_create_gpu()
{
    set_api_instance_type
    VM_TYPE=$MACHINE_TYPE
    PPG=
    ACC_NETWORKING="$AZ_NETWORKING"
    if [ "$AZURE_PPG" != "" ] ; then
       PPG="--ppg=$AZURE_PPG"
    fi
    PUBLIC_IP_ATTR="--public-ip-sku Standard"    
    AZURE_ZONE="--zone $AZ_ZONE"    
    _az_create_vm $1
}

az_create_cpu()
{
    PPG=
    if [ "$AZURE_PPG" != "" ] ; then
        PPG="--ppg=$AZURE_PPG"
    fi
    ACC_NETWORKING="$AZ_NETWORKING"
    if [ "$1" == "head" ] ; then
        VM_TYPE=$AZ_HEAD_INSTANCE_TYPE
	ACC_NETWORKING=
    elif [ "$1" == "worker" ] ; then
        VM_TYPE=$AZ_WORKER_INSTANCE_TYPE
    fi 
    PUBLIC_IP_ATTR="--public-ip-sku Standard"
    AZURE_ZONE="--zone $AZ_ZONE"    
    _az_create_vm $1
}
_az_create_vm()
{
    _az_precreate $1

    AZURE_SPOT_VMS=
    if [ "$AZ_SPOT_VMS" == "yes" ] ; then
        AZURE_SPOT_VMS="--priority Spot --max-price=-1"
    fi
    
    if [ $DEBUG -eq 1 ] ; then    
	echo "
    az vm create -n $NAME -g $RESOURCE_GROUP --size $VM_TYPE \
       --image $AZ_IMAGE --os-disk-size-gb $BOOT_SIZE \
       --generate-ssh-keys --vnet-name $VIRTUAL_NETWORK --subnet $SUBNET \
       --location $REGION \
       --ssh-key-value ~/.ssh/id_rsa.pub $PUBLIC_IP_ATTR $AZURE_ZONE \
       $ACC_NETWORKING $PPG
"
	# --data-disk-sizes-gb $DATA_DISK_SIZE 
	# $AZ_NETWORKING \	
	#   --priority $PRIORITY --max-price 0.06 \
	    fi
    echo "Creating VM..."
    az vm create -n $NAME -g $RESOURCE_GROUP --size $VM_TYPE \
       --image $AZ_IMAGE --os-disk-size-gb $BOOT_SIZE \
       --generate-ssh-keys --vnet-name $VIRTUAL_NETWORK --subnet $SUBNET \
       --location $REGION \
       --ssh-key-value ~/.ssh/id_rsa.pub $PUBLIC_IP_ATTR $AZURE_ZONE \
       $ACC_NETWORKING $PPG $AZURE_SPOT_VMS

    if [ $? -ne 0 ] ; then
	echo "Problem creating VM. Exiting ..."
	exit 12
    fi
}


az_delete_vm()
{
    _az_set_resource_group
    az vm delete -g $RESOURCE_GROUP --name $VM_DELETE --yes --no-wait
    echo "Do you want to delete the resource group $RESOURCE_GROUP (y/n)?"
    read ACCEPT
    if [ "$ACCEPT" == "y" ] ; then
	az group delete -n $RESOURCE_GROUP --yes --no-wait
    fi
}


###################################################################
#  AWS VM OPERATIONS                                              #
###################################################################

check_aws_tools()
{
    which aws 2>&1 > /dev/null
    if [ $? -ne 0 ] ; then
	echo "AWS CLI does not appear to be installed"
	printf "Do you want to install AWS CLI? Enter: 'y/n' (default: y): "
	read INSTALL_AWS
	if [ "$INSTALL_AWS" == "y" ] || [ "$INSTALL_AWS" == "" ] ; then
            echo "Installing AWS CLI"
	else
	    echo "Exiting...."
	    exit 77
	fi

	curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
	unzip awscliv2.zip
	sudo ./aws/install
	aws --version
	if [ $? -ne 0 ] ; then
	    echo "Problem installing aws tools"
	    echo "Exiting..."
	    exit 88
	fi
        aws configure
    fi
}

aws_setup()
{
    if [ $NON_INTERACT -eq 0 ] ; then
	check_aws_tools
    fi
}

aws_list_public_ips()
{
    # aws ec2    --output table
    echo ""
}

_aws_precreate()
{
    echo ""
}

aws_create_gpu()
{
    echo ""    
}

aws_create_cpu()
{
    echo ""    
}

_aws_create_vm()
{
    _az_precreate $1        
}


aws_delete_vm()
{
    echo ""
}


###################################################################
#  ABSTRACT VM OPERATIONS                                              #
###################################################################

_missing_cloud()
{
    echo "You forgot to specify your cloud provider. "
    echo "Add the switch '-c gcp' for GCP, '-c aws' for AWS, '-c azure' for Azure."
    echo ""
    exit 42    
}    

create_vm_cpu()
{
    if [ "$CLOUD" == "gcp" ] ; then
	gcloud_create_cpu $1
    elif [ "$CLOUD" == "azure" ] ; then
	az_create_cpu $1
    elif [ "$CLOUD" == "aws" ] ; then
	aws_create_cpu $1
    else
	_missing_cloud	
    fi
}

create_vm_gpu()
{
    echo "Creating api-enabled VM...."
    echo ""
    if [ "$CLOUD" == "gcp" ] ; then
	gcloud_create_gpu $1
    elif [ "$CLOUD" == "azure" ] ; then
	az_create_gpu $1
    elif [ "$CLOUD" == "aws" ] ; then
	aws_create_gpu $1
    else
	_missing_cloud	
    fi
    echo ""
    echo "To check the VM status, run:"
    echo "./rondb-cloud-installer.sh -l -c gcp|azure|aws"
    echo ""
}


delete_vm()
{
    #enter_prefix
    if [ "$VM_DELETE" == "" ] ; then
        list_public_ips	
	echo ""
	printf "Enter the name of the VM to delete: "
	read VM_DELETE
    fi

    echo "Deleting $VM_DELETE"
    if [ "$CLOUD" == "gcp" ] ; then
	gcloud_delete_vm
    elif [ "$CLOUD" == "azure" ] ; then
	az_delete_vm
    elif [ "$CLOUD" == "aws" ] ; then
	aws_delete_vm
    else
	_missing_cloud	
    fi
    echo ""
    echo "To check the VM status, run:"
    echo "./rondb-cloud-installer.sh -l -c gcp|azure|aws"
    echo ""
    
}

list_public_ips()
{
    echo "Listing public IPs"
    echo ""
    if [ "$CLOUD" == "gcp" ] ; then
	gcloud_list_public_ips
    elif [ "$CLOUD" == "azure" ] ; then
	az_list_public_ips
    elif [ "$CLOUD" == "aws" ] ; then
	aws_list_public_ips
    else
	_missing_cloud	
    fi    
}

cloud_setup()
{

    RAW_SSH_KEY="${USER}:$(cat ~/.ssh/id_rsa.pub)"
    ESCAPED_SSH_KEY="$RAW_SSH_KEY"
    
    if [ "$CLOUD" == "gcp" ] ; then
	gcloud_setup
    elif [ "$CLOUD" == "azure" ] ; then
	az_setup
    elif [ "$CLOUD" == "aws" ] ; then
	aws_setup
    else
	_missing_cloud	
    fi    
}    

set_head_instance_type()
{
    if [ "$CLOUD" == "azure" ] ; then
        MACHINE_TYPE=$AZ_HEAD_INSTANCE_TYPE
    elif [ "$CLOUD" == "gcp" ] ; then 
        MACHINE_TYPE=$GCP_HEAD_INSTANCE_TYPE
    elif [ "$CLOUD" == "aws" ] ; then
        MACHINE_TYPE=$AWS_HEAD_INSTANCE_TYPE
    else
        echo "Error. Unrecognized cloud: $CLOUD "
        echo "Head type exiting."
        exit 444
    fi
    BOOT_SIZE_GBS=$HEAD_NODE_BOOT_SIZE
}

set_worker_instance_type()
{
    if [ "$CLOUD" == "azure" ] ; then
        MACHINE_TYPE=$AZ_WORKER_INSTANCE_TYPE
    elif [ "$CLOUD" == "gcp" ] ; then 
        MACHINE_TYPE=$GCP_WORKER_INSTANCE_TYPE
    elif [ "$CLOUD" == "aws" ] ; then
        MACHINE_TYPE=$AWS_WORKER_INSTANCE_TYPE        
    else
        echo "Error. Unrecognized cloud: $CLOUD "
        echo "Head type exiting."
        exit 444
    fi
    BOOT_SIZE_GBS=$DATA_NODE_BOOT_SIZE
}

set_api_instance_type()
{
    if [ "$CLOUD" == "azure" ] ; then
        MACHINE_TYPE=$AZ_API_INSTANCE_TYPE
    elif [ "$CLOUD" == "gcp" ] ; then 
        MACHINE_TYPE=$GCP_API_INSTANCE_TYPE
    elif [ "$CLOUD" == "aws" ] ; then
        MACHINE_TYPE=$AWS_API_INSTANCE_TYPE        
    else
        echo "Error. Unrecognized cloud: $CLOUD "
        echo "Head type exiting."
        exit 444
    fi


}



###################################################################
#   MAIN                                                          #
###################################################################
help()
{
    echo "usage: $SCRIPTNAME "
    echo " [-h|--help]      help message"
    echo " [-i|--install-action localhost|cluster]"
    echo "                 'localhost' installs RonDB on a single VM"
    echo "                 'cluster' installs RonDB on a multi-VM cluster"
    echo " [-c|--cloud gcp|azure] Name of the public cloud "
    echo " [--debug] Verbose logging for this script"
    echo " [-drc|--dry-run-create-vms]  creates the VMs, generates cluster definition (YML) files but doesn't run karamel."
    echo " [-a|--num-api-nodes num] Number of API nodes (MySQL Servers) to create for the cluster."
    echo " [-dc|--download-opensource-url url] downloads open-source binaries from this URL."
    echo " [-gdt|--gcp-data-node-instance-type compute instance type for database nodes in GCP]"
    echo " [-gat|--gcp-api-node-instance-type compute instance type for api nodes in GCP]"    
    echo " [-azdt|--azure-data-node-instance-type compute instance type for database nodes in Azure]"
    echo " [-azat|--azure-api-node-instance-type compute instance type for api nodes in Azure]"    
    echo " [-ght|--gcp-head-instance-type compute instance type for the head node on GCP (mgm server)]"
    echo " [-azht|--azure-head-instance-type compute instance type for the head node on Azure (mgm server)]"    
    echo " [-l|--list-public-ips] List the public ips of all VMs."
    echo " [-n|--vm-name-prefix name] The prefix for the VM name created."
    echo " [-ni|--non-interactive] skip license/terms acceptance and all confirmation screens."
    echo " [-os|--os-image] OS Image for nodes (azure or gcp image)."
    echo " [-ppg|--proximity-placement-group name] Use Azure Proximity Placement Group for nodes"    
    echo " [-rm|--remove] Delete a VM - you will be prompted for the name of the VM to delete."
    echo " [-sc|--skip-create] skip creating the VMs, use the existing VM(s) with the same vm_name(s)."
    echo " [-w|--num-data-nodes num] Number of Database Nodes to create for the cluster."
    echo " [-dt|--database-node-instance-type compute instance type for database nodes (lookup name in GCP,Azure)]"
    echo " [-r|--num-replicas num] specify the number of database replicas to use."
    echo " [-z|--availability-zone num] Availability Zone (normally 1,2 or 3)"
    echo " [-bh|--head-node-boot-size num] Head node boot size (in GBytes)"
    echo " [-bd|--database-node-boot-size num] Database node boot size (in GBytes)"
    echo " [-ba|--api-node-boot-size num] API node boot size (in GBytes)"
    echo " [-u|--use-spot-vms] Use Spot VMs"
    
    echo ""
    echo "Azure options"
    echo " [-alink|--azure-dns-virtual-network-link link] Azure private DNS Zone to virtual network link name."
    echo " [-adns|--azure-private-dns-zone fqdn] Azure private DNS Zone fqdn."	
    echo " [-avn|--azure-virtual-network network] Azure virtual network to use."
    echo " [-arg|--azure-resource-group group] Azure resource group to use."
    echo " [-acc-off|--accelerated-networking-off] Set if no accelerated networking is desirable"    
    echo ""
    echo "GCP options"
    echo " [-nvme|--nvme num_disks] the number of disks to attach to each database node"	          
    exit 3

}


while [ $# -gt 0 ]; do    # Until you run out of parameters . . .
    case "$1" in
	-h|--help|-help)
	    help
	    ;;
	-i|--install-action)
	    shift
	    case $1 in
		localhost)
		    INSTALL_ACTION=$INSTALL_CPU
		    ACTION="localhost"
                    GCP_HEAD_INSTANCE_TYPE=n2-standard-8
                    AZ_HEAD_INSTANCE_TYPE=Standard_D8s_v4
  		    ;;
		cluster)
                    INSTALL_ACTION=$INSTALL_CLUSTER
		    ACTION="cluster"
		    ;;
		*)
		    echo "Could not recognise '-i' option: $1"
              	    get_install_option_help
                    exit 33
	    esac
	    ;;
	-c|--cloud)
	    shift
	    case $1 in
		gcp|aws|azure)
		    CLOUD=$1
  		    ;;
		*)
                    echo "Invalid option for '-c' option: $1"
		    echo "Valid options are: gcp | azure | aws"
                    exit 44
	    esac
	    ;;

	-alink|--azure-dns-virtual-network-link)
	    shift
	    DNS_VN_LINK=$1
            ;;
	-avn|--azure-virtual-network)
	    shift
	    VIRTUAL_NETWORK=$1
	    ;;
	-arg|--azure-resource-group)
	    shift
	    RESOURCE_GROUP=$1
	    ;;
	-adns|--azure-private-dns-zone)
	    shift
	    DNS_PRIVATE_ZONE=$1
	    ;;
        -at|--api-node-instance-type)
            shitft
            API_INSTANCE_TYPE=$1
            ;;
	-dc|--download-opensource-url)
      	    shift
	    DOWNLOAD_URL=$1
	    ;;
	--debug)
	    DEBUG=1
	    ;;
	-drc|--dry-run-create-vms)
            DRY_RUN_CREATE_VMS=1
            ;;
	-a|--num-api-nodes)
            shift
	    NUM_WORKERS_GPU=$1
            ;;
	-ght|--gcp-head-instance-type)
      	    shift
	    GCP_HEAD_INSTANCE_TYPE=$1
            ;;
	-azht|--azure-head-instance-type)
      	    shift
	    AZ_HEAD_INSTANCE_TYPE=$1
            ;;
	-gdt|--gcp-data-node-instance-type)
      	    shift
	    GCP_WORKER_INSTANCE_TYPE=$1
            ;;	    	
	-azdt|--azure-data-node-instance-type)
      	    shift
	    AZ_WORKER_INSTANCE_TYPE=$1
            ;;	    	
	-gat|--gcp-api-node-instance-type)
      	    shift
	    GCP_API_INSTANCE_TYPE=$1
            ;;	    	
	-azat|--azure-api-node-instance-type)
      	    shift
	    AZ_API_INSTANCE_TYPE=$1
            ;;	    	
	-nvme|--nvme)
	    shift
	    NUM_NVME_DRIVES_PER_WORKER=$1
            for (( i=1; i<=${NUM_NVME_DRIVES_PER_WORKER}; i++ ))
	    do
		LOCAL_DISK="$LOCAL_DISK --local-ssd=interface=NVME"
	    done
     	    ;;
	-l|--list-public-ips)
	    DO_LISTING=1
	    ;;	
	-ni|--non-interactive)
	    NON_INTERACT=1
	    ;;
	-rm|--remove)
	    RM_TYPE="delete"
	    ;;
	-n|--vm-name-prefix)
      	    shift
	    PREFIX=$1
            ;;
	-sc|--skip-create)
      	    SKIP_CREATE=1
            ;;
	-r|--num-replicas)
      	    shift
      	    NUM_REPLICAS=$1
            ;;
	-p|--http-proxy)
            shift
            PROXY=$1
            proto="$(echo $PROXY | grep :// | sed -e's,^\(.*://\).*,\1,g')"
	    if [ "$proto" == "http://" ] ; then
		export http_proxy=$PROXY
	    elif [ "$proto" == "https://" ] ; then
		export https_proxy=$PROXY
	    else
		echo "Invalid proxy URL: $PROXY"
		echo "URL must start with 'https://'  or 'http://'"
		exit 20
	    fi	      
	    ;;
	-w|--num-data-nodes)
            shift
	    NUM_WORKERS_CPU=$1
            ;;
 	-ppg|--proximity-placement-group)
 	    shift
 	    AZURE_PPG=$1
            ;;
 	-z|--availability-zone)
 	    shift
 	    AZ_ZONE=$1
 	    ZONE=$1
            ;;
 	-os|--os-image)
 	    shift
 	    AZ_IMAGE=$1
 	    GCP_IMAGE=$1
            ;;
 	-acc-off|--accelerated-networking-off)
 	    AZ_NETWORKING=
            ;;
        -bh|--head-node-boot-size)
 	    shift
 	    HEAD_NODE_BOOT_SIZE=$1
            ;;
        -bd|--database-node-boot-size)
 	    shift
 	    DATA_NODE_BOOT_SIZE=$1
            ;;                                                                        
        -ba|--api-node-boot-size)
 	    shift
 	    API_NODE_BOOT_SIZE=$1
            ;;
        -u|--use-spot-vms)
 	    shift
    	    AZ_SPOT_VMS="yes"
            ;;
	*)
	    exit_error "Unrecognized parameter: $1"
	    ;;
    esac
    shift       # Check next set of parameters.
done


if [ $DO_LISTING -eq 1 ] ; then
    list_public_ips
    exit 0
fi

if [ "$RM_TYPE" != "" ] ; then
    delete_vm
    exit 0
fi    

if [ $DRY_RUN -eq 1 ] ; then
    NON_INTERACT=1
fi    

if [ $NON_INTERACT -eq 0 ] ; then    
    check_linux
    splash_screen
    display_license
    accept_license
    enter_email
    enter_cloud
    install_action
    enter_prefix
else
    if [ "$PREFIX" == "" ] ; then
	PREFIX=$USER
    fi
fi

if [ "$CLOUD" != "gcp" ] ; then
    if [ $NUM_NVME_DRIVES_PER_WORKER -gt 0 ] ; then
	echo ""
	echo "Sorry! NVM disks are currently only supported for GCP."
	echo ""
        exit 88
    fi
fi


download_installer
if [ $DRY_RUN -eq 1 ] ; then
    echo ""
    echo "The cluster definition (YML) files are now available here:"
    echo "$(pwd)/$CLUSTER_DEFINITIONS_DIR"
    ls -l $(pwd)/$CLUSTER_DEFINITIONS_DIR
    echo ""    
    echo "You can customize/edit them and re-run this installer."
    echo ""
    exit 0
fi    
cloud_setup

HEAD_GPU=0
if [ $INSTALL_ACTION -eq $INSTALL_CPU ] ; then
    set_name "cpu"
elif [ $INSTALL_ACTION -eq $INSTALL_GPU ] ; then
    set_name "api"
    HEAD_GPU=1
elif [ $INSTALL_ACTION -eq $INSTALL_CLUSTER ] ; then
    set_name "head"    
else
    exit_error "Bad install action: $INSTALL_ACTION"
fi

if [ $SKIP_CREATE -eq 0 ] ; then
    set_head_instance_type
    if [ "$CLOUD" == "gcp" ] ; then
        # Create a firewall rule to open the port for grafana and Karamel on the head node, ignore errors if already exists
        gcloud compute firewall-rules create grafana-rondb --source-tags=grafana --allow tcp:3000 --source-ranges=0.0.0.0/0 --description="Open port for Grafana" 1>&2 > /dev/null
        gcloud compute firewall-rules create karamel --allow tcp:9090 --source-tags=karamel --source-ranges=0.0.0.0/0 --description="Open port for Karamel" 1>&2 > /dev/null        
    fi
    
    if [ $HEAD_GPU -eq 1 ] ; then    
	create_vm_gpu "head"
    else
	create_vm_cpu "head"
    fi
    if [ "$CLOUD" == "azure" ] ; then
        sleep 20
        # Shortcut to create a network security group (NSG) add the 443 inbound rule, and applies it to the VM 
        az vm open-port -g $RESOURCE_GROUP -n $NAME --port 443 --priority 900
        az vm open-port -g $RESOURCE_GROUP -n $NAME --port 9090 --priority 898
        az vm open-port -g $RESOURCE_GROUP -n $NAME --port 3000 --priority 897
    fi    
    if [ $INSTALL_ACTION -eq $INSTALL_CLUSTER ] ; then
	set_worker_instance_type
        cpu_worker_size
	set_api_instance_type        
        gpu_worker_size
    fi
else
    echo "Skipping VM creation...."
fi	

if [ $INSTALL_ACTION -eq $INSTALL_CLUSTER ] ; then
    set_name "head"    
fi  

echo "Wait for VMs to be properly started"
sleep 60

IP=
while [ "$IP" == "" ] ; do
    echo "Getting IPs"
    get_ips
    sleep 5
done

echo "Found IP: $IP"

host_ip=$IP
clear_known_hosts

#if [[ "$GCP_IMAGE" =~ "centos" ]] || [[ "$AZ_IMAGE" =~ "centos" ]] ; then
#    ssh -t -o StrictHostKeyChecking=no $IP "sudo yum install wget -y > /dev/null"
#fi    


echo "Installing installer on $IP"
scp -o StrictHostKeyChecking=no ./.tmp/rondb-installer.sh ${IP}:
if [ $? -ne 0 ] ; then
    echo "Problem copying installer to head server. Exiting..."
    exit 10
fi    

ssh -t -o StrictHostKeyChecking=no $IP "mkdir -p $CLUSTER_DEFINITIONS_DIR"
if [ $? -ne 0 ] ; then
    echo "Problem creating $CLUSTER_DEFINITIONS_DIR directory on head server. Exiting..."
    exit 11
fi    

scp -o StrictHostKeyChecking=no ./.tmp/$CLUSTER_DEFINITIONS_DIR/rondb-*.yml ${IP}:~/${CLUSTER_DEFINITIONS_DIR}/
if [ $? -ne 0 ] ; then
    echo "Problem scp'ing cluster definitions to head server. Exiting..."
    exit 12
fi    

if [ $INSTALL_ACTION -eq $INSTALL_CLUSTER ] ; then

    #    if [[ $(AZ_IMAGE) =~ "Ubuntu" ]] && [[ $OS_VERSION -gt 18 ]] ; then
    if [[ $OS_VERSION -gt 18 ]] ; then    
       ssh -t -o StrictHostKeyChecking=no $IP "if [ ! -e ~/.ssh/id_rsa.pub ] ; then cat /dev/zero | ssh-keygen -m PEM -q -N \"\" ; fi"
    else
       ssh -t -o StrictHostKeyChecking=no $IP "if [ ! -e ~/.ssh/id_rsa.pub ] ; then cat /dev/zero | ssh-keygen -q -N \"\" ; fi"
    fi

    pubkey=$(ssh -t -o StrictHostKeyChecking=no $IP "cat ~/.ssh/id_rsa.pub")

    keyfile=".pubkey.pub"
    echo "$pubkey" > $keyfile
    echo ""
    echo "Public key for head node is:"
    echo "$pubkey"
    echo ""


    WORKERS="-w "

    if [ $NUM_WORKERS_CPU -eq 0 ] && [ $NUM_WORKERS_GPU -eq 0 ] ; then
	WORKERS="-w none "
    fi

    i=0
    while [ $i -lt ${CPUS} ] ;
    do
	host_ip=${CPU[${i}]}
	if [ $DEBUG -eq 1 ] ; then
	    echo "I think host_ip is ${CPU[$i]}"
	    echo "I think host_ip is ${CPU[${i}]}"
	    echo "All  hosts ${CPU[*]}"
	fi
	clear_known_hosts

	ssh-copy-id -o StrictHostKeyChecking=no -f -i $keyfile ${CPU[${i}]}
	ssh -t -o StrictHostKeyChecking=no $IP "ssh -t -o StrictHostKeyChecking=no ${PRIVATE_CPU[${i}]} \"pwd\""
	if [ $? -ne 0 ] ; then
	    echo ""
	    echo "Error. Public key SSH from $IP to ${PRIVATE_CPU[${i}]} not working."
	    echo "Exiting..."
	    echo ""
	    exit 9
	else
	    echo "Success: SSH from $IP to ${PRIVATE_CPU[${i}]}"
	fi

	WORKERS="${WORKERS}${PRIVATE_CPU[${i}]},"
	if [ $DEBUG -eq 1 ] ; then
	    echo "cpu workers: $WORKERS"
	fi
	i=$((i+1))
    done

    i=0
    while [ $i -lt ${GPUS} ] ;
    do
	host_ip=${GPU[${i}]}
	if [ $DEBUG -eq 1 ] ; then	
	    echo "I think API host_ip is ${GPU[$i]}"
	    echo "I think API host_ip is ${GPU[${i}]}"
	    echo "All  hosts ${GPU[*]}"
	fi
	clear_known_hosts
	ssh-copy-id -o StrictHostKeyChecking=no -f -i $keyfile ${GPU[${i}]}
	if [ $? -ne 0 ] ; then
            echo ""
            echo "Problem copying ssh key to host."
            echo "ssh-copy-id -o StrictHostKeyChecking=no -f -i $keyfile ${GPU[${i}]}"
        fi
	ssh -t -o StrictHostKeyChecking=no $IP "ssh -t -o StrictHostKeyChecking=no ${PRIVATE_GPU[${i}]} \"pwd\""
	if [ $? -ne 0 ] ; then
	    echo ""
            echo "	ssh -t -o StrictHostKeyChecking=no $IP \"ssh -t -o StrictHostKeyChecking=no ${PRIVATE_GPU[${i}]} \"pwd\"\""
	    echo "Error. Public key SSH from $IP to ${PRIVATE_GPU[${i}]} not working."
	    echo "Exiting..."
	    echo ""
	    exit 9
	else
	    echo "Success: SSH from $IP to ${PRIVATE_GPU[${i}]}"
	fi
	ssh -t -o StrictHostKeyChecking=no $IP "ssh -t -o StrictHostKeyChecking=no ${GPU[${i}]} \"touch .api-node\""
        
	WORKERS="${WORKERS}${PRIVATE_GPU[${i}]},"
	if [ $DEBUG -eq 1 ] ; then
	    echo "api workers: $WORKERS"
	fi
	i=$((i+1))	
    done

    if [ "$WORKERS" != "-w none " ] ; then
        WORKERS=${WORKERS::-1}
    fi
    
    if [ $DEBUG -eq 1 ] ; then    
	echo "ALL WORKERS: $WORKERS"
    fi
else
    WORKERS="-w none"
fi

if [ $DEBUG -eq 1 ] ; then	
    echo ""
    echo "Running installer on $IP :"
    echo ""
fi

DRY_RUN_KARAMEL=""
if [ $DRY_RUN_CREATE_VMS -eq 1 ] ; then
    DRY_RUN_KARAMEL=" -dr "
fi

NVME_SWITCH=""
if [ $NUM_NVME_DRIVES_PER_WORKER -gt 0 ] ; then
    NVME_SWITCH=" -nvme $NUM_NVME_DRIVES_PER_WORKER "
fi
if [ $DEBUG -eq 1 ] ; then	
    echo "ssh -t -o StrictHostKeyChecking=no $IP \"~/rondb-installer.sh -i $ACTION -ni -c $CLOUD ${DOWNLOAD}${DOWNLOAD_USERNAME}${DOWNLOAD_PASSWORD}${WORKERS}${DRY_RUN_KARAMEL}${NVME_SWITCH} && sleep 5\""
fi
ssh -t -o StrictHostKeyChecking=no $IP "~/rondb-installer.sh -r $NUM_REPLICAS -i $ACTION -ni -c $CLOUD ${DOWNLOAD}${DOWNLOAD_USERNAME}${DOWNLOAD_PASSWORD}${WORKERS}${DRY_RUN_KARAMEL}${NVME_SWITCH} && sleep 5"

if [ $? -ne 0 ] ; then
    echo "Problem running installer. Exiting..."
    exit 2
fi

if [ $DRY_RUN_CREATE_VMS -eq 0 ] ; then    
    echo ""
    echo "****************************************"
    echo "*                                      *"
    echo "* Public IP access to Karamel at:      *"
    echo "  http://${IP}:9090/index.html   "
    echo "*                                      *"
    echo "*                                      *"
    echo "* View installation progress:          *"
    echo " ssh ${IP} \"tail -f installation.log\"   "
    echo "*                                      *"
    echo "****************************************"
else
    echo ""
    echo "****************************************"
    echo "*                                      *"
    echo "*                                      *"    
    echo " ssh ${IP}"
    echo " Then, edit your cluster definition ~/$CLUSTER_DEFINITIONS_DIR/$YML_FILE"
    echo " Then run karamel on your new cluster definition: "
    echo " cd karamel-0.6"
    echo " setsid ./bin/karamel -headless -launch ../$YML_FILE > ../installation.log 2>&1 &"
    echo "*                                      *"    
    echo "****************************************"
fi    
