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
ADMINS_NAME=$(yq e '.Network.Admins[] | .Name' $CONFIG_FILE)
ADMINS_PASS=$(yq e '.Network.Admins[] | .Pass' $CONFIG_FILE)
ADMINS_ORG=$(yq e '.Network.Admins[] | .Org' $CONFIG_FILE)
ORDERERS_NAME=$(yq e '.Network.Orderers[] | .Name' $CONFIG_FILE)
ORDERERS_PASS=$(yq e '.Network.Orderers[] | .Pass' $CONFIG_FILE)
ORDERERS_ORG=$(yq e '.Network.Orderers[] | .Org' $CONFIG_FILE)
PEERS_NAME=$(yq e '.Network.Peers[] | .Name' $CONFIG_FILE)
PEERS_PASS=$(yq e '.Network.Peers[] | .Pass' $CONFIG_FILE)
PEERS_ORG=$(yq e '.Network.Peers[] | .Org' $CONFIG_FILE)
FSCS_NAME=$(yq e '.Ecosystem.FSCs[] | .Name' $CONFIG_FILE)
FSCS_PASS=$(yq e '.Ecosystem.FSCs[] | .Pass' $CONFIG_FILE)
FSCS_OWNER=$(yq e '.Ecosystem.FSCs[] | .Owner' $CONFIG_FILE)
AUDITORS_NAME=$(yq e '.Ecosystem.Auditors[] | .Name' $CONFIG_FILE)
AUDITORS_PASS=$(yq e '.Ecosystem.Auditors[] | .Pass' $CONFIG_FILE)
AUDITORS_OWNER=$(yq e '.Ecosystem.Auditors[] | .Owner' $CONFIG_FILE)
ISSUERS_NAME=$(yq e '.Ecosystem.Issuers[] | .Name' $CONFIG_FILE)
ISSUERS_PASS=$(yq e '.Ecosystem.Issuers[] | .Pass' $CONFIG_FILE)
ISSUERS_OWNER=$(yq e '.Ecosystem.Issuers[] | .Owner' $CONFIG_FILE)
USERS_NAME=$(yq e '.Ecosystem.Users[] | .Name' $CONFIG_FILE)
USERS_PASS=$(yq e '.Ecosystem.Users[] | .Pass' $CONFIG_FILE)
USERS_OWNER=$(yq e '.Ecosystem.Users[] | .Owner' $CONFIG_FILE)


###############################################################
# Set variables
###############################################################
export FABRIC_CA_CLIENT_HOME=$PWD/keys


###############################################################
# enroll client
###############################################################
fabric-ca-client enroll -u http://$NETWORK_CA_NAME:$NETWORK_CA_PASS@$NETWORK_CA_NAME:$NETWORK_CA_PORT -M $FABRIC_CA_CLIENT_HOME/Client
fabric-ca-client affiliation add $NETWORK_CA_ORG


###############################################################
# enroll admins
###############################################################
echo "ScriptInfo: enroll admin"
for index in $(seq 0 $(($(echo "$ADMINS_NAME" | wc -l) - 1))); do
  ADMIN_NAME=$(echo "$ADMINS_NAME" | sed -n "$((index+1))p")
  ADMIN_PASS=$(echo "$ADMINS_PASS" | sed -n "$((index+1))p")
  ADMIN_ORG=$(echo "$ADMINS_ORG" | sed -n "$((index+1))p")
  #TODO: read "ca.jenziner.jedo.test" from network-config.yaml
  CA_CERT_PATH="$FABRIC_CA_CLIENT_HOME/$ADMIN_ORG/ca.jenziner.jedo.test/ca-cert.pem" 
  ADMIN_MSP_DIR=$FABRIC_CA_CLIENT_HOME/$ADMIN_ORG/$ADMIN_NAME/msp
  ADMIN_TLS_DIR=$FABRIC_CA_CLIENT_HOME/$ADMIN_ORG/$ADMIN_NAME/tls
  fabric-ca-client register  -u http://$NETWORK_CA_NAME:$NETWORK_CA_PORT --id.name $ADMIN_NAME --id.secret $ADMIN_PASS --id.type admin --id.affiliation $ADMIN_ORG
  fabric-ca-client enroll -u http://$ADMIN_NAME:$ADMIN_PASS@$NETWORK_CA_NAME:$NETWORK_CA_PORT -M $ADMIN_MSP_DIR
  fabric-ca-client enroll -u http://$ADMIN_NAME:$ADMIN_PASS@$NETWORK_CA_NAME:$NETWORK_CA_PORT --enrollment.profile tls -M $ADMIN_TLS_DIR
  mkdir -p $ADMIN_MSP_DIR/admincerts $ADMIN_MSP_DIR/tlscacerts
  cp $CA_CERT_PATH $ADMIN_MSP_DIR/cacerts/ca-cert.pem
