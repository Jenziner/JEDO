###############################################################
#!/bin/bash
#
# This script checks prerequisites
# Documentation: https://hyperledger-fabric.readthedocs.io
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

log_section "Prerequisites checking..."


###############################################################
# Function to help with prerequisits
###############################################################
inst_help_yq() {
    echo "installation: sudo wget https://github.com/mikefarah/yq/releases/download/v4.6.3/yq_linux_amd64 -O /usr/local/bin/yq"
    echo "make it executable: chmod +x /usr/local/bin/yq"
}
inst_help_docker() {
    echo "installation: sudo apt sudo apt install docker.io"
}
inst_help_openssl() {
    echo "installation: sudo apt sudo apt install openssl"
}


###############################################################
# Function check prerequisits
###############################################################
check_command() {
    local command="$1"
    if ! command -v "$command" &> /dev/null; then
        log_error "$command is not installed"
        inst_help_${command//-/_}
        exit 1
    else
        log_info "$command is installed:"
        # try to print version
        if "$command" --version &> /dev/null; then
            "$command" --version
        elif "$command" version &> /dev/null; then
            "$command" version
        elif "$command" -v &> /dev/null; then
            "$command" -v
        else
            echo_warn "Version information is not available."
        fi
    fi
}

###############################################################
# RUN
###############################################################
check_command yq
check_command docker
check_command openssl

log_info "Prerequisites checked."