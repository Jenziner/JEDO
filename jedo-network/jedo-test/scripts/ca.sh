###############################################################
#!/bin/bash
#
# This script starts Hyperledger Fabric CA
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
ROOTCA_PORT=$(yq eval '.FabricNetwork.RootCA.Port' $NETWORK_CONFIG_FILE)
ORGANIZATIONS=$(yq e '.FabricNetwork.Organizations[].Name' $NETWORK_CONFIG_FILE)

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
    CA_EXT=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Ext" $NETWORK_CONFIG_FILE)

    # skip if external CA is defined
    if ! [[ -n "$CA_EXT" ]]; then
        echo ""
        echo_warn "Intermediate-CA for $ORGANIZATION starting... - see Documentation here: https://hyperledger-fabric-ca.readthedocs.io"
        CA_NAME=$(yq eval ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Name" $NETWORK_CONFIG_FILE)
        CA_PASS=$(yq eval ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Pass" $NETWORK_CONFIG_FILE)
        CA_IP=$(yq eval ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.IP" $NETWORK_CONFIG_FILE)
        CA_PORT=$(yq eval ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Port" $NETWORK_CONFIG_FILE)
        CA_OPPORT=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.OpPort" $NETWORK_CONFIG_FILE)
        CA_OPENSSL=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.OpenSSL" $NETWORK_CONFIG_FILE)

        docker run -d \
            --network $DOCKER_NETWORK_NAME \
            --name $CA_NAME \
            --ip $CA_IP \
            $hosts_args \
            --restart=unless-stopped \
            --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/jedo-network/src/fabric_ca_logo.png" \
            -e FABRIC_CA_SERVER_LOGLEVEL=debug \
            -e FABRIC_CA_NAME=tls.$CA_NAME \
            -e FABRIC_CA_SERVER=$CA_SRV_DIR \
            -e FABRIC_CA_SERVER_MSPDIR=$CA_SRV_DIR/msp \
            -e FABRIC_CA_SERVER_LISTENADDRESS=$CA_IP \
            -e FABRIC_CA_SERVER_PORT=$CA_PORT \
            -e FABRIC_CA_SERVER_CSR_HOSTS="tls.$CA_NAME,localhost" \
            -e FABRIC_CA_SERVER_TLS_ENABLED=true \
            -e FABRIC_CA_SERVER_IDEMIX_CUURVE=gurvy.Bn254 \
            -e FABRIC_CA_SERVER_INTERMEDIATE_TLS_CERTFILES=$CA_DIR/tls/tlscacerts/tls-$TLS_CERT_FILE \
            -e FABRIC_CA_SERVER_OPERATIONS_LISTENADDRESS=0.0.0.0:$CA_OPPORT \
            -e FABRIC_CA_CLIENT=$CA_CLI_DIR \
            -e FABRIC_CA_CLIENT_MSPDIR=$CA_CLI_DIR/msp \
            -e FABRIC_CA_CLIENT_TLS_ENABLED=true \
            -e FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_SRV_DIR/tls-cert.pem \
            -v ${PWD}/keys/$CA_NAME:$CA_DIR \
            -v ${PWD}/keys/tls.$CA_NAME:$CA_SRV_DIR \
            -v ${PWD}/keys/cli.$CA_NAME:$CA_CLI_DIR \
            -v ${PWD}/keys/:$KEYS_DIR \
            -p $CA_PORT:$CA_PORT \
            -p $CA_OPPORT:$CA_OPPORT \
            hyperledger/fabric-ca:latest \
            sh -c "fabric-ca-server start -b $CA_NAME:$CA_PASS -u https://$ROOTCA_NAME:$ROOTCA_PASS@tls.$ROOTCA_NAME:$ROOTCA_PORT" 

        # Waiting Intermediate-CA startup
        CheckContainer "$CA_NAME" "$DOCKER_CONTAINER_WAIT"
        CheckContainerLog "$CA_NAME" "Listening on https://0.0.0.0:$CA_PORT" "$DOCKER_CONTAINER_WAIT"

        # Installing OpenSSL
        if [[ $CA_OPENSSL = true ]]; then
            echo_info "OpenSSL installing..."
            docker exec $CA_NAME sh -c 'command -v apk && apk update && apk add --no-cache openssl || (apt-get update && apt-get install -y openssl)'
            CheckOpenSSL "$CA_NAME" "$DOCKER_CONTAINER_WAIT"
        fi

        # Enroll Root-CA-Admin
        echo ""
        echo_info "Admin for $CA_NAME enrolling..."
        docker exec -it $CA_NAME fabric-ca-client enroll -u https://$CA_NAME:$CA_PASS@tls.$CA_NAME:$CA_PORT 

        echo_ok "Intermediate-CA for $ORGANIZATION started."
    fi
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
