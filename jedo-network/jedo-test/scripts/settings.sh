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
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
function echo_error() {
    echo -e "${RED}ScriptInfo: $1${NC}"
}
function echo_warn() {
    echo -e "${YELLOW}ScriptInfo: $1${NC}"
}
function echo_ok() {
    echo -e "${GREEN}ScriptInfo: $1${NC}"
}
function echo_info() {
    echo -e "ScriptInfo: $1"
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

    ROOTCA=$(yq eval '.FabricNetwork.RootCA.Name' $NETWORK_CONFIG_FILE)
    ROOTCA_IP=$(yq eval '.FabricNetwork.RootCA.IP' $NETWORK_CONFIG_FILE)
    hosts_args+="--add-host=$ROOTCA:$ROOTCA_IP --add-host=tls.$ROOTCA:$ROOTCA_IP "

    for ORGANIZATION in $ORGANIZATIONS; do
        CA=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Name" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
        CA_IP=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.IP" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
        CA_API=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CAAPI.Name" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
        CA_API_IP=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CAAPI.IP" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
        PEERS=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[].Name" $NETWORK_CONFIG_FILE)
        ORDERERS=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Name" $NETWORK_CONFIG_FILE)

        if [[ -n "$CA" ]]; then
            hosts_args+="--add-host=$CA:$CA_IP --add-host=tls.$CA:$CA_IP "
        fi

        if [[ -n "$CA_API" ]]; then
            hosts_args+="--add-host=$CA_API:$CA_API_IP "
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

###############################################################
# Function to check Docker Container
###############################################################
CheckContainer() {
    local container_name=$1
    local wait_time_limit=$2
    local wait_time=0
    local success=false

    while [ $wait_time -lt $wait_time_limit ]; do
        if docker inspect -f '{{.State.Running}}' "$container_name" | grep true > /dev/null; then
            success=true
            echo_ok "ScriptInfo: Docker Container $container_name started."
            break
        fi
        echo "Waiting for $container_name... ($wait_time seconds)"
        sleep 2
        wait_time=$((wait_time + 2))
    done

    if [ "$success" = false ]; then
        echo_error "ScriptError: $container_name did not start."
        docker logs "$container_name"
        exit 1
    fi
}


###############################################################
# Function to check Health of a fabric Server
###############################################################
CheckHealth() {
    local service_name=$1
    local ip_address=$2
    local port=$3
    local wait_time_limit=$4
    local wait_time=0
    local success=false

    while [ $wait_time -lt $wait_time_limit ]; do
        response=$(curl -vk https://"$ip_address":"$port"/healthz 2>&1 | grep "OK")
        if [[ $response == *"OK"* ]]; then
            success=true
            echo_ok "ScriptInfo: Fabric-CA $service_name health-check passed."
            break
        fi
        echo "Waiting for $service_name... ($wait_time seconds)"
        sleep 2
        wait_time=$((wait_time + 2))
    done

    if [ "$success" = false ]; then
        echo_error "ScriptError: $service_name health-check failed."
        exit 1
    fi
}


###############################################################
# Function to check OpenSSL
###############################################################
CheckOpenSSL() {
    local service_name=$1
    local wait_time_limit=$2
    local wait_time=0
    local success=false

    # waiting OpenSSL installation
    while [ $wait_time -lt $wait_time_limit ]; do
        if docker exec $service_name sh -c 'command -v openssl' > /dev/null; then
            SUCCESS=true
            docker exec -it $service_name sh -c 'openssl version'
            echo_ok "ScriptInfo: OpenSSL Docker Container $service_name started."
            break
        fi
        echo "Waiting for OpenSSL installation... ($wait_time seconds)"
        sleep 2
        wait_time=$((wait_time + 2))
    done

    if [ "$SUCCESS" = false ]; then
        echo_error "ScriptError: OpenSSL installation failed."
        docker logs $service_name
        exit 1
    fi
}


###############################################################
# Function to check Log
###############################################################
CheckContainerLog() {
    local container_name=$1
    local log_entry=$2
    local wait_time_limit=$3
    local wait_time=0
    local success=false

    while [ $wait_time -lt $wait_time_limit ]; do
        if docker logs "$container_name" 2>&1 | grep -q "$log_entry"; then
            success=true
            echo_ok "ScriptInfo: Expected log entry '$log_entry' found for Docker Container $container_name."
            break
        fi
        echo "Waiting for expected log entry '$log_entry' in $container_name... ($wait_time seconds)"
        sleep 2
        wait_time=$((wait_time + 2))
    done

    if [ "$success" = false ]; then
        echo_error "ScriptError: Expected log entry '$log_entry' not found for $container_name within the time limit."
        docker logs "$container_name"
        exit 1
    fi
}
