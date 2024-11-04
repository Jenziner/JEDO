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

ROOT_NAME=$(yq eval ".Root.Name" "$CONFIG_FILE")
AFFILIATION_ROOT=${ROOT_NAME##*.}.${ROOT_NAME%%.*}

ROOT_TLSCA_NAME=$(yq eval ".Root.TLS-CA.Name" "$CONFIG_FILE")
ROOT_TLSCA_PASS=$(yq eval ".Root.TLS-CA.Pass" "$CONFIG_FILE")
ROOT_TLSCA_PORT=$(yq eval ".Root.TLS-CA.Port" "$CONFIG_FILE")

ROOT_ORGCA_NAME=$(yq eval ".Root.ORG-CA.Name" "$CONFIG_FILE")
ROOT_ORGCA_PASS=$(yq eval ".Root.ORG-CA.Pass" "$CONFIG_FILE")
ROOT_ORGCA_PORT=$(yq eval ".Root.ORG-CA.Port" "$CONFIG_FILE")

get_hosts

INTERMEDIATS=$(yq e ".Intermediates[].Name" $CONFIG_FILE)
for INTERMEDIATE in $INTERMEDIATS; do
    ###############################################################
    # Start Intermediate-TLS-CA
    ###############################################################
    INTERTLSCA_NAME=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .TLS-CA.Name" $CONFIG_FILE)
    INTERTLSCA_PASS=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .TLS-CA.Pass" $CONFIG_FILE)
    INTERTLSCA_IP=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .TLS-CA.IP" $CONFIG_FILE)
    INTERTLSCA_PORT=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .TLS-CA.Port" $CONFIG_FILE)
    INTERTLSCA_OPPORT=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .TLS-CA.OpPort" $CONFIG_FILE)
    INTERTLSCA_OPENSSL=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .TLS-CA.OpenSSL" $CONFIG_FILE)

    # skip if not specified
    if [[ -n "$INTERTLSCA_NAME" ]]; then
        echo ""
        echo_warn "Intermediate-TLS-CA for $INTERMEDIATE starting... - see Documentation here: https://hyperledger-fabric-ca.readthedocs.io"

        # Add Affiliation
        echo ""
        echo_info "Affiliation adding..."
        AFFILIATION_INT=$AFFILIATION_ROOT.${INTERMEDIATE,,}
        docker exec -it $ROOT_TLSCA_NAME fabric-ca-client affiliation add $AFFILIATION_INT -u https://$ROOT_TLSCA_NAME:$ROOT_TLSCA_PASS@$ROOT_TLSCA_NAME:$ROOT_TLSCA_PORT
        docker exec -it $ROOT_TLSCA_NAME fabric-ca-client affiliation list

        # Enroll Intermediate-TLS
        echo ""
        echo_info "Intermediate-TLS $INTERTLSCA_NAME registering and enrolling..."
        docker exec -it $ROOT_TLSCA_NAME fabric-ca-client register -u https://$ROOT_TLSCA_NAME:$ROOT_TLSCA_PASS@$ROOT_TLSCA_NAME:$ROOT_TLSCA_PORT \
            --id.name $INTERTLSCA_NAME --id.secret $INTERTLSCA_PASS --id.type client --id.affiliation $AFFILIATION_ROOT \
            --id.attrs 'hf.IntermediateCA=true'
        docker exec -it $ROOT_TLSCA_NAME fabric-ca-client enroll -u https://$INTERTLSCA_NAME:$INTERTLSCA_PASS@$ROOT_TLSCA_NAME:$ROOT_TLSCA_PORT --mspdir $INFRA_DIR/_intermediate/$INTERTLSCA_NAME/keys/server/msp \
            --enrollment.attrs "hf.IntermediateCA" \
            --csr.hosts "$INTERTLSCA_NAME,$INTERTLSCA_IP,localhost,0.0.0.0,$ROOT_TLSCA_NAME" \
            --enrollment.profile ca
        docker exec -it $ROOT_TLSCA_NAME fabric-ca-client enroll -u https://$INTERTLSCA_NAME:$INTERTLSCA_PASS@$ROOT_TLSCA_NAME:$ROOT_TLSCA_PORT --mspdir $INFRA_DIR/_intermediate/$INTERTLSCA_NAME/keys/server/tls \
            --enrollment.attrs "hf.IntermediateCA" \
            --csr.hosts "$INTERTLSCA_NAME,$INTERTLSCA_IP,localhost,0.0.0.0,$ROOT_TLSCA_NAME" \
            --enrollment.profile tls


        # Initiate Intermediate-TLS-CA
        ROOT_TLS_CA_CERT=$(basename $(ls ${PWD}/infrastructure/_intermediate/$INTERTLSCA_NAME/keys/server/tls/tlscacerts/*.pem | head -n 1))
        TLS_CA_KEY=$(basename $(ls ${PWD}/infrastructure/_intermediate/$INTERTLSCA_NAME/keys/server/tls/keystore/*_sk | head -n 1))
        echo ""
        echo_info "Intermediate-CA $INTERTLSCA_NAME starting..."

        docker run -d \
            --name $INTERTLSCA_NAME \
            --network $DOCKER_NETWORK_NAME \
            --ip $INTERTLSCA_IP \
            $hosts_args \
            --restart=unless-stopped \
            --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/src/fabric_ca_logo.png" \
            -p $INTERTLSCA_PORT:$INTERTLSCA_PORT \
            -p $INTERTLSCA_OPPORT:$INTERTLSCA_OPPORT \
            -v ${PWD}/infrastructure/_intermediate/$INTERTLSCA_NAME/keys/server:$CA_SRV_DIR \
            -v ${PWD}/infrastructure/_intermediate/$INTERTLSCA_NAME/keys/client:$CA_CLI_DIR \
            -v ${PWD}/infrastructure/:$INFRA_DIR \
            -e FABRIC_CA_SERVER_LOGLEVEL=debug \
            -e FABRIC_CA_SERVER_CA_NAME=$INTERTLSCA_NAME \
            -e FABRIC_CA_SERVER_PORT=$INTERTLSCA_PORT \
            -e FABRIC_CA_SERVER_HOME=$CA_SRV_DIR \
            -e FABRIC_CA_SERVER_MSPDIR=$CA_SRV_DIR/msp \
            -e FABRIC_CA_SERVER_LISTENADDRESS=$INTERTLSCA_PORT \
            -e FABRIC_CA_SERVER_CSR_CA_PATHLENGTH=1 \
            -e FABRIC_CA_SERVER_SIGNING.PROFILES.CA.CACONSTRAINT.MAXPATHLEN=1 \
            -e FABRIC_CA_SERVER_SIGNING.PROFILES.CA.CACONSTRAINT.MAXPATHLENZERO=false \
            -e FABRIC_CA_SERVER_TLS_ENABLED=true \
            -e FABRIC_CA_SERVER_TLS_CERTFILE=$CA_SRV_DIR/tls/signcerts/cert.pem \
            -e FABRIC_CA_SERVER_TLS_KEYFILE=$CA_SRV_DIR/tls/keystore/$TLS_CA_KEY \
            -e FABRIC_CA_SERVER_INTERMEDIATE_PARENTSERVER_URL=https://$ROOT_TLSCA_NAME:$ROOT_TLSCA_PASS@$ROOT_TLSCA_NAME:$ROOT_TLSCA_PORT \
            -e FABRIC_CA_SERVER_INTERMEDIATE_PARENTSERVER_CANAME=$ROOT_TLSCA_NAME \
            -e FABRIC_CA_SERVER_INTERMEDIATE_ENROLLMENT_HOSTS=$INTERTLSCA_NAME \
            -e FABRIC_CA_SERVER_INTERMEDIATE_ENROLLMENT_PROFILE=ca \
            -e FABRIC_CA_SERVER_INTERMEDIATE_TLS_CERTFILES=$CA_SRV_DIR/tls/tlscacerts/$ROOT_TLS_CA_CERT \
            -e FABRIC_CA_SERVER_CA_CHAINFILE=$CA_SRV_DIR/tls/cacerts/ca-chain.pem \
            -e FABRIC_CA_SERVER_IDEMIX_CUURVE=gurvy.Bn254 \
            -e FABRIC_CA_SERVER_OPERATIONS_LISTENADDRESS=0.0.0.0:$INTERTLSCA_OPPORT \
            -e FABRIC_CA_SERVER_OPERATIONS_TLS=true \
            -e FABRIC_CA_SERVER_OPERATIONS_TLS_CERTFILE=$CA_SRV_DIR/tls/signcerts/cert.pem \
            -e FABRIC_CA_SERVER_OPERATIONS_TLS_KEYFILE=$CA_SRV_DIR/tls/keystore/$TLS_CA_KEY \
            -e FABRIC_CA_SERVER_CFG_AFFILIATIONS_ALLOWREMOVE=true \
            -e FABRIC_CA_CLIENT_HOME=$CA_CLI_DIR \
            -e FABRIC_CA_CLIENT_MSPDIR=$CA_CLI_DIR/msp \
            -e FABRIC_CA_CLIENT_TLS_ENABLED=true \
            -e FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_SRV_DIR/tls/tlscacerts/$ROOT_TLS_CA_CERT \
            hyperledger/fabric-ca:latest \
            sh -c "fabric-ca-server start -b $INTERTLSCA_NAME:$INTERTLSCA_PASS" 

        # Waiting Root-CA startup
        CheckContainer "$INTERTLSCA_NAME" "$DOCKER_CONTAINER_WAIT"
        CheckContainerLog "$INTERTLSCA_NAME" "Listening on https://0.0.0.0:$INTERTLSCA_PORT" "$DOCKER_CONTAINER_WAIT"

        # Installing OpenSSL
        if [[ $INTERTLSCA_OPENSSL = true ]]; then
            echo_info "OpenSSL installing..."
            docker exec $INTERTLSCA_NAME sh -c 'command -v apk && apk update && apk add --no-cache openssl || (apt-get update && apt-get install -y openssl)'
            CheckOpenSSL "$INTERTLSCA_NAME" "$DOCKER_CONTAINER_WAIT"
        fi

        # Enroll Intermediate-TLS
        echo ""
        echo_info "Intermediate-TLS enrolling..."
        docker exec -it $INTERTLSCA_NAME fabric-ca-client enroll -u https://$INTERTLSCA_NAME:$INTERTLSCA_PASS@$INTERTLSCA_NAME:$INTERTLSCA_PORT

        # Add Affiliation
        echo ""
        echo_info "Affiliation adding..."
        ROOT_NAME=$(yq eval ".Root.Name" "$CONFIG_FILE")
        DN="${ROOT_NAME%%.*}"   # Alles vor dem ersten Punkt
        TLDN="${ROOT_NAME##*.}" 

        AFFILIATION_ROOT=$TLDN
        docker exec -it $INTERTLSCA_NAME fabric-ca-client affiliation add $AFFILIATION_ROOT -u https://$INTERTLSCA_NAME:$INTERTLSCA_PASS@$INTERTLSCA_NAME:$INTERTLSCA_PORT
        AFFILIATION_ROOT=$TLDN.$DN
        docker exec -it $INTERTLSCA_NAME fabric-ca-client affiliation add $AFFILIATION_ROOT -u https://$INTERTLSCA_NAME:$INTERTLSCA_PASS@$INTERTLSCA_NAME:$INTERTLSCA_PORT
        AFFILIATION_INT=$AFFILIATION_ROOT.${INTERMEDIATE,,}
        docker exec -it $INTERTLSCA_NAME fabric-ca-client affiliation add $AFFILIATION_INT -u https://$INTERTLSCA_NAME:$INTERTLSCA_PASS@$INTERTLSCA_NAME:$INTERTLSCA_PORT

        # Remove default affiliation
        echo ""
        echo_info "Default affiliation removing..."
        docker exec -it $INTERTLSCA_NAME fabric-ca-client affiliation remove org1 --force -u https://$INTERTLSCA_NAME:$INTERTLSCA_PASS@$INTERTLSCA_NAME:$INTERTLSCA_PORT
        docker exec -it $INTERTLSCA_NAME fabric-ca-client affiliation remove org2 --force -u https://$INTERTLSCA_NAME:$INTERTLSCA_PASS@$INTERTLSCA_NAME:$INTERTLSCA_PORT
        docker exec -it $INTERTLSCA_NAME fabric-ca-client affiliation list

        echo_ok "Intermediate-TLS-CA $INTERTLSCA_NAME started."

        chmod -R 777 infrastructure
    fi

    ###############################################################
    # Start Intermediate-ORG-CA
    ###############################################################
    INTERORGCA_NAME=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .ORG-CA.Name" $CONFIG_FILE)
    INTERORGCA_PASS=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .ORG-CA.Pass" $CONFIG_FILE)
    INTERORGCA_IP=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .ORG-CA.IP" $CONFIG_FILE)
    INTERORGCA_PORT=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .ORG-CA.Port" $CONFIG_FILE)
    INTERORGCA_OPPORT=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .ORG-CA.OpPort" $CONFIG_FILE)
    INTERORGCA_OPENSSL=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .ORG-CA.OpenSSL" $CONFIG_FILE)

    # skip if not specified
    if [[ -n "$INTERTLSCA_NAME" ]]; then
        echo ""
        echo_warn "Intermediate-ORG-CA for $INTERMEDIATE starting... - see Documentation here: https://hyperledger-fabric-ca.readthedocs.io"

        # Add Affiliation
        echo ""
        echo_info "Affiliation adding..."
        AFFILIATION_INT=$AFFILIATION_ROOT.${INTERMEDIATE,,}
        docker exec -it $ROOT_ORGCA_NAME fabric-ca-client affiliation add $AFFILIATION_INT -u https://$ROOT_ORGCA_NAME:$ROOT_ORGCA_PASS@$ROOT_ORGCA_NAME:$ROOT_ORGCA_PORT
        docker exec -it $ROOT_ORGCA_NAME fabric-ca-client affiliation list

        # Enroll Intermediate-ORG
        echo ""
        echo_info "Intermediate-ORG $INTERORGCA_NAME registering and enrolling..."
        docker exec -it $ROOT_ORGCA_NAME fabric-ca-client register -u https://$ROOT_ORGCA_NAME:$ROOT_ORGCA_PASS@$ROOT_ORGCA_NAME:$ROOT_ORGCA_PORT \
            --id.name $INTERORGCA_NAME --id.secret $INTERORGCA_PASS --id.type client --id.affiliation $AFFILIATION_ROOT \
            --id.attrs 'hf.IntermediateCA=true'
        docker exec -it $ROOT_ORGCA_NAME fabric-ca-client enroll -u https://$INTERORGCA_NAME:$INTERORGCA_PASS@$ROOT_ORGCA_NAME:$ROOT_ORGCA_PORT --mspdir $INFRA_DIR/_intermediate/$INTERORGCA_NAME/keys/server/msp \
            --enrollment.attrs "hf.IntermediateCA" \
            --csr.hosts "$INTERORGCA_NAME,$INTERORGCA_IP,localhost,0.0.0.0,$ROOT_ORGCA_NAME" \
            --enrollment.profile ca
        docker exec -it $ROOT_ORGCA_NAME fabric-ca-client enroll -u https://$INTERORGCA_NAME:$INTERORGCA_PASS@$ROOT_ORGCA_NAME:$ROOT_ORGCA_PORT --mspdir $INFRA_DIR/_intermediate/$INTERORGCA_NAME/keys/server/tls \
            --enrollment.attrs "hf.IntermediateCA" \
            --csr.hosts "$INTERORGCA_NAME,$INTERORGCA_IP,localhost,0.0.0.0,$ROOT_ORGCA_NAME" \
            --enrollment.profile tls


        # Initiate Intermediate-ORG-CA
        ROOT_ORG_CA_CERT=$(basename $(ls ${PWD}/infrastructure/_intermediate/$INTERORGCA_NAME/keys/server/tls/tlscacerts/*.pem | head -n 1))
        ORG_CA_KEY=$(basename $(ls ${PWD}/infrastructure/_intermediate/$INTERORGCA_NAME/keys/server/tls/keystore/*_sk | head -n 1))
        echo ""
        echo_info "Intermediate-CA $INTERORGCA_NAME starting..."

        docker run -d \
            --name $INTERORGCA_NAME \
            --network $DOCKER_NETWORK_NAME \
            --ip $INTERORGCA_IP \
            $hosts_args \
            --restart=unless-stopped \
            --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/src/fabric_ca_logo.png" \
            -p $INTERORGCA_PORT:$INTERORGCA_PORT \
            -p $INTERORGCA_OPPORT:$INTERORGCA_OPPORT \
            -v ${PWD}/infrastructure/_intermediate/$INTERORGCA_NAME/keys/server:$CA_SRV_DIR \
            -v ${PWD}/infrastructure/_intermediate/$INTERORGCA_NAME/keys/client:$CA_CLI_DIR \
            -v ${PWD}/infrastructure/:$INFRA_DIR \
            -e FABRIC_CA_SERVER_LOGLEVEL=debug \
            -e FABRIC_CA_SERVER_CA_NAME=$INTERORGCA_NAME \
            -e FABRIC_CA_SERVER_PORT=$INTERORGCA_PORT \
            -e FABRIC_CA_SERVER_HOME=$CA_SRV_DIR \
            -e FABRIC_CA_SERVER_MSPDIR=$CA_SRV_DIR/msp \
            -e FABRIC_CA_SERVER_LISTENADDRESS=$INTERORGCA_PORT \
            -e FABRIC_CA_SERVER_TLS_ENABLED=true \
            -e FABRIC_CA_SERVER_TLS_CERTFILE=$CA_SRV_DIR/tls/signcerts/cert.pem \
            -e FABRIC_CA_SERVER_TLS_KEYFILE=$CA_SRV_DIR/tls/keystore/$ORG_CA_KEY \
            -e FABRIC_CA_SERVER_INTERMEDIATE_PARENTSERVER_URL=https://$ROOT_ORGCA_NAME:$ROOT_ORGCA_PASS@$ROOT_ORGCA_NAME:$ROOT_ORGCA_PORT \
            -e FABRIC_CA_SERVER_INTERMEDIATE_PARENTSERVER_CANAME=$ROOT_ORGCA_NAME \
            -e FABRIC_CA_SERVER_INTERMEDIATE_ENROLLMENT_HOSTS=$INTERORGCA_NAME \
            -e FABRIC_CA_SERVER_INTERMEDIATE_ENROLLMENT_PROFILE=ca \
            -e FABRIC_CA_SERVER_INTERMEDIATE_TLS_CERTFILES=$CA_SRV_DIR/tls/tlscacerts/$ROOT_ORG_CA_CERT \
            -e FABRIC_CA_SERVER_CA_CHAINFILE=$CA_SRV_DIR/msp/cacerts/ca-chain.pem \
            -e FABRIC_CA_SERVER_IDEMIX_CUURVE=gurvy.Bn254 \
            -e FABRIC_CA_SERVER_OPERATIONS_LISTENADDRESS=0.0.0.0:$INTERORGCA_OPPORT \
            -e FABRIC_CA_SERVER_OPERATIONS_TLS=true \
            -e FABRIC_CA_SERVER_OPERATIONS_TLS_CERTFILE=$CA_SRV_DIR/tls/signcerts/cert.pem \
            -e FABRIC_CA_SERVER_OPERATIONS_TLS_KEYFILE=$CA_SRV_DIR/tls/keystore/$ORG_CA_KEY \
            -e FABRIC_CA_SERVER_CFG_AFFILIATIONS_ALLOWREMOVE=true \
            -e FABRIC_CA_CLIENT_HOME=$CA_CLI_DIR \
            -e FABRIC_CA_CLIENT_MSPDIR=$CA_CLI_DIR/msp \
            -e FABRIC_CA_CLIENT_TLS_ENABLED=true \
            -e FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_SRV_DIR/tls/tlscacerts/$ROOT_ORG_CA_CERT \
            hyperledger/fabric-ca:latest \
            sh -c "fabric-ca-server start -b $INTERORGCA_NAME:$INTERORGCA_PASS" 

        # Waiting Root-CA startup
        CheckContainer "$INTERORGCA_NAME" "$DOCKER_CONTAINER_WAIT"
        CheckContainerLog "$INTERORGCA_NAME" "Listening on https://0.0.0.0:$INTERORGCA_PORT" "$DOCKER_CONTAINER_WAIT"

        # Installing OpenSSL
        if [[ $INTERORGCA_OPENSSL = true ]]; then
            echo_info "OpenSSL installing..."
            docker exec $INTERORGCA_NAME sh -c 'command -v apk && apk update && apk add --no-cache openssl || (apt-get update && apt-get install -y openssl)'
            CheckOpenSSL "$INTERORGCA_NAME" "$DOCKER_CONTAINER_WAIT"
        fi

        # Enroll Intermediate-ORG
        echo ""
        echo_info "Intermediate-ORG enrolling..."
        docker exec -it $INTERORGCA_NAME fabric-ca-client enroll -u https://$INTERORGCA_NAME:$INTERORGCA_PASS@$INTERORGCA_NAME:$INTERORGCA_PORT

        # Add Affiliation
        echo ""
        echo_info "Affiliation adding..."
        ROOT_NAME=$(yq eval ".Root.Name" "$CONFIG_FILE")
        DN="${ROOT_NAME%%.*}"   # Alles vor dem ersten Punkt
        TLDN="${ROOT_NAME##*.}" 

        AFFILIATION_ROOT=$TLDN
        docker exec -it $INTERORGCA_NAME fabric-ca-client affiliation add $AFFILIATION_ROOT -u https://$INTERORGCA_NAME:$INTERORGCA_PASS@$INTERORGCA_NAME:$INTERORGCA_PORT
        AFFILIATION_ROOT=$TLDN.$DN
        docker exec -it $INTERORGCA_NAME fabric-ca-client affiliation add $AFFILIATION_ROOT -u https://$INTERORGCA_NAME:$INTERORGCA_PASS@$INTERORGCA_NAME:$INTERORGCA_PORT
        AFFILIATION_INT=$AFFILIATION_ROOT.${INTERMEDIATE,,}
        docker exec -it $INTERORGCA_NAME fabric-ca-client affiliation add $AFFILIATION_INT -u https://$INTERORGCA_NAME:$INTERORGCA_PASS@$INTERORGCA_NAME:$INTERORGCA_PORT

        # Remove default affiliation
        echo ""
        echo_info "Default affiliation removing..."
        docker exec -it $INTERORGCA_NAME fabric-ca-client affiliation remove org1 --force -u https://$INTERORGCA_NAME:$INTERORGCA_PASS@$INTERORGCA_NAME:$INTERORGCA_PORT
        docker exec -it $INTERORGCA_NAME fabric-ca-client affiliation remove org2 --force -u https://$INTERORGCA_NAME:$INTERORGCA_PASS@$INTERORGCA_NAME:$INTERORGCA_PORT
        docker exec -it $INTERORGCA_NAME fabric-ca-client affiliation list

        echo_ok "Intermediate-ORG-CA $INTERORGCA_NAME started."

        chmod -R 777 infrastructure
    fi
done


###############################################################
# Last Tasks
###############################################################
