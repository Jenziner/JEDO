###############################################################
#!/bin/bash
#
# This script removes all according jedo-network
#
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/params.sh"
check_script


###############################################################
# Remove Docker-Stuff
###############################################################
log_info "Old JEDO-Ecosystem $DOCKER_NETWORK_NAME removing..."


# Remove Docker Container
log_warn "Docker Container removing..."
if docker network inspect "$DOCKER_NETWORK_NAME" &>/dev/null; then
    CONTAINERS=$(docker ps -a --filter "network=$DOCKER_NETWORK_NAME" --format "{{.ID}}")
    if [ -n "$CONTAINERS" ]; then
        for CONTAINER in $CONTAINERS; do
            docker rm -f "$CONTAINER"
        done
    fi
fi


# Remove Docker Network
log_warn "Docker Network removing..."
docker network rm  $DOCKER_NETWORK_NAME || true


# Remove Folder
log_warn "Folder removing..."
rm -rf infrastructure
# rm -rf configuration
# rm -rf chaincode
# rm -rf gateway


# Remove Chaincode Packages
log_warn "Chaincode packages removing..."
rm -f *.tar.gz


log_ok "Old JEDO-Ecosystem $DOCKER_NETWORK_NAME removed."