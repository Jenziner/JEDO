###############################################################
#!/bin/bash
#
# This script removes all according jedo-network
#
#
###############################################################
source ./utils/utils.sh
source ./utils/help.sh
check_script


###############################################################
# Params
###############################################################
CONFIG_FILE="./config/infrastructure-dev.yaml"
DOCKER_NETWORK_NAME=$(yq eval ".Docker.Network.Name" "$CONFIG_FILE")
CHANNELS=$(yq e ".FabricNetwork.Channels[].Name" $CONFIG_FILE)


###############################################################
# Remove Docker-Stuff
###############################################################
echo ""
echo_warn "$DOCKER_NETWORK_NAME removing..."

for CHANNEL in $CHANNELS; do
    echo ""
    echo_info "Channel $CHANNEL removing..."
    ORGANIZATIONS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[].Name" $CONFIG_FILE)

    # Remove Root-CA
    echo_info "Root-CA removing..."
    ROOTCA=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .RootCA.Name" "$CONFIG_FILE")
    if [[ -n "$ROOTCA" ]]; then
        docker rm -f $ROOTCA || true
    fi

    for ORGANIZATION in $ORGANIZATIONS; do
        echo ""
        echo_info "Docker Container from $ORGANIZATION removing..."
        CA=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Name" "$CONFIG_FILE")
        CAAPI=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.CAAPI.Name" "$CONFIG_FILE")
        PEERS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[].Name" "$CONFIG_FILE")
        PEERS_DB=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[].DB.Name" "$CONFIG_FILE")
        ORDERERS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Name" "$CONFIG_FILE")

        # Remove CA
        if [[ -n "$CA" ]]; then
            docker rm -f $CA || true
        fi

        # Remove CA-API
        if [[ -n "$CAAPI" ]]; then
            docker rm -f $CAAPI || true
        fi

        # Remove CouchDBs
        for index in $(seq 0 $(($(echo "$PEERS_DB" | wc -l) - 1))); do
            PEER_DB=$(echo "$PEERS_DB" | sed -n "$((index+1))p")
            docker rm -f ${PEER_DB} || true
        done

        # Remove peers
        for index in $(seq 0 $(($(echo "$PEERS" | wc -l) - 1))); do
            PEER=$(echo "$PEERS" | sed -n "$((index+1))p")
            docker rm -f ${PEER} || true
            docker rm -f cli.${PEER} || true
        done

        # Remove orderers
        for index in $(seq 0 $(($(echo "$ORDERERS" | wc -l) - 1))); do
            ORDERER=$(echo "$ORDERERS" | sed -n "$((index+1))p")
            docker rm -f $ORDERER || true
        done
    done
done

# Remove Docker Network
echo ""
echo_info "Docker Network removing..."
docker network rm  $DOCKER_NETWORK_NAME || true

# Remove Folder
echo ""
echo_info "Folder removing..."
rm -f ./config/configtx.yaml
rm -f ./config/*.genesisblock
rm -f ./config/*.tx
rm -rf ./config/couchdb
rm -rf keys
rm -rf tokengen
rm -rf production
#rm tokenchaincode/zkatdlog_pp.json

echo_ok "$DOCKER_NETWORK_NAME removed."