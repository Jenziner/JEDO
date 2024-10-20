###############################################################
#!/bin/bash
#
# This script starts Hyperledger Fabric Nodes
#
#
###############################################################
source ./scripts/settings.sh
source ./scripts/help.sh
check_script

echo_ok "Starting Node Container - see Documentation here: https://hyperledger-fabric.readthedocs.io"

###############################################################
# Function to echo in colors
###############################################################
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
function echo_info() {
    echo -e "${YELLOW}$1${NC}"
}
function echo_error() {
    echo -e "${RED}$1${NC}"
}


###############################################################
# Params - from ./config/network-config.yaml
###############################################################
export FABRIC_CFG_PATH=./config
NETWORK_CONFIG_FILE="./config/network-config.yaml"
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' "$NETWORK_CONFIG_FILE")
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' "$NETWORK_CONFIG_FILE")
CHANNEL=$(yq e '.FabricNetwork.Channel' $NETWORK_CONFIG_FILE)
ORGANIZATIONS=$(yq e '.FabricNetwork.Organizations[].Name' $NETWORK_CONFIG_FILE)

hosts_args=""
for ORGANIZATION in $ORGANIZATIONS; do
  CA=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Name" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
  CA_IP=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.IP" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
  PEERS=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[].Name" $NETWORK_CONFIG_FILE)
  ORDERERS=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Name" $NETWORK_CONFIG_FILE)

  hosts_args+="--add-host=$CA:$CA_IP "

    for index in $(seq 0 $(($(echo "$PEERS" | wc -l) - 1))); do
        PEER=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].Name" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
        PEER_IP=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].IP" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
        hosts_args+="--add-host=$PEER:$PEER_IP "
    done

    for index in $(seq 0 $(($(echo "$PEERS" | wc -l) - 1))); do
        DB=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].DB.Name" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
        DB_IP=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].DB.IP" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
        hosts_args+="--add-host=$DB:$DB_IP "
    done

    for index in $(seq 0 $(($(echo "$PEERS" | wc -l) - 1))); do
        CLI=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].Name" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
        CLI_IP=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].CLI" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
        hosts_args+="--add-host=cli.$CLI:$CLI_IP "
    done

    for index in $(seq 0 $(($(echo "$ORDERERS" | wc -l) - 1))); do
        ORDERER=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[$index].Name" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
        ORDERER_IP=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[$index].IP" $NETWORK_CONFIG_FILE | tr -d '\n' | tr -d '\r')
        hosts_args+="--add-host=$ORDERER:$ORDERER_IP "
    done
done


