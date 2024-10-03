###############################################################
#!/bin/bash
#
# This script starts Hyperledger Fabric Peers
#
# Prerequisits:
#   - yq: 
#       - installation: sudo wget https://github.com/mikefarah/yq/releases/download/v4.6.3/yq_linux_amd64 -O /usr/local/bin/yq
#       - make it executable: chmod +x /usr/local/bin/yq
#
###############################################################
set -Exeuo pipefail
ls scripts/peer.sh || { echo "ScriptInfo: run this script from the root directory: ./scripts/peer.sh"; exit 1; }


###############################################################
# Params - from ./config/network-config.yaml
###############################################################
CONFIG_FILE="./config/network-config.yaml"
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' "$CONFIG_FILE")
PEERS=$(yq e '.Network.Peers[] | .Name' $CONFIG_FILE)
PEERS_IP=$(yq e '.Network.Peers[] | .IP' $CONFIG_FILE)
PEERS_PORT1=$(yq e '.Network.Peers[] | .Port1' $CONFIG_FILE)
PEERS_PORT2=$(yq e '.Network.Peers[] | .Port2' $CONFIG_FILE)
PEERS_ADMIN=$(yq e '.Network.Peers[] | .Admin.Name' $CONFIG_FILE)
PEERS_ADMIN_PASS=$(yq e '.Network.Peers[] | .Admin.Pass' $CONFIG_FILE)
PEERS_ADMIN_ORG_NAME=$(yq e '.Network.Peers[] | .Admin.Org.Name' $CONFIG_FILE)
PEERS_ADMIN_ORG_MSP=$(yq e '.Network.Peers[] | .Admin.Org.MSP' $CONFIG_FILE)
PEERS_DB_NAME=$(yq e '.Network.Peers[] | .DB.Name' $CONFIG_FILE)
PEERS_DB_IP=$(yq e '.Network.Peers[] | .DB.IP' $CONFIG_FILE)
PEERS_DB_PORT=$(yq e '.Network.Peers[] | .DB.Port' $CONFIG_FILE)
PEERS_DB_ADMIN=$(yq e '.Network.Peers[] | .DB.Admin.Name' $CONFIG_FILE)
PEERS_DB_ADMIN_PASS=$(yq e '.Network.Peers[] | .DB.Admin.Pass' $CONFIG_FILE)




## not used
NETWORK_CA_NAME=$(yq eval '.Network.CA.Name' "$CONFIG_FILE")
NETWORK_CA_PORT=$(yq eval '.Network.CA.Port' "$CONFIG_FILE")
NETWORK_CA_ADMIN_NAME=$(yq eval '.Network.CA.Admin.Name' "$CONFIG_FILE")
NETWORK_CA_ADMIN_PASS=$(yq eval '.Network.CA.Admin.Pass' "$CONFIG_FILE")
FSCS=$(yq e '.Network.FSCs[] | .Name' $CONFIG_FILE)
FSCS_PASSWORD=$(yq e '.Network.FSCs[] | .Pass' $CONFIG_FILE)
FSCS_OWNER=$(yq e '.Network.FSCs[] | .Owner' $CONFIG_FILE)
AUDITORS=$(yq e '.Network.Auditors[] | .Name' $CONFIG_FILE)
AUDITORS_PASSWORD=$(yq e '.Network.Auditors[] | .Pass' $CONFIG_FILE)
AUDITORS_OWNER=$(yq e '.Network.Auditors[] | .Owner' $CONFIG_FILE)
ISSUERS=$(yq e '.Network.Issuers[] | .Name' $CONFIG_FILE)
ISSUERS_PASSWORD=$(yq e '.Network.Issuers[] | .Pass' $CONFIG_FILE)
ISSUERS_OWNER=$(yq e '.Network.Issuers[] | .Owner' $CONFIG_FILE)
USERS=$(yq e '.Network.Users[] | .Name' $CONFIG_FILE)
USERS_PASSWORD=$(yq e '.Network.Users[] | .Pass' $CONFIG_FILE)
USERS_OWNER=$(yq e '.Network.Users[] | .Owner' $CONFIG_FILE)


###############################################################
# Function to test CouchDB
###############################################################
function ask_db() {
    while true; do
        container_status=$(docker ps -a --filter "name=$PEER_DB_NAME" --filter "status=running" --format "{{.Names}}")

        if [ "$container_status" == "$PEER_DB_NAME" ]; then
            echo "ScriptInfo: Docker-Container '$PEER_DB_NAME' running."

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
    # TODO: Check DockerContainer or set it with: docker network connect DOCKER_NETWORK_NAME $PEER_DB_NAME
}


