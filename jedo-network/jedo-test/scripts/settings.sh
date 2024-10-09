###############################################################
#!/bin/bash
#
# This file provides general settings and general functions.
#
#
###############################################################
set -Eeuo pipefail

###############################################################
# Function to echo in colors
###############################################################
function check_script() {
    if [[ "$JEDO_INITIATED" != "yes" ]]; then
        echo_error "Script does not run independently, use ./scripts/jedo.sh"
        exit 1
    fi
}


###############################################################
# Function to echo in colors
###############################################################
YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
function echo_info() {
    echo -e "${YELLOW}$1${NC}"
}
function echo_ok() {
    echo -e "${GREEN}$1${NC}"
}
function echo_error() {
    echo -e "${RED}$1${NC}"
}


###############################################################
# Function to pause
###############################################################
cool_down() {
    local message="$1"
    while true; do
        echo_info "${message}  Check console."
        read -p "Continue? (Y/n): " response
        response=${response:-Y}  # "Y" if Enter
        case $response in
            [Yy]* ) return 0 ;;   # continue
            [Nn]* ) echo_ok "Work done."; exit 0 ;; # exit
            * ) echo_info "Choose Y or n." ;;
        esac
    done
}


###############################################################
# Define args for hosts-file
###############################################################
get_hosts() {
    hosts_args=""
    for ORGANIZATION in $ORGANIZATIONS; do
        CA=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Name" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
        CA_IP=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.IP" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
        CA_CLI=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.CLI" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
        PEERS=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[].Name" $NETWORK_CONFIG_FILE)
        ORDERERS=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Name" $NETWORK_CONFIG_FILE)

        if [[ -n "$CA" ]]; then
            hosts_args+="--add-host=$CA:$CA_IP --add-host=cli.$CA:$CA_CLI "
        fi

        for index in $(seq 0 $(($(echo "$PEERS" | wc -l) - 1))); do
            PEER=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].Name" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
            PEER_IP=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].IP" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
            DB=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].DB.Name" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
            DB_IP=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].DB.IP" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
            CLI=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].Name" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
            CLI_IP=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].CLI" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
            hosts_args+="--add-host=$PEER:$PEER_IP --add-host=$DB:$DB_IP --add-host=cli.$CLI:$CLI_IP "
        done

        for index in $(seq 0 $(($(echo "$ORDERERS" | wc -l) - 1))); do
            ORDERER=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[$index].Name" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
            ORDERER_IP=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[$index].IP" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
            hosts_args+="--add-host=$ORDERER:$ORDERER_IP "
        done
    done
}

