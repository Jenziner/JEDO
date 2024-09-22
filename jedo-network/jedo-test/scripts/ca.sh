###############################################################
#!/bin/bash
#
# This script starts Hyperledger Fabric CA
#
# Prerequisits:
# - yq (sudo wget https://github.com/mikefarah/yq/releases/download/v4.6.3/yq_linux_amd64 -O /usr/local/bin/yq)
#
###############################################################
set -Eeuo pipefail


###############################################################
# Params - from ./config/network-config.yaml
###############################################################
CONFIG_FILE="./config/network-config.yaml"
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' "$CONFIG_FILE")
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' "$CONFIG_FILE")
NETWORK_CA_NAME=$(yq eval '.Network.CA.Name' "$CONFIG_FILE")
NETWORK_CA_IP=$(yq eval '.Network.CA.IP' "$CONFIG_FILE")
NETWORK_CA_PORT=$(yq eval '.Network.CA.Port' "$CONFIG_FILE")
NETWORK_CA_ADMIN_NAME=$(yq eval '.Network.CA.Admin.Name' "$CONFIG_FILE")
NETWORK_CA_ADMIN_PASS=$(yq eval '.Network.CA.Admin.Pass' "$CONFIG_FILE")


###############################################################
# Starting CA Docker-Container
###############################################################
WAIT_TIME=0
SUCCESS=false
# Stop Docker Container if running
if docker ps -a --filter "name=$NETWORK_CA_NAME" --format "{{.Names}}" | grep -q "$NETWORK_CA_NAME"; then
  echo "ScriptInfo: $NETWORK_CA_NAME exists, will be removed"
  docker rm -f $NETWORK_CA_NAME
fi
# Run Docker Container
echo "ScriptInfo: running $NETWORK_CA_NAME"
docker pull hyperledger/fabric-ca:latest
docker run -d \
    --network $DOCKER_NETWORK_NAME \
    --name $NETWORK_CA_NAME \
    --ip $NETWORK_CA_IP \
    --restart=unless-stopped \
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/jedo-network/src/fabric_logo.png" \
    -e FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server \
    -e FABRIC_CA_SERVER_CA_NAME=$NETWORK_CA_NAME \
    -e FABRIC_CA_SERVER_TLS_ENABLED=false \
    -e FABRIC_CA_SERVER_PORT=$NETWORK_CA_PORT \
    -v ${PWD}/../fabric-ca:/etc/hyperledger/fabric-ca \
    -v ${PWD}/keys/ca:/etc/hyperledger/fabric-ca-server \
    -p $NETWORK_CA_PORT:$NETWORK_CA_PORT \
    hyperledger/fabric-ca:latest \
    sh -c "fabric-ca-server start -b $NETWORK_CA_ADMIN_NAME:$NETWORK_CA_ADMIN_PASS --idemix.curve gurvy.Bn254 -d"

# waiting startup
while [ $WAIT_TIME -lt $DOCKER_CONTAINER_WAIT ]; do
    if curl -s http://$NETWORK_CA_NAME:$NETWORK_CA_PORT/cainfo > /dev/null; then
        SUCCESS=true
        echo "ScriptInfo: $NETWORK_CA_NAME is up and running!"
        break
    fi
    echo "Waiting for $NETWORK_CA_NAME... ($WAIT_TIME seconds)"
    sleep 2
    WAIT_TIME=$((WAIT_TIME + 2))
done

if [ "$SUCCESS" = false ]; then
    echo "ScriptError: $NETWORK_CA_NAME did not start within $MAX_WAIT seconds."
    docker logs $NETWORK_CA_NAME
    exit 1
fi

# run ca-client
#    docker run -it --network fabric-network \
#    --name jedo-ca-client \
#    -v /mnt/user/appdata/fabric-ca/crypto-config:/etc/hyperledger/fabric-ca-server \
#    hyperledger/fabric-ca:latest bash