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
# Params
###############################################################
CONFIG_FILE="$SCRIPT_DIR/infrastructure-dev.yaml"
DOCKER_UNRAID=$(yq eval '.Docker.Unraid' $CONFIG_FILE)
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $CONFIG_FILE)

CA_SRV_DIR=/etc/hyperledger/fabric-ca-server
CA_CLI_DIR=/etc/hyperledger/fabric-ca-client
INFRA_DIR=/etc/hyperledger/infrastructure

ROOT_NAME=$(yq eval ".Root.Name" "$CONFIG_FILE")
AFFILIATION_ROOT=${ROOT_NAME##*.}.${ROOT_NAME%%.*}

get_hosts

ORGANIZATIONS=$(yq e ".Organizations[].Name" $CONFIG_FILE)
for ORGANIZATION in $ORGANIZATIONS; do
    ###############################################################
    # Start Node-TLS-CA
    ###############################################################
    ROOT_NAME=$(yq eval ".Root.Name" "$CONFIG_FILE")
    DN="${ROOT_NAME%%.*}"   # Alles vor dem ersten Punkt
    AFFILIATION_TLDN="${ROOT_NAME##*.}" 
    AFFILIATION_ROOT=$AFFILIATION_TLDN.$DN
    AFFILIATION_NODE=$AFFILIATION_ROOT.${ORGANIZATION,,}

    # ROOT_REFERENCE=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Root" "$CONFIG_FILE")
    # ROOT_TLSCA_NAME=$(yq eval ".Intermediates[] | select(.Name == \"$ROOT_REFERENCE\") | .TLS-CA.Name" "$CONFIG_FILE")
    # ROOT_TLSCA_PASS=$(yq eval ".Intermediates[] | select(.Name == \"$ROOT_REFERENCE\") | .TLS-CA.Pass" "$CONFIG_FILE")
    # ROOT_TLSCA_PORT=$(yq eval ".Intermediates[] | select(.Name == \"$ROOT_REFERENCE\") | .TLS-CA.Port" "$CONFIG_FILE")

ROOT_TLSCA_NAME=$(yq eval ".Root.TLS-CA.Name" "$CONFIG_FILE")
ROOT_TLSCA_PASS=$(yq eval ".Root.TLS-CA.Pass" "$CONFIG_FILE")
ROOT_TLSCA_PORT=$(yq eval ".Root.TLS-CA.Port" "$CONFIG_FILE")

    echo ""
    echo_warn "Node-TLS-CA for $ORGANIZATION starting... - see Documentation here: https://hyperledger-fabric-ca.readthedocs.io"

    CA_EXT=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .TLS-CA.Ext" $CONFIG_FILE)
    if ! [[ -n "$CA_EXT" ]]; then

        NODETLSCA_NAME=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .TLS-CA.Name" $CONFIG_FILE)
        NODETLSCA_PASS=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .TLS-CA.Pass" $CONFIG_FILE)
        NODETLSCA_IP=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .TLS-CA.IP" $CONFIG_FILE)
        NODETLSCA_PORT=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .TLS-CA.Port" $CONFIG_FILE)
        NODETLSCA_OPPORT=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .TLS-CA.OpPort" $CONFIG_FILE)
        NODETLSCA_OPENSSL=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .TLS-CA.OpenSSL" $CONFIG_FILE)

        # Enroll Node-TLS
        echo ""
        echo_info "Node-TLS $NODETLSCA_NAME registering and enrolling..."
        docker exec -it $ROOT_TLSCA_NAME fabric-ca-client register -u https://$ROOT_TLSCA_NAME:$ROOT_TLSCA_PASS@$ROOT_TLSCA_NAME:$ROOT_TLSCA_PORT \
            --id.name $NODETLSCA_NAME --id.secret $NODETLSCA_PASS --id.type client --id.affiliation $AFFILIATION_NODE \
            --id.attrs 'hf.IntermediateCA=true'
        docker exec -it $ROOT_TLSCA_NAME fabric-ca-client enroll -u https://$NODETLSCA_NAME:$NODETLSCA_PASS@$ROOT_TLSCA_NAME:$ROOT_TLSCA_PORT --mspdir $INFRA_DIR/$ORGANIZATION/$NODETLSCA_NAME/keys/server/msp \
            --enrollment.attrs "hf.IntermediateCA" \
            --csr.hosts "$NODETLSCA_NAME,$NODETLSCA_IP,localhost,$ROOT_TLSCA_NAME" \
            --enrollment.profile ca
        docker exec -it $ROOT_TLSCA_NAME fabric-ca-client enroll -u https://$NODETLSCA_NAME:$NODETLSCA_PASS@$ROOT_TLSCA_NAME:$ROOT_TLSCA_PORT --mspdir $INFRA_DIR/$ORGANIZATION/$NODETLSCA_NAME/keys/server/tls \
            --enrollment.attrs "hf.IntermediateCA" \
            --csr.hosts "$NODETLSCA_NAME,$NODETLSCA_IP,localhost,$ROOT_TLSCA_NAME" \
            --enrollment.profile tls

        # Initiate Intermediate-TLS-CA
        ROOT_TLS_CA_CERT=$(basename $(ls ${PWD}/infrastructure/$ORGANIZATION/$NODETLSCA_NAME/keys/server/tls/tlscacerts/*.pem | head -n 1))
        TLS_CA_KEY=$(basename $(ls ${PWD}/infrastructure/$ORGANIZATION/$NODETLSCA_NAME/keys/server/tls/keystore/*_sk | head -n 1))
        echo ""
        echo_info "Node-CA $NODETLSCA_NAME starting..."

        docker run -d \
            --name $NODETLSCA_NAME \
            --network $DOCKER_NETWORK_NAME \
            --ip $NODETLSCA_IP \
            $hosts_args \
            --restart=unless-stopped \
            --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/src/fabric_ca_logo.png" \
            -p $NODETLSCA_PORT:$NODETLSCA_PORT \
            -p $NODETLSCA_OPPORT:$NODETLSCA_OPPORT \
            -v ${PWD}/infrastructure/$ORGANIZATION/$NODETLSCA_NAME/keys/server:$CA_SRV_DIR \
            -v ${PWD}/infrastructure/$ORGANIZATION/$NODETLSCA_NAME/keys/client:$CA_CLI_DIR \
            -v ${PWD}/infrastructure/:$INFRA_DIR \
            -e FABRIC_CA_SERVER_LOGLEVEL=debug \
            -e FABRIC_CA_SERVER_CA_NAME=$NODETLSCA_NAME \
            -e FABRIC_CA_SERVER_PORT=$NODETLSCA_PORT \
            -e FABRIC_CA_SERVER_HOME=$CA_SRV_DIR \
            -e FABRIC_CA_SERVER_MSPDIR=$CA_SRV_DIR/msp \
            -e FABRIC_CA_SERVER_LISTENADDRESS=$NODETLSCA_PORT \
            -e FABRIC_CA_SERVER_CSR_HOSTS="$NODETLSCA_NAME,$NODETLSCA_IP,localhost,0.0.0.0" \
            -e FABRIC_CA_SERVER_CSR_CA_PATHLENGTH=0 \
            -e FABRIC_CA_SERVER_TLS_ENABLED=true \
            -e FABRIC_CA_SERVER_TLS_CERTFILE=$CA_SRV_DIR/tls/signcerts/cert.pem \
            -e FABRIC_CA_SERVER_TLS_KEYFILE=$CA_SRV_DIR/tls/keystore/$TLS_CA_KEY \
            -e FABRIC_CA_SERVER_INTERMEDIATE_PARENTSERVER_URL=https://$ROOT_TLSCA_NAME:$ROOT_TLSCA_PASS@$ROOT_TLSCA_NAME:$ROOT_TLSCA_PORT \
            -e FABRIC_CA_SERVER_INTERMEDIATE_PARENTSERVER_CANAME=$ROOT_TLSCA_NAME \
            -e FABRIC_CA_SERVER_INTERMEDIATE_ENROLLMENT_HOSTS=$NODETLSCA_NAME \
            -e FABRIC_CA_SERVER_INTERMEDIATE_ENROLLMENT_PROFILE=ca \
            -e FABRIC_CA_SERVER_INTERMEDIATE_TLS_CERTFILES=$CA_SRV_DIR/tls/tlscacerts/$ROOT_TLS_CA_CERT \
            -e FABRIC_CA_SERVER_CA_CHAINFILE=$CA_SRV_DIR/tls/cacerts/ca-chain.pem \
            -e FABRIC_CA_SERVER_IDEMIX_CUURVE=gurvy.Bn254 \
            -e FABRIC_CA_SERVER_OPERATIONS_LISTENADDRESS=0.0.0.0:$NODETLSCA_OPPORT \
            -e FABRIC_CA_SERVER_OPERATIONS_TLS=true \
            -e FABRIC_CA_SERVER_OPERATIONS_TLS_CERTFILE=$CA_SRV_DIR/tls/signcerts/cert.pem \
            -e FABRIC_CA_SERVER_OPERATIONS_TLS_KEYFILE=$CA_SRV_DIR/tls/keystore/$TLS_CA_KEY \
            -e FABRIC_CA_SERVER_CFG_AFFILIATIONS_ALLOWREMOVE=true \
            -e FABRIC_CA_CLIENT_HOME=$CA_CLI_DIR \
            -e FABRIC_CA_CLIENT_MSPDIR=$CA_CLI_DIR/msp \
            -e FABRIC_CA_CLIENT_TLS_ENABLED=true \
            -e FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_SRV_DIR/tls/tlscacerts/$ROOT_TLS_CA_CERT \
            hyperledger/fabric-ca:latest \
            sh -c "fabric-ca-server start -b $NODETLSCA_NAME:$NODETLSCA_PASS" 

        # Waiting Root-CA startup
        CheckContainer "$NODETLSCA_NAME" "$DOCKER_CONTAINER_WAIT"
        CheckContainerLog "$NODETLSCA_NAME" "Listening on https://0.0.0.0:$NODETLSCA_PORT" "$DOCKER_CONTAINER_WAIT"

        # Installing OpenSSL
        if [[ $NODETLSCA_OPENSSL = true ]]; then
            echo_info "OpenSSL installing..."
            docker exec $NODETLSCA_NAME sh -c 'command -v apk && apk update && apk add --no-cache openssl || (apt-get update && apt-get install -y openssl)'
            CheckOpenSSL "$NODETLSCA_NAME" "$DOCKER_CONTAINER_WAIT"
        fi

        # Enroll Node-TLS
        echo ""
        echo_info "Node-TLS enrolling..."
        docker exec -it $NODETLSCA_NAME fabric-ca-client enroll -u https://$NODETLSCA_NAME:$NODETLSCA_PASS@$NODETLSCA_NAME:$NODETLSCA_PORT

        # Add Affiliation
        echo ""
        echo_info "Affiliation adding..."
        docker exec -it $NODETLSCA_NAME fabric-ca-client affiliation add $AFFILIATION_TLDN -u https://$NODETLSCA_NAME:$NODETLSCA_PASS@$NODETLSCA_NAME:$NODETLSCA_PORT
        docker exec -it $NODETLSCA_NAME fabric-ca-client affiliation add $AFFILIATION_ROOT -u https://$NODETLSCA_NAME:$NODETLSCA_PASS@$NODETLSCA_NAME:$NODETLSCA_PORT
        docker exec -it $NODETLSCA_NAME fabric-ca-client affiliation add $AFFILIATION_NODE -u https://$NODETLSCA_NAME:$NODETLSCA_PASS@$NODETLSCA_NAME:$NODETLSCA_PORT
        # Add Affiliation also to the root
        if [[ -n "$ROOT_TLSCA_NAME" ]]; then
            docker exec -it $ROOT_TLSCA_NAME fabric-ca-client affiliation add $AFFILIATION_NODE -u https://$ROOT_TLSCA_NAME:$ROOT_TLSCA_PASS@$ROOT_TLSCA_NAME:$ROOT_TLSCA_PORT
        fi

        # Remove default affiliation
        echo ""
        echo_info "Default affiliation removing..."
        docker exec -it $NODETLSCA_NAME fabric-ca-client affiliation remove org1 --force -u https://$NODETLSCA_NAME:$NODETLSCA_PASS@$NODETLSCA_NAME:$NODETLSCA_PORT
        docker exec -it $NODETLSCA_NAME fabric-ca-client affiliation remove org2 --force -u https://$NODETLSCA_NAME:$NODETLSCA_PASS@$NODETLSCA_NAME:$NODETLSCA_PORT
        docker exec -it $NODETLSCA_NAME fabric-ca-client affiliation list

    fi
    echo_ok "Node-TLS-CA for $ORGANIZATION started."


    ###############################################################
    # Start Node-ORG-CA
    ###############################################################
    # ROOT_REFERENCE=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Root" "$CONFIG_FILE")
    # ROOT_ORGCA_NAME=$(yq eval ".Intermediates[] | select(.Name == \"$ROOT_REFERENCE\") | .ORG-CA.Name" "$CONFIG_FILE")
    # ROOT_ORGCA_PASS=$(yq eval ".Intermediates[] | select(.Name == \"$ROOT_REFERENCE\") | .ORG-CA.Pass" "$CONFIG_FILE")
    # ROOT_ORGCA_PORT=$(yq eval ".Intermediates[] | select(.Name == \"$ROOT_REFERENCE\") | .ORG-CA.Port" "$CONFIG_FILE")

ROOT_ORGCA_NAME=$(yq eval ".Root.ORG-CA.Name" "$CONFIG_FILE")
ROOT_ORGCA_PORT=$(yq eval ".Root.ORG-CA.Port" "$CONFIG_FILE")
ROOT_ORGCA_PASS=$(yq eval ".Root.ORG-CA.Pass" "$CONFIG_FILE")

    echo ""
    echo_warn "Node-ORG-CA for $ORGANIZATION starting... - see Documentation here: https://hyperledger-fabric-ca.readthedocs.io"

    CA_EXT=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .ORG-CA.Ext" $CONFIG_FILE)
    if ! [[ -n "$CA_EXT" ]]; then

        NODEORGCA_NAME=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .ORG-CA.Name" $CONFIG_FILE)
        NODEORGCA_PASS=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .ORG-CA.Pass" $CONFIG_FILE)
        NODEORGCA_IP=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .ORG-CA.IP" $CONFIG_FILE)
        NODEORGCA_PORT=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .ORG-CA.Port" $CONFIG_FILE)
        NODEORGCA_OPPORT=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .ORG-CA.OpPort" $CONFIG_FILE)
        NODEORGCA_OPENSSL=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .ORG-CA.OpenSSL" $CONFIG_FILE)

        # Enroll Node-ORG
        echo ""
        echo_info "Node-ORG $NODEORGCA_NAME registering and enrolling..."
        docker exec -it $ROOT_ORGCA_NAME fabric-ca-client register -u https://$ROOT_ORGCA_NAME:$ROOT_ORGCA_PASS@$ROOT_ORGCA_NAME:$ROOT_ORGCA_PORT \
            --id.name $NODEORGCA_NAME --id.secret $NODEORGCA_PASS --id.type client --id.affiliation $AFFILIATION_NODE \
            --id.attrs 'hf.IntermediateCA=true'
        docker exec -it $ROOT_ORGCA_NAME fabric-ca-client enroll -u https://$NODEORGCA_NAME:$NODEORGCA_PASS@$ROOT_ORGCA_NAME:$ROOT_ORGCA_PORT --mspdir $INFRA_DIR/$ORGANIZATION/$NODEORGCA_NAME/keys/server/msp \
            --enrollment.attrs "hf.IntermediateCA" \
            --csr.hosts "$NODEORGCA_NAME,$NODEORGCA_IP,localhost,$ROOT_ORGCA_NAME" \
            --enrollment.profile ca
        docker exec -it $ROOT_ORGCA_NAME fabric-ca-client enroll -u https://$NODEORGCA_NAME:$NODEORGCA_PASS@$ROOT_ORGCA_NAME:$ROOT_ORGCA_PORT --mspdir $INFRA_DIR/$ORGANIZATION/$NODEORGCA_NAME/keys/server/tls \
            --enrollment.attrs "hf.IntermediateCA" \
            --csr.hosts "$NODEORGCA_NAME,$NODEORGCA_IP,localhost,$ROOT_ORGCA_NAME" \
            --enrollment.profile tls

        # Initiate Intermediate-ORG-CA
        ROOT_ORG_CA_CERT=$(basename $(ls ${PWD}/infrastructure/$ORGANIZATION/$NODEORGCA_NAME/keys/server/tls/tlscacerts/*.pem | head -n 1))
        ORG_CA_KEY=$(basename $(ls ${PWD}/infrastructure/$ORGANIZATION/$NODEORGCA_NAME/keys/server/tls/keystore/*_sk | head -n 1))
        echo ""
        echo_info "Node-CA $NODEORGCA_NAME starting..."

        docker run -d \
            --name $NODEORGCA_NAME \
            --network $DOCKER_NETWORK_NAME \
            --ip $NODEORGCA_IP \
            $hosts_args \
            --restart=unless-stopped \
            --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/src/fabric_ca_logo.png" \
            -p $NODEORGCA_PORT:$NODEORGCA_PORT \
            -p $NODEORGCA_OPPORT:$NODEORGCA_OPPORT \
            -v ${PWD}/infrastructure/$ORGANIZATION/$NODEORGCA_NAME/keys/server:$CA_SRV_DIR \
            -v ${PWD}/infrastructure/$ORGANIZATION/$NODEORGCA_NAME/keys/client:$CA_CLI_DIR \
            -v ${PWD}/infrastructure/:$INFRA_DIR \
            -e FABRIC_CA_SERVER_LOGLEVEL=debug \
            -e FABRIC_CA_SERVER_CA_NAME=$NODEORGCA_NAME \
            -e FABRIC_CA_SERVER_PORT=$NODEORGCA_PORT \
            -e FABRIC_CA_SERVER_HOME=$CA_SRV_DIR \
            -e FABRIC_CA_SERVER_MSPDIR=$CA_SRV_DIR/msp \
            -e FABRIC_CA_SERVER_LISTENADDRESS=$NODEORGCA_PORT \
            -e FABRIC_CA_SERVER_CSR_HOSTS="$NODEORGCA_NAME,$NODEORGCA_IP,localhost,0.0.0.0" \
            -e FABRIC_CA_SERVER_CSR_CA_PATHLENGTH=0 \
            -e FABRIC_CA_SERVER_TLS_ENABLED=true \
            -e FABRIC_CA_SERVER_TLS_CERTFILE=$CA_SRV_DIR/tls/signcerts/cert.pem \
            -e FABRIC_CA_SERVER_TLS_KEYFILE=$CA_SRV_DIR/tls/keystore/$ORG_CA_KEY \
            -e FABRIC_CA_SERVER_INTERMEDIATE_PARENTSERVER_URL=https://$ROOT_ORGCA_NAME:$ROOT_ORGCA_PASS@$ROOT_ORGCA_NAME:$ROOT_ORGCA_PORT \
            -e FABRIC_CA_SERVER_INTERMEDIATE_PARENTSERVER_CANAME=$ROOT_ORGCA_NAME \
            -e FABRIC_CA_SERVER_INTERMEDIATE_ENROLLMENT_HOSTS=$NODEORGCA_NAME \
            -e FABRIC_CA_SERVER_INTERMEDIATE_ENROLLMENT_PROFILE=ca \
            -e FABRIC_CA_SERVER_INTERMEDIATE_TLS_CERTFILES=$CA_SRV_DIR/tls/tlscacerts/$ROOT_ORG_CA_CERT \
            -e FABRIC_CA_SERVER_CA_CHAINFILE=$CA_SRV_DIR/msp/cacerts/ca-chain.pem \
            -e FABRIC_CA_SERVER_IDEMIX_CUURVE=gurvy.Bn254 \
            -e FABRIC_CA_SERVER_OPERATIONS_LISTENADDRESS=0.0.0.0:$NODEORGCA_OPPORT \
            -e FABRIC_CA_SERVER_OPERATIONS_TLS=true \
            -e FABRIC_CA_SERVER_OPERATIONS_TLS_CERTFILE=$CA_SRV_DIR/tls/signcerts/cert.pem \
            -e FABRIC_CA_SERVER_OPERATIONS_TLS_KEYFILE=$CA_SRV_DIR/tls/keystore/$ORG_CA_KEY \
            -e FABRIC_CA_SERVER_CFG_AFFILIATIONS_ALLOWREMOVE=true \
            -e FABRIC_CA_CLIENT_HOME=$CA_CLI_DIR \
            -e FABRIC_CA_CLIENT_MSPDIR=$CA_CLI_DIR/msp \
            -e FABRIC_CA_CLIENT_TLS_ENABLED=true \
            -e FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_SRV_DIR/tls/tlscacerts/$ROOT_ORG_CA_CERT \
            hyperledger/fabric-ca:latest \
            sh -c "fabric-ca-server start -b $NODEORGCA_NAME:$NODEORGCA_PASS" 

        # Waiting Root-CA startup
        CheckContainer "$NODEORGCA_NAME" "$DOCKER_CONTAINER_WAIT"
        CheckContainerLog "$NODEORGCA_NAME" "Listening on https://0.0.0.0:$NODEORGCA_PORT" "$DOCKER_CONTAINER_WAIT"

        # Installing OpenSSL
        if [[ $NODEORGCA_OPENSSL = true ]]; then
            echo_info "OpenSSL installing..."
            docker exec $NODEORGCA_NAME sh -c 'command -v apk && apk update && apk add --no-cache openssl || (apt-get update && apt-get install -y openssl)'
            CheckOpenSSL "$NODEORGCA_NAME" "$DOCKER_CONTAINER_WAIT"
        fi

        # Enroll Node-ORG
        echo ""
        echo_info "Node-ORG enrolling..."
        docker exec -it $NODEORGCA_NAME fabric-ca-client enroll -u https://$NODEORGCA_NAME:$NODEORGCA_PASS@$NODEORGCA_NAME:$NODEORGCA_PORT

        # Add Affiliation
        echo ""
        echo_info "Affiliation adding..."
        docker exec -it $NODEORGCA_NAME fabric-ca-client affiliation add $AFFILIATION_TLDN -u https://$NODEORGCA_NAME:$NODEORGCA_PASS@$NODEORGCA_NAME:$NODEORGCA_PORT
        docker exec -it $NODEORGCA_NAME fabric-ca-client affiliation add $AFFILIATION_ROOT -u https://$NODEORGCA_NAME:$NODEORGCA_PASS@$NODEORGCA_NAME:$NODEORGCA_PORT
        docker exec -it $NODEORGCA_NAME fabric-ca-client affiliation add $AFFILIATION_INT -u https://$NODEORGCA_NAME:$NODEORGCA_PASS@$NODEORGCA_NAME:$NODEORGCA_PORT
        # Add Affiliation also to the root
        if [[ -n "$ROOT_ORGCA_NAME" ]]; then
            docker exec -it $ROOT_ORGCA_NAME fabric-ca-client affiliation add $AFFILIATION_NODE -u https://$ROOT_ORGCA_NAME:$ROOT_ORGCA_PASS@$ROOT_ORGCA_NAME:$ROOT_ORGCA_PORT
        fi

        # Remove default affiliation
        echo ""
        echo_info "Default affiliation removing..."
        docker exec -it $NODEORGCA_NAME fabric-ca-client affiliation remove org1 --force -u https://$NODEORGCA_NAME:$NODEORGCA_PASS@$NODEORGCA_NAME:$NODEORGCA_PORT
        docker exec -it $NODEORGCA_NAME fabric-ca-client affiliation remove org2 --force -u https://$NODEORGCA_NAME:$NODEORGCA_PASS@$NODEORGCA_NAME:$NODEORGCA_PORT
        docker exec -it $NODEORGCA_NAME fabric-ca-client affiliation list

    fi
    echo_ok "Node-ORG-CA for $ORGANIZATION started."
done


###############################################################
# Last Tasks
###############################################################
chmod -R 777 infrastructure
