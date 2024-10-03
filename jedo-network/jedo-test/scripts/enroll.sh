###############################################################
#!/bin/bash
#
# Register and enroll all identities needed for the JEDO-Token-Test network.
#
# Prerequisits:
#   - yq: 
#       - installation: sudo wget https://github.com/mikefarah/yq/releases/download/v4.6.3/yq_linux_amd64 -O /usr/local/bin/yq
#       - make it executable: chmod +x /usr/local/bin/yq
#
###############################################################
set -Exeuo pipefail
ls scripts/enroll.sh || { echo "ScriptInfo: run this script from the root directory: ./scripts/enroll.sh"; exit 1; }


###############################################################
# Params - from ./config/network-config.yaml
###############################################################
CONFIG_FILE="./config/network-config.yaml"
ECOSYSTEM_NAME=$(yq eval '.Ecosystem.Name' "$CONFIG_FILE")
NETWORK_CA_NAME=$(yq eval '.Network.CA.Name' "$CONFIG_FILE")
NETWORK_CA_PORT=$(yq eval '.Network.CA.Port' "$CONFIG_FILE")
NETWORK_CA_PASS=$(yq eval '.Network.CA.Pass' "$CONFIG_FILE")
NETWORK_CA_ORG=$(yq eval '.Network.CA.Org' "$CONFIG_FILE")
ORDERERS=$(yq e '.Network.Orderers[] | .Name' $CONFIG_FILE)
ORDERERS_PASSWORD=$(yq e '.Network.Orderers[] | .Pass' $CONFIG_FILE)
ORDERERS_ORG=$(yq e '.Network.Orderers[] | .Org' $CONFIG_FILE)
PEERS=$(yq e '.Network.Peers[] | .Name' $CONFIG_FILE)
PEERS_PASSWORD=$(yq e '.Network.Peers[] | .Pass' $CONFIG_FILE)
PEERS_ORG=$(yq e '.Network.Peers[] | .Org' $CONFIG_FILE)
FSCS=$(yq e '.Ecosystem.FSCs[] | .Name' $CONFIG_FILE)
FSCS_PASSWORD=$(yq e '.Ecosystem.FSCs[] | .Pass' $CONFIG_FILE)
FSCS_OWNER=$(yq e '.Ecosystem.FSCs[] | .Owner' $CONFIG_FILE)
AUDITORS=$(yq e '.Ecosystem.Auditors[] | .Name' $CONFIG_FILE)
AUDITORS_PASSWORD=$(yq e '.Ecosystem.Auditors[] | .Pass' $CONFIG_FILE)
AUDITORS_OWNER=$(yq e '.Ecosystem.Auditors[] | .Owner' $CONFIG_FILE)
ISSUERS=$(yq e '.Ecosystem.Issuers[] | .Name' $CONFIG_FILE)
ISSUERS_PASSWORD=$(yq e '.Ecosystem.Issuers[] | .Pass' $CONFIG_FILE)
ISSUERS_OWNER=$(yq e '.Ecosystem.Issuers[] | .Owner' $CONFIG_FILE)
USERS=$(yq e '.Ecosystem.Users[] | .Name' $CONFIG_FILE)
USERS_PASSWORD=$(yq e '.Ecosystem.Users[] | .Pass' $CONFIG_FILE)
USERS_OWNER=$(yq e '.Ecosystem.Users[] | .Owner' $CONFIG_FILE)


###############################################################
# Set variables
###############################################################
export FABRIC_CA_CLIENT_HOME=$PWD/keys


###############################################################
# enroll admin
###############################################################
fabric-ca-client enroll -u http://$NETWORK_CA_NAME:$NETWORK_CA_PASS@$NETWORK_CA_NAME:$NETWORK_CA_PORT -M $FABRIC_CA_CLIENT_HOME/Client
fabric-ca-client affiliation add $NETWORK_CA_ORG


###############################################################
# enroll orderers
###############################################################
echo "ScriptInfo: enroll orderer"
for index in $(seq 0 $(($(echo "$ORDERERS" | wc -l) - 1))); do
  ORDERER=$(echo "$ORDERERS" | sed -n "$((index+1))p")
  ORDERER_PASSWORD=$(echo "$ORDERERS_PASSWORD" | sed -n "$((index+1))p")
  ORDERER_ORG=$(echo "$ORDERERS_ORG" | sed -n "$((index+1))p")
  fabric-ca-client register -u http://$NETWORK_CA_NAME:$NETWORK_CA_PORT --id.name $ORDERER --id.secret $ORDERER_PASSWORD --id.type orderer --id.affiliation $ORDERER_ORG
  fabric-ca-client enroll -u http://$ORDERER:$ORDERER_PASSWORD@$NETWORK_CA_NAME:$NETWORK_CA_PORT -M $FABRIC_CA_CLIENT_HOME/$ORDERER_ORG/$ORDERER/msp
  fabric-ca-client enroll -u http://$ORDERER:$ORDERER_PASSWORD@$NETWORK_CA_NAME:$NETWORK_CA_PORT --enrollment.profile tls -M $FABRIC_CA_CLIENT_HOME/$ORDERER_ORG/$ORDERER/tls
done


