###############################################################
#!/bin/bash
#
# This script starts Hyperledger Fabric Orderer
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
FABRIC_BIN_PATH=$(yq eval '.Fabric.Path' "$CONFIG_FILE")
DOCKER_UNRAID=$(yq eval '.Docker.Unraid' $CONFIG_FILE)
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $CONFIG_FILE)

INFRA_DIR=/etc/hyperledger/infrastructure

ROOT_NAME=$(yq eval ".Root.Name" "$CONFIG_FILE")
AFFILIATION_ROOT=${ROOT_NAME##*.}.${ROOT_NAME%%.*}

get_hosts

export FABRIC_CFG_PATH=${PWD}/infrastructure
ORGANIZATIONS=$(yq e ".Organizations[].Name" $CONFIG_FILE)

for ORGANIZATION in $ORGANIZATIONS; do
    echo ""
    echo_warn "Orderers for $ORGANIZATION enrolling..."
    AFFILIATION_NODE=$AFFILIATION_ROOT.${ORGANIZATION,,}

    # Get responsible TLS-CA
    TLSCA_EXT=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .TLS-CA.Ext" $CONFIG_FILE)
    if [[ -n "$TLSCA_EXT" ]]; then
        TLSCA_NAME=$(yq eval ".. | select(has(\"TLS-CA\")) | .TLS-CA | select(.Name == \"$TLSCA_EXT\") | .Name" "$CONFIG_FILE")
        TLSCA_PASS=$(yq eval ".. | select(has(\"TLS-CA\")) | .TLS-CA | select(.Name == \"$TLSCA_EXT\") | .Pass" "$CONFIG_FILE")
        TLSCA_PORT=$(yq eval ".. | select(has(\"TLS-CA\")) | .TLS-CA | select(.Name == \"$TLSCA_EXT\") | .Port" "$CONFIG_FILE")
    else
        TLSCA_NAME=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .TLS-CA.Name" $CONFIG_FILE)
        TLSCA_PASS=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .TLS-CA.Pass" $CONFIG_FILE)
        TLSCA_PORT=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .TLS-CA.Port" $CONFIG_FILE)
    fi

    # Get responsible ORG-CA
    ORGCA_EXT=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .ORG-CA.Ext" $CONFIG_FILE)
    if [[ -n "$ORGCA_EXT" ]]; then
        ORGCA_NAME=$(yq eval ".. | select(has(\"ORG-CA\")) | .ORG-CA | select(.Name == \"$ORGCA_EXT\") | .Name" "$CONFIG_FILE")
        ORGCA_PASS=$(yq eval ".. | select(has(\"ORG-CA\")) | .ORG-CA | select(.Name == \"$ORGCA_EXT\") | .Pass" "$CONFIG_FILE")
        ORGCA_PORT=$(yq eval ".. | select(has(\"ORG-CA\")) | .ORG-CA | select(.Name == \"$ORGCA_EXT\") | .Port" "$CONFIG_FILE")
    else
        ORGCA_NAME=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .ORG-CA.Name" $CONFIG_FILE)
        ORGCA_PASS=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .ORG-CA.Pass" $CONFIG_FILE)
        ORGCA_PORT=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .ORG-CA.Port" $CONFIG_FILE)
    fi

    ORDERERS=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Name" $CONFIG_FILE)
    for ORDERER in $ORDERERS; do
        ###############################################################
        # Enroll orderer
        ###############################################################
        ORDERER_NAME=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Name" $CONFIG_FILE)
        ORDERER_PASS=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Pass" $CONFIG_FILE)
        ORDERER_IP=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[] | select(.Name == \"$ORDERER\") | .IP" $CONFIG_FILE)
        ORDERER_SUBJECT=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Subject" $CONFIG_FILE)

        # Extract fields from subject
        C=$(echo "$ORDERER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
        ST=$(echo "$ORDERER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
        L=$(echo "$ORDERER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')
        CN=$(echo "$ORDERER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^CN=/) {sub(/^CN=/, "", $i); print $i}}')
        CSR_NAMES=$(echo "$ORDERER_SUBJECT" | sed 's/,CN=[^,]*//')

        echo ""
        echo_info "$ORDERER_NAME registering and enrolling..."
        # Register and enroll ORG orderer
        docker exec -it $ORGCA_NAME fabric-ca-client register -u https://$ORGCA_NAME:$ORGCA_PASS@$ORGCA_NAME:$ORGCA_PORT \
            --id.name $ORDERER_NAME --id.secret $ORDERER_PASS --id.type orderer --id.affiliation $AFFILIATION_NODE
        docker exec -it $ORGCA_NAME fabric-ca-client enroll -u https://$ORDERER_NAME:$ORDERER_PASS@$ORGCA_NAME:$ORGCA_PORT --mspdir $INFRA_DIR/$ORGANIZATION/$ORDERER_NAME/keys/server/msp \
            --csr.cn $CN --csr.names "$CSR_NAMES"

        # Register and enroll TLS orderer
        docker exec -it $TLSCA_NAME fabric-ca-client register -u https://$TLSCA_NAME:$TLSCA_PASS@$TLSCA_NAME:$TLSCA_PORT \
            --id.name $ORDERER_NAME --id.secret $ORDERER_PASS --id.type orderer --id.affiliation $AFFILIATION_NODE
        docker exec -it $TLSCA_NAME fabric-ca-client enroll -u https://$ORDERER_NAME:$ORDERER_PASS@$TLSCA_NAME:$TLSCA_PORT --mspdir $INFRA_DIR/$ORGANIZATION/$ORDERER_NAME/keys/server/tls \
            --csr.cn $CN --csr.names "$CSR_NAMES" --csr.hosts "$ORDERER_NAME,$ORDERER_IP,$DOCKER_UNRAID" \
            --enrollment.profile tls 

        # Generating NodeOUs-File
        echo ""
        echo_info "NodeOUs-File writing..."
        CA_CERT_FILE=$(ls ${PWD}/infrastructure/$ORGANIZATION/$ORDERER_NAME/keys/server/msp/cacerts/*.pem)
        cat <<EOF > ${PWD}/infrastructure/$ORGANIZATION/$ORDERER_NAME/keys/server/msp/config.yaml
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

        chmod -R 777 infrastructure


        ###############################################################
        # ORDERER
        ###############################################################
        ORDERER_NAME=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Name" $CONFIG_FILE)
        ORDERER_PASS=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Pass" $CONFIG_FILE)
        ORDERER_IP=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[] | select(.Name == \"$ORDERER\") | .IP" $CONFIG_FILE)
        ORDERER_PORT=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Port" $CONFIG_FILE)
        ORDERER_CLPORT=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[] | select(.Name == \"$ORDERER\") | .ClusterPort" $CONFIG_FILE)
        ORDERER_OPPORT=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[] | select(.Name == \"$ORDERER\") | .OpPort" $CONFIG_FILE)
        ORDERER_ADMPORT=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[] | select(.Name == \"$ORDERER\") | .AdminPort" $CONFIG_FILE)

        TLS_PRIVATEKEY_FILE=$(basename $(ls ${PWD}/infrastructure/$ORGANIZATION/$ORDERER_NAME/keys/server/tls/keystore/*_sk))
        TLS_TLSCACERT_FILE=$(basename $(ls ${PWD}/infrastructure/$ORGANIZATION/$ORDERER_NAME/keys/server/tls/tlscacerts/*.pem))



        echo ""
        echo_warn "Orderer $ORDERER_NAME starting..."
        docker run -d \
            --name $ORDERER_NAME \
            --network $DOCKER_NETWORK_NAME \
            --ip $ORDERER_IP \
            $hosts_args \
            --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/infrastructure/src/fabric_logo.png" \
            -p $ORDERER_PORT:$ORDERER_PORT \
            -p $ORDERER_OPPORT:$ORDERER_OPPORT \
            -p $ORDERER_CLPORT:$ORDERER_CLPORT \
            -p $ORDERER_ADMPORT:$ORDERER_ADMPORT \
            -v $FABRIC_BIN_PATH/config/orderer.yaml:/etc/hyperledger/fabric/orderer.yaml \
            -v ${PWD}/infrastructure/$ORGANIZATION/$ORDERER_NAME/keys/server/msp:/etc/hyperledger/orderer/msp \
            -v ${PWD}/infrastructure/$ORGANIZATION/$ORDERER_NAME/keys/server/tls:/etc/hyperledger/orderer/tls \
            -v ${PWD}/infrastructure/$ORGANIZATION/$ORDERER_NAME/production:/var/hyperledger/production \
            -e ORDERER_GENERAL_LISTENADDRESS=0.0.0.0 \
            -e ORDERER_GENERAL_LISTENPORT=$ORDERER_PORT \
            -e ORDERER_GENERAL_LOCALMSPID=${ORGANIZATION} \
            -e ORDERER_GENERAL_LOCALMSPDIR=/etc/hyperledger/orderer/msp \
            -e ORDERER_GENERAL_TLS_ENABLED=true \
            -e ORDERER_GENERAL_TLS_CERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem \
            -e ORDERER_GENERAL_TLS_PRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/$TLS_PRIVATEKEY_FILE \
            -e ORDERER_GENERAL_TLS_ROOTCAS=[/etc/hyperledger/orderer/tls/tlscacerts/$TLS_TLSCACERT_FILE] \
            -e ORDERER_GENERAL_CLUSTER_LISTENADDRESS=0.0.0.0 \
            -e ORDERER_GENERAL_CLUSTER_LISTENPORT=$ORDERER_CLPORT \
            -e ORDERER_GENERAL_CLUSTER_SERVERCERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem \
            -e ORDERER_GENERAL_CLUSTER_SERVERPRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/$TLS_PRIVATEKEY_FILE \
            -e ORDERER_GENERAL_CLUSTER_ROOTCAS=[/etc/hyperledger/orderer/tls/tlscacerts/$TLS_TLSCACERT_FILE] \
            -e ORDERER_GENERAL_CLUSTER_CLIENTCERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem \
            -e ORDERER_GENERAL_CLUSTER_CLIENTPRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/$TLS_PRIVATEKEY_FILE \
            -e ORDERER_GENERAL_BOOTSTRAPMETHOD=none \
            -e ORDERER_ADMIN_LISTENADDRESS=0.0.0.0:$ORDERER_ADMPORT \
            -e ORDERER_ADMIN_TLS_ENABLED=true \
            -e ORDERER_ADMIN_TLS_CLIENTAUTHREQUIRED=true \
            -e ORDERER_ADMIN_TLS_CERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem \
            -e ORDERER_ADMIN_TLS_PRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/$TLS_PRIVATEKEY_FILE \
            -e ORDERER_ADMIN_TLS_CLIENTROOTCAS=[/etc/hyperledger/orderer/tls/tlscacerts/$TLS_TLSCACERT_FILE] \
            -e ORDERER_CHANNELPARTICIPATION_ENABLED=true \
            --restart unless-stopped \
            hyperledger/fabric-orderer:latest

        CheckContainer "$ORDERER_NAME" "$DOCKER_CONTAINER_WAIT"
        CheckContainerLog "$ORDERER_NAME" "Beginning to serve requests" "$DOCKER_CONTAINER_WAIT"
    done
done
###############################################################
# Last Tasks
###############################################################



