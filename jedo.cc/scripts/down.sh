###############################################################
#!/bin/bash
#
# This script removes all according jedo-network
#
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
check_script


###############################################################
# Params
###############################################################
CONFIG_FILE="$SCRIPT_DIR/infrastructure-cc.yaml"
DOCKER_NETWORK_NAME=$(yq eval ".Docker.Network.Name" "$CONFIG_FILE")


###############################################################
# Remove Docker-Stuff
###############################################################
echo ""
echo_warn "$DOCKER_NETWORK_NAME removing..."


# Remove Docker Container
echo ""
echo_info "Docker Container removing..."
if docker network inspect "$DOCKER_NETWORK_NAME" &>/dev/null; then
    CONTAINERS=$(docker ps -a --filter "network=$DOCKER_NETWORK_NAME" --format "{{.ID}}")
    if [ -n "$CONTAINERS" ]; then
        for CONTAINER in $CONTAINERS; do
            docker rm -f "$CONTAINER"
        done
    fi
fi


# Remove Docker Network
echo ""
echo_info "Docker Network removing..."
docker network rm  $DOCKER_NETWORK_NAME || true


# Remove Folder
echo ""
echo_info "Folder removing..."
rm -rf infrastructure
rm -rf configuration
rm -rf chaincode
#rm tokenchaincode/zkatdlog_pp.json


echo_ok "$DOCKER_NETWORK_NAME removed."