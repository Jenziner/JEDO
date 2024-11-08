###############################################################
#!/bin/bash
#
# This file provides general settings and general functions.
#
#
###############################################################
set -Eeuo pipefail

###############################################################
# Function to check script call
###############################################################
function check_script() {
    if [[ "$JEDO_INITIATED" != "yes" ]]; then
        echo_error "Script does not run independently, use ./dev/jedo.sh"
        exit 1
    fi
}


###############################################################
# Function to echo in colors
###############################################################
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[1;34m'
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
    echo -e "${BLUE}ScriptInfo: $1${NC}"
}


###############################################################
# Function to pause
###############################################################
cool_down() {
    local kind="$1"
    local message="$2"
    if [[ "$kind" == "pause" ]]; then
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
    fi
}


###############################################################
# Function for temporary end
###############################################################
temp_end() {
    echo_error "TEMP END"
    exit 1
}


###############################################################
# Define args for hosts-file
###############################################################
get_hosts() {
    CONFIG_FILE="$SCRIPT_DIR/infrastructure-dev.yaml"

    hosts_args=""

    UTIL_CA_NAME=$(yq eval ".Root.Name" $CONFIG_FILE)
    UTIL_CA_IP=$(yq eval ".Root.IP" $CONFIG_FILE)
    [[ -n "$UTIL_CA_NAME" && -n "$UTIL_CA_IP" ]] && hosts_args+="--add-host=$UTIL_CA_NAME:$UTIL_CA_IP "
    UTIL_CA_NAME=$(yq eval ".Root.TLS-CA.Name" $CONFIG_FILE)
    [[ -n "$UTIL_CA_NAME" && -n "$UTIL_CA_IP" ]] && hosts_args+="--add-host=$UTIL_CA_NAME:$UTIL_CA_IP "
    UTIL_CA_NAME=$(yq eval ".Root.ORG-CA.Name" $CONFIG_FILE)
    [[ -n "$UTIL_CA_NAME" && -n "$UTIL_CA_IP" ]] && hosts_args+="--add-host=$UTIL_CA_NAME:$UTIL_CA_IP "

    UTIL_INTERMEDIATES=$(yq eval ".Intermediates[].Name" $CONFIG_FILE)
    for UTIL_INTERMEDIATE in $UTIL_INTERMEDIATES; do
        UTIL_INT_CA_NAME=$(yq eval ".Intermediates[] | select(.Name == \"$UTIL_INTERMEDIATE\") | .Name" $CONFIG_FILE)
        UTIL_INT_CA_IP=$(yq eval ".Intermediates[] | select(.Name == \"$UTIL_INTERMEDIATE\") | .IP" $CONFIG_FILE)
        [[ -n "$UTIL_INT_CA_NAME" && -n "$UTIL_INT_CA_IP" ]] && hosts_args+="--add-host=$UTIL_INT_CA_NAME:$UTIL_INT_CA_IP "
        UTIL_INT_TLSCA_NAME=$(yq eval ".Intermediates[] | select(.Name == \"$UTIL_INTERMEDIATE\") | .TLS-CA.Name" "$CONFIG_FILE")
        [[ -n "$UTIL_INT_TLSCA_NAME" && -n "$UTIL_INT_CA_IP" ]] && hosts_args+="--add-host=$UTIL_INT_TLSCA_NAME:$UTIL_INT_CA_IP "
        UTIL_INT_ORGCA_NAME=$(yq eval ".Intermediates[] | select(.Name == \"$UTIL_INTERMEDIATE\") | .ORG-CA.Name" "$CONFIG_FILE")
        [[ -n "$UTIL_INT_ORGCA_NAME" && -n "$UTIL_INT_CA_IP" ]] && hosts_args+="--add-host=$UTIL_INT_ORGCA_NAME:$UTIL_INT_CA_IP "
    done

    UTIL_ORGANIZATIONS=$(yq e ".Organizations[].Name" $CONFIG_FILE)
    for UTIL_ORGANIZATION in $UTIL_ORGANIZATIONS; do
        UTIL_TLSCA_NAME=$(yq eval ".Organizations[] | select(.Name == \"$UTIL_ORGANIZATION\") | .TLS-CA.Name" $CONFIG_FILE)
        UTIL_TLSCA_IP=$(yq eval ".Organizations[] | select(.Name == \"$UTIL_ORGANIZATION\") | .TLS-CA.IP" $CONFIG_FILE)
        UTIL_TLSCAAPI_NAME=$(yq eval ".Organizations[] | select(.Name == \"$UTIL_ORGANIZATION\") | .TLS-CA.CAAPI.Name" $CONFIG_FILE)
        UTIL_TLSCAAPI_IP=$(yq eval ".Organizations[] | select(.Name == \"$UTIL_ORGANIZATION\") | .TLS-CA.CAAPI.IP" $CONFIG_FILE)
        UTIL_ORGCA_NAME=$(yq eval ".Organizations[] | select(.Name == \"$UTIL_ORGANIZATION\") | .ORG-CA.Name" $CONFIG_FILE)
        UTIL_ORGCA_IP=$(yq eval ".Organizations[] | select(.Name == \"$UTIL_ORGANIZATION\") | .ORG-CA.IP" $CONFIG_FILE)
        UTIL_ORGCAAPI_NAME=$(yq eval ".Organizations[] | select(.Name == \"$UTIL_ORGANIZATION\") | .ORG-CA.CAAPI.Name" $CONFIG_FILE)
        UTIL_ORGCAAPI_IP=$(yq eval ".Organizations[] | select(.Name == \"$UTIL_ORGANIZATION\") | .ORG-CA.CAAPI.IP" $CONFIG_FILE)
        UTIL_PEERS=$(yq eval ".Organizations[] | select(.Name == \"$UTIL_ORGANIZATION\") | .Peers[].Name" $CONFIG_FILE)
        UTIL_ORDERERS=$(yq eval ".Organizations[] | select(.Name == \"$UTIL_ORGANIZATION\") | .Orderers[].Name" $CONFIG_FILE)

        [[ -n "$UTIL_TLSCA_NAME" && -n "$UTIL_TLSCA_IP" ]] && hosts_args+="--add-host=$UTIL_TLSCA_NAME:$UTIL_TLSCA_IP "
        [[ -n "$UTIL_TLSCAAPI_NAME" && -n "$UTIL_TLSCAAPI_IP" ]] && hosts_args+="--add-host=$UTIL_TLSCAAPI_NAME:$UTIL_TLSCAAPI_IP "
        [[ -n "$UTIL_ORGCA_NAME" && -n "$UTIL_ORGCA_IP" ]] && hosts_args+="--add-host=$UTIL_ORGCA_NAME:$UTIL_ORGCA_IP "
        [[ -n "$UTIL_ORGCAAPI_NAME" && -n "$UTIL_ORGCAAPI_IP" ]] && hosts_args+="--add-host=$UTIL_ORGCAAPI_NAME:$UTIL_ORGCAAPI_IP "

        for UTIL_ORDERER in $UTIL_ORDERERS; do
            UTIL_ORDERER_NAME=$(yq eval ".Organizations[] | select(.Name == \"$UTIL_ORGANIZATION\") | .Orderers[] | select(.Name == \"$UTIL_ORDERER\") | .Name" $CONFIG_FILE)
            UTIL_ORDERER_IP=$(yq eval ".Organizations[] | select(.Name == \"$UTIL_ORGANIZATION\") | .Orderers[] | select(.Name == \"$UTIL_ORDERER\") | .IP" $CONFIG_FILE)
            [[ -n "$UTIL_ORDERER_NAME" && -n "$UTIL_ORDERER_IP" ]] && hosts_args+="--add-host=$UTIL_ORDERER_NAME:$UTIL_ORDERER_IP "
        done


        for UTIL_PEER in $UTIL_PEERS; do
            UTIL_PEER_NAME=$(yq eval ".Organizations[] | select(.Name == \"$UTIL_ORGANIZATION\") | .Peers[] | select(.Name == \"$UTIL_PEER\") | .Name" $CONFIG_FILE)
            UTIL_PEER_IP=$(yq eval ".Organizations[] | select(.Name == \"$UTIL_ORGANIZATION\") | .Peers[] | select(.Name == \"$UTIL_PEER\") | .IP" $CONFIG_FILE)
            UTIL_DB_NAME=$(yq eval ".Organizations[] | select(.Name == \"$UTIL_ORGANIZATION\") | .Peers[] | select(.Name == \"$UTIL_PEER\") | .DB.Name" $CONFIG_FILE)
            UTIL_DB_IP=$(yq eval ".Organizations[] | select(.Name == \"$UTIL_ORGANIZATION\") | .Peers[] | select(.Name == \"$UTIL_PEER\") | .DB.IP" $CONFIG_FILE)
            UTIL_CLI_NAME=$(yq eval ".Organizations[] | select(.Name == \"$UTIL_ORGANIZATION\") | .Peers[] | select(.Name == \"$UTIL_PEER\") | .Name" $CONFIG_FILE)
            UTIL_CLI_IP=$(yq eval ".Organizations[] | select(.Name == \"$UTIL_ORGANIZATION\") | .Peers[] | select(.Name == \"$UTIL_PEER\") | .CLI" $CONFIG_FILE)
            [[ -n "$UTIL_PEER_NAME" && -n "$UTIL_PEER_IP" ]] && hosts_args+="--add-host=$UTIL_PEER_NAME:$UTIL_PEER_IP "
            [[ -n "$UTIL_DB_NAME" && -n "$UTIL_DB_IP" ]] && hosts_args+="--add-host=$UTIL_DB_NAME:$UTIL_DB_IP "
            [[ -n "$UTIL_CLI_NAME" && -n "$UTIL_CLI_IP" ]] && hosts_args+="--add-host=cli.$UTIL_CLI_NAME:$UTIL_CLI_IP "
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
            echo_ok "Docker Container $container_name started."
            break
        fi
        echo "Waiting for $container_name... ($wait_time seconds)"
        sleep 2
        wait_time=$((wait_time + 2))
    done

    if [ "$success" = false ]; then
        echo_error "$container_name did not start."
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
            echo_ok "Fabric-CA $service_name health-check passed."
            break
        fi
        echo "Waiting for $service_name... ($wait_time seconds)"
        sleep 2
        wait_time=$((wait_time + 2))
    done

    if [ "$success" = false ]; then
        echo_error "$service_name health-check failed."
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
            echo_ok "OpenSSL Docker Container $service_name started."
            break
        fi
        echo "Waiting for OpenSSL installation... ($wait_time seconds)"
        sleep 2
        wait_time=$((wait_time + 2))
    done

    if [ "$SUCCESS" = false ]; then
        echo_error "OpenSSL installation failed."
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
            echo_ok "Expected log entry '$log_entry' found for Docker Container $container_name."
            break
        fi
        echo "Waiting for expected log entry '$log_entry' in $container_name... ($wait_time seconds)"
        sleep 2
        wait_time=$((wait_time + 2))
    done

    if [ "$success" = false ]; then
        echo_error "Expected log entry '$log_entry' not found for $container_name within the time limit."
        docker logs "$container_name"
        exit 1
    fi
}


###############################################################
# Function to check CouchDB
###############################################################
CheckCouchDB() {
    local container_name=$1
    local container_ip=$2
    local wait_time_limit=$3
    local wait_time=0
    local success=false

    while [ $wait_time -lt $wait_time_limit ]; do
        if curl -s http://$container_ip:5984 > /dev/null; then
            success=true
            echo_ok "CouchDB $container_name port test passed."
            break
        fi
        echo "Waiting for CouchDB $container_name... ($wait_time seconds)"
        sleep 2
        wait_time=$((wait_time + 2))
    done

    if [ "$success" = false ]; then
        echo_error "CouchDB $container_name port test failed."
        docker logs $container_name
        exit 1
    fi
}