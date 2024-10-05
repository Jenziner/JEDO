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
NETWORK_CONFIG_FILE="./config/network-config.yaml"
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $NETWORK_CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $NETWORK_CONFIG_FILE)
ORGANIZATIONS=$(yq e '.FabricNetwork.Organizations[].Name' $NETWORK_CONFIG_FILE)


###############################################################
# Starting CA Docker-Container
###############################################################
echo "ScriptInfo: pull docker image"
docker pull hyperledger/fabric-ca:latest
for ORGANIZATION in $ORGANIZATIONS; do
    CA_NAME=$(yq eval ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Name" $NETWORK_CONFIG_FILE)
    CA_IP=$(yq eval ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.IP" $NETWORK_CONFIG_FILE)
    CA_PORT=$(yq eval ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Port" $NETWORK_CONFIG_FILE)
    CA_PASS=$(yq eval ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Pass" $NETWORK_CONFIG_FILE)

    WAIT_TIME=0
    SUCCESS=false

    echo "ScriptInfo: running $CA_NAME"
    docker run -d \
        --network $DOCKER_NETWORK_NAME \
        --name $CA_NAME \
        --ip $CA_IP \
        --restart=unless-stopped \
        --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/jedo-network/src/fabric_ca_logo.png" \
        -e FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server \
        -e FABRIC_CA_SERVER_CA_NAME=$CA_NAME \
        -e FABRIC_CA_SERVER_TLS_ENABLED=false \
        -e FABRIC_CA_SERVER_PORT=$CA_PORT \
        -v ${PWD}/keys/$ORGANIZATION:/etc/hyperledger/fabric-ca \
        -v ${PWD}/keys/$ORGANIZATION/$CA_NAME:/etc/hyperledger/fabric-ca-server \
        -p $CA_PORT:$CA_PORT \
        hyperledger/fabric-ca:latest \
        sh -c "fabric-ca-server start -b $CA_NAME:$CA_PASS --idemix.curve gurvy.Bn254 -d"

    # waiting startup
    while [ $WAIT_TIME -lt $DOCKER_CONTAINER_WAIT ]; do
        if curl -s http://$CA_NAME:$CA_PORT/cainfo > /dev/null; then
            SUCCESS=true
            echo "ScriptInfo: $CA_NAME is up and running!"
            break
        fi
        echo "Waiting for $CA_NAME... ($WAIT_TIME seconds)"
        sleep 2
        WAIT_TIME=$((WAIT_TIME + 2))
    done

    if [ "$SUCCESS" = false ]; then
        echo "ScriptError: $CA_NAME did not start."
        docker logs $CA_NAME
        exit 1
    fi
done
# run ca-client
#    docker run -it --network fabric-network \
#    --name jedo-ca-client \
#    -v /mnt/user/appdata/fabric-ca/crypto-config:/etc/hyperledger/fabric-ca-server \
#    hyperledger/fabric-ca:latest bash