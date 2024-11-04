###############################################################
#!/bin/bash
#
# This script starts Root-CA and generates certificates for Intermediate-CA
# 
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
check_script


###############################################################
# Params - from ./config/network-config.yaml
###############################################################
CONFIG_FILE="$SCRIPT_DIR/infrastructure-dev.yaml"
DOCKER_UNRAID=$(yq eval '.Docker.Unraid' $CONFIG_FILE)
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $CONFIG_FILE)

CA_SRV_DIR=/etc/hyperledger/fabric-ca-server
CA_CLI_DIR=/etc/hyperledger/fabric-ca-client
INFRA_DIR=/etc/hyperledger/infrastructure

get_hosts


###############################################################
# Start Root-TLS-CA
###############################################################
ROOT_TLSCA_NAME=$(yq eval ".Root.TLS-CA.Name" "$CONFIG_FILE")
ROOT_TLSCA_PASS=$(yq eval ".Root.TLS-CA.Pass" "$CONFIG_FILE")
ROOT_TLSCA_IP=$(yq eval ".Root.TLS-CA.IP" "$CONFIG_FILE")
ROOT_TLSCA_PORT=$(yq eval ".Root.TLS-CA.Port" "$CONFIG_FILE")
ROOT_TLSCA_OPENSSL=$(yq eval ".Root.TLS-CA.OpenSSL" "$CONFIG_FILE")

# skip if not specified
if [[ -n "$ROOT_TLSCA_NAME" ]]; then
    echo ""
    echo_info "Root-CA $ROOT_TLSCA_NAME starting..."

    docker run -d \
        --name $ROOT_TLSCA_NAME \
        --network $DOCKER_NETWORK_NAME \
        --ip $ROOT_TLSCA_IP \
        $hosts_args \
        --restart=on-failure \
        --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/src/fabric_ca_logo.png" \
        -p $ROOT_TLSCA_PORT:$ROOT_TLSCA_PORT \
        -v ${PWD}/infrastructure/_root/$ROOT_TLSCA_NAME/keys/server:$CA_SRV_DIR \
        -v ${PWD}/infrastructure/_root/$ROOT_TLSCA_NAME/keys/client:$CA_CLI_DIR \
        -v ${PWD}/infrastructure/:$INFRA_DIR \
        -e FABRIC_CA_SERVER_LOGLEVEL=debug \
        -e FABRIC_CA_SERVER_CA_NAME=$ROOT_TLSCA_NAME \
        -e FABRIC_CA_SERVER_PORT=$ROOT_TLSCA_PORT \
        -e FABRIC_CA_SERVER_HOME=$CA_SRV_DIR \
        -e FABRIC_CA_SERVER_MSPDIR=$CA_SRV_DIR/msp \
        -e FABRIC_CA_SERVER_CSR_CN=$ROOT_TLSCA_NAME \
        -e FABRIC_CA_SERVER_CSR_HOSTS="$ROOT_TLSCA_NAME,$ROOT_TLSCA_IP,localhost,0.0.0.0" \
        -e FABRIC_CA_SERVER_CSR_CA_PATHLENGTH=2 \
        -e FABRIC_CA_SERVER_SIGNING.PROFILES.CA.CACONSTRAINT.MAXPATHLEN=2 \
        -e FABRIC_CA_SERVER_SIGNING.PROFILES.CA.CACONSTRAINT.MAXPATHLENZERO=false \
        -e FABRIC_CA_SERVER_TLS_ENABLED=true \
        -e FABRIC_CA_SERVER_CFG_AFFILIATIONS_ALLOWREMOVE=true \
        -e FABRIC_CA_CLIENT_HOME=$CA_CLI_DIR \
        -e FABRIC_CA_CLIENT_MSPDIR=$CA_CLI_DIR/msp \
        -e FABRIC_CA_CLIENT_TLS_ENABLED=true \
        -e FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_SRV_DIR/tls-cert.pem \
        hyperledger/fabric-ca:latest \
        sh -c "fabric-ca-server start -b $ROOT_TLSCA_NAME:$ROOT_TLSCA_PASS" 

    # Waiting Root-CA startup
    CheckContainer "$ROOT_TLSCA_NAME" "$DOCKER_CONTAINER_WAIT"
    CheckContainerLog "$ROOT_TLSCA_NAME" "Listening on https://0.0.0.0:$ROOT_TLSCA_PORT" "$DOCKER_CONTAINER_WAIT"

    # Installing OpenSSL
    if [[ $ROOT_TLSCA_OPENSSL = true ]]; then
        echo_info "OpenSSL installing..."
        docker exec $ROOT_TLSCA_NAME sh -c 'command -v apk && apk update && apk add --no-cache openssl || (apt-get update && apt-get install -y openssl)'
        CheckOpenSSL "$ROOT_TLSCA_NAME" "$DOCKER_CONTAINER_WAIT"
    fi

    # Enroll Root-TLS
    echo ""
    echo_info "Root-TLS enrolling..."
    docker exec -it $ROOT_TLSCA_NAME fabric-ca-client enroll -u https://$ROOT_TLSCA_NAME:$ROOT_TLSCA_PASS@$ROOT_TLSCA_NAME:$ROOT_TLSCA_PORT \


    # Add Affiliation
    echo ""
    echo_info "Affiliation adding..."
    ROOT_NAME=$(yq eval ".Root.Name" "$CONFIG_FILE")
    DN="${ROOT_NAME%%.*}"   # Alles vor dem ersten Punkt
    TLDN="${ROOT_NAME##*.}" 

    AFFILIATION_ROOT=$TLDN
    docker exec -it $ROOT_TLSCA_NAME fabric-ca-client affiliation add $AFFILIATION_ROOT -u https://$ROOT_TLSCA_NAME:$ROOT_TLSCA_PASS@$ROOT_TLSCA_NAME:$ROOT_TLSCA_PORT
    AFFILIATION_ROOT=$TLDN.$DN
    docker exec -it $ROOT_TLSCA_NAME fabric-ca-client affiliation add $AFFILIATION_ROOT -u https://$ROOT_TLSCA_NAME:$ROOT_TLSCA_PASS@$ROOT_TLSCA_NAME:$ROOT_TLSCA_PORT

    # Remove default affiliation
    echo ""
    echo_info "Default affiliation removing..."
    docker exec -it $ROOT_TLSCA_NAME fabric-ca-client affiliation remove org1 --force -u https://$ROOT_TLSCA_NAME:$ROOT_TLSCA_PASS@$ROOT_TLSCA_NAME:$ROOT_TLSCA_PORT
    docker exec -it $ROOT_TLSCA_NAME fabric-ca-client affiliation remove org2 --force -u https://$ROOT_TLSCA_NAME:$ROOT_TLSCA_PASS@$ROOT_TLSCA_NAME:$ROOT_TLSCA_PORT
    docker exec -it $ROOT_TLSCA_NAME fabric-ca-client affiliation list

    echo_ok "Root-CA $ROOT_TLSCA_NAME started..."

    chmod -R 777 infrastructure
