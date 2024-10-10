###############################################################
#!/bin/bash
#
# Register and enroll all identities needed for the JEDO-Token-Test network.
#
#
# Folder-Structure:
# keys/
# ├── JenzinerOrg/
#     ├── admin/             # Admin-certificates and keys
#     ├── ca/                # CA-certificates and keys
#     ├── orderer/           # Orderer-certificates and keys
#     ├── peer0/             # Peer 0 certificates and keys
#     └── peer1/             # Peer 1 certificates and keys
# ├── LiebewilerOrg/
#     ├── admin/             # Admin-certificates and keys
#     ├── ca/                # CA-certificates and keys
#     ├── orderer/           # Orderer-certificates and keys
#     └── peer0/             # Peer 1 certificates and keys
# └── tlscerts_collections
#     ├── tls_ca_certs       # one certificate file per CA
#     ├── tls_ca_combined    # one certificate with all CA certificates combined (tls_ca_combined.pem)
#     ├── tls_node_certs     # one certificate file per Node (peer and orderer of all organizations)
#     └── tls_node_combined  # one certificate with all Node certificates combined (peer and orderer of all organizations) (tls_node_combined.pem)
# Make sure to mount the right collection folder / file for each Node (e.g. $PWD/keys/tlscerts_collections/tls_ca_combined/combined_tls_ca.pem:/etc/hyperledger/fabric/ca/combined_tls_ca.pem)
#
###############################################################
source ./scripts/settings.sh
source ./scripts/help.sh
check_script

echo_ok "Register and Enroll identities - see Documentation here: https://hyperledger-fabric.readthedocs.io"


###############################################################
# Set variables
###############################################################
NETWORK_CONFIG_FILE="./config/network-config.yaml"
ORGANIZATIONS=$(yq e '.FabricNetwork.Organizations[].Name' $NETWORK_CONFIG_FILE)


for ORGANIZATION in $ORGANIZATIONS; do
###############################################################
# Params for fabric network
###############################################################
  export FABRIC_CA_CLIENT_HOME=$PWD/keys/$ORGANIZATION
  CA_NAME=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Name" $NETWORK_CONFIG_FILE)
  CA_PASS=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Pass" $NETWORK_CONFIG_FILE)
  CA_PORT=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Port" $NETWORK_CONFIG_FILE)
  ADMIN_NAME=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Admin.Name" $NETWORK_CONFIG_FILE)
  ADMIN_PASS=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Admin.Pass" $NETWORK_CONFIG_FILE)
  ORDERERS_NAME=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Name" $NETWORK_CONFIG_FILE)
  ORDERERS_PASS=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Pass" $NETWORK_CONFIG_FILE)
  PEERS_NAME=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[].Name" $NETWORK_CONFIG_FILE)
  PEERS_PASS=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[].Pass" $NETWORK_CONFIG_FILE)


###############################################################
# enroll client
###############################################################
  fabric-ca-client enroll -u http://$CA_NAME:$CA_PASS@$CA_NAME:$CA_PORT -M $FABRIC_CA_CLIENT_HOME/Client
  fabric-ca-client affiliation add $ORGANIZATION


