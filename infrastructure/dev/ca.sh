###############################################################
#!/bin/bash
#
# This script starts Hyperledger Fabric CA
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
CHANNELS=$(yq eval ".FabricNetwork.Channels[].Name" $CONFIG_FILE)

for CHANNEL in $CHANNELS; do
    ROOTCA_NAME=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .RootCA.Name" "$CONFIG_FILE")
    ROOTCA_PASS=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .RootCA.Pass" "$CONFIG_FILE")
    ROOTCA_PORT=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .RootCA.Port" "$CONFIG_FILE")
    ORGANIZATIONS=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[].Name" $CONFIG_FILE)

    CA_DIR=/etc/hyperledger/fabric-ca
    CA_SRV_DIR=/etc/hyperledger/fabric-ca-server
    CA_CLI_DIR=/etc/hyperledger/fabric-ca-client
    KEYS_DIR=/etc/hyperledger/keys
    TLS_CERT_FILE="tls-${ROOTCA_NAME//./-}-${ROOTCA_PORT}.pem"

    get_hosts


    ###############################################################
    # Start Intermediate-CAs
    ###############################################################
    for ORGANIZATION in $ORGANIZATIONS; do
        CA_EXT=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Ext" $CONFIG_FILE)

        # skip if external CA is defined
        if ! [[ -n "$CA_EXT" ]]; then
            echo ""
            echo_warn "Intermediate-CA for $ORGANIZATION starting... - see Documentation here: https://hyperledger-fabric-ca.readthedocs.io"
            CA_NAME=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Name" $CONFIG_FILE)
            CA_SUBJECT=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Subject" $CONFIG_FILE)
            CA_PASS=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Pass" $CONFIG_FILE)
            CA_IP=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.IP" $CONFIG_FILE)
            CA_PORT=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Port" $CONFIG_FILE)
            CA_OPPORT=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.OpPort" $CONFIG_FILE)
            CA_OPENSSL=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.OpenSSL" $CONFIG_FILE)

            docker run -d \
                --network $DOCKER_NETWORK_NAME \
                --name $CA_NAME \
                --ip $CA_IP \
                $hosts_args \
                --restart=unless-stopped \
                --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/infrastructure/src/fabric_ca_logo.png" \
                -e FABRIC_CA_SERVER_LOGLEVEL=debug \
                -e FABRIC_CA_NAME=$CA_NAME \
                -e FABRIC_CA_SERVER=$CA_SRV_DIR \
                -e FABRIC_CA_SERVER_MSPDIR=$CA_SRV_DIR/msp \
                -e FABRIC_CA_SERVER_LISTENADDRESS=$CA_IP \
                -e FABRIC_CA_SERVER_PORT=$CA_PORT \
                -e FABRIC_CA_SERVER_CSR_HOSTS="$CA_NAME,localhost" \
                -e FABRIC_CA_SERVER_TLS_ENABLED=true \
                -e FABRIC_CA_SERVER_IDEMIX_CUURVE=gurvy.Bn254 \
                -e FABRIC_CA_SERVER_INTERMEDIATE_TLS_CERTFILES=$CA_DIR/tls/tlscacerts/$TLS_CERT_FILE \
                -e FABRIC_CA_SERVER_OPERATIONS_LISTENADDRESS=0.0.0.0:$CA_OPPORT \
                -e FABRIC_CA_CLIENT=$CA_CLI_DIR \
                -e FABRIC_CA_CLIENT_MSPDIR=$CA_CLI_DIR/msp \
                -e FABRIC_CA_CLIENT_TLS_ENABLED=true \
                -e FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_SRV_DIR/tls-cert.pem \
                -v ${PWD}/keys/$CHANNEL/_infrastructure/$ORGANIZATION/$CA_NAME:$CA_DIR \
                -v ${PWD}/keys/$CHANNEL/_infrastructure/$ORGANIZATION/$CA_NAME:$CA_SRV_DIR \
                -v ${PWD}/keys/$CHANNEL/_infrastructure/$ORGANIZATION/$CA_NAME/cli.$CA_NAME:$CA_CLI_DIR \
                -v ${PWD}/keys/:$KEYS_DIR \
                -p $CA_PORT:$CA_PORT \
                -p $CA_OPPORT:$CA_OPPORT \
                hyperledger/fabric-ca:latest \
                sh -c "fabric-ca-server start -b $CA_NAME:$CA_PASS -u https://$ROOTCA_NAME:$ROOTCA_PASS@$ROOTCA_NAME:$ROOTCA_PORT" 

            # Waiting Intermediate-CA startup
            CheckContainer "$CA_NAME" "$DOCKER_CONTAINER_WAIT"
            CheckContainerLog "$CA_NAME" "Listening on https://0.0.0.0:$CA_PORT" "$DOCKER_CONTAINER_WAIT"

            # Installing OpenSSL
            if [[ $CA_OPENSSL = true ]]; then
                echo_info "OpenSSL installing..."
                docker exec $CA_NAME sh -c 'command -v apk && apk update && apk add --no-cache openssl || (apt-get update && apt-get install -y openssl)'
                CheckOpenSSL "$CA_NAME" "$DOCKER_CONTAINER_WAIT"
            fi

            # Enroll Intermediate-CA-Admin
            echo ""
            echo_info "Admin for $CA_NAME enrolling..."
            docker exec -it $CA_NAME fabric-ca-client enroll -u https://$CA_NAME:$CA_PASS@$CA_NAME:$CA_PORT 

            # Add Affiliation for Organization
            echo ""
            echo_info "Affiliation adding for $ORGANIZATION..."

            # Extract fields from subject
            C=$(echo "$CA_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
            ST=$(echo "$CA_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
            L=$(echo "$CA_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')
            docker exec -it $CA_NAME fabric-ca-client affiliation add $ST -u https://$CA_NAME:$CA_PASS@$CA_NAME:$CA_PORT --mspdir $CA_CLI_DIR/msp
            docker exec -it $CA_NAME fabric-ca-client affiliation add $ST.jedo -u https://$CA_NAME:$CA_PASS@$CA_NAME:$CA_PORT --mspdir $CA_CLI_DIR/msp
            docker exec -it $CA_NAME fabric-ca-client affiliation add $ST.jedo.$C -u https://$CA_NAME:$CA_PASS@$CA_NAME:$CA_PORT --mspdir $CA_CLI_DIR/msp
            docker exec -it $CA_NAME fabric-ca-client affiliation add $ST.jedo.$C.$L -u https://$CA_NAME:$CA_PASS@$CA_NAME:$CA_PORT --mspdir $CA_CLI_DIR/msp

            echo_ok "Intermediate-CA for $ORGANIZATION started."

            # Add Affiliation for Region
            REGIONS=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Regions[].Name" $CONFIG_FILE)
            for REGION in $REGIONS; do
                echo ""
                echo_info "Affiliation adding for $REGION..."
                REGION_SUBJECT=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Regions[] | select(.Name == \"$REGION\") | .Subject" $CONFIG_FILE)

                # Extract fields from subject
                C=$(echo "$REGION_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
                ST=$(echo "$REGION_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
                L=$(echo "$REGION_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')
                AFFILIATION="$ST.jedo.$C.$L"

                docker exec -it $CA_NAME fabric-ca-client affiliation add $AFFILIATION -u https://$CA_NAME:$CA_PASS@$CA_NAME:$CA_PORT --mspdir $CA_CLI_DIR/msp

                OWNERS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Regions[] | select(.Name == \"$REGION\") | .Owners[].Name" $CONFIG_FILE)
                for OWNER in $OWNERS; do
                    # Add Affiliation
                    echo ""
                    echo_info "Affiliation adding for $OWNER..."
                    OWNER_SUBJECT=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Regions[] | select(.Name == \"$REGION\") | .Owners[] | select(.Name == \"$OWNER\") | .Subject" $CONFIG_FILE)

                    # Extract fields from subject
                    C=$(echo "$OWNER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
                    ST=$(echo "$OWNER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
                    L=$(echo "$OWNER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')
                    O=$(echo "$OWNER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^O=/) {sub(/^O=/, "", $i); print $i}}')
                    docker exec -it $CA_NAME fabric-ca-client affiliation add $ST.jedo.$C.$L.$O -u https://$CA_NAME:$CA_PASS@$CA_NAME:$CA_PORT --mspdir $CA_CLI_DIR/msp
                done
            done
        fi
    done
done

chmod -R 777 ./keys

# Rechte für Intermediate-Admin
# {
#   "hf.Registrar.Roles": "*",
#   "hf.Registrar.DelegateRoles": "*",
#   "hf.Registrar.Attributes": "*",
#   "hf.AffiliationMgr": true,
#   "hf.Revoker": true,
#   "hf.GenCRL": true
# }
# 
