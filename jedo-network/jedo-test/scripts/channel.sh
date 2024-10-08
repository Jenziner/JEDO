###############################################################
#!/bin/bash
#
# This script creates Channel
#
# Prerequisits:
#   - yq: 
#       - installation: sudo wget https://github.com/mikefarah/yq/releases/download/v4.6.3/yq_linux_amd64 -O /usr/local/bin/yq
#       - make it executable: chmod +x /usr/local/bin/yq
#
###############################################################
source ./scripts/settings.sh
source ./scripts/help.sh
check_script


###############################################################
# Function to echo in colors
###############################################################
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
function echo_info() {
    echo -e "${YELLOW}$1${NC}"
}
function echo_error() {
    echo -e "${RED}$1${NC}"
}


###############################################################
# Params - from ./config/network-config.yaml
###############################################################
export FABRIC_CFG_PATH=./config
NETWORK_CONFIG_FILE="./config/network-config.yaml"
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' "$NETWORK_CONFIG_FILE")
CHANNEL=$(yq e '.FabricNetwork.Channel' $NETWORK_CONFIG_FILE)
ORGANIZATIONS=$(yq e '.FabricNetwork.Organizations[].Name' $NETWORK_CONFIG_FILE)


###############################################################
# Channel
###############################################################
FIRST_ORGANIZATION=$(yq e ".FabricNetwork.Organizations[0] | .Name" $NETWORK_CONFIG_FILE)
FIRST_CA=$(yq e ".FabricNetwork.Organizations[0] | .CA.Name" $NETWORK_CONFIG_FILE)
FIRST_ORDERER=$(yq e ".FabricNetwork.Organizations[0] | .Orderers[0].Name" $NETWORK_CONFIG_FILE)
FIRST_ORDERER_PORT=$(yq e ".FabricNetwork.Organizations[0] | .Orderers[0].Port" $NETWORK_CONFIG_FILE)
FIRST_PEER=$(yq e ".FabricNetwork.Organizations[0] | .Peers[0].Name" $NETWORK_CONFIG_FILE)

#        TLS_ROOTCERTS=$(ls $PWD/keys/$FIRST_ORGANIZATION/$FIRST_ORDERER/tls/tlscacerts/*.pem | xargs -n 1 basename | sed 's|^|/etc/hyperledger/orderer/tls/tlscacerts/|' | tr '\n' ',' | sed 's/,$//')



CANAME=${FIRST_CA//./-}
TLS_CA_PATH="$PWD/keys/$FIRST_ORGANIZATION/$FIRST_ORDERER/tls/tlscacerts"
FIRST_ORDERER_CACERT=$(find "$TLS_CA_PATH" -type f -name "*.pem" -exec basename {} \; | grep "$CANAME")
TLS_PRIVATE_KEY=$(basename $(ls $PWD/keys/$FIRST_ORGANIZATION/$FIRST_PEER/tls/keystore/*_sk))

docker exec -it cli.$FIRST_PEER peer channel create \
-c $CHANNEL \
-f /tmp/$DOCKER_NETWORK_NAME/config/$CHANNEL.tx \
-o $FIRST_ORDERER:$FIRST_ORDERER_PORT \
--outputBlock /tmp/$DOCKER_NETWORK_NAME/config/$CHANNEL.block \
--tls \
--cafile /etc/hyperledger/fabric/tls/tlscacerts/tls_ca_combined.pem \
--certfile /etc/hyperledger/fabric/tls/signcerts/cert.pem \
--keyfile /etc/hyperledger/fabric/tls/keystore/$TLS_PRIVATE_KEY \
--ordererTLSHostnameOverride $FIRST_ORDERER


for ORGANIZATION in $ORGANIZATIONS; do
    PEERS_NAME=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[].Name" $NETWORK_CONFIG_FILE)

    for index in $(seq 0 $(($(echo "$PEERS_NAME" | wc -l) - 1))); do
        PEER_NAME=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].Name" $NETWORK_CONFIG_FILE)

        # join channel
        echo_info "ScriptInfo: join channel $CHANNEL with $PEER_NAME"
    done
done




