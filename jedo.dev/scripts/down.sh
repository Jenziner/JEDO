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
CONFIG_FILE="$SCRIPT_DIR/infrastructure-dev.yaml"
DOCKER_NETWORK_NAME=$(yq eval ".Docker.Network.Name" "$CONFIG_FILE")


###############################################################
# Remove Docker-Stuff
###############################################################
echo ""
echo_warn "$DOCKER_NETWORK_NAME removing..."


# TLS-CA
TLSS=$(yq e ".TLS.Hosts[].Name" $CONFIG_FILE)
for TLS in $TLSS; do
    echo ""
    echo_info "Docker Container from $TLS removing..."
    TLS_HOST_NAME=$(yq e ".TLS.Hosts[] | select(.Name == \"$TLS\") | .Name" "$CONFIG_FILE")

    if [[ -n "$TLS_HOST_NAME" ]]; then
        docker rm -f $TLS_HOST_NAME || true
    fi

done


# Remove Root-CA
echo_info "Root-CA removing..."
ROOT_CA_NAME=$(yq eval ".Root.Name" "$CONFIG_FILE")
if [[ -n "$ROOT_CA_NAME" ]]; then
    docker rm -f $ROOT_CA_NAME || true
fi


# Remove Intermediate-CA
INTERMEDIATS=$(yq e ".Intermediates[].Name" $CONFIG_FILE)
for INTERMEDIATE in $INTERMEDIATS; do
    echo ""
    echo_info "Docker Container from $INTERMEDIATE removing..."
    CA_NAME=$(yq e ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .Name" "$CONFIG_FILE")

    if [[ -n "$CA_NAME" ]]; then
        docker rm -f $CA_NAME || true
    fi

done


# Remove organizations
ORGANIZATIONS=$(yq eval ".Organizations[].Name" $CONFIG_FILE)
for ORGANIZATION in $ORGANIZATIONS; do
    echo ""
    echo_info "Docker Container from $ORGANIZATION removing..."
    TLSCA=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .TLS-CA.Name" "$CONFIG_FILE")
    TLSCAAPI=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .TLS-CA.CAAPI.Name" "$CONFIG_FILE")
    ORGCA=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .ORG-CA.Name" "$CONFIG_FILE")
    ORGCAAPI=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .ORG-CA.CAAPI.Name" "$CONFIG_FILE")
    PEERS=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[].Name" "$CONFIG_FILE")
    PEERS_DB=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[].DB.Name" "$CONFIG_FILE")
    ORDERERS=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Name" "$CONFIG_FILE")

    # Remove TLS-CA
    if [[ -n "$TLSCA" ]]; then
        docker rm -f $TLSCA || true
    fi

    # Remove TLSCA-API
    if [[ -n "$TLSCAAPI" ]]; then
        docker rm -f $TLSCAAPI || true
    fi

    # Remove ORG-CA
    if [[ -n "$ORGCA" ]]; then
        docker rm -f $ORGCA || true
    fi

    # Remove ORGCA-API
    if [[ -n "$ORGCAAPI" ]]; then
        docker rm -f $ORGCAAPI || true
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