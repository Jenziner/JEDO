#!/bin/bash
#
# This script deploys jedo-wallet chaincode as CCAAS
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/ccutils.sh"
check_script


###############################################################
# Params - from ./infrastructure-cc.yaml
###############################################################
CONFIG_FILE="$SCRIPT_DIR/infrastructure-cc.yaml"
FABRIC_BIN_PATH=$(yq eval '.Fabric.Path' "$CONFIG_FILE")
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $CONFIG_FILE)
ORBIS=$(yq eval ".Orbis.Name" "$CONFIG_FILE")

get_hosts


###############################################################
# Setup Admin Environment für peer Commands
###############################################################
setupAdminEnv() {
    AGER=$1
    
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID=$AGER
    export CORE_PEER_MSPCONFIGPATH=${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/admin.$AGER.$REGNUM.jedo.cc/msp
    export CORE_PEER_ADDRESS=$PEER_ADDRESS
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER_ROOTCERT
    
    echo_info "Admin environment set for $AGER"
    echo_info "- MSPID: ${GREEN}${CORE_PEER_LOCALMSPID}${NC}"
    echo_info "- MSPConfigPath: ${GREEN}${CORE_PEER_MSPCONFIGPATH}${NC}"
    echo_info "- Address: ${GREEN}${CORE_PEER_ADDRESS}${NC}"
}


###############################################################
# Function buildDockerImages
###############################################################
buildDockerImages() {
    echo ""
    echo_info "Building Chaincode-as-a-Service docker image '${CC_NAME}'"
    echo_info "This may take a minute..."
    
    cd "${PWD}"
    
    docker build \
        -t ${CC_NAME}_ccaas_image:${CC_VERSION} \
        ./chaincode
    
    if [ $? -ne 0 ]; then
        echo_error "Docker build failed"
        exit 1
    fi
    
    echo_ok "Docker image built: ${CC_NAME}_ccaas_image:${CC_VERSION}"
}


###############################################################
# Deploy CCAAS
###############################################################
REGNUMS=$(yq e ".Regnum[].Name" $CONFIG_FILE)
for REGNUM in $REGNUMS; do
    echo ""
    echo_warn "CCAAS for $REGNUM deploying..."

    FABRIC_CFG_PATH=/etc/hyperledger/fabric  # ⬅️ Container Path!
    PEER_ADDRESSES=()
    TLS_ROOT_CERT_FILES=()

    CHANNEL_NAME=$REGNUM
    CC_NAME="jedo-wallet"
    CC_SRC_PATH=/opt/gopath/src/github.com/hyperledger/fabric/chaincode  # ⬅️ Container Path!
    CCAAS_DOCKER_RUN="true"
    CC_VERSION="1.0"
    CC_SEQUENCE="1"
    CC_INIT_FCN="InitLedger"
    CC_END_POLICY=""
    CC_COLL_CONFIG=""
    DELAY="3"
    MAX_RETRY="5"
    VERBOSE="false"

    # Build the docker image 
    buildDockerImages

    # Install chaincode on peers
    AGERS=$(yq eval ".Ager[] | select(.Administration.Parent == \"$REGNUM\") | .Name" $CONFIG_FILE)
    for AGER in $AGERS; do
        # Loop all orderer
        ORDERERS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[].Name" $CONFIG_FILE)
        for ORDERER in $ORDERERS; do
            ORDERER_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .IP" $CONFIG_FILE)
            ORDERER_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Port" $CONFIG_FILE)
            ORDERER_ADDRESS=$ORDERER_IP:$ORDERER_PORT
            ORDERER_TLSCACERT_CONTAINER="/etc/hyperledger/orderer/tls/tlscacerts/tls-ca-cert.pem"  # ⬅️ Container Path!
        done
        
        PEERS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[].Name" $CONFIG_FILE)
        for PEER in $PEERS; do
            echo ""
            echo_warn "Chaincode on $PEER installing..."
            PEER_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .IP" $CONFIG_FILE)
            PEER_PORT1=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .Port1" $CONFIG_FILE)
            PEER_ADDRESS=$PEER_IP:$PEER_PORT1
            PEER_ADDRESSES+=("--peerAddresses" "$PEER_ADDRESS")
            
            # ⬅️ Container Path für TLS Cert: identisch wie beim Peer-Start!
            TLS_TLSCACERT_FILE=$(basename $(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER/tls/tlscacerts/*.pem))
            PEER_ROOTCERT_CONTAINER="/etc/hyperledger/fabric/tls/tlscacerts/$TLS_TLSCACERT_FILE"
            TLS_ROOT_CERT_FILES+=("--tlsRootCertFiles" "$PEER_ROOTCERT_CONTAINER")

            CCAASS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .CCAAS[].Name" $CONFIG_FILE)
            for CCAAS in $CCAASS; do
                CCAAS_NAME=$CCAAS
                CCAAS_SERVER=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .CCAAS[] | select(.Name == \"$CCAAS\") | .Server" $CONFIG_FILE)
                CCAAS_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .CCAAS[] | select(.Name == \"$CCAAS\") | .IP" $CONFIG_FILE)
                CCAAS_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .CCAAS[] | select(.Name == \"$CCAAS\") | .Port" $CONFIG_FILE)

                echo_info "Executing with the following:"
                echo_info "- CHANNEL_NAME: ${GREEN}${CHANNEL_NAME}${NC}"
                echo_info "- CC_VERSION: ${GREEN}${CC_VERSION}${NC}"
                echo_info "- CC_SEQUENCE: ${GREEN}${CC_SEQUENCE}${NC}"
                echo_info "- CCAAS Name: ${GREEN}${CCAAS_NAME}${NC}"
                echo_info "- CCAAS Server: ${CCAAS_SERVER}${NC}"

                PACKAGE_ID=$(packageChaincode $PEER $CCAAS_NAME $CC_VERSION $CCAAS_SERVER $CCAAS_PORT)
                echo_info "Package-ID für $PEER: ${GREEN}$PACKAGE_ID${NC}"

                # install and approve the chaincode
                installChaincode $CCAAS_NAME $ORBIS $REGNUM $AGER $PEER $PEER_ADDRESS $ORDERER_ADDRESS
                echo_ok "Chaincode on $PEER installed..."

                # Start CCAAS Docker container
                docker stop $CCAAS_SERVER 2>/dev/null || true
                docker rm $CCAAS_SERVER 2>/dev/null || true
                
                docker run -d \
                    --name $CCAAS_SERVER \
                    --hostname $CCAAS_SERVER \
                    --network $DOCKER_NETWORK_NAME \
                    --ip $CCAAS_IP \
                    $hosts_args \
                    --restart=unless-stopped \
                    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/infrastructure/src/fabric_logo.png" \
                    -p $CCAAS_PORT:$CCAAS_PORT \
                    -e CHAINCODE_SERVER_ADDRESS=0.0.0.0:$CCAAS_PORT \
                    -e CHAINCODE_ID=$PACKAGE_ID \
                    -e CORE_CHAINCODE_ID_NAME=$PACKAGE_ID \
                    -e CORE_CHAINCODE_LOGGING_LEVEL=info \
                    ${CC_NAME}_ccaas_image:${CC_VERSION}

                CheckContainer "$CCAAS_SERVER" "$DOCKER_CONTAINER_WAIT"
                echo_ok "CCAAS $CCAAS_SERVER started."
            done
        done
        
        # Für Single-Peer-Setup Arrays explizit auf den letzten Peer setzen
        PEER_ADDRESSES=(--peerAddresses "$PEER_ADDRESS")
        TLS_ROOT_CERT_FILES=(--tlsRootCertFiles "$PEER_ROOTCERT_CONTAINER")

        # ✅ Committing chaincode via docker exec!
        echo_warn "Chaincode committing..."
        
        docker exec \
          -e CORE_PEER_TLS_ENABLED=true \
          -e CORE_PEER_LOCALMSPID=$AGER \
          -e CORE_PEER_MSPCONFIGPATH=/var/hyperledger/infrastructure/$ORBIS/$REGNUM/$AGER/admin.$AGER.$REGNUM.jedo.cc/msp \
          -e CORE_PEER_ADDRESS=$PEER_ADDRESS \
          -e CORE_PEER_TLS_ROOTCERT_FILE=$PEER_ROOTCERT_CONTAINER \
          $PEER peer lifecycle chaincode commit \
            -o $ORDERER_ADDRESS \
            --tls \
            --cafile "$ORDERER_TLSCACERT_CONTAINER" \
            --channelID $CHANNEL_NAME \
            --name ${CC_NAME} \
            "${PEER_ADDRESSES[@]}" \
            "${TLS_ROOT_CERT_FILES[@]}" \
            --version ${CC_VERSION} \
            --sequence ${CC_SEQUENCE} \
            ${CC_INIT_FCN:+--init-required} \
            ${CC_END_POLICY} \
            ${CC_COLL_CONFIG}

        if [ $? -ne 0 ]; then
            echo_error "Chaincode commit failed"
            exit 1
        fi

        # ✅ Query committed via docker exec!
        docker exec \
          -e CORE_PEER_TLS_ENABLED=true \
          -e CORE_PEER_LOCALMSPID=$AGER \
          -e CORE_PEER_MSPCONFIGPATH=/var/hyperledger/infrastructure/$ORBIS/$REGNUM/$AGER/admin.$AGER.$REGNUM.jedo.cc/msp \
          -e CORE_PEER_ADDRESS=$PEER_ADDRESS \
          $PEER peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name ${CC_NAME}
        
        echo_ok "Chaincode committed"

        # ✅ Invoking chaincode via docker exec!
        echo_warn "Chaincode invoking InitLedger..."
        rc=1
        COUNTER=1
        fcn_call='{"function":"'${CC_INIT_FCN}'","Args":[]}'


        while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
            sleep $DELAY
            echo_warn "Chaincode invoking (attempt $COUNTER of $MAX_RETRY)..."
            
            docker exec \
              -e CORE_PEER_TLS_ENABLED=true \
              -e CORE_PEER_LOCALMSPID=$AGER \
              -e CORE_PEER_MSPCONFIGPATH=/var/hyperledger/infrastructure/$ORBIS/$REGNUM/$AGER/admin.$AGER.$REGNUM.jedo.cc/msp \
              -e CORE_PEER_ADDRESS=$PEER_ADDRESS \
              -e CORE_PEER_TLS_ROOTCERT_FILE=$PEER_ROOTCERT_CONTAINER \
              $PEER peer chaincode invoke \
                -o $ORDERER_ADDRESS \
                --tls \
                --cafile "$ORDERER_TLSCACERT_CONTAINER" \
                -C $CHANNEL_NAME \
                -n ${CC_NAME} \
                "${PEER_ADDRESSES[@]}" \
                "${TLS_ROOT_CERT_FILES[@]}" \
                --isInit \
                -c ${fcn_call}
            
            rc=$?
            COUNTER=$((COUNTER + 1))
        done

        if [ $rc -eq 0 ]; then
            echo_ok "Chaincode invoked successfully."
        else
            echo_error "Chaincode invoke failed after $MAX_RETRY attempts."
            exit 1
        fi
    done

    echo_ok "Chaincode deployment completed for $REGNUM!"
done


###############################################################
# Summary
###############################################################
echo ""
echo_ok "=========================================="
echo_ok "Deployment Summary"
echo_ok "=========================================="
echo_ok "Chaincode: ${CC_NAME}"
echo_ok "Version: ${CC_VERSION}"
echo_ok "Sequence: ${CC_SEQUENCE}"
echo_ok "Channels deployed: ${REGNUMS}"
echo_ok "=========================================="
