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


# Remove Root-CA
echo_info "Root-CA removing..."
ROOT_TLSCA_NAME=$(yq eval ".Root.TLS-CA.Name" "$CONFIG_FILE")
if [[ -n "$ROOT_TLSCA_NAME" ]]; then
    docker rm -f $ROOT_TLSCA_NAME || true
fi

ROOT_ORGCA_NAME=$(yq eval ".Root.ORG-CA.Name" "$CONFIG_FILE")
if [[ -n "$ROOT_ORGCA_NAME" ]]; then
    docker rm -f $ROOT_ORGCA_NAME || true
fi


# Remove Intermediate-CA
INTERMEDIATS=$(yq e ".Intermediates[].Name" $CONFIG_FILE)
for INTERMEDIATE in $INTERMEDIATS; do
    echo ""
    echo_info "Docker Container from $INTERMEDIATE removing..."
    TLS_CA=$(yq e ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .TLS-CA.Name" "$CONFIG_FILE")
    ID_CA=$(yq e ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .ID-CA.Name" "$CONFIG_FILE")

    # Remove TLS-CA
    if [[ -n "$TLS_CA" ]]; then
        docker rm -f $TLS_CA || true
    fi

    # Remove ID-CA
    if [[ -n "$ID_CA" ]]; then
        docker rm -f $ID_CA || true
    fi
done


# Remove organizations
ORGANIZATIONS=$(yq eval ".Organizations[].Name" $CONFIG_FILE)
for ORGANIZATION in $ORGANIZATIONS; do
    echo ""
    echo_info "Docker Container from $ORGANIZATION removing..."
    CA=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Name" "$CONFIG_FILE")
    CAAPI=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.CAAPI.Name" "$CONFIG_FILE")
    PEERS=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[].Name" "$CONFIG_FILE")
    PEERS_DB=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[].DB.Name" "$CONFIG_FILE")
    ORDERERS=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Name" "$CONFIG_FILE")

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

# Remove Docker Network
echo ""
echo_info "Docker Network removing..."
docker network rm  $DOCKER_NETWORK_NAME || true

# Remove Folder
echo ""
echo_info "Folder removing..."
rm -rf infrastructure
rm -rf chaincode
#rm tokenchaincode/zkatdlog_pp.json

echo_ok "$DOCKER_NETWORK_NAME removed."