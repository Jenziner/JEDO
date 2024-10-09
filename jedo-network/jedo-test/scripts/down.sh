###############################################################
#!/bin/bash
#
# This script fully tears down and deletes all artifacts from the sample network that was started with ./scripts/up.sh.
#
#
###############################################################
source ./scripts/settings.sh
source ./scripts/help.sh
check_script

echo_ok "Shuting down network"


###############################################################
# Params - from ./config/network-config.yaml
###############################################################
NETWORK_CONFIG_FILE="./config/network-config.yaml"
FABRIC_PATH=$(yq eval ".Fabric.Path" "$NETWORK_CONFIG_FILE")
DOCKER_NETWORK_NAME=$(yq eval ".Docker.Network.Name" "$NETWORK_CONFIG_FILE")
ORGANIZATIONS=$(yq e ".FabricNetwork.Organizations[].Name" $NETWORK_CONFIG_FILE)


###############################################################
# Remove Docker-Stuff
###############################################################
echo_info "ScriptInfo: removing docker container"

for ORGANIZATION in $ORGANIZATIONS; do
    CA=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Name" $NETWORK_CONFIG_FILE)
    PEERS=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[].Name" $NETWORK_CONFIG_FILE)
    PEERS_DB=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[].DB.Name" $NETWORK_CONFIG_FILE)
    ORDERERS=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Name" $NETWORK_CONFIG_FILE)

    # remove CA
    if [[ -n "$CA" ]]; then
        docker rm -f $CA || true
        docker rm -f cli.${CA} || true
    fi

    # remove couchDBs
    for index in $(seq 0 $(($(echo "$PEERS_DB" | wc -l) - 1))); do
        PEER_DB=$(echo "$PEERS_DB" | sed -n "$((index+1))p")
        docker rm -f ${PEER_DB} || true
    done

    # remove peers
    for index in $(seq 0 $(($(echo "$PEERS" | wc -l) - 1))); do
        PEER=$(echo "$PEERS" | sed -n "$((index+1))p")
        docker rm -f ${PEER} || true
        docker rm -f cli.${PEER} || true
    done

    # remove orderers
    for index in $(seq 0 $(($(echo "$ORDERERS" | wc -l) - 1))); do
        ORDERER=$(echo "$ORDERERS" | sed -n "$((index+1))p")
        docker rm -f $ORDERER || true
    done
done

echo_info "ScriptInfo: removing docker network"
docker network rm  $DOCKER_NETWORK_NAME || true

###############################################################
# Remove Folder
###############################################################
echo_info "ScriptInfo: removing folders"
rm -f ./config/configtx.yaml
rm -f ./config/*.genesisblock
rm -f ./config/*.tx
rm -rf ./config/couchdb
rm -rf keys
rm -rf tokengen
rm -rf production
#rm tokenchaincode/zkatdlog_pp.json