done


###############################################################
# enroll orderers
###############################################################
echo "ScriptInfo: enroll orderer"
for index in $(seq 0 $(($(echo "$ORDERERS_NAME" | wc -l) - 1))); do
  ORDERER_NAME=$(echo "$ORDERERS_NAME" | sed -n "$((index+1))p")
  ORDERER_PASS=$(echo "$ORDERERS_PASS" | sed -n "$((index+1))p")
  ORDERER_ORG=$(echo "$ORDERERS_ORG" | sed -n "$((index+1))p")
  fabric-ca-client register -u http://$NETWORK_CA_NAME:$NETWORK_CA_PORT --id.name $ORDERER_NAME --id.secret $ORDERER_PASS --id.type orderer --id.affiliation $ORDERER_ORG
  fabric-ca-client enroll -u http://$ORDERER_NAME:$ORDERER_PASS@$NETWORK_CA_NAME:$NETWORK_CA_PORT -M $FABRIC_CA_CLIENT_HOME/$ORDERER_ORG/$ORDERER_NAME/msp
  fabric-ca-client enroll -u http://$ORDERER_NAME:$ORDERER_PASS@$NETWORK_CA_NAME:$NETWORK_CA_PORT --enrollment.profile tls -M $FABRIC_CA_CLIENT_HOME/$ORDERER_ORG/$ORDERER_NAME/tls
done


###############################################################
# enroll peers
###############################################################
echo "ScriptInfo: enroll peers"
for index in $(seq 0 $(($(echo "$PEERS_NAME" | wc -l) - 1))); do
  PEER_NAME=$(echo "$PEERS_NAME" | sed -n "$((index+1))p")
  PEER_PASS=$(echo "$PEERS_PASS" | sed -n "$((index+1))p")
  PEER_ORG=$(echo "$PEERS_ORG" | sed -n "$((index+1))p")

  PEER_MSP_DIR=$FABRIC_CA_CLIENT_HOME/$PEER_ORG/$PEER_NAME/msp
  PEER_TLS_DIR=$FABRIC_CA_CLIENT_HOME/$PEER_ORG/$PEER_NAME/tls

  fabric-ca-client register -u http://$NETWORK_CA_NAME:$NETWORK_CA_PORT --id.name $PEER_NAME --id.secret $PEER_PASS --id.type peer --id.affiliation $PEER_ORG
  fabric-ca-client enroll -u http://$PEER_NAME:$PEER_PASS@$NETWORK_CA_NAME:$NETWORK_CA_PORT -M $PEER_MSP_DIR
  fabric-ca-client enroll -u http://$PEER_NAME:$PEER_PASS@$NETWORK_CA_NAME:$NETWORK_CA_PORT --enrollment.profile tls -M $PEER_TLS_DIR

  mkdir -p $PEER_MSP_DIR/admincerts $PEER_MSP_DIR/tlscacerts
  cp $CA_CERT_PATH $PEER_MSP_DIR/cacerts/ca-cert.pem
  # TODO: read "admin.jenziner.jedo.test" from network-config.yaml
  cp $FABRIC_CA_CLIENT_HOME/$PEER_ORG/admin.jenziner.jedo.test/msp/signcerts/cert.pem $PEER_MSP_DIR/admincerts/admin-cert.pem

    cat <<EOF > $PEER_MSP_DIR/config.yaml
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/ca-cert.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/ca-cert.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/ca-cert.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/ca-cert.pem
    OrganizationalUnitIdentifier: orderer