###############################################################
# enroll peers
###############################################################
echo "ScriptInfo: enroll peers"
for index in $(seq 0 $(($(echo "$PEERS" | wc -l) - 1))); do
  PEER=$(echo "$PEERS" | sed -n "$((index+1))p")
  PEER_PASSWORD=$(echo "$PEERS_PASSWORD" | sed -n "$((index+1))p")
  PEER_ORG=$(echo "$PEERS_ORG" | sed -n "$((index+1))p")
  fabric-ca-client register -u http://$NETWORK_CA_NAME:$NETWORK_CA_PORT --id.name $PEER --id.secret $PEER_PASSWORD --id.type peer --id.affiliation $PEER_ORG
  fabric-ca-client enroll -u http://$PEER:$PEER_PASSWORD@$NETWORK_CA_NAME:$NETWORK_CA_PORT -M $FABRIC_CA_CLIENT_HOME/$PEER_ORG/$PEER/msp
  fabric-ca-client enroll -u http://$PEER:$PEER_PASSWORD@$NETWORK_CA_NAME:$NETWORK_CA_PORT --enrollment.profile tls -M $FABRIC_CA_CLIENT_HOME/$PEER_ORG/$PEER/tls
done


###############################################################
# Fabric Smart Client node identities (identity of the node, used when talking to other nodes)
###############################################################
echo "ScriptInfo: register fsc"
for index in $(seq 0 $(($(echo "$FSCS" | wc -l) - 1))); do
  FSC=$(echo "$FSCS" | sed -n "$((index+1))p")
  FSC_PASSWORD=$(echo "$FSCS_PASSWORD" | sed -n "$((index+1))p")
  FSC_OWNER=$(echo "$FSCS_OWNER" | sed -n "$((index+1))p")
  fabric-ca-client register -u http://$NETWORK_CA_NAME:$NETWORK_CA_PORT --id.name fsc$FSC --id.secret $FSC_PASSWORD --id.type client
  fabric-ca-client enroll -u http://fsc$FSC:$FSC_PASSWORD@$NETWORK_CA_NAME:$NETWORK_CA_PORT -M $FABRIC_CA_CLIENT_HOME/$ECOSYSTEM_NAME/$FSC_OWNER/fsc/msp
  # make private key name predictable
  mv "$FABRIC_CA_CLIENT_HOME/$ECOSYSTEM_NAME/$FSC_OWNER/fsc/msp/keystore/"* "$FABRIC_CA_CLIENT_HOME/$ECOSYSTEM_NAME/$FSC_OWNER/fsc/msp/keystore/priv_sk"
done


###############################################################
# Issuer and Auditor wallet users (non-anonymous)
###############################################################
echo "ScriptInfo: register auditors"
for index in $(seq 0 $(($(echo "$AUDITORS" | wc -l) - 1))); do
  AUDITOR=$(echo "$AUDITORS" | sed -n "$((index+1))p")
  AUDITOR_PASSWORD=$(echo "$AUDITORS_PASSWORD" | sed -n "$((index+1))p")
  AUDITOR_OWNER=$(echo "$AUDITORS_OWNER" | sed -n "$((index+1))p")
  fabric-ca-client register -u http://$NETWORK_CA_NAME:$NETWORK_CA_PORT --id.name $AUDITOR --id.secret $AUDITOR_PASSWORD --id.type client
  fabric-ca-client enroll -u http://$AUDITOR:$AUDITOR_PASSWORD@$NETWORK_CA_NAME:$NETWORK_CA_PORT -M $FABRIC_CA_CLIENT_HOME/$ECOSYSTEM_NAME/$AUDITOR_OWNER/$AUDITOR/msp
done
echo "ScriptInfo: register issuers"
for index in $(seq 0 $(($(echo "$ISSUERS" | wc -l) - 1))); do
  ISSUER=$(echo "$ISSUERS" | sed -n "$((index+1))p")
  ISSUER_PASSWORD=$(echo "$ISSUERS_PASSWORD" | sed -n "$((index+1))p")
  ISSUER_OWNER=$(echo "$ISSUERS_OWNER" | sed -n "$((index+1))p")
  fabric-ca-client register -u http://$NETWORK_CA_NAME:$NETWORK_CA_PORT --id.name $ISSUER --id.secret $ISSUER_PASSWORD --id.type client
  fabric-ca-client enroll -u http://$ISSUER:$ISSUER_PASSWORD@$NETWORK_CA_NAME:$NETWORK_CA_PORT -M $FABRIC_CA_CLIENT_HOME/$ECOSYSTEM_NAME/$ISSUER_OWNER/$ISSUER/msp
done


###############################################################
# Owner wallet users (pseudonymous) on all owner nodes
###############################################################
echo "ScriptInfo: register users"
for index in $(seq 0 $(($(echo "$USERS" | wc -l) - 1))); do
  USER=$(echo "$USERS" | sed -n "$((index+1))p")
  USER_PASSWORD=$(echo "$USERS_PASSWORD" | sed -n "$((index+1))p")
  USER_OWNER=$(echo "$USERS_OWNER" | sed -n "$((index+1))p")
  fabric-ca-client register -u http://$NETWORK_CA_NAME:$NETWORK_CA_PORT --id.name $USER --id.secret $USER_PASSWORD --id.type client --enrollment.type idemix --idemix.curve gurvy.Bn254
  fabric-ca-client enroll -u http://$USER:$USER_PASSWORD@$NETWORK_CA_NAME:$NETWORK_CA_PORT -M $FABRIC_CA_CLIENT_HOME/$ECOSYSTEM_NAME/$USER_OWNER/wallet/$USER/msp --enrollment.type idemix --idemix.curve gurvy.Bn254
done


###############################################################
# set permissions
###############################################################
chmod -R 777 ./keys
echo "DEBUG END peer cert"
exit 1
