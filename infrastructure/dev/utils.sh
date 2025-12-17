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
        echo_error "Script does not run independently, use ./jedo.sh"
        exit 1
    fi
}


###############################################################
# Functions to echo in colors
###############################################################
# Text Color
WHITEB='\033[1;29m'
WHITE='\033[0;29m'
BLACKB='\033[1;30m'
BLACK='\033[0;30m'
REDB='\033[1;31m'
RED='\033[0;31m'
GREENB='\033[1;32m'
GREEN='\033[0;32m'
YELLOWB='\033[1;33m'
YELLOW='\033[0;33m'
BLUEB='\033[1;34m'
BLUE='\033[0;34m'
PURPLEB='\033[1;35m'
PURPLE='\033[0;35m'
TURQUOISEB='\033[1;36m'
TURQUOISE='\033[0;36m'
NC='\033[0m' # No Color

# Background Color (40-47)
BG_BLACK='\033[40m'
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_YELLOW='\033[43m'
BG_BLUE='\033[44m'
BG_PURPLE='\033[45m'
BG_TURQUOISE='\033[46m'
BG_WHITE='\033[47m'

SECTION_TITLE='\033[1;37;44m'  # Bold, White Text, Blue Background
function echo_section() {
    echo -e "${SECTION_TITLE}>>> SECTION: $1 <<<${NC}"
}

function echo_error() {
    echo -e "${REDB}ScriptError: ${RED}$1${NC}"
}
function echo_warn() {
    echo -e "${YELLOWB}ScriptWarn: ${YELLOW}$1${NC}"
}
function echo_ok() {
    echo -e "${GREENB}ScriptOk: ${GREEN}$1${NC}"
}
function echo_info() {
    echo -e "${BLUEB}ScriptInfo: ${BLUE}$1${NC}"
}
function echo_debug() {
    echo -e "${PURPLEB}ScriptDebug: ${PURPLE}$1${NC}"
}
function echo_test() {
    echo -e "${TURQUOISEB}ScripTest: ${TURQUOISE}$1${NC}"
}

function echo_value_error() {
    echo -e "${REDB}$1 ${RED}$2${NC}"
}
function echo_value_warn() {
    echo -e "${YELLOWB}$1 ${YELLOW}$2${NC}"
}
function echo_value_ok() {
    echo -e "${GREENB}$1 ${GREEN}$2${NC}"
}
function echo_value_info() {
    echo -e "${BLUEB}$1 ${BLUE}$2${NC}"
}
function echo_value_debug() {
    echo -e "${PURPLEB}$1 ${PURPLE}$2${NC}"
}
function echo_value_test() {
    echo -e "${TURQUOISEB}$1 ${TURQUOISE}$2${NC}"
}
function log_debug() {
    if [[ $LOGLEVEL == "DEBUG" ]]; then
        echo -e "${PURPLEB}[DEBUG] $1 ${PURPLE}$2${NC}"
    fi
}


###############################################################
# Function to pause
###############################################################
cool_down() {
    local kind="$1"
    local message="$2"
    if [[ "$kind" == "pause" ]]; then
        while true; do
            echo_warn "${message}  Check console."
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
    hosts_args=""

    local ip_paths
    ip_paths=$(yq eval '.. | select(tag == "!!map" and has("IP")).IP | path | join(".")' "$CONFIG_FILE")

    for ip_path in $ip_paths; do
        local name_path="${ip_path%.IP}.Name"
        local name=$(yq eval ".$name_path" "$CONFIG_FILE")
        local ip=$(yq eval ".$ip_path" "$CONFIG_FILE")

        if [[ -n "$name" && -n "$ip" ]]; then
            hosts_args+="--add-host=$name:$ip "
        fi
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
            echo_ok "Expected log entry found for Docker Container $container_name."
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