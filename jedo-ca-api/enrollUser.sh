#!/bin/bash
CA_NAME=$1
CA_PORT=$2
USER_MSP_DIR=$3
USER_NAME=$4
USER_PASS=$5

docker exec $CA_NAME fabric-ca-client enroll -u https://$USER_NAME:$USER_PASS@tls.$CA_NAME:$CA_PORT \
   --mspdir $USER_MSP_DIR --csr.cn tls.$CA_NAME