EOF

  cp $PEER_TLS_DIR/keystore/* $PEER_TLS_DIR/server.key
  cp $PEER_TLS_DIR/signcerts/cert.pem $PEER_TLS_DIR/server.crt
  cp $PEER_TLS_DIR/tlscacerts/* $PEER_TLS_DIR/ca.crt
done


###############################################################
# Fabric Smart Client node identities (identity of the node, used when talking to other nodes)
###############################################################
echo "ScriptInfo: register fsc"
for index in $(seq 0 $(($(echo "$FSCS_NAME" | wc -l) - 1))); do
  FSC_NAME=$(echo "$FSCS_NAME" | sed -n "$((index+1))p")
  FSC_PASS=$(echo "$FSCS_PASS" | sed -n "$((index+1))p")
  FSC_OWNER=$(echo "$FSCS_OWNER" | sed -n "$((index+1))p")
  fabric-ca-client register -u http://$NETWORK_CA_NAME:$NETWORK_CA_PORT --id.name fsc$FSC_NAME --id.secret $FSC_PASS --id.type client
  fabric-ca-client enroll -u http://fsc$FSC_NAME:$FSC_PASS@$NETWORK_CA_NAME:$NETWORK_CA_PORT -M $FABRIC_CA_CLIENT_HOME/$ECOSYSTEM_NAME/$FSC_OWNER/fsc/msp
  # make private key name predictable
  mv "$FABRIC_CA_CLIENT_HOME/$ECOSYSTEM_NAME/$FSC_OWNER/fsc/msp/keystore/"* "$FABRIC_CA_CLIENT_HOME/$ECOSYSTEM_NAME/$FSC_OWNER/fsc/msp/keystore/priv_sk"
done


###############################################################
# Issuer and Auditor wallet users (non-anonymous)
###############################################################
echo "ScriptInfo: register auditors"
for index in $(seq 0 $(($(echo "$AUDITORS_NAME" | wc -l) - 1))); do
  AUDITOR_NAME=$(echo "$AUDITORS_NAME" | sed -n "$((index+1))p")
  AUDITOR_PASS=$(echo "$AUDITORS_PASS" | sed -n "$((index+1))p")
  AUDITOR_OWNER=$(echo "$AUDITORS_OWNER" | sed -n "$((index+1))p")
  fabric-ca-client register -u http://$NETWORK_CA_NAME:$NETWORK_CA_PORT --id.name $AUDITOR_NAME --id.secret $AUDITOR_PASS --id.type client
  fabric-ca-client enroll -u http://$AUDITOR_NAME:$AUDITOR_PASS@$NETWORK_CA_NAME:$NETWORK_CA_PORT -M $FABRIC_CA_CLIENT_HOME/$ECOSYSTEM_NAME/$AUDITOR_OWNER/$AUDITOR_NAME/msp
done
echo "ScriptInfo: register issuers"
for index in $(seq 0 $(($(echo "$ISSUERS_NAME" | wc -l) - 1))); do
  ISSUER_NAME=$(echo "$ISSUERS_NAME" | sed -n "$((index+1))p")
  ISSUER_PASS=$(echo "$ISSUERS_PASS" | sed -n "$((index+1))p")
  ISSUER_OWNER=$(echo "$ISSUERS_OWNER" | sed -n "$((index+1))p")
  fabric-ca-client register -u http://$NETWORK_CA_NAME:$NETWORK_CA_PORT --id.name $ISSUER_NAME --id.secret $ISSUER_PASS --id.type client
  fabric-ca-client enroll -u http://$ISSUER_NAME:$ISSUER_PASS@$NETWORK_CA_NAME:$NETWORK_CA_PORT -M $FABRIC_CA_CLIENT_HOME/$ECOSYSTEM_NAME/$ISSUER_OWNER/$ISSUER_NAME/msp
done


###############################################################
# Owner wallet users (pseudonymous) on all owner nodes
###############################################################
echo "ScriptInfo: register users"
for index in $(seq 0 $(($(echo "$USERS_NAME" | wc -l) - 1))); do
  USER_NAME=$(echo "$USERS_NAME" | sed -n "$((index+1))p")
  USER_PASS=$(echo "$USERS_PASS" | sed -n "$((index+1))p")
  USER_OWNER=$(echo "$USERS_OWNER" | sed -n "$((index+1))p")
  fabric-ca-client register -u http://$NETWORK_CA_NAME:$NETWORK_CA_PORT --id.name $USER_NAME --id.secret $USER_PASS --id.type client --enrollment.type idemix --idemix.curve gurvy.Bn254
  fabric-ca-client enroll -u http://$USER_NAME:$USER_PASS@$NETWORK_CA_NAME:$NETWORK_CA_PORT -M $FABRIC_CA_CLIENT_HOME/$ECOSYSTEM_NAME/$USER_OWNER/wallet/$USER_NAME/msp --enrollment.type idemix --idemix.curve gurvy.Bn254
done


###############################################################
# set permissions
###############################################################
chmod -R 777 ./keys