for index in $(seq 0 $(($(echo "$PEERS" | wc -l) - 1))); do
    ###############################################################
    # Check CouchDB
    ###############################################################
    echo "ScriptInfo: check CouchDB"
    PEER_DB_NAME=$(echo "$PEERS_DB_NAME" | sed -n "$((index+1))p")
    PEER_DB_IP=$(echo "$PEERS_DB_IP" | sed -n "$((index+1))p")
    PEER_DB_PORT=$(echo "$PEERS_DB_PORT" | sed -n "$((index+1))p")
    PEER_DB_ADMIN=$(echo "$PEERS_DB_ADMIN" | sed -n "$((index+1))p")
    PEER_DB_ADMIN_PASS=$(echo "$PEERS_DB_ADMIN_PASS" | sed -n "$((index+1))p")
    echo "ScriptInfo: check CouchDB $PEER_DB_NAME"

    ask_db


    ###############################################################
    # Run Peer
    ###############################################################
    PEER=$(echo "$PEERS" | sed -n "$((index+1))p")
    PEER_IP=$(echo "$PEERS_IP" | sed -n "$((index+1))p")
    PEER_PORT1=$(echo "$PEERS_PORT1" | sed -n "$((index+1))p")
    PEER_PORT2=$(echo "$PEERS_PORT2" | sed -n "$((index+1))p")
    PEER_ADMIN_ORG_NAME=$(echo "$PEERS_ADMIN_ORG_NAME" | sed -n "$((index+1))p")
    PEER_ADMIN_ORG_MSP=$(echo "$PEERS_ADMIN_ORG_MSP" | sed -n "$((index+1))p")
    echo "ScriptInfo: run peer $PEER"

    export FABRIC_CFG_PATH=./config

    docker run -d \
    --name $PEER \
    --network $DOCKER_NETWORK_NAME \
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/jedo-network/src/fabric_logo.png" \
    -e CORE_VM_ENDPOINT=unix:///var/run/docker.sock \
    -e CORE_PEER_ID=$PEER \
    -e CORE_PEER_LISTENADDRESS=0.0.0.0:$PEER_PORT1 \
    -e CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:$PEER_PORT2 \
    -e CORE_PEER_ADDRESS=$PEER:$PEER_PORT1 \
    -e CORE_PEER_LOCALMSPID=$PEER_ADMIN_ORG_MSP \
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
    -v /mnt/user/appdata/fabric/config/core.yaml:/etc/hyperledger/fabric/core.yaml \
    -v ${PWD}/crypto-config/peerOrganizations/$PEER_ADMIN_ORG_NAME/peers/$PEER/msp:/etc/hyperledger/peer/msp \
    -v ${PWD}/crypto-config/peerOrganizations/$PEER_ADMIN_ORG_NAME/peers/$PEER/tls:/etc/hyperledger/fabric/tls \
    -v ${PWD}/production/$PEER:/var/hyperledger/production \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -p $PEER_PORT1:$PEER_PORT1 \
    -p $PEER_PORT2:$PEER_PORT2 \
    hyperledger/fabric-peer:latest

    docker logs $PEER


    ###############################################################
    # Run CLI
    ###############################################################
    echo "ScriptInfo: run cli $PEER"

    docker run -d \
    --name $PEER.cli \
    --network $DOCKER_NETWORK_NAME \
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/jedo-network/src/fabric_logo.png" \
    -e GOPATH=/opt/gopath \
    -e CORE_PEER_ID=$PEER.cli \
    -e CORE_PEER_ADDRESS=$PEER:$PEER_PORT1 \
    -e CORE_PEER_LOCALMSPID=$PEER_ADMIN_ORG_MSP \
    -e CORE_PEER_TLS_ENABLED=true \
    -e CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt \
    -e CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt \
    -e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/peer/msp \
    -e FABRIC_LOGGING_SPEC=DEBUG \
    -v ${PWD}/crypto-config/peerOrganizations/$PEER_ADMIN_ORG_NAME/peers/$PEER/tls:/etc/hyperledger/fabric/tls \
    -v ${PWD}/crypto-config/peerOrganizations/$PEER_ADMIN_ORG_NAME/users/Admin@$PEER/msp:/etc/hyperledger/peer/msp \
    -v ${PWD}/chaincode:/opt/gopath/src/github.com/hyperledger/fabric/chaincode \
    -v ${PWD}/production:/var/hyperledger/production \
    -v ${PWD}:/tmp/jedo-network \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -w /opt/gopath/src/github.com/hyperledger/fabric \
    -it \
    hyperledger/fabric-tools:latest
# TODO: Check if mount is needed
#    -v ${PWD}/crypto-config/ordererOrganizations/test.jedo.btc/orderers/orderer.test.jedo.btc/tls:/etc/hyperledger/orderer/tls \


done


