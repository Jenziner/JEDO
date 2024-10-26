###############################################################
#!/bin/bash
#
# This script starts Hyperledger Fabric Peer
#
#
###############################################################
source ./utils/utils.sh
source ./utils/help.sh
check_script

echo_ok "Starting Docker-Container for Peer - see Documentation here: https://hyperledger-fabric.readthedocs.io"


###############################################################
# Params - from ./configinfrastructure-dev.yaml
###############################################################
CONFIG_FILE="./config/infrastructure-dev.yaml"
FABRIC_BIN_PATH=$(yq eval '.Fabric.Path' "$CONFIG_FILE")
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $CONFIG_FILE)
CHANNELS=$(yq e ".FabricNetwork.Channels[].Name" $CONFIG_FILE)


for CHANNEL in $CHANNELS; do
    export FABRIC_CFG_PATH=${PWD}/config/$CHANNEL
    CA_DIR=/etc/hyperledger/fabric-ca
    ORGANIZATIONS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[].Name" $CONFIG_FILE)

    get_hosts

    for ORGANIZATION in $ORGANIZATIONS; do
        CA_EXT=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Ext" $CONFIG_FILE)
        if [[ -n "$CA_EXT" ]]; then
            CA_NAME=$(yq eval ".. | select(has(\"CA\")) | .CA | select(.Name == \"$CA_EXT\") | .Name" "$CONFIG_FILE")
            CA_ORG=$(yq eval ".FabricNetwork.Channels[].Organizations[] | select(.CA.Name == \"$CA_NAME\") | .Name" "$CONFIG_FILE")
        else
            CA_NAME=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Name" $CONFIG_FILE)
            CA_ORG=$ORGANIZATION
        fi
        PEERS=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[].Name" $CONFIG_FILE)

        for PEER in $PEERS; do
            ###############################################################
            # CouchDB
            ###############################################################
            PEER_DB_NAME=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[] | select(.Name == \"$PEER\") | .DB.Name" $CONFIG_FILE)
            PEER_DB_PASS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[] | select(.Name == \"$PEER\") | .DB.Pass" $CONFIG_FILE)
            PEER_DB_IP=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[] | select(.Name == \"$PEER\") | .DB.IP" $CONFIG_FILE)
            PEER_DB_PORT=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[] | select(.Name == \"$PEER\") | .DB.Port" $CONFIG_FILE)

            WAIT_TIME=0
            SUCCESS=false

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
            -v $PWD/production/$CHANNEL/$ORGANIZATION/$PEER_DB_NAME:/opt/couchdb/data \
            -v $PWD/config/$CHANNEL/$ORGANIZATION/$PEER_DB_NAME:/opt/couchdb/etc/local.d \
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
            PEER_NAME=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[] | select(.Name == \"$PEER\") | .Name" $CONFIG_FILE)
            PEER_PASS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[] | select(.Name == \"$PEER\") | .Pass" $CONFIG_FILE)
            PEER_IP=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[] | select(.Name == \"$PEER\") | .IP" $CONFIG_FILE)
            PEER_PORT1=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[] | select(.Name == \"$PEER\") | .Port1" $CONFIG_FILE)
            PEER_PORT2=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[] | select(.Name == \"$PEER\") | .Port2" $CONFIG_FILE)
            PEER_OPPORT=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[] | select(.Name == \"$PEER\") | .OpPort" $CONFIG_FILE)
            PEER_CLI=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[] | select(.Name == \"$PEER\") | .CLI" $CONFIG_FILE)

            FIRST_ORDERER_NAME=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[0].Name" $CONFIG_FILE)
            FIRST_ORDERER_PORT=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[0].Port" $CONFIG_FILE)

            TLS_PRIVATE_KEY=$(basename $(ls $PWD/keys/$CHANNEL/_infrastructure/$ORGANIZATION/$PEER_NAME/tls/keystore/*_sk))

            WAIT_TIME=0
            SUCCESS=false

            echo ""
            echo_warn "Peer $PEER_NAME starting..."
            docker run -d \
            --name $PEER_NAME \
            --network $DOCKER_NETWORK_NAME \
            --ip $PEER_IP \
            $hosts_args \
            --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/infrastructure/src/fabric_logo.png" \
            -e CORE_VM_ENDPOINT=unix:///var/run/docker.sock \
            -e CORE_PEER_ID=$PEER_NAME \
            -e CORE_PEER_LISTENADDRESS=0.0.0.0:$PEER_PORT1 \
            -e CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:$PEER_PORT2 \
            -e CORE_PEER_ADDRESS=$PEER_NAME:$PEER_PORT1 \
            -e CORE_PEER_LOCALMSPID=${ORGANIZATION}MSP \
            -e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/peer/msp \
            -e CORE_PEER_TLS_ENABLED=true \
            -e CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/signcerts/cert.pem \
            -e CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/keystore/$TLS_PRIVATE_KEY \
            -e CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/msp/ca-chain.pem \
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
            -e CORE_ORDERER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/msp/ca-chain.pem \
            -v $FABRIC_BIN_PATH/config/core.yaml:/etc/hyperledger/fabric/core.yaml \
            -v ${PWD}/keys/$CHANNEL/_infrastructure/$ORGANIZATION/$PEER_NAME/msp:/etc/hyperledger/peer/msp \
            -v ${PWD}/keys/$CHANNEL/_infrastructure/$CA_ORG/$CA_NAME/ca-chain.pem:/etc/hyperledger/peer/msp/ca-chain.pem \
            -v ${PWD}/keys/$CHANNEL/_infrastructure/$ORGANIZATION/$PEER_NAME/tls:/etc/hyperledger/fabric/tls \
            -v ${PWD}/keys/$CHANNEL/_infrastructure/$ORGANIZATION/$FIRST_ORDERER_NAME/tls:/etc/hyperledger/orderer/tls \
            -v ${PWD}/production/$CHANNEL/$ORGANIZATION/$PEER_NAME:/var/hyperledger/production \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -p $PEER_PORT1:$PEER_PORT1 \
            -p $PEER_PORT2:$PEER_PORT2 \
            -p $PEER_OPPORT:$PEER_OPPORT \
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
            -e GOPATH=/opt/gopath \
            -e CORE_PEER_ID=cli.$PEER_NAME \
            -e CORE_PEER_ADDRESS=$PEER_NAME:$PEER_PORT1 \
            -e CORE_PEER_LOCALMSPID=${ORGANIZATION}MSP \
            -e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/peer/msp \
            -e CORE_PEER_TLS_ENABLED=true \
            -e CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/peer/msp/ca-chain.pem \
            -e CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/msp/ca-chain.pem \
            -e CORE_ORDERER_ADDRESS=$FIRST_ORDERER_NAME:$FIRST_ORDERER_PORT \
            -e CORE_ORDERER_TLS_ENABLED=true \
            -e CORE_ORDERER_TLS_ROOTCERT_FILE=/etc/hyperledger/peer/msp/ca-chain.pem \
            -e FABRIC_LOGGING_SPEC=DEBUG \
            -v ${PWD}/keys/$CHANNEL/_infrastructure/$ORGANIZATION/$PEER_NAME/msp:/etc/hyperledger/peer/msp \
            -v ${PWD}/keys/$CHANNEL/_infrastructure/$CA_ORG/$CA_NAME/ca-chain.pem:/etc/hyperledger/peer/msp/ca-chain.pem \
            -v ${PWD}/keys/$CHANNEL/_infrastructure/$ORGANIZATION/$PEER_NAME/tls:/etc/hyperledger/fabric/tls \
            -v ${PWD}/keys/$CHANNEL/_infrastructure/$ORGANIZATION/$FIRST_ORDERER_NAME/tls:/etc/hyperledger/orderer/tls \
            -v ${PWD}/production/$CHANNEL/$ORGANIZATION/$PEER_NAME:/var/hyperledger/production \
            -v ${PWD}/chaincode/$CHANNEL/$ORGANIZATION/$PEER_NAME:/opt/gopath/src/github.com/hyperledger/fabric/chaincode \
            -v ${PWD}/config/$CHANNEL:/etc/hyperledger/config \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -w /opt/gopath/src/github.com/hyperledger/fabric \
            -it \
            --restart unless-stopped \
            hyperledger/fabric-tools:latest

            CheckContainer "cli.$PEER_NAME" "$DOCKER_CONTAINER_WAIT"

            # ###############################################################
            # # sign channelconfig
            # ###############################################################
            # echo ""
            # echo_info "Channelconfig $CHANNEL with $PEER_NAME signing..."
            # docker exec -it cli.$PEER_NAME peer channel signconfigtx -f /etc/hyperledger/config/$CHANNEL.tx
            # echo_ok "Channelconfig $CHANNEL with $PEER_NAME signed."
        done
    done
done

