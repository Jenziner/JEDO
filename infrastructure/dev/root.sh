###############################################################
#!/bin/bash
#
# This script starts Root-CA and generates certificates for Intermediate-CA
# 
#
###############################################################
source ./utils/utils.sh
source ./utils/help.sh
check_script


###############################################################
# Params - from ./config/network-config.yaml
###############################################################
CONFIG_FILE="./config/infrastructure-dev.yaml"
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $CONFIG_FILE)
CHANNELS=$(yq e ".FabricNetwork.Channels[].Name" $CONFIG_FILE)

for CHANNEL in $CHANNELS; do
    echo ""
    echo_warn "Root-CA starting for $CHANNEL... - see Documentation here: https://hyperledger-fabric-ca.readthedocs.io"

    ROOTCA_NAME=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .RootCA.Name" "$CONFIG_FILE")
    ROOTCA_SUBJECT=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .RootCA.Subject" "$CONFIG_FILE")
    ROOTCA_PASS=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .RootCA.Pass" "$CONFIG_FILE")
    ROOTCA_IP=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .RootCA.IP" "$CONFIG_FILE")
    ROOTCA_PORT=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .RootCA.Port" "$CONFIG_FILE")
    ROOTCA_OPPORT=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .RootCA.OpPort" "$CONFIG_FILE")
    ROOTCA_OPENSSL=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .RootCA.OpenSSL" "$CONFIG_FILE")
    ORGANIZATIONS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[].Name" $CONFIG_FILE)

    ROOTCA_SRV_DIR=/etc/hyperledger/fabric-ca-server
    ROOTCA_CLI_DIR=/etc/hyperledger/fabric-ca-client
    KEYS_DIR=/etc/hyperledger/keys

    get_hosts


    ###############################################################
    # Start Root-CA
    ###############################################################
    docker run -d \
        --network $DOCKER_NETWORK_NAME \
        --name $ROOTCA_NAME \
        --ip $ROOTCA_IP \
        $hosts_args \
        --restart=unless-stopped \
        --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/infrastructure/src/fabric_ca_logo.png" \
        -e FABRIC_CA_SERVER_LOGLEVEL=debug \
        -e FABRIC_CA_NAME=$ROOTCA_NAME \
        -e FABRIC_CA_SERVER=$ROOTCA_SRV_DIR \
        -e FABRIC_CA_SERVER_MSPDIR=$ROOTCA_SRV_DIR/msp \
        -e FABRIC_CA_SERVER_LISTENADDRESS=$ROOTCA_IP \
        -e FABRIC_CA_SERVER_PORT=$ROOTCA_PORT \
        -e FABRIC_CA_SERVER_CSR_HOSTS="$ROOTCA_NAME,localhost" \
        -e FABRIC_CA_SERVER_TLS_ENABLED=true \
        -e FABRIC_CA_SERVER_IDEMIX_CUURVE=gurvy.Bn254 \
        -e FABRIC_CA_SERVER_OPERATIONS_LISTENADDRESS=0.0.0.0:$ROOTCA_OPPORT \
        -e FABRIC_CA_CLIENT=$ROOTCA_CLI_DIR \
        -e FABRIC_CA_CLIENT_MSPDIR=$ROOTCA_CLI_DIR/msp \
        -e FABRIC_CA_CLIENT_TLS_ENABLED=true \
        -e FABRIC_CA_CLIENT_TLS_CERTFILES=$ROOTCA_SRV_DIR/tls-cert.pem \
        -v ${PWD}/keys/$ROOTCA_NAME:$ROOTCA_SRV_DIR \
        -v ${PWD}/keys/$ROOTCA_NAME/cli.$ROOTCA_NAME:$ROOTCA_CLI_DIR \
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
    docker exec -it $ROOTCA_NAME fabric-ca-client enroll -u https://$ROOTCA_NAME:$ROOTCA_PASS@$ROOTCA_NAME:$ROOTCA_PORT

    # Add Affiliation
    echo ""
    echo_info "Affiliation adding..."
    # Extract fields from subject
    C=$(echo "$ROOTCA_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
    ST=$(echo "$ROOTCA_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
    L=$(echo "$ROOTCA_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')

    docker exec -it $ROOTCA_NAME fabric-ca-client affiliation add $C -u https://$ROOTCA_NAME:$ROOTCA_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $ROOTCA_CLI_DIR/msp
    docker exec -it $ROOTCA_NAME fabric-ca-client affiliation add $C.$ST -u https://$ROOTCA_NAME:$ROOTCA_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $ROOTCA_CLI_DIR/msp
    docker exec -it $ROOTCA_NAME fabric-ca-client affiliation add $C.$ST.$L -u https://$ROOTCA_NAME:$ROOTCA_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $ROOTCA_CLI_DIR/msp

    echo_ok "Root-CA started."


    ###############################################################
    # Generate Intermediate certificats
    ###############################################################
    echo ""
    echo_warn "Intermediate-CA certificates generating..."
    for ORGANIZATION in $ORGANIZATIONS; do
        CA_EXT=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Ext" "$CONFIG_FILE")


        # Skip if external CA is defined
        if ! [[ -n "$CA_EXT" ]]; then
            CA_NAME=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Name" $CONFIG_FILE)
            CA_SUBJECT=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Subject" $CONFIG_FILE)
            CA_PASS=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Pass" $CONFIG_FILE)

            # Add Affiliation
            echo ""
            echo_info "Affiliation adding for $ORGANIZATION..."

            # Extract fields from subject
            C=$(echo "$CA_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
            ST=$(echo "$CA_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
            L=$(echo "$CA_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')
            O=$(echo "$CA_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^O=/) {sub(/^O=/, "", $i); print $i}}')
            CN=$(echo "$CA_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^CN=/) {sub(/^CN=/, "", $i); print $i}}')
            CSR_NAMES=$(echo "$CA_SUBJECT" | sed 's/,CN=[^,]*//')
            AFFILIATION="$C.$ST.$L.$O"

            docker exec -it $ROOTCA_NAME fabric-ca-client affiliation add $AFFILIATION -u https://$ROOTCA_NAME:$ROOTCA_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $ROOTCA_CLI_DIR/msp

            # Register User
            echo ""
            echo_info "User $CA_NAME registering..."
            docker exec -it $ROOTCA_NAME fabric-ca-client register -u https://$ROOTCA_NAME:$ROOTCA_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $ROOTCA_CLI_DIR/msp \
                --id.name $CA_NAME --id.secret $CA_PASS --id.type client --id.affiliation $AFFILIATION --id.attrs "hf.Registrar.Roles=client,hf.IntermediateCA=true"

            # Enroll User
            echo ""
            echo_info "User $CA_NAME enrolling..."
            docker exec -it $ROOTCA_NAME fabric-ca-client enroll -u https://$CA_NAME:$CA_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $KEYS_DIR/$CA_NAME/msp \
                --csr.cn $CN --csr.names "$CSR_NAMES"

            # Enroll User TLS
            echo ""
            echo_info "User $CA_NAME TLS enrolling..."
            docker exec -it $ROOTCA_NAME fabric-ca-client enroll -u https://$CA_NAME:$CA_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $KEYS_DIR/$CA_NAME/tls \
                --enrollment.profile tls --csr.hosts $ROOTCA_NAME  --csr.cn $CN --csr.names "$CSR_NAMES"
        fi
    done

    chmod -R 777 ./keys

    echo_ok "Intermediate-CA certificates generated."

done

#     --tls.enabled \
#     --operations.listenAddress=0.0.0.0:$ROOTCA_OPPORT \
#     --operations.tls.enabled \
#     --operations.tls.certfile=$ROOTCA_DIR/tls-cert.pem \
#     --operations.tls.keyfile=$ROOTCA_DIR/tls-key.pem 

