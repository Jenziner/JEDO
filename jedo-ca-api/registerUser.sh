#!/bin/bash
CA_NAME=$1
CA_PASS=$2
CA_PORT=$3
CA_MSP_DIR=$4
USER_NAME=$5
USER_PASS=$6
ORGANIZATION=$7

docker exec $CA_NAME fabric-ca-client register -u https://$CA_NAME:$CA_PASS@tls.$CA_NAME:$CA_PORT \
   --mspdir $CA_MSP_DIR --id.name $USER_NAME --id.secret $USER_PASS --id.type client --id.affiliation $ORGANIZATION \
   --enrollment.type idemix --idemix.curve gurvy.Bn254
