###############################################################
#!/bin/bash
#
# Temporary script.
#
# Prerequisits:
#   - yq: 
#       - installation: sudo wget https://github.com/mikefarah/yq/releases/download/v4.6.3/yq_linux_amd64 -O /usr/local/bin/yq
#       - make it executable: chmod +x /usr/local/bin/yq
#
###############################################################
set -Eeuo pipefail


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
# Set variables
###############################################################
NETWORK_CONFIG_FILE="./config/network-config.yaml"
ORGANIZATIONS=$(yq e '.FabricNetwork.Organizations[].Name' $NETWORK_CONFIG_FILE)

###############################################################
# collect and distribute tls-ca certificates
###############################################################


hosts_args=""
for ORGANIZATION in $ORGANIZATIONS; do
  CA=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Name" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
  CA_IP=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.IP" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
  PEERS=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[].Name" $NETWORK_CONFIG_FILE)
  ORDERERS=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Name" $NETWORK_CONFIG_FILE)

  hosts_args+="--add-host=$CA:$CA_IP "

    for index in $(seq 0 $(($(echo "$PEERS" | wc -l) - 1))); do
        PEER=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].Name" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
        PEER_IP=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].IP" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
        hosts_args+="--add-host=$PEER:$PEER_IP "
    done

    for index in $(seq 0 $(($(echo "$ORDERERS" | wc -l) - 1))); do
        ORDERER=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[$index].Name" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
        ORDERER_IP=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[$index].IP" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
        hosts_args+="--add-host=$ORDERER:$ORDERER_IP "
    done
done
echo_info "$hosts_args" 