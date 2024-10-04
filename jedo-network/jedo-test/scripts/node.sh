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
set -Exeuo pipefail
ls scripts/node.sh || { echo "ScriptInfo: run this script from the root directory: ./scripts/node.sh"; exit 1; }


###############################################################
# Params - from ./config/network-config.yaml
###############################################################
CONFIG_FILE="./config/network-config.yaml"
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' "$CONFIG_FILE")
PEERS=$(yq e '.Network.Peers[] | .Name' $CONFIG_FILE)
PEERS_IP=$(yq e '.Network.Peers[] | .IP' $CONFIG_FILE)
PEERS_PORT1=$(yq e '.Network.Peers[] | .Port1' $CONFIG_FILE)
PEERS_PORT2=$(yq e '.Network.Peers[] | .Port2' $CONFIG_FILE)
PEERS_ORG=$(yq e '.Network.Peers[] | .Org' $CONFIG_FILE)
PEERS_CLI=$(yq e '.Network.Peers[] | .CLI' $CONFIG_FILE)
PEERS_DB_NAME=$(yq e '.Network.Peers[] | .DB.Name' $CONFIG_FILE)
PEERS_DB_IP=$(yq e '.Network.Peers[] | .DB.IP' $CONFIG_FILE)
PEERS_DB_PORT=$(yq e '.Network.Peers[] | .DB.Port' $CONFIG_FILE)
PEERS_DB_ADMIN=$(yq e '.Network.Peers[] | .DB.Admin.Name' $CONFIG_FILE)
PEERS_DB_ADMIN_PASS=$(yq e '.Network.Peers[] | .DB.Admin.Pass' $CONFIG_FILE)
ORDERERS=$(yq e '.Network.Orderers[] | .Name' $CONFIG_FILE)
ORDERERS_IP=$(yq e '.Network.Orderers[] | .IP' $CONFIG_FILE)
ORDERERS_PORT=$(yq e '.Network.Orderers[] | .Port' $CONFIG_FILE)
ORDERERS_ORG=$(yq e '.Network.Orderers[] | .Org' $CONFIG_FILE)
FIRST_ORDERER=$(yq e '.Network.Orderers[0].Name' $CONFIG_FILE)


###############################################################
# Function to test CouchDB
###############################################################
function ask_db() {
    while true; do
        container_status=$(docker ps -a --filter "name=$PEER_DB_NAME" --filter "status=running" --format "{{.Names}}")

        if [ "$container_status" == "$PEER_DB_NAME" ]; then
            echo "ScriptInfo: Docker-Container '$PEER_DB_NAME' running."

            # Check network
            container_network=$(docker inspect --format "{{json .NetworkSettings.Networks}}" "$PEER_DB_NAME" | jq -r "keys[] | select(. == \"$DOCKER_NETWORK_NAME\")")

            if [ -z "$container_network" ]; then
                # Container not in the network, try to connect
                docker network connect "$DOCKER_NETWORK_NAME" "$PEER_DB_NAME"
                # Check if successfull
                if [ $? -ne 0 ]; then
                    echo "ScriptError: Container '$PEER_DB_NAME' not in '$DOCKER_NETWORK_NAME' network."
                    exit 1
                fi
            fi

            # Standard port and custom port needs to be tested
            couchdb_status_default_port=$(curl -s --connect-timeout 5 -u "$PEER_DB_ADMIN:$PEER_DB_ADMIN_PASS" "http://$PEER_DB_IP:5984/_up" || echo "")
            couchdb_status_custom_port=$(curl -s --connect-timeout 5 -u "$PEER_DB_ADMIN:$PEER_DB_ADMIN_PASS" "http://$PEER_DB_IP:$PEER_DB_PORT/_up" || echo "")
            couchdb_port=""

            # Default port processing
            if [[ -n "$couchdb_status_default_port" ]]; then
                couchdb_status_default_port=$(echo "$couchdb_status_default_port" | jq -r '.status')
                if [[ "$couchdb_status_default_port" == "ok" ]]; then
                    couchdb_port="5984"
                fi
            fi

            # Custom port processing
            if [[ -n "$couchdb_status_custom_port" ]]; then
                couchdb_status_custom_port=$(echo "$couchdb_status_custom_port" | jq -r '.status')
                if [[ "$couchdb_status_custom_port" == "ok" ]]; then
                    couchdb_port="$PEER_DB_PORT"
                fi
            fi

            if [ "$couchdb_port" != "" ]; then
                echo "ScriptInfo: CouchDB at '$PEER_DB_IP:$couchdb_port' up and running."
                return 0
            else
                echo "ScriptError: CouchDB '$PEER_DB_IP' status is not ok"
            fi
        else
            echo "ScriptError: Docker Container '$PEER_DB_NAME' not running"
        fi
    
        # Instructions in case of any error
        echo "Instruction to install CouchDB:"
        echo
        echo "Container-Name: $PEER_DB_NAME"
        echo "Set docker network: $DOCKER_NETWORK_NAME"
        echo "IP:Port: $PEER_DB_IP:$PEER_DB_PORT"
        echo "Use spare data and config path for each DB (e.g. append DB name)."
        echo "Add variables for admin-account COUCHDB_USER=$PEER_DB_ADMIN and COUCHDB_PASSWORD=$PEER_DB_ADMIN_PASS"
        echo
        echo "Check DB, goto http://$PEER_DB_IP:$PEER_DB_PORT/_utils/ and log in with user $PEER_DB_ADMIN and password $PEER_DB_ADMIN_PASS"
        echo
        read -p "Do you want to try again? (Y/n) [Y]: " exit_response
        exit_response=${exit_response:-Y}
        exit_response=$(echo "$exit_response" | tr '[:upper:]' '[:lower:]')

        if [[ "$exit_response" != "y" ]]; then
            exit 1
        fi
    done
}