###############################################################
# enroll admin
###############################################################
  echo_info "ScriptInfo: enroll admin for $ORGANIZATION"
  CA_CERT_PATH="$FABRIC_CA_CLIENT_HOME/$CA_NAME/ca-cert.pem" 

  ADMIN_MSP_DIR=$FABRIC_CA_CLIENT_HOME/$ADMIN_NAME/msp
  ADMIN_TLS_DIR=$FABRIC_CA_CLIENT_HOME/$ADMIN_NAME/tls
  
  fabric-ca-client register  -u http://$CA_NAME:$CA_PORT --id.name $ADMIN_NAME --id.secret $ADMIN_PASS --id.type admin --id.affiliation $ORGANIZATION
  fabric-ca-client enroll -u http://$ADMIN_NAME:$ADMIN_PASS@$CA_NAME:$CA_PORT -M $ADMIN_MSP_DIR
  fabric-ca-client enroll -u http://$ADMIN_NAME:$ADMIN_PASS@$CA_NAME:$CA_PORT --enrollment.profile tls -M $ADMIN_TLS_DIR
  
  mkdir -p $ADMIN_MSP_DIR/admincerts $ADMIN_MSP_DIR/tlscacerts
  cp $CA_CERT_PATH $ADMIN_MSP_DIR/cacerts/ca-cert.pem

    CA_CERT_FILE=$(ls $ADMIN_MSP_DIR/cacerts/*.pem)
    cat <<EOF > $ADMIN_MSP_DIR/config.yaml
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: orderer
EOF


###############################################################
# enroll orderers
###############################################################
  echo_info "ScriptInfo: enroll orderers for $ORGANIZATION"
  for index in $(seq 0 $(($(echo "$ORDERERS_NAME" | wc -l) - 1))); do
    ORDERER_NAME=$(echo "$ORDERERS_NAME" | sed -n "$((index+1))p")
    ORDERER_PASS=$(echo "$ORDERERS_PASS" | sed -n "$((index+1))p")

    ORDERER_MSP_DIR=$FABRIC_CA_CLIENT_HOME/$ORDERER_NAME/msp
    ORDERER_TLS_DIR=$FABRIC_CA_CLIENT_HOME/$ORDERER_NAME/tls

    fabric-ca-client register -u http://$CA_NAME:$CA_PORT --id.name $ORDERER_NAME --id.secret $ORDERER_PASS --id.type orderer --id.affiliation $ORGANIZATION
    fabric-ca-client enroll -u http://$ORDERER_NAME:$ORDERER_PASS@$CA_NAME:$CA_PORT -M $ORDERER_MSP_DIR 
    fabric-ca-client enroll -u http://$ORDERER_NAME:$ORDERER_PASS@$CA_NAME:$CA_PORT --enrollment.profile tls -M $ORDERER_TLS_DIR --csr.hosts $ORDERER_NAME --csr.cn $ORDERER_NAME

    CA_CERT_FILE=$(ls $ORDERER_MSP_DIR/cacerts/*.pem)
    cat <<EOF > $ORDERER_MSP_DIR/config.yaml
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: orderer
EOF
  done


###############################################################
# enroll peers
###############################################################
  echo_info "ScriptInfo: enroll peers for $ORGANIZATION"
  for index in $(seq 0 $(($(echo "$PEERS_NAME" | wc -l) - 1))); do
    PEER_NAME=$(echo "$PEERS_NAME" | sed -n "$((index+1))p")
    PEER_PASS=$(echo "$PEERS_PASS" | sed -n "$((index+1))p")

    PEER_MSP_DIR=$FABRIC_CA_CLIENT_HOME/$PEER_NAME/msp
    PEER_TLS_DIR=$FABRIC_CA_CLIENT_HOME/$PEER_NAME/tls

    fabric-ca-client register -u http://$CA_NAME:$CA_PORT --id.name $PEER_NAME --id.secret $PEER_PASS --id.type peer --id.affiliation $ORGANIZATION
    fabric-ca-client enroll -u http://$PEER_NAME:$PEER_PASS@$CA_NAME:$CA_PORT -M $PEER_MSP_DIR
    fabric-ca-client enroll -u http://$PEER_NAME:$PEER_PASS@$CA_NAME:$CA_PORT --enrollment.profile tls -M $PEER_TLS_DIR --csr.hosts $PEER_NAME --csr.cn $PEER_NAME

    CA_CERT_FILE=$(ls $PEER_MSP_DIR/cacerts/*.pem)
    cat <<EOF > $PEER_MSP_DIR/config.yaml
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: orderer
EOF
  done
done


###############################################################
# Params for token network
###############################################################
export FABRIC_CA_CLIENT_HOME=$PWD/keys
TOKEN_NETWORK_NAME=$(yq eval '.TokenNetwork.Name' "$NETWORK_CONFIG_FILE")
FSCS_NAME=$(yq e '.TokenNetwork.FSCs[] | .Name' $NETWORK_CONFIG_FILE)
FSCS_PASS=$(yq e '.TokenNetwork.FSCs[] | .Pass' $NETWORK_CONFIG_FILE)
FSCS_OWNER=$(yq e '.TokenNetwork.FSCs[] | .Owner' $NETWORK_CONFIG_FILE)
AUDITORS_NAME=$(yq e '.TokenNetwork.Auditors[] | .Name' $NETWORK_CONFIG_FILE)
AUDITORS_PASS=$(yq e '.TokenNetwork.Auditors[] | .Pass' $NETWORK_CONFIG_FILE)
AUDITORS_OWNER=$(yq e '.TokenNetwork.Auditors[] | .Owner' $NETWORK_CONFIG_FILE)
ISSUERS_NAME=$(yq e '.TokenNetwork.Issuers[] | .Name' $NETWORK_CONFIG_FILE)
ISSUERS_PASS=$(yq e '.TokenNetwork.Issuers[] | .Pass' $NETWORK_CONFIG_FILE)
ISSUERS_OWNER=$(yq e '.TokenNetwork.Issuers[] | .Owner' $NETWORK_CONFIG_FILE)
USERS_NAME=$(yq e '.TokenNetwork.Users[] | .Name' $NETWORK_CONFIG_FILE)
USERS_PASS=$(yq e '.TokenNetwork.Users[] | .Pass' $NETWORK_CONFIG_FILE)
USERS_OWNER=$(yq e '.TokenNetwork.Users[] | .Owner' $NETWORK_CONFIG_FILE)


###############################################################
# enroll client of first Organization
###############################################################
ORGANIZATION=$(yq e ".FabricNetwork.Organizations[0] | .Name" $NETWORK_CONFIG_FILE)
CA_NAME=$(yq e ".FabricNetwork.Organizations[0] | .CA.Name" $NETWORK_CONFIG_FILE)
CA_PASS=$(yq e ".FabricNetwork.Organizations[0] | .CA.Pass" $NETWORK_CONFIG_FILE)
CA_PORT=$(yq e ".FabricNetwork.Organizations[0] | .CA.Port" $NETWORK_CONFIG_FILE)
fabric-ca-client enroll -u http://$CA_NAME:$CA_PASS@$CA_NAME:$CA_PORT -M $FABRIC_CA_CLIENT_HOME/$ORGANIZATION/Client


###############################################################
# Fabric Smart Client node identities (identity of the node, used when talking to other nodes)
###############################################################
echo_info "ScriptInfo: register fsc"
for index in $(seq 0 $(($(echo "$FSCS_NAME" | wc -l) - 1))); do
  FSC_NAME=$(echo "$FSCS_NAME" | sed -n "$((index+1))p")
  FSC_PASS=$(echo "$FSCS_PASS" | sed -n "$((index+1))p")
  FSC_OWNER=$(echo "$FSCS_OWNER" | sed -n "$((index+1))p")
  fabric-ca-client register -u http://$CA_NAME:$CA_PORT --id.name fsc$FSC_NAME --id.secret $FSC_PASS --id.type client
  fabric-ca-client enroll -u http://fsc$FSC_NAME:$FSC_PASS@$CA_NAME:$CA_PORT -M $FABRIC_CA_CLIENT_HOME/$TOKEN_NETWORK_NAME/$FSC_OWNER/fsc/msp
  # make private key name predictable
  mv "$FABRIC_CA_CLIENT_HOME/$TOKEN_NETWORK_NAME/$FSC_OWNER/fsc/msp/keystore/"* "$FABRIC_CA_CLIENT_HOME/$TOKEN_NETWORK_NAME/$FSC_OWNER/fsc/msp/keystore/priv_sk"
done


###############################################################
# Issuer and Auditor wallet users (non-anonymous)
###############################################################
echo_info "ScriptInfo: register auditors"
for index in $(seq 0 $(($(echo "$AUDITORS_NAME" | wc -l) - 1))); do
  AUDITOR_NAME=$(echo "$AUDITORS_NAME" | sed -n "$((index+1))p")
  AUDITOR_PASS=$(echo "$AUDITORS_PASS" | sed -n "$((index+1))p")
  AUDITOR_OWNER=$(echo "$AUDITORS_OWNER" | sed -n "$((index+1))p")
  fabric-ca-client register -u http://$CA_NAME:$CA_PORT --id.name $AUDITOR_NAME --id.secret $AUDITOR_PASS --id.type client
  fabric-ca-client enroll -u http://$AUDITOR_NAME:$AUDITOR_PASS@$CA_NAME:$CA_PORT -M $FABRIC_CA_CLIENT_HOME/$TOKEN_NETWORK_NAME/$AUDITOR_OWNER/$AUDITOR_NAME/msp
done
echo_info "ScriptInfo: register issuers"
for index in $(seq 0 $(($(echo "$ISSUERS_NAME" | wc -l) - 1))); do
  ISSUER_NAME=$(echo "$ISSUERS_NAME" | sed -n "$((index+1))p")
  ISSUER_PASS=$(echo "$ISSUERS_PASS" | sed -n "$((index+1))p")
  ISSUER_OWNER=$(echo "$ISSUERS_OWNER" | sed -n "$((index+1))p")
  fabric-ca-client register -u http://$CA_NAME:$CA_PORT --id.name $ISSUER_NAME --id.secret $ISSUER_PASS --id.type client
  fabric-ca-client enroll -u http://$ISSUER_NAME:$ISSUER_PASS@$CA_NAME:$CA_PORT -M $FABRIC_CA_CLIENT_HOME/$TOKEN_NETWORK_NAME/$ISSUER_OWNER/$ISSUER_NAME/msp
done


###############################################################
# Owner wallet users (pseudonymous) on all owner nodes
###############################################################
echo_info "ScriptInfo: register users"
for index in $(seq 0 $(($(echo "$USERS_NAME" | wc -l) - 1))); do
  USER_NAME=$(echo "$USERS_NAME" | sed -n "$((index+1))p")
  USER_PASS=$(echo "$USERS_PASS" | sed -n "$((index+1))p")
  USER_OWNER=$(echo "$USERS_OWNER" | sed -n "$((index+1))p")
  fabric-ca-client register -u http://$CA_NAME:$CA_PORT --id.name $USER_NAME --id.secret $USER_PASS --id.type client --enrollment.type idemix --idemix.curve gurvy.Bn254
  fabric-ca-client enroll -u http://$USER_NAME:$USER_PASS@$CA_NAME:$CA_PORT -M $FABRIC_CA_CLIENT_HOME/$TOKEN_NETWORK_NAME/$USER_OWNER/wallet/$USER_NAME/msp --enrollment.type idemix --idemix.curve gurvy.Bn254
done


###############################################################
# collect and combine certificates
###############################################################
echo_info "ScriptInfo: collect and distribute tls-ca certificates"
TLS_DIR="$PWD/keys/tlscerts_collections"
TLS_CA_CERTS_DIR="$TLS_DIR/tls_ca_certs"
TLS_CA_COMBINED_DIR="$TLS_DIR/tls_ca_combined"
TLS_NODE_CERTS_DIR="$TLS_DIR/tls_node_certs"
TLS_NODE_COMBINED_DIR="$TLS_DIR/tls_node_combined"
mkdir -p "$TLS_CA_CERTS_DIR"
mkdir -p "$TLS_CA_COMBINED_DIR"
mkdir -p "$TLS_NODE_CERTS_DIR"
mkdir -p "$TLS_NODE_COMBINED_DIR"

# collect certs from all ca
for ORGANIZATION in $ORGANIZATIONS; do
  CA=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Name" $NETWORK_CONFIG_FILE)
  CA_NAME=$(echo "$CA" | tr '.' '-')
  CA_PORT=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Port" $NETWORK_CONFIG_FILE)
  TLS_CA_CERT_FILE="$PWD/keys/$ORGANIZATION/$CA/ca-cert.pem"

  if [[ -f "$TLS_CA_CERT_FILE" ]]; then
    cp "$TLS_CA_CERT_FILE" "$TLS_CA_CERTS_DIR/tls-$CA_NAME-$CA_PORT.pem"
  fi
done

# make combined ca file
cat "$TLS_CA_CERTS_DIR/"*.pem > "$TLS_CA_COMBINED_DIR/tls_ca_combined.pem"

# collect certs from all nodes
for ORGANIZATION in $ORGANIZATIONS; do
  PEERS_NAME=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[].Name" $NETWORK_CONFIG_FILE)
  ORDERERS_NAME=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Name" $NETWORK_CONFIG_FILE)

  for PEER_NAME in $PEERS_NAME; do
    PEER_CERT_FILE="$PWD/keys/$ORGANIZATION/$PEER_NAME/tls/signcerts/cert.pem"
    if [[ -f "$PEER_CERT_FILE" ]]; then
      PEER_NAME_CLEAN=$(echo "$PEER_NAME" | tr '.' '-')
      cp "$PEER_CERT_FILE" "$TLS_NODE_CERTS_DIR/tls-$PEER_NAME_CLEAN-cert.pem"
    fi
  done

  for ORDERER_NAME in $ORDERERS_NAME; do
    ORDERER_CERT_FILE="$PWD/keys/$ORGANIZATION/$ORDERER_NAME/tls/signcerts/cert.pem"
    if [[ -f "$ORDERER_CERT_FILE" ]]; then
      ORDERER_NAME_CLEAN=$(echo "$ORDERER_NAME" | tr '.' '-')
      cp "$ORDERER_CERT_FILE" "$TLS_NODE_CERTS_DIR/tls-$ORDERER_NAME_CLEAN-cert.pem"
    fi
  done
done

# make combined nodes file
cat "$TLS_NODE_CERTS_DIR/"*.pem > "$TLS_NODE_COMBINED_DIR/tls_node_combined.pem"

# check tls_node_combined.pem:
csplit -z -f "$TLS_NODE_COMBINED_DIR/cert_" "$TLS_NODE_COMBINED_DIR/tls_node_combined.pem" '/-----BEGIN CERTIFICATE-----/' '{*}'
for CERT in "$TLS_NODE_COMBINED_DIR"/cert_*; do
    echo "Certificate: $CERT"
    openssl x509 -in "$CERT" -noout -subject -nameopt multiline
done
rm "$TLS_NODE_COMBINED_DIR"/cert_*


###############################################################
# set permissions
###############################################################
echo_info "ScriptInfo: set permissions for keys-folder"
chmod -R 777 ./keys