fi

###############################################################
# Start Root-ORG-CA
###############################################################
ROOT_ORGCA_NAME=$(yq eval ".Root.ORG-CA.Name" "$CONFIG_FILE")
ROOT_ORGCA_PASS=$(yq eval ".Root.ORG-CA.Pass" "$CONFIG_FILE")
ROOT_ORGCA_IP=$(yq eval ".Root.ORG-CA.IP" "$CONFIG_FILE")
ROOT_ORGCA_PORT=$(yq eval ".Root.ORG-CA.Port" "$CONFIG_FILE")
ROOT_ORGCA_OPENSSL=$(yq eval ".Root.ORG-CA.OpenSSL" "$CONFIG_FILE")

# skip if not specified
if [[ -n "$ROOT_ORGCA_NAME" ]]; then
    echo ""
    echo_info "Root-CA $ROOT_ORGCA_NAME starting..."

    docker run -d \
        --name $ROOT_ORGCA_NAME \
        --network $DOCKER_NETWORK_NAME \
        --ip $ROOT_ORGCA_IP \
        $hosts_args \
        --restart=on-failure \
        --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/src/fabric_ca_logo.png" \
        -p $ROOT_ORGCA_PORT:$ROOT_ORGCA_PORT \
        -v ${PWD}/infrastructure/_root/$ROOT_ORGCA_NAME/keys/server:$CA_SRV_DIR \
        -v ${PWD}/infrastructure/_root/$ROOT_ORGCA_NAME/keys/client:$CA_CLI_DIR \
        -v ${PWD}/infrastructure/:$INFRA_DIR \
        -e FABRIC_CA_SERVER_LOGLEVEL=debug \
        -e FABRIC_CA_SERVER_CA_NAME=$ROOT_ORGCA_NAME \
        -e FABRIC_CA_SERVER_PORT=$ROOT_ORGCA_PORT \
        -e FABRIC_CA_SERVER_HOME=$CA_SRV_DIR \
        -e FABRIC_CA_SERVER_MSPDIR=$CA_SRV_DIR/msp \
        -e FABRIC_CA_SERVER_CSR_CN=$ROOT_ORGCA_NAME \
        -e FABRIC_CA_SERVER_CSR_HOSTS="$ROOT_ORGCA_NAME,$ROOT_ORGCA_IP,localhost,0.0.0.0" \
        -e FABRIC_CA_SERVER_CSR_CA_PATHLENGTH=2 \
        -e FABRIC_CA_SERVER_TLS_ENABLED=true \
        -e FABRIC_CA_SERVER_CFG_AFFILIATIONS_ALLOWREMOVE=true \
        -e FABRIC_CA_CLIENT_HOME=$CA_CLI_DIR \
        -e FABRIC_CA_CLIENT_MSPDIR=$CA_CLI_DIR/msp \
        -e FABRIC_CA_CLIENT_TLS_ENABLED=true \
        -e FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_SRV_DIR/tls-cert.pem \
        hyperledger/fabric-ca:latest \
        sh -c "fabric-ca-server start -b $ROOT_ORGCA_NAME:$ROOT_ORGCA_PASS" 

    # Waiting Root-CA startup
    CheckContainer "$ROOT_ORGCA_NAME" "$DOCKER_CONTAINER_WAIT"
    CheckContainerLog "$ROOT_ORGCA_NAME" "Listening on https://0.0.0.0:$ROOT_ORGCA_PORT" "$DOCKER_CONTAINER_WAIT"

    # Installing OpenSSL
    if [[ $ROOT_ORGCA_OPENSSL = true ]]; then
        echo_info "OpenSSL installing..."
        docker exec $ROOT_ORGCA_NAME sh -c 'command -v apk && apk update && apk add --no-cache openssl || (apt-get update && apt-get install -y openssl)'
        CheckOpenSSL "$ROOT_ORGCA_NAME" "$DOCKER_CONTAINER_WAIT"
    fi

    # Enroll Root-ORG
    echo ""
    echo_info "Root-ORG enrolling..."
    docker exec -it $ROOT_ORGCA_NAME fabric-ca-client enroll -u https://$ROOT_ORGCA_NAME:$ROOT_ORGCA_PASS@$ROOT_ORGCA_NAME:$ROOT_ORGCA_PORT

    # Add Affiliation
    echo ""
    echo_info "Affiliation adding..."
    ROOT_NAME=$(yq eval ".Root.Name" "$CONFIG_FILE")
    DN="${ROOT_NAME%%.*}"   # Alles vor dem ersten Punkt
    TLDN="${ROOT_NAME##*.}" 

    AFFILIATION_ROOT=$TLDN
    docker exec -it $ROOT_ORGCA_NAME fabric-ca-client affiliation add $AFFILIATION_ROOT -u https://$ROOT_ORGCA_NAME:$ROOT_ORGCA_PASS@$ROOT_ORGCA_NAME:$ROOT_ORGCA_PORT
    AFFILIATION_ROOT=$TLDN.$DN
    docker exec -it $ROOT_ORGCA_NAME fabric-ca-client affiliation add $AFFILIATION_ROOT -u https://$ROOT_ORGCA_NAME:$ROOT_ORGCA_PASS@$ROOT_ORGCA_NAME:$ROOT_ORGCA_PORT

    # Remove default affiliation
    echo ""
    echo_info "Default affiliation removing..."
    docker exec -it $ROOT_ORGCA_NAME fabric-ca-client affiliation remove org1 --force -u https://$ROOT_ORGCA_NAME:$ROOT_ORGCA_PASS@$ROOT_ORGCA_NAME:$ROOT_ORGCA_PORT
    docker exec -it $ROOT_ORGCA_NAME fabric-ca-client affiliation remove org2 --force -u https://$ROOT_ORGCA_NAME:$ROOT_ORGCA_PASS@$ROOT_ORGCA_NAME:$ROOT_ORGCA_PORT
    docker exec -it $ROOT_ORGCA_NAME fabric-ca-client affiliation list

    echo_ok "Root-CA $ROOT_ORGCA_NAME started."

    chmod -R 777 infrastructure
fi

###############################################################
# Last Tasks
###############################################################