###############################################################
# Orderers
###############################################################
for ORGANIZATION in $ORGANIZATIONS; do
    ORDERERS_NAME=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Name" $NETWORK_CONFIG_FILE)

    for index in $(seq 0 $(($(echo "$ORDERERS_NAME" | wc -l) - 1))); do
        ORDERER_NAME=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[$index].Name" $NETWORK_CONFIG_FILE)
        ORDERER_PASS=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[$index].Pass" $NETWORK_CONFIG_FILE)
        ORDERER_IP=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[$index].IP" $NETWORK_CONFIG_FILE)
        ORDERER_PORT=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[$index].Port" $NETWORK_CONFIG_FILE)
        ORDERER_OPPORT=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[$index].OpPort" $NETWORK_CONFIG_FILE)
        ORDERER_CLUSTER_PORT=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[$index].ClusterPort" $NETWORK_CONFIG_FILE) # Neu: Cluster-Port
        TLS_PRIVATE_KEY=$(basename $(ls $PWD/keys/$ORGANIZATION/$ORDERER_NAME/tls/keystore/*_sk))
#        TLS_CA_CERTS=$(ls $PWD/keys/tlscerts_collections/tls_ca_certs/*.pem | xargs -n 1 basename | sed 's|^|/etc/hyperledger/orderer/tls/tlscacerts/|' | tr '\n' ',' | sed 's/,$//')

        ORGS=$(yq e '.FabricNetwork.Organizations[].Name' $NETWORK_CONFIG_FILE)
        CLUSTER_PEERS=""
        for ORG in $ORGS; do
            ORG_ORDERERS_NAME=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Name" $NETWORK_CONFIG_FILE)
            ORG_ORDERERS_PORT=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].ClusterPort" $NETWORK_CONFIG_FILE)

            for index in $(seq 0 $(($(echo "$ORG_ORDERERS_NAME" | wc -l) - 1))); do
                ORG_ORDERER_NAME=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[$index].Name" $NETWORK_CONFIG_FILE)
                ORG_ORDERER_CLUSTER_PORT=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[$index].ClusterPort" $NETWORK_CONFIG_FILE)

                if [ "$ORG_ORDERER_NAME" != "$ORDERER_NAME" ]; then
                    CLUSTER_PEERS+="$ORG_ORDERER_NAME:$ORG_ORDERER_CLUSTER_PORT,"
                fi
            done
        done
        CLUSTER_PEERS=$(echo $CLUSTER_PEERS | sed 's/,$//')

        WAIT_TIME=0
        SUCCESS=false

        echo_info "ScriptInfo: run orderer $ORDERER_NAME"
        docker run -d \
        --name $ORDERER_NAME \
        --network $DOCKER_NETWORK_NAME \
        --ip $ORDERER_IP \
        $hosts_args \
        --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/infrastructure/src/fabric_logo.png" \
        -e ORDERER_GENERAL_LISTENADDRESS=0.0.0.0 \
        -e ORDERER_GENERAL_LISTENPORT=$ORDERER_PORT \
        -e ORDERER_GENERAL_GENESISMETHOD=file \
        -e ORDERER_GENERAL_GENESISFILE=/etc/hyperledger/fabric/genesis.block \
        -e ORDERER_GENERAL_LOCALMSPID=${ORGANIZATION}MSP \
        -e ORDERER_GENERAL_LOCALMSPDIR=/etc/hyperledger/orderer/msp \
        -e ORDERER_GENERAL_TLS_ENABLED=true \
        -e ORDERER_GENERAL_TLS_CERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem \
        -e ORDERER_GENERAL_TLS_PRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/$TLS_PRIVATE_KEY \
        -e ORDERER_GENERAL_TLS_ROOTCAS=[/etc/hyperledger/fabric/tls/tlscacerts/tls_ca_combined.pem] \
        -e ORDERER_GENERAL_TLS_CLIENTAUTHREQUIRED=true \
        -e ORDERER_GENERAL_TLS_CLIENTROOTCAS=[/etc/hyperledger/fabric/tls/tlscacerts/tls_ca_combined.pem] \
        -e ORDERER_GENERAL_CLUSTER_LISTENADDRESS=0.0.0.0 \
        -e ORDERER_GENERAL_CLUSTER_LISTENPORT=$ORDERER_CLUSTER_PORT \
        -e ORDERER_GENERAL_CLUSTER_PEERS=[$CLUSTER_PEERS] \
        -e ORDERER_GENERAL_CLUSTER_SERVERCERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem \
        -e ORDERER_GENERAL_CLUSTER_SERVERPRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/$TLS_PRIVATE_KEY \
        -e ORDERER_GENERAL_CLUSTER_ROOTCAS=[/etc/hyperledger/fabric/tls/tlscacerts/tls_ca_combined.pem] \
        -e ORDERER_GENERAL_CLUSTER_CLIENTCERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem \
        -e ORDERER_GENERAL_CLUSTER_CLIENTPRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/$TLS_PRIVATE_KEY \
        -e ORDERER_GENERAL_CLUSTER_DIALTIMEOUT=10s \
        -e ORDERER_GENERAL_CLUSTER_RPCTIMEOUT=10s \
        -e ORDERER_RAFT_ELECTIONTICK=20 \
        -e ORDERER_RAFT_HEARBEATTICK=2 \
        -e ORDERER_RAFT_SNAPSHOTINTERVALSIZE=20MB \
        -v $PWD/../fabric/config/orderer.yaml:/etc/hyperledger/fabric/orderer.yaml \
        -v $PWD/config/$CHANNEL.genesisblock:/etc/hyperledger/fabric/genesis.block \
        -v $PWD/keys/$ORGANIZATION/$ORDERER_NAME/msp:/etc/hyperledger/orderer/msp \
        -v $PWD/keys/$ORGANIZATION/$ORDERER_NAME/tls:/etc/hyperledger/orderer/tls \
        -v $PWD/keys/tlscerts_collections/tls_ca_combined:/etc/hyperledger/orderer/tls/tlscacerts \
        -v $PWD/keys/tlscerts_collections/tls_ca_combined/tls_ca_combined.pem:/etc/hyperledger/fabric/tls/tlscacerts/tls_ca_combined.pem \
        -v $PWD/production/$ORDERER_NAME:/var/hyperledger/production \
        -p $ORDERER_PORT:$ORDERER_PORT \
        -p $ORDERER_OPPORT:$ORDERER_OPPORT \
        -p $ORDERER_CLUSTER_PORT:$ORDERER_CLUSTER_PORT \
        --restart unless-stopped \
        hyperledger/fabric-orderer:latest

        # waiting startup
        while [ $WAIT_TIME -lt $DOCKER_CONTAINER_WAIT ]; do
            if docker inspect -f '{{.State.Running}}' $ORDERER_NAME | grep true > /dev/null; then
                SUCCESS=true
                echo_info "ScriptInfo: $ORDERER_NAME is up and running!"
                break
            fi
            echo "Waiting for $ORDERER_NAME... ($WAIT_TIME seconds)"
            sleep 2
            WAIT_TIME=$((WAIT_TIME + 2))
        done

        if [ "$SUCCESS" = false ]; then
            echo_error "ScriptError: $ORDERER_NAME did not start."
            docker logs $ORDERER_NAME
            exit 1
        fi
    done
done


###############################################################
# CouchDBs
###############################################################
for ORGANIZATION in $ORGANIZATIONS; do
    PEERS_DB_NAME=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[].DB.Name" $NETWORK_CONFIG_FILE)

    for index in $(seq 0 $(($(echo "$PEERS_DB_NAME" | wc -l) - 1))); do
        PEER_DB_NAME=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].DB.Name" $NETWORK_CONFIG_FILE)
        PEER_DB_PASS=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].DB.Pass" $NETWORK_CONFIG_FILE)
        PEER_DB_IP=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].DB.IP" $NETWORK_CONFIG_FILE)
        PEER_DB_PORT=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].DB.Port" $NETWORK_CONFIG_FILE)

        WAIT_TIME=0
        SUCCESS=false

        echo_info "ScriptInfo: run CouchDB $PEER_DB_NAME"
        docker run -d \
        --name $PEER_DB_NAME \
        --network $DOCKER_NETWORK_NAME \
        --ip $PEER_DB_IP \
        $hosts_args \
        --label net.unraid.docker.icon="https://raw.githubusercontent.com/apache/couchdb/main/branding/logo/CouchDB_Logo_192px.png" \
        -e COUCHDB_USER=$PEER_DB_NAME \
        -e COUCHDB_PASSWORD=$PEER_DB_PASS \
        -v $PWD/production/couchdb/$PEER_DB_NAME:/opt/couchdb/data \
        -v $PWD/config/couchdb/$PEER_DB_NAME:/opt/couchdb/etc/local.d \
        -p $PEER_DB_PORT:5984 \
        --restart unless-stopped \
        couchdb:latest

        # waiting startup for CouchDB
        while [ $WAIT_TIME -lt $DOCKER_CONTAINER_WAIT ]; do
            if curl -s http://$PEER_DB_IP:5984 > /dev/null; then
                SUCCESS=true
                echo_info "ScriptInfo: CouchDB $PEER_DB_NAME is up and running!"
                break
            fi
            echo "Waiting for CouchDB $PEER_DB_NAME... ($WAIT_TIME seconds)"
            sleep 2
            WAIT_TIME=$((WAIT_TIME + 2))
        done

        if [ "$SUCCESS" = false ]; then
            echo_error "ScriptError: CouchDB $PEER_DB_NAME did not start."
            docker logs $PEER_DB_NAME
            exit 1
        fi

        #create user-db
        curl -X PUT http://$PEER_DB_IP:5984/_users -u $PEER_DB_NAME:$PEER_DB_PASS
    done
done


###############################################################
# Peers
###############################################################
for ORGANIZATION in $ORGANIZATIONS; do
    PEERS_NAME=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[].Name" $NETWORK_CONFIG_FILE)

    for index in $(seq 0 $(($(echo "$PEERS_NAME" | wc -l) - 1))); do
        PEER_NAME=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].Name" $NETWORK_CONFIG_FILE)
        PEER_PASS=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].Pass" $NETWORK_CONFIG_FILE)
        PEER_IP=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].IP" $NETWORK_CONFIG_FILE)
        PEER_PORT1=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].Port1" $NETWORK_CONFIG_FILE)
        PEER_PORT2=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].Port2" $NETWORK_CONFIG_FILE)
        PEER_OPPORT=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].OpPort" $NETWORK_CONFIG_FILE)
        PEER_CLI=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].CLI" $NETWORK_CONFIG_FILE)
        PEER_DB_NAME=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].DB.Name" $NETWORK_CONFIG_FILE)
        PEER_DB_PASS=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].DB.Pass" $NETWORK_CONFIG_FILE)
        PEER_DB_IP=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].DB.IP" $NETWORK_CONFIG_FILE)
        PEER_DB_PORT=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[$index].DB.Port" $NETWORK_CONFIG_FILE)
        FIRST_ORDERER=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[0].Name" $NETWORK_CONFIG_FILE)
        FIRST_ORDERER_PORT=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[0].Port" $NETWORK_CONFIG_FILE)
        TLS_PRIVATE_KEY=$(basename $(ls $PWD/keys/$ORGANIZATION/$PEER_NAME/tls/keystore/*_sk))

        WAIT_TIME=0
        SUCCESS=false

        echo_info "ScriptInfo: run Peer $PEER_NAME"
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
        -e CORE_PEER_GOSSIP_BOOTSTRAP=127.0.0.1:$PEER_PORT1 \
        -e CORE_PEER_GOSSIP_ENDPOINT=0.0.0.0:$PEER_PORT1 \
        -e CORE_PEER_GOSSIP_EXTERNALENDPOINT=0.0.0.0:$PEER_PORT1 \
        -e CORE_PEER_GOSSIP_MAX_CONNECTION_TIMEOUT=20s \
        -e CORE_PEER_GOSSIP_KEEPALIVE_INTERVAL=60s \
        -e CORE_PEER_TLS_ENABLED=true \
        -e CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/signcerts/cert.pem \
        -e CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/keystore/$TLS_PRIVATE_KEY \
        -e CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/tlscacerts/tls_node_combined.pem \
        -e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/peer/msp \
        -e CORE_LEDGER_STATE_STATEDATABASE=CouchDB \
        -e CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=$PEER_DB_IP:5984 \
        -e CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=$PEER_DB_NAME \
        -e CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=$PEER_DB_PASS \
        -e CORE_ORDERER_ADDRESS=$FIRST_ORDERER:$FIRST_ORDERER_PORT \
        -e CORE_ORDERER_TLS_ENABLED=true \
        -e CORE_ORDERER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/tlscacerts/tls_ca_combined.pem \
        -e CORE_ORDERER_TLS_CERT_FILE=/etc/hyperledger/orderer/tls/signcerts/cert.pem \
        -v $PWD/../fabric/config/core.yaml:/etc/hyperledger/fabric/core.yaml \
        -v $PWD/keys/$ORGANIZATION/$PEER_NAME/msp:/etc/hyperledger/peer/msp \
        -v $PWD/keys/$ORGANIZATION/$PEER_NAME/tls:/etc/hyperledger/fabric/tls \
        -v $PWD/keys/$ORGANIZATION/$FIRST_ORDERER/tls:/etc/hyperledger/orderer/tls \
        -v $PWD/keys/tlscerts_collections/tls_ca_combined/tls_ca_combined.pem:/etc/hyperledger/fabric/tls/tlscacerts/tls_ca_combined.pem \
        -v $PWD/keys/tlscerts_collections/tls_node_combined/tls_node_combined.pem:/etc/hyperledger/fabric/tls/tlscacerts/tls_node_combined.pem \
        -v $PWD/production/$PEER_NAME:/var/hyperledger/production \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -p $PEER_PORT1:$PEER_PORT1 \
        -p $PEER_PORT2:$PEER_PORT2 \
        -p $PEER_OPPORT:$PEER_OPPORT \
        --restart unless-stopped \
        hyperledger/fabric-peer:latest

        # waiting startup
        while [ $WAIT_TIME -lt $DOCKER_CONTAINER_WAIT ]; do
            if docker inspect -f '{{.State.Running}}' $PEER_NAME | grep true > /dev/null; then
                SUCCESS=true
                echo_info "ScriptInfo: $PEER_NAME is up and running!"
                break
            fi
            echo "Waiting for $PEER_NAME... ($WAIT_TIME seconds)"
            sleep 2
            WAIT_TIME=$((WAIT_TIME + 2))
        done

        if [ "$SUCCESS" = false ]; then
            echo_error "ScriptError: $PEER_NAME did not start."
            docker logs $PEER_NAME
            exit 1
        fi

        # Run CLI
        echo_info "ScriptInfo: run cli $PEER_NAME"
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
        -e CORE_PEER_TLS_ENABLED=true \
        -e CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/tlscacerts/tls_node_combined.pem \
        -e CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/tlscacerts/tls_node_combined.pem \
        -e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/peer/msp \
        -e CORE_ORDERER_ADDRESS=$FIRST_ORDERER:$FIRST_ORDERER_PORT \
        -e CORE_ORDERER_TLS_ENABLED=true \
        -e CORE_ORDERER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/tlscacerts/tls_ca_combined.pem \
        -e FABRIC_LOGGING_SPEC=DEBUG \
        -v $PWD/keys/$ORGANIZATION/$PEER_NAME/msp:/etc/hyperledger/peer/msp \
        -v $PWD/keys/$ORGANIZATION/$PEER_NAME/tls:/etc/hyperledger/fabric/tls \
        -v $PWD/keys/$ORGANIZATION/$FIRST_ORDERER/tls:/etc/hyperledger/orderer/tls \
        -v $PWD/keys/tlscerts_collections/tls_ca_combined/tls_ca_combined.pem:/etc/hyperledger/fabric/tls/tlscacerts/tls_ca_combined.pem \
        -v $PWD/keys/tlscerts_collections/tls_node_combined/tls_node_combined.pem:/etc/hyperledger/fabric/tls/tlscacerts/tls_node_combined.pem \
        -v $PWD/production/$PEER_NAME:/var/hyperledger/production \
        -v $PWD/chaincode/$PEER_NAME:/opt/gopath/src/github.com/hyperledger/fabric/chaincode \
        -v $PWD:/tmp/$DOCKER_NETWORK_NAME \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -w /opt/gopath/src/github.com/hyperledger/fabric \
        -it \
        --restart unless-stopped \
        hyperledger/fabric-tools:latest

        # sign channelconfig
        echo_info "ScriptInfo: sign channelconfig $CHANNEL with $PEER_NAME"
        docker exec -it cli.$PEER_NAME peer channel signconfigtx -f /tmp/jedo-network/config/$CHANNEL.tx
    done
done
