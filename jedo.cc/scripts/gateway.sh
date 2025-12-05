###############################################################
#!/bin/bash
#
# This script starts Wallet API Gateway
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
FABRIC_BIN_PATH=$(yq eval '.Fabric.Path' "$CONFIG_FILE")
DOCKER_UNRAID=$(yq eval '.Docker.Unraid' $CONFIG_FILE)
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $CONFIG_FILE)

get_hosts


###############################################################
# Params for gateway
###############################################################
ORBIS_GATEWAY_NAME=$(yq eval ".Orbis.Gateway.Name" "$CONFIG_FILE")
ORBIS_GATEWAY_IP=$(yq eval ".Orbis.Gateway.IP" "$CONFIG_FILE")
ORBIS_GATEWAY_PORT=$(yq eval ".Orbis.Gateway.Port" "$CONFIG_FILE")

HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server


###############################################################
# ORDERER
###############################################################
echo ""
echo_info "Docker $ORBIS_GATEWAY_NAME starting..."
docker run -d \
    --name $ORBIS_GATEWAY_NAME \
    --network $DOCKER_NETWORK_NAME \
    --ip $ORBIS_GATEWAY_IP \
    $hosts_args \
    --restart=on-failure:1 \
    -p $ORBIS_GATEWAY_PORT:$ORBIS_GATEWAY_PORT \
    -v ${PWD}/gateway:/app \
    -v ${PWD}/gateway/.env:/app/.env \
    -v ${PWD}/infrastructure:/app/infrastructure:ro \
    -v /app/node_modules \
    node:20-alpine \
    sh -c "cd /app && npm install && npm run build && npm start"

CheckContainer "$ORBIS_GATEWAY_NAME" "$DOCKER_CONTAINER_WAIT"
CheckContainerLog "$ORBIS_GATEWAY_NAME" "Health check available at" "$DOCKER_CONTAINER_WAIT"

echo ""
echo_ok "Gateway $ORBIS_GATEWAY_NAME started."
###############################################################
# Last Tasks
###############################################################


