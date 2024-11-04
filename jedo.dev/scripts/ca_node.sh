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
    ROOT_NAME=$(yq eval ".Root.Name" "$CONFIG_FILE")
    DN="${ROOT_NAME%%.*}"   # Alles vor dem ersten Punkt
    AFFILIATION_TLDN="${ROOT_NAME##*.}" 
    AFFILIATION_ROOT=$AFFILIATION_TLDN.$DN
    AFFILIATION_NODE=$AFFILIATION_ROOT.${ORGANIZATION,,}


    ###############################################################
    # Start Node-TLS-CA
    ###############################################################
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

        # Initiate Intermediate-TLS-CA
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
            -e FABRIC_CA_SERVER_IDEMIX_CUURVE=gurvy.Bn254 \
            -e FABRIC_CA_SERVER_CFG_AFFILIATIONS_ALLOWREMOVE=true \
            -e FABRIC_CA_SERVER_TLS_ENABLED=true \
            -e FABRIC_CA_CLIENT_HOME=$CA_CLI_DIR \
            -e FABRIC_CA_CLIENT_MSPDIR=$CA_CLI_DIR/msp \
            -e FABRIC_CA_CLIENT_TLS_ENABLED=true \
            -e FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_SRV_DIR/tls-cert.pem \
            hyperledger/fabric-ca:latest \
            sh -c "fabric-ca-server start -b $NODETLSCA_NAME:$NODETLSCA_PASS" 

        # Waiting Node-TLS startup
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

        # Remove default affiliation
        echo ""
        echo_info "Default affiliation removing..."
        docker exec -it $NODETLSCA_NAME fabric-ca-client affiliation remove org1 --force -u https://$NODETLSCA_NAME:$NODETLSCA_PASS@$NODETLSCA_NAME:$NODETLSCA_PORT
        docker exec -it $NODETLSCA_NAME fabric-ca-client affiliation remove org2 --force -u https://$NODETLSCA_NAME:$NODETLSCA_PASS@$NODETLSCA_NAME:$NODETLSCA_PORT
        docker exec -it $NODETLSCA_NAME fabric-ca-client affiliation list

    fi

    # Workarounds
    cp ${PWD}/infrastructure/$ORGANIZATION/$NODETLSCA_NAME/keys/server/ca-cert.pem ${PWD}/infrastructure/$ORGANIZATION/$NODETLSCA_NAME/keys/server/msp/cacerts/

    echo_ok "Node-TLS-CA for $ORGANIZATION started."


    ###############################################################
    # Start Node-ORG-CA
    ###############################################################
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

        # Initiate Intermediate-ORG-CA
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
            -e FABRIC_CA_SERVER_CSR_CN=$NODEORGCA_NAME \
            -e FABRIC_CA_SERVER_CSR_HOSTS="$NODEORGCA_NAME,$NODEORGCA_IP,localhost,0.0.0.0" \
            -e FABRIC_CA_SERVER_CSR_CA_PATHLENGTH=0 \
            -e FABRIC_CA_SERVER_IDEMIX_CUURVE=gurvy.Bn254 \
            -e FABRIC_CA_SERVER_CFG_AFFILIATIONS_ALLOWREMOVE=true \
            -e FABRIC_CA_SERVER_TLS_ENABLED=true \
            -e FABRIC_CA_CLIENT_HOME=$CA_CLI_DIR \
            -e FABRIC_CA_CLIENT_MSPDIR=$CA_CLI_DIR/msp \
            -e FABRIC_CA_CLIENT_TLS_ENABLED=true \
            -e FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_SRV_DIR/tls-cert.pem \
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
        docker exec -it $NODEORGCA_NAME fabric-ca-client affiliation add $AFFILIATION_NODE -u https://$NODEORGCA_NAME:$NODEORGCA_PASS@$NODEORGCA_NAME:$NODEORGCA_PORT

        # Remove default affiliation
        echo ""
        echo_info "Default affiliation removing..."
        docker exec -it $NODEORGCA_NAME fabric-ca-client affiliation remove org1 --force -u https://$NODEORGCA_NAME:$NODEORGCA_PASS@$NODEORGCA_NAME:$NODEORGCA_PORT
        docker exec -it $NODEORGCA_NAME fabric-ca-client affiliation remove org2 --force -u https://$NODEORGCA_NAME:$NODEORGCA_PASS@$NODEORGCA_NAME:$NODEORGCA_PORT
        docker exec -it $NODEORGCA_NAME fabric-ca-client affiliation list

    fi

    # Workarounds
    cp ${PWD}/infrastructure/$ORGANIZATION/$NODEORGCA_NAME/keys/server/ca-cert.pem ${PWD}/infrastructure/$ORGANIZATION/$NODEORGCA_NAME/keys/server/msp/cacerts/

    echo_ok "Node-ORG-CA for $ORGANIZATION started."


    ###############################################################
    # Enroll Operators
    ###############################################################
    OPERATORS=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Operators[].Name" $CONFIG_FILE)
    for OPERATOR in $OPERATORS; do
        OPERATOR_NAME=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Operators[] | select(.Name == \"$OPERATOR\") | .Name" $CONFIG_FILE)
        OPERATOR_PASS=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Operators[] | select(.Name == \"$OPERATOR\") | .Pass" $CONFIG_FILE)
        OPERATOR_TYPE=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Operators[] | select(.Name == \"$OPERATOR\") | .Type" $CONFIG_FILE)
        OPERATOR_SUBJECT=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Operators[] | select(.Name == \"$OPERATOR\") | .Subject" $CONFIG_FILE)

        # Extract fields from subject
        C=$(echo "$OPERATOR_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
        ST=$(echo "$OPERATOR_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
        L=$(echo "$OPERATOR_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')
        CN=$(echo "$OPERATOR_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^CN=/) {sub(/^CN=/, "", $i); print $i}}')
        CSR_NAMES=$(echo "$OPERATOR_SUBJECT" | sed 's/,CN=[^,]*//')


        echo ""
        echo_info "Operator $OPERATOR registering and enrolling..."
        docker exec -it $NODEORGCA_NAME fabric-ca-client register -u https://$NODEORGCA_NAME:$NODEORGCA_PASS@$NODEORGCA_NAME:$NODEORGCA_PORT \
            --id.name $OPERATOR_NAME --id.secret $OPERATOR_PASS --id.type $OPERATOR_TYPE --id.affiliation $AFFILIATION_NODE \
            --id.attrs 'hf.Registrar.Roles=admin,hf.Registrar.Attributes=*,hf.Revoker=true,hf.AffiliationMgr=true,hf.GenCRL=true'
        docker exec -it $NODEORGCA_NAME fabric-ca-client enroll -u https://$OPERATOR_NAME:$OPERATOR_PASS@$NODEORGCA_NAME:$NODEORGCA_PORT --mspdir $INFRA_DIR/$ORGANIZATION/_Operators/$OPERATOR_NAME/keys/msp \
            --enrollment.attrs "hf.Registrar.Roles,hf.Registrar.Attributes,hf.Revoker,hf.AffiliationMgr,hf.GenCRL" \
            --csr.cn $CN --csr.names "$CSR_NAMES"

        docker exec -it $NODETLSCA_NAME fabric-ca-client register -u https://$NODETLSCA_NAME:$NODETLSCA_PASS@$NODETLSCA_NAME:$NODETLSCA_PORT \
            --id.name $OPERATOR_NAME --id.secret $OPERATOR_PASS --id.type $OPERATOR_TYPE --id.affiliation $AFFILIATION_NODE
        docker exec -it $NODETLSCA_NAME fabric-ca-client enroll -u https://$OPERATOR_NAME:$OPERATOR_PASS@$NODETLSCA_NAME:$NODETLSCA_PORT --mspdir $INFRA_DIR/$ORGANIZATION/_Operators/$OPERATOR_NAME/keys/tls \
            --csr.cn $CN --csr.names "$CSR_NAMES" \
            --enrollment.profile tls

        # Generating NodeOUs-File
        echo ""
        echo_info "NodeOUs-File writing..."
        CA_CERT_FILE=$(ls ${PWD}/infrastructure/$ORGANIZATION/_Operators/$OPERATOR_NAME/keys/msp/cacerts/*.pem)
        cat <<EOF > ${PWD}/infrastructure/$ORGANIZATION/_Operators/$OPERATOR_NAME/keys/msp/config.yaml
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: orderer
EOF


    done
done


###############################################################
# Last Tasks
###############################################################
chmod -R 777 infrastructure
