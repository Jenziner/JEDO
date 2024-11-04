###############################################################
#!/bin/bash
#
# This script starts Hyperledger Fabric Peer
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
    echo_warn "Peers for $ORGANIZATION enrolling..."
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

    PEERS=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[].Name" $CONFIG_FILE)
    for PEER in $PEERS; do
        ###############################################################
        # Enroll peer
        ###############################################################
        PEER_NAME=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[] | select(.Name == \"$PEER\") | .Name" $CONFIG_FILE)
        PEER_PASS=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[] | select(.Name == \"$PEER\") | .Pass" $CONFIG_FILE)
        PEER_IP=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[] | select(.Name == \"$PEER\") | .IP" $CONFIG_FILE)
        PEER_SUBJECT=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[] | select(.Name == \"$PEER\") | .Subject" $CONFIG_FILE)

        # Extract fields from subject
        C=$(echo "$PEER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
        ST=$(echo "$PEER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
        L=$(echo "$PEER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')
        CN=$(echo "$PEER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^CN=/) {sub(/^CN=/, "", $i); print $i}}')
        CSR_NAMES=$(echo "$PEER_SUBJECT" | sed 's/,CN=[^,]*//')

        echo ""
        echo_info "$PEER_NAME registering and enrolling..."
        # Register and enroll ORG peer
        docker exec -it $ORGCA_NAME fabric-ca-client register -u https://$ORGCA_NAME:$ORGCA_PASS@$ORGCA_NAME:$ORGCA_PORT \
            --id.name $PEER_NAME --id.secret $PEER_PASS --id.type peer --id.affiliation $AFFILIATION_NODE
        docker exec -it $ORGCA_NAME fabric-ca-client enroll -u https://$PEER_NAME:$PEER_PASS@$ORGCA_NAME:$ORGCA_PORT --mspdir $INFRA_DIR/$ORGANIZATION/$PEER_NAME/keys/server/msp \
            --csr.cn $CN --csr.names "$CSR_NAMES"

        # Register and enroll TLS peer
        docker exec -it $TLSCA_NAME fabric-ca-client register -u https://$TLSCA_NAME:$TLSCA_PASS@$TLSCA_NAME:$TLSCA_PORT \
            --id.name $PEER_NAME --id.secret $PEER_PASS --id.type peer --id.affiliation $AFFILIATION_NODE
        docker exec -it $TLSCA_NAME fabric-ca-client enroll -u https://$PEER_NAME:$PEER_PASS@$TLSCA_NAME:$TLSCA_PORT --mspdir $INFRA_DIR/$ORGANIZATION/$PEER_NAME/keys/server/tls \
            --csr.cn $CN --csr.names "$CSR_NAMES" --csr.hosts "$PEER_NAME,$PEER_IP,$DOCKER_UNRAID" \
            --enrollment.profile tls 

        # Generating NodeOUs-File
        echo ""
        echo_info "NodeOUs-File writing..."
        CA_CERT_FILE=$(ls ${PWD}/infrastructure/$ORGANIZATION/$PEER_NAME/keys/server/msp/cacerts/*.pem)
        cat <<EOF > ${PWD}/infrastructure/$ORGANIZATION/$PEER_NAME/keys/server/msp/config.yaml
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
        # CouchDB
        ###############################################################
        PEER_DB_NAME=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[] | select(.Name == \"$PEER\") | .DB.Name" $CONFIG_FILE)
        PEER_DB_PASS=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[] | select(.Name == \"$PEER\") | .DB.Pass" $CONFIG_FILE)
        PEER_DB_IP=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[] | select(.Name == \"$PEER\") | .DB.IP" $CONFIG_FILE)
        PEER_DB_PORT=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[] | select(.Name == \"$PEER\") | .DB.Port" $CONFIG_FILE)

        echo ""
        echo_warn "CouchDB $PEER_DB_NAME starting..."
        docker run -d \
        --name $PEER_DB_NAME \
        --network $DOCKER_NETWORK_NAME \
        --ip $PEER_DB_IP \
        $hosts_args \
        --label net.unraid.docker.icon="https://raw.githubusercontent.com/apache/couchdb/main/branding/logo/CouchDB_Logo_192px.png" \
        -e COUCHDB_USER=$PEER_DB_NAME \
        -e COUCHDB_PASSWORD=$PEER_DB_PASS \
        -v ${PWD}/infrastructure/$ORGANIZATION/$PEER_DB_NAME:/opt/couchdb/data \
        -v ${PWD}/infrastructure/$ORGANIZATION/$PEER_DB_NAME:/opt/couchdb/etc/local.d \
        -p $PEER_DB_PORT:5984 \
        --restart unless-stopped \
        couchdb:latest

        CheckContainer "$PEER_DB_NAME" "$DOCKER_CONTAINER_WAIT"
        CheckCouchDB "$PEER_DB_NAME" "$PEER_DB_IP" "$DOCKER_CONTAINER_WAIT"

        #create user-db
        curl -X PUT http://$PEER_DB_IP:5984/_users -u $PEER_DB_NAME:$PEER_DB_PASS


        ###############################################################
        # Peer
        ###############################################################
        PEER_NAME=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[] | select(.Name == \"$PEER\") | .Name" $CONFIG_FILE)
        PEER_PASS=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[] | select(.Name == \"$PEER\") | .Pass" $CONFIG_FILE)
        PEER_IP=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[] | select(.Name == \"$PEER\") | .IP" $CONFIG_FILE)
        PEER_PORT1=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[] | select(.Name == \"$PEER\") | .Port1" $CONFIG_FILE)
        PEER_PORT2=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[] | select(.Name == \"$PEER\") | .Port2" $CONFIG_FILE)
        PEER_OPPORT=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[] | select(.Name == \"$PEER\") | .OpPort" $CONFIG_FILE)
        PEER_CLI=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[] | select(.Name == \"$PEER\") | .CLI" $CONFIG_FILE)

        FIRST_ORDERER_NAME=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[0].Name" $CONFIG_FILE)
        FIRST_ORDERER_PORT=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[0].Port" $CONFIG_FILE)

        TLS_PRIVATEKEY_FILE=$(basename $(ls ${PWD}/infrastructure/$ORGANIZATION/$PEER_NAME/keys/server/tls/keystore/*_sk))
        TLS_TLSCACERT_FILE=$(basename $(ls ${PWD}/infrastructure/$ORGANIZATION/$PEER_NAME/keys/server/tls/tlscacerts/*.pem))

        echo ""
        echo_warn "Peer $PEER_NAME starting..."
        docker run -d \
            --name $PEER_NAME \
            --network $DOCKER_NETWORK_NAME \
            --ip $PEER_IP \
            $hosts_args \
            --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/infrastructure/src/fabric_logo.png" \
            -p $PEER_PORT1:$PEER_PORT1 \
            -p $PEER_PORT2:$PEER_PORT2 \
            -p $PEER_OPPORT:$PEER_OPPORT \
            -v $FABRIC_BIN_PATH/config/core.yaml:/etc/hyperledger/fabric/core.yaml \
            -v ${PWD}/infrastructure/$ORGANIZATION/$PEER_NAME/keys/server/msp:/etc/hyperledger/peer/msp \
            -v ${PWD}/infrastructure/$ORGANIZATION/$PEER_NAME/keys/server/tls:/etc/hyperledger/fabric/tls \
            -v ${PWD}/infrastructure/$ORGANIZATION/$FIRST_ORDERER_NAME/keys/server/tls:/etc/hyperledger/orderer/tls \
            -v ${PWD}/infrastructure/$ORGANIZATION/$PEER_NAME/production:/var/hyperledger/production \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -e CORE_VM_ENDPOINT=unix:///var/run/docker.sock \
            -e CORE_PEER_ID=$PEER_NAME \
            -e CORE_PEER_LISTENADDRESS=0.0.0.0:$PEER_PORT1 \
            -e CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:$PEER_PORT2 \
            -e CORE_PEER_ADDRESS=$PEER_NAME:$PEER_PORT1 \
            -e CORE_PEER_LOCALMSPID=${ORGANIZATION} \
            -e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/peer/msp \
            -e CORE_PEER_TLS_ENABLED=true \
            -e CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/signcerts/cert.pem \
            -e CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/keystore/$TLS_PRIVATEKEY_FILE \
            -e CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/tlscacerts/$TLS_TLSCACERT_FILE \
            -e CORE_PEER_GOSSIP_BOOTSTRAP=127.0.0.1:$PEER_PORT1 \
            -e CORE_PEER_GOSSIP_ENDPOINT=0.0.0.0:$PEER_PORT1 \
            -e CORE_PEER_GOSSIP_EXTERNALENDPOINT=0.0.0.0:$PEER_PORT1 \
            -e CORE_PEER_GOSSIP_MAX_CONNECTION_TIMEOUT=20s \
            -e CORE_PEER_GOSSIP_KEEPALIVE_INTERVAL=60s \
            -e CORE_LEDGER_STATE_STATEDATABASE=CouchDB \
            -e CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=$PEER_DB_IP:5984 \
            -e CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=$PEER_DB_NAME \
            -e CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=$PEER_DB_PASS \
            -e CORE_ORDERER_ADDRESS=$FIRST_ORDERER_NAME:$FIRST_ORDERER_PORT \
            -e CORE_ORDERER_TLS_ENABLED=true \
            -e CORE_ORDERER_TLS_CERT_FILE=/etc/hyperledger/orderer/tls/signcerts/cert.pem \
            --restart unless-stopped \
            hyperledger/fabric-peer:latest

        CheckContainer "$PEER_NAME" "$DOCKER_CONTAINER_WAIT"
        CheckContainerLog "$PEER_NAME" "Started peer with ID" "$DOCKER_CONTAINER_WAIT"


        ###############################################################
        # Peer CLI
        ###############################################################
        echo ""
        echo_warn "CLI  cli.$PEER_NAME starting..."

        docker run -d \
        --name cli.$PEER_NAME \
        --network $DOCKER_NETWORK_NAME \
        --ip $PEER_CLI \
        $hosts_args \
        --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/infrastructure/src/fabric_cli_logo.png" \
        -v ${PWD}/infrastructure/$ORGANIZATION/$PEER_NAME/keys/server/msp:/etc/hyperledger/peer/msp \
        -v ${PWD}/infrastructure/$ORGANIZATION/$PEER_NAME/keys/server/tls:/etc/hyperledger/fabric/tls \
        -v ${PWD}/infrastructure/$ORGANIZATION/$FIRST_ORDERER_NAME/keys/server/tls:/etc/hyperledger/orderer/tls \
        -v ${PWD}/infrastructure/$ORGANIZATION/$PEER_NAME/production:/var/hyperledger/production \
        -v ${PWD}/infrastructure/$ORGANIZATION/$PEER_NAME:/opt/gopath/src/github.com/hyperledger/fabric/chaincode \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -w /opt/gopath/src/github.com/hyperledger/fabric \
        -e GOPATH=/opt/gopath \
        -e CORE_PEER_ID=cli.$PEER_NAME \
        -e CORE_PEER_ADDRESS=$PEER_NAME:$PEER_PORT1 \
        -e CORE_PEER_LOCALMSPID=${ORGANIZATION}MSP \
        -e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/peer/msp \
        -e CORE_PEER_TLS_ENABLED=true \
        -e CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/signcerts/cert.pem \
        -e CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/tlscacerts/$TLS_TLSCACERT_FILE \
        -e CORE_ORDERER_ADDRESS=$FIRST_ORDERER_NAME:$FIRST_ORDERER_PORT \
        -e CORE_ORDERER_TLS_ENABLED=true \
        -e CORE_ORDERER_TLS_CERT_FILE=/etc/hyperledger/orderer/tls/signcerts/cert.pem \
        -e FABRIC_LOGGING_SPEC=DEBUG \
        -it \
        --restart unless-stopped \
        hyperledger/fabric-tools:latest

        CheckContainer "cli.$PEER_NAME" "$DOCKER_CONTAINER_WAIT"
    done
done
###############################################################
# Last Tasks
###############################################################


# ###############################################################
# # sign channelconfig
# ###############################################################
# echo ""
# echo_info "Channelconfig $CHANNEL with $PEER_NAME signing..."
# docker exec -it cli.$PEER_NAME peer channel signconfigtx -f /etc/hyperledger/config/$CHANNEL.tx
# echo_ok "Channelconfig $CHANNEL with $PEER_NAME signed."