###############################################################
# Peers
###############################################################
for index in $(seq 0 $(($(echo "$PEERS" | wc -l) - 1))); do
    # Check CouchDB
    PEER_DB_NAME=$(echo "$PEERS_DB_NAME" | sed -n "$((index+1))p")
    PEER_DB_IP=$(echo "$PEERS_DB_IP" | sed -n "$((index+1))p")
    PEER_DB_PORT=$(echo "$PEERS_DB_PORT" | sed -n "$((index+1))p")
    PEER_DB_ADMIN=$(echo "$PEERS_DB_ADMIN" | sed -n "$((index+1))p")
    PEER_DB_ADMIN_PASS=$(echo "$PEERS_DB_ADMIN_PASS" | sed -n "$((index+1))p")
    echo "ScriptInfo: check CouchDB $PEER_DB_NAME"
    ask_db

    # Run Peer
    PEER=$(echo "$PEERS" | sed -n "$((index+1))p")
    PEER_IP=$(echo "$PEERS_IP" | sed -n "$((index+1))p")
    PEER_PORT1=$(echo "$PEERS_PORT1" | sed -n "$((index+1))p")
    PEER_PORT2=$(echo "$PEERS_PORT2" | sed -n "$((index+1))p")
    PEER_ORG=$(echo "$PEERS_ORG" | sed -n "$((index+1))p")
    PEER_CLI=$(echo "$PEERS_CLI" | sed -n "$((index+1))p")
    export FABRIC_CFG_PATH=./config

    echo "ScriptInfo: run peer $PEER"
    docker run -d \
    --name $PEER \
    --network $DOCKER_NETWORK_NAME \
    --ip $PEER_IP \
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/jedo-network/src/fabric_logo.png" \
    -e CORE_VM_ENDPOINT=unix:///var/run/docker.sock \
    -e CORE_PEER_ID=$PEER \
    -e CORE_PEER_LISTENADDRESS=0.0.0.0:$PEER_PORT1 \
    -e CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:$PEER_PORT2 \
    -e CORE_PEER_ADDRESS=$PEER:$PEER_PORT1 \
    -e CORE_PEER_LOCALMSPID=${PEER_ORG}MSP \
    -e CORE_PEER_GOSSIP_BOOTSTRAP=127.0.0.1:$PEER_PORT1 \
    -e CORE_PEER_GOSSIP_ENDPOINT=0.0.0.0:$PEER_PORT1 \
    -e CORE_PEER_GOSSIP_EXTERNALENDPOINT=0.0.0.0:$PEER_PORT1 \
    -e CORE_PEER_TLS_ENABLED=true \
    -e CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt \
    -e CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/server.key \
    -e CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt \
    -e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/peer/msp \
    -e CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=$PEER_DB_IP:$PEER_DB_PORT \
    -e CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=$PEER_DB_ADMIN \
    -e CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=$PEER_DB_ADMIN_PASS \
    -v $PWD/../fabric/config/core.yaml:/etc/hyperledger/fabric/core.yaml \
    -v $PWD/keys/$PEER_ORG/$PEER/msp:/etc/hyperledger/peer/msp \
    -v $PWD/keys/$PEER_ORG/$PEER/tls:/etc/hyperledger/fabric/tls \
    -v $PWD/production/$PEER:/var/hyperledger/production \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -p $PEER_PORT1:$PEER_PORT1 \
    -p $PEER_PORT2:$PEER_PORT2 \
    hyperledger/fabric-peer:latest
    docker logs $PEER

    # Run CLI only if IP is defined
    if [ -n "$PEER_CLI" ]; then
        echo "ScriptInfo: run cli $PEER"
        docker run -d \
        --name $PEER.cli \
        --network $DOCKER_NETWORK_NAME \
        --ip $PEER_CLI \
        --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/jedo-network/src/fabric_cli_logo.png" \
        -e GOPATH=/opt/gopath \
        -e CORE_PEER_ID=$PEER.cli \
        -e CORE_PEER_ADDRESS=$PEER:$PEER_PORT1 \
        -e CORE_PEER_LOCALMSPID=${PEER_ORG}MSP \
        -e CORE_PEER_TLS_ENABLED=true \
        -e CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt \
        -e CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt \
        -e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/peer/msp \
        -e FABRIC_LOGGING_SPEC=DEBUG \
        -v $PWD/keys/$PEER_ORG/$PEER/msp:/etc/hyperledger/peer/msp \
        -v $PWD/keys/$PEER_ORG/$PEER/tls:/etc/hyperledger/fabric/tls \
        -v $PWD/keys/$PEER_ORG/$FIRST_ORDERER/tls:/etc/hyperledger/orderer/tls \
        -v $PWD/production/$PEER:/var/hyperledger/production \
        -v $PWD/chaincode/$PEER:/opt/gopath/src/github.com/hyperledger/fabric/chaincode \
        -v $PWD:/tmp/jedo-network \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -w /opt/gopath/src/github.com/hyperledger/fabric \
        -it \
        hyperledger/fabric-tools:latest
    fi

