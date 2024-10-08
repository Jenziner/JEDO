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