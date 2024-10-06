###############################################################
#!/bin/bash
#
# This script starts Hyperledger Fabric Nodes
#
# Prerequisits:
#   - yq: 
#       - installation: sudo wget https://github.com/mikefarah/yq/releases/download/v4.6.3/yq_linux_amd64 -O /usr/local/bin/yq
#       - make it executable: chmod +x /usr/local/bin/yq
#
###############################################################
set -Eeuo pipefail
ls scripts/node.sh || { echo "ScriptInfo: run this script from the root directory: ./scripts/node.sh"; exit 1; }


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
ORGANIZATIONS=$(yq e '.FabricNetwork.Organizations[].Name' $NETWORK_CONFIG_FILE)


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
        TLS_PRIVATE_KEY=$(basename $(ls $PWD/keys/$ORGANIZATION/$PEER_NAME/tls/keystore/*_sk))
#        TLS_ROOTCERT=$(basename $(ls $PWD/keys/$ORGANIZATION/$PEER_NAME/tls/tlscacerts/*))
#        TLS_ROOTCERTS=$(ls $PWD/keys/$ORGANIZATION/$PEER_NAME/tls/tlscacerts/*.pem | xargs -I {} basename {} | tr '\n' ',' | sed 's/,$//')

        WAIT_TIME=0
        SUCCESS=false

        echo_info "ScriptInfo: run Peer $PEER_NAME"
        docker run -d \
        --name $PEER_NAME \
        --network $DOCKER_NETWORK_NAME \
        --ip $PEER_IP \
        --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/jedo-network/src/fabric_logo.png" \
        -e CORE_VM_ENDPOINT=unix:///var/run/docker.sock \
        -e CORE_PEER_ID=$PEER_NAME \
        -e CORE_PEER_LISTENADDRESS=0.0.0.0:$PEER_PORT1 \
        -e CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:$PEER_PORT2 \
        -e CORE_PEER_ADDRESS=$PEER_NAME:$PEER_PORT1 \
        -e CORE_PEER_LOCALMSPID=${ORGANIZATION}MSP \
        -e CORE_PEER_GOSSIP_BOOTSTRAP=127.0.0.1:$PEER_PORT1 \
        -e CORE_PEER_GOSSIP_ENDPOINT=0.0.0.0:$PEER_PORT1 \
        -e CORE_PEER_GOSSIP_EXTERNALENDPOINT=0.0.0.0:$PEER_PORT1 \
        -e CORE_PEER_TLS_ENABLED=true \
        -e CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/signcerts/cert.pem \
        -e CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/keystore/$TLS_PRIVATE_KEY \
        -e CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/tlscacerts/tls-combined-ca.pem \
        -e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/peer/msp \
        -e CORE_LEDGER_STATE_STATEDATABASE=CouchDB \
        -e CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=$PEER_DB_IP:5984 \
        -e CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=$PEER_DB_NAME \
        -e CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=$PEER_DB_PASS \
        -v $PWD/../fabric/config/core.yaml:/etc/hyperledger/fabric/core.yaml \
        -v $PWD/keys/$ORGANIZATION/$PEER_NAME/msp:/etc/hyperledger/peer/msp \
        -v $PWD/keys/$ORGANIZATION/$PEER_NAME/tls:/etc/hyperledger/fabric/tls \
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

        # Run CLI if IP defined
        if [ -n "$PEER_CLI" ]; then
            echo_info "ScriptInfo: run cli $PEER_NAME"
            docker run -d \
            --name cli.$PEER_NAME \
            --network $DOCKER_NETWORK_NAME \
            --ip $PEER_CLI \
            --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/jedo-network/src/fabric_cli_logo.png" \
            -e GOPATH=/opt/gopath \
            -e CORE_PEER_ID=cli.$PEER_NAME \
            -e CORE_PEER_ADDRESS=$PEER_NAME:$PEER_PORT1 \
            -e CORE_PEER_LOCALMSPID=${ORGANIZATION}MSP \
            -e CORE_PEER_TLS_ENABLED=true \
            -e CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt \
            -e CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt \
            -e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/peer/msp \
            -e FABRIC_LOGGING_SPEC=DEBUG \
            -v $PWD/keys/$ORGANIZATION/$PEER_NAME/msp:/etc/hyperledger/peer/msp \
            -v $PWD/keys/$ORGANIZATION/$PEER_NAME/tls:/etc/hyperledger/fabric/tls \
            -v $PWD/keys/$ORGANIZATION/$FIRST_ORDERER/tls:/etc/hyperledger/orderer/tls \
            -v $PWD/production/$PEER_NAME:/var/hyperledger/production \
            -v $PWD/chaincode/$PEER_NAME:/opt/gopath/src/github.com/hyperledger/fabric/chaincode \
            -v $PWD:/tmp/$DOCKER_NETWORK_NAME \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -w /opt/gopath/src/github.com/hyperledger/fabric \
            -it \
            --restart unless-stopped \
            hyperledger/fabric-tools:latest
        fi
    done
done


###############################################################
# Orderers
###############################################################
CHANNEL=$(yq e '.FabricNetwork.Channel' $NETWORK_CONFIG_FILE)
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
        TLS_ROOTCERTS=$(ls $PWD/keys/$ORGANIZATION/$ORDERER_NAME/tls/tlscacerts/*.pem | xargs -n 1 basename | sed 's|^|/etc/hyperledger/orderer/tls/tlscacerts/|' | tr '\n' ',' | sed 's/,$//')

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
        --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/jedo-network/src/fabric_logo.png" \
        -e ORDERER_GENERAL_LISTENADDRESS=0.0.0.0 \
        -e ORDERER_GENERAL_LISTENPORT=$ORDERER_PORT \
        -e ORDERER_GENERAL_GENESISMETHOD=file \
        -e ORDERER_GENERAL_GENESISFILE=/etc/hyperledger/fabric/genesis.block \
        -e ORDERER_GENERAL_LOCALMSPID=${ORGANIZATION}MSP \
        -e ORDERER_GENERAL_LOCALMSPDIR=/etc/hyperledger/orderer/msp \
        -e ORDERER_GENERAL_TLS_ENABLED=true \
        -e ORDERER_GENERAL_TLS_CERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem \
        -e ORDERER_GENERAL_TLS_PRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/$TLS_PRIVATE_KEY \
        -e ORDERER_GENERAL_TLS_ROOTCAS=[$TLS_ROOTCERTS] \
        -e ORDERER_GENERAL_TLS_CLIENTAUTHREQUIRED=true \
        -e ORDERER_GENERAL_TLS_CLIENTROOTCAS=[$TLS_ROOTCERTS] \
        -e ORDERER_GENERAL_CLUSTER_LISTENADDRESS=0.0.0.0 \
        -e ORDERER_GENERAL_CLUSTER_LISTENPORT=$ORDERER_CLUSTER_PORT \
        -e ORDERER_GENERAL_CLUSTER_PEERS=[$CLUSTER_PEERS] \
        -e ORDERER_GENERAL_CLUSTER_SERVERCERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem \
        -e ORDERER_GENERAL_CLUSTER_SERVERPRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/$TLS_PRIVATE_KEY \
        -e ORDERER_GENERAL_CLUSTER_ROOTCAS=[$TLS_ROOTCERTS] \
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
