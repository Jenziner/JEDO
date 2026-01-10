###############################################################
#!/bin/bash
#
# This file provides general settings and general functions.
#
#
###############################################################
set -Eeuo pipefail


###############################################################
# Color setup
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


###############################################################
# Functions for terminal colors
###############################################################
function log_section() {
    echo -e "${SECTION_TITLE}>>> SECTION: $1 <<<${NC}"
}

function log_ok() {
    if [[ $LOGLEVEL == "ERROR" || $LOGLEVEL == "WARN" || $LOGLEVEL == "INFO" || $LOGLEVEL == "DEBUG" ]]; then
        local msg1=$1
        local msg2=${2:-}   # leer, falls nicht gesetzt
        if [[ -n "$msg2" ]]; then
            echo -e "${GREENB}[INFO] $msg1 ${GREEN}$msg2${NC}"
        else
            echo -e "${GREENB}[INFO] $msg1${NC}"
        fi
    fi
}

function log_test() {
    if [[ $LOGLEVEL == "ERROR" || $LOGLEVEL == "WARN" || $LOGLEVEL == "INFO" || $LOGLEVEL == "DEBUG" ]]; then
        local msg1=$1
        local msg2=${2:-}   # leer, falls nicht gesetzt
        if [[ -n "$msg2" ]]; then
            echo -e "${TURQUOISEB}[INFO] $msg1 ${TURQUOISE}$msg2${NC}"
        else
            echo -e "${TURQUOISEB}[INFO] $msg1${NC}"
        fi
    fi
}

function log_error() {
    if [[ $LOGLEVEL == "ERROR" || $LOGLEVEL == "WARN" || $LOGLEVEL == "INFO" || $LOGLEVEL == "DEBUG" ]]; then
        local msg1=$1
        local msg2=${2:-}   # leer, falls nicht gesetzt
        if [[ -n "$msg2" ]]; then
            echo -e "${REDB}[INFO] $msg1 ${RED}$msg2${NC}"
        else
            echo -e "${REDB}[INFO] $msg1${NC}"
        fi
    fi
}

function log_warn() {
    if [[ $LOGLEVEL == "WARN" || $LOGLEVEL == "INFO" || $LOGLEVEL == "DEBUG" ]]; then
        local msg1=$1
        local msg2=${2:-}   # leer, falls nicht gesetzt
        if [[ -n "$msg2" ]]; then
            echo -e "${YELLOWB}[INFO] $msg1 ${YELLOW}$msg2${NC}"
        else
            echo -e "${YELLOWB}[INFO] $msg1${NC}"
        fi
    fi
}

function log_info() {
    if [[ $LOGLEVEL == "INFO" || $LOGLEVEL == "DEBUG" ]]; then
        local msg1=$1
        local msg2=${2:-}   # leer, falls nicht gesetzt
        if [[ -n "$msg2" ]]; then
            echo -e "${BLUEB}[INFO] $msg1 ${BLUE}$msg2${NC}"
        else
            echo -e "${BLUEB}[INFO] $msg1${NC}"
        fi
    fi
}

function log_debug() {
    if [[ $LOGLEVEL == "DEBUG" ]]; then
        local msg1=$1
        local msg2=${2:-}   # leer, falls nicht gesetzt
        if [[ -n "$msg2" ]]; then
            echo -e "${PURPLEB}[DEBUG] $msg1 ${PURPLE}$msg2${NC}"
        else
            echo -e "${PURPLEB}[DEBUG] $msg1${NC}"
        fi
    fi
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
            log_ok "Docker Container $container_name started."
            break
        fi
        echo "Waiting for $container_name... ($wait_time seconds)"
        sleep 2
        wait_time=$((wait_time + 2))
    done

    if [ "$success" = false ]; then
        log_error "$container_name did not start."
        docker logs "$container_name"
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
            log_ok "Expected log entry found for Docker Container $container_name."
            break
        fi
        echo "Waiting for expected log entry '$log_entry' in $container_name... ($wait_time seconds)"
        sleep 2
        wait_time=$((wait_time + 2))
    done

    if [ "$success" = false ]; then
        log_error "Expected log entry '$log_entry' not found for $container_name within the time limit."
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
            log_ok "CouchDB $container_name port test passed."
            break
        fi
        echo "Waiting for CouchDB $container_name... ($wait_time seconds)"
        sleep 2
        wait_time=$((wait_time + 2))
    done

    if [ "$success" = false ]; then
        log_error "CouchDB $container_name port test failed."
        docker logs $container_name
        exit 1
    fi
}