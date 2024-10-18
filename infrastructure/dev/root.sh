###############################################################
#!/bin/bash
#
# This script starts Root-CA and generates certificates for Intermediate-CA
# 
#
###############################################################
source ./scripts/settings.sh
source ./scripts/help.sh
check_script


###############################################################
# Params - from ./config/network-config.yaml
###############################################################
NETWORK_CONFIG_FILE="./config/network-config.yaml"
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $NETWORK_CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $NETWORK_CONFIG_FILE)
ROOTCA_NAME=$(yq eval '.FabricNetwork.RootCA.Name' $NETWORK_CONFIG_FILE)
ROOTCA_PASS=$(yq eval '.FabricNetwork.RootCA.Pass' $NETWORK_CONFIG_FILE)
ROOTCA_IP=$(yq eval '.FabricNetwork.RootCA.IP' $NETWORK_CONFIG_FILE)
ROOTCA_PORT=$(yq eval '.FabricNetwork.RootCA.Port' $NETWORK_CONFIG_FILE)
ROOTCA_OPPORT=$(yq eval '.FabricNetwork.RootCA.OpPort' $NETWORK_CONFIG_FILE)
ROOTCA_OPENSSL=$(yq eval '.FabricNetwork.RootCA.OpenSSL' $NETWORK_CONFIG_FILE)
ORGANIZATIONS=$(yq e '.FabricNetwork.Organizations[].Name' $NETWORK_CONFIG_FILE)

ROOTCA_SRV_DIR=/etc/hyperledger/fabric-ca-server
ROOTCA_CLI_DIR=/etc/hyperledger/fabric-ca-client
KEYS_DIR=/etc/hyperledger/keys

get_hosts


###############################################################
# Start Root-CA
###############################################################
echo ""
echo_warn "Root-CA starting... - see Documentation here: https://hyperledger-fabric-ca.readthedocs.io"
docker run -d \
    --network $DOCKER_NETWORK_NAME \
    --name $ROOTCA_NAME \
    --ip $ROOTCA_IP \
    $hosts_args \
    --restart=unless-stopped \
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/jedo-network/src/fabric_ca_logo.png" \
    -e FABRIC_CA_SERVER_LOGLEVEL=debug \
    -e FABRIC_CA_NAME=tls.$ROOTCA_NAME \
    -e FABRIC_CA_SERVER=$ROOTCA_SRV_DIR \
    -e FABRIC_CA_SERVER_MSPDIR=$ROOTCA_SRV_DIR/msp \
    -e FABRIC_CA_SERVER_LISTENADDRESS=$ROOTCA_IP \
    -e FABRIC_CA_SERVER_PORT=$ROOTCA_PORT \
    -e FABRIC_CA_SERVER_CSR_HOSTS="tls.$ROOTCA_NAME,localhost" \
    -e FABRIC_CA_SERVER_TLS_ENABLED=true \
    -e FABRIC_CA_SERVER_IDEMIX_CUURVE=gurvy.Bn254 \
    -e FABRIC_CA_SERVER_OPERATIONS_LISTENADDRESS=0.0.0.0:$ROOTCA_OPPORT \
    -e FABRIC_CA_CLIENT=$ROOTCA_CLI_DIR \
    -e FABRIC_CA_CLIENT_MSPDIR=$ROOTCA_CLI_DIR/msp \
    -e FABRIC_CA_CLIENT_TLS_ENABLED=true \
    -e FABRIC_CA_CLIENT_TLS_CERTFILES=$ROOTCA_SRV_DIR/tls-cert.pem \
    -v ${PWD}/keys/tls.$ROOTCA_NAME:$ROOTCA_SRV_DIR \
    -v ${PWD}/keys/cli.$ROOTCA_NAME:$ROOTCA_CLI_DIR \
    -v ${PWD}/keys/:$KEYS_DIR \
    -p $ROOTCA_PORT:$ROOTCA_PORT \
    -p $ROOTCA_OPPORT:$ROOTCA_OPPORT \
    hyperledger/fabric-ca:latest \
    sh -c "fabric-ca-server start -b $ROOTCA_NAME:$ROOTCA_PASS" 