done


###############################################################
# Orderers
###############################################################
for index in $(seq 0 $(($(echo "$ORDERERS" | wc -l) - 1))); do
    # Run Peer
    ORDERER=$(echo "$ORDERERS" | sed -n "$((index+1))p")
    ORDERER_IP=$(echo "$ORDERERS_IP" | sed -n "$((index+1))p")
    ORDERER_PORT=$(echo "$ORDERERS_PORT" | sed -n "$((index+1))p")
    ORDERER_ORG=$(echo "$ORDERERS_ORG" | sed -n "$((index+1))p")
    export FABRIC_CFG_PATH=./config

    echo "ScriptInfo: run orderer $ORDERER"
    docker run -d \
    --name $ORDERER \
    --network $DOCKER_NETWORK_NAME \
    --ip $ORDERER_IP \
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/jedo-network/src/fabric_logo.png" \
    -e ORDERER_GENERAL_LISTENADDRESS=0.0.0.0 \
    -e ORDERER_GENERAL_LISTENPORT=$ORDERER_PORT \
    -e ORDERER_GENERAL_GENESISMETHOD=file \
    -e ORDERER_GENERAL_GENESISFILE=/etc/hyperledger/fabric/genesis.block \
    -e ORDERER_GENERAL_LOCALMSPID=${ORDERER_ORG}MSP \
    -e ORDERER_GENERAL_LOCALMSPDIR=/etc/hyperledger/orderer/msp \
    -e ORDERER_GENERAL_TLS_ENABLED=true \
    -e ORDERER_GENERAL_TLS_CERTIFICATE=/etc/hyperledger/orderer/tls/server.crt \
    -e ORDERER_GENERAL_TLS_PRIVATEKEY=/etc/hyperledger/orderer/tls/server.key \
    -e ORDERER_GENERAL_TLS_ROOTCAS=[/etc/hyperledger/orderer/tls/ca.crt] \
    -v $PWD/../fabric/config/orderer.yaml:/etc/hyperledger/fabric/orderer.yaml \
    -v $PWD/configtx/genesis.block:/etc/hyperledger/fabric/genesis.block \
    -v $PWD/keys/$ORDERER_ORG/$ORDERER/msp:/etc/hyperledger/orderer/msp \
    -v $PWD/keys/$ORDERER_ORG/$ORDERER/tls:/etc/hyperledger/orderer/tls \
    -v $PWD/production/$ORDERER:/var/hyperledger/production \
    -p $ORDERER_PORT:$ORDERER_PORT \
    hyperledger/fabric-orderer:latest
    docker logs $ORDERER

done