# Waiting Root-CA startup
CheckContainer "$ROOTCA_NAME" "$DOCKER_CONTAINER_WAIT"
CheckContainerLog "$ROOTCA_NAME" "Listening on https://0.0.0.0:$ROOTCA_PORT" "$DOCKER_CONTAINER_WAIT"

# Installing OpenSSL
if [[ $ROOTCA_OPENSSL = true ]]; then
    echo_info "OpenSSL installing..."
    docker exec $ROOTCA_NAME sh -c 'command -v apk && apk update && apk add --no-cache openssl || (apt-get update && apt-get install -y openssl)'
    CheckOpenSSL "$ROOTCA_NAME" "$DOCKER_CONTAINER_WAIT"
fi

# Enroll Root-CA-Admin
echo ""
echo_info "Root-Admin enrolling..."
docker exec -it $ROOTCA_NAME fabric-ca-client enroll -u https://$ROOTCA_NAME:$ROOTCA_PASS@tls.$ROOTCA_NAME:$ROOTCA_PORT

# Add Affiliation
echo ""
echo_info "Affiliation adding..."
docker exec -it $ROOTCA_NAME fabric-ca-client affiliation add JEDO -u https://$ROOTCA_NAME:$ROOTCA_PASS@tls.$ROOTCA_NAME:$ROOTCA_PORT --mspdir $ROOTCA_CLI_DIR/msp

echo_ok "Root-CA started."


###############################################################
# Generate Intermediate certificats
###############################################################
echo ""
echo_warn "Intermediate-CA certificates generating..."
for ORGANIZATION in $ORGANIZATIONS; do
    CA_EXT=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Ext" $NETWORK_CONFIG_FILE)

    # Skip if external CA is defined
    if ! [[ -n "$CA_EXT" ]]; then
        CA_NAME=$(yq eval ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Name" $NETWORK_CONFIG_FILE)
        CA_PASS=$(yq eval ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Pass" $NETWORK_CONFIG_FILE)

        # Add Affiliation
        echo ""
        echo_info "Affiliation adding for $ORGANIZATION..."
        docker exec -it $ROOTCA_NAME fabric-ca-client affiliation add $ORGANIZATION -u https://$ROOTCA_NAME:$ROOTCA_PASS@tls.$ROOTCA_NAME:$ROOTCA_PORT --mspdir $ROOTCA_CLI_DIR/msp

        # Register User
        echo ""
        echo_info "User $CA_NAME registering..."
        docker exec -it $ROOTCA_NAME fabric-ca-client register -u https://$ROOTCA_NAME:$ROOTCA_PASS@tls.$ROOTCA_NAME:$ROOTCA_PORT --mspdir $ROOTCA_CLI_DIR/msp \
            --id.name $CA_NAME --id.secret $CA_PASS --id.type client --id.attrs "hf.Registrar.Roles=client,hf.IntermediateCA=true"

        # Enroll User
        echo ""
        echo_info "User $CA_NAME enrolling..."
        docker exec -it $ROOTCA_NAME fabric-ca-client enroll -u https://$CA_NAME:$CA_PASS@tls.$ROOTCA_NAME:$ROOTCA_PORT --mspdir $KEYS_DIR/$CA_NAME/msp \
            --csr.cn tls.$ROOTCA_NAME

        # Enroll User TLS
        echo ""
        echo_info "User $CA_NAME TLS enrolling..."
        docker exec -it $ROOTCA_NAME fabric-ca-client enroll -u https://$CA_NAME:$CA_PASS@tls.$ROOTCA_NAME:$ROOTCA_PORT --enrollment.profile tls --mspdir $KEYS_DIR/$CA_NAME/tls --csr.hosts tls.$ROOTCA_NAME --csr.cn tls.$ROOTCA_NAME
     fi
done

chmod -R 777 ./keys

echo_ok "Intermediate-CA certificates generated."

#     --tls.enabled \
#     --operations.listenAddress=0.0.0.0:$ROOTCA_OPPORT \
#     --operations.tls.enabled \
#     --operations.tls.certfile=$ROOTCA_DIR/tls-cert.pem \
#     --operations.tls.keyfile=$ROOTCA_DIR/tls-key.pem 

