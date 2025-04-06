###############################################################
#!/bin/bash
#
# This script creates Channel
#
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/ccutils.sh"
check_script


###############################################################
# Params - from ./configinfrastructure-cc.yaml
###############################################################
CONFIG_FILE="$SCRIPT_DIR/infrastructure-cc.yaml"
FABRIC_BIN_PATH=$(yq eval '.Fabric.Path' "$CONFIG_FILE")
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $CONFIG_FILE)
ORBIS=$(yq eval ".Orbis.Name" "$CONFIG_FILE")

get_hosts


###############################################################
# Function writeDockerfile
###############################################################
writeDockerfile() {
    echo ""
    echo_info "Dockerfile for tokenchaincode writing..."
cat <<EOF > $CC_SRC_PATH/dockerfile_tcc
FROM golang:1.23 as builder
RUN git clone https://github.com/hyperledger-labs/fabric-token-sdk.git
WORKDIR fabric-token-sdk 

# Change the hash to checkout a different commit / version. It should be the same as in app/go.mod.
RUN git checkout v0.3.0 && go mod download
RUN CGO_ENABLED=1 go build -buildvcs=false -o /tcc token/services/network/fabric/tcc/main/main.go && chmod +x /tcc

# Final image
FROM golang:1.23
COPY --from=builder /tcc .
EXPOSE 9999

# zkatdlog is the output of the tokengen command. It contains the certificates 
# of the issuer and auditor and the CA that issues owner account credentials,
# as well as cryptographic curves needed by the chaincode to verify proofs.
# It is generated once to initialize the network, when the 'init' function is
# invoked on the chaincode.
ENV PUBLIC_PARAMS_FILE_PATH=/zkatdlog_pp.json
ADD zkatdlog_pp.json /zkatdlog_pp.json

CMD [ "./tcc"]
EOF
}


###############################################################
# Function buildDockerImages
###############################################################
buildDockerImages() {
    echo ""
    echo_info "Building Chaincode-as-a-Service docker image '${CC_NAME}' '${CC_SRC_PATH}'"
    echo_info "This may take several minutes..."
    docker build \
        -f $CC_SRC_PATH/dockerfile_tcc \
        -t ${CC_NAME}_ccaas_image:latest \
        --build-arg CC_SERVER_PORT=9999 \
        $CC_SRC_PATH
}



###############################################################
# Deploy CCAAS
###############################################################
REGNUMS=$(yq e ".Regnum[].Name" $CONFIG_FILE)
for REGNUM in $REGNUMS; do
    echo ""
    echo_warn "CCAAS for $REGNUM running..."

    CHANNEL_NAME=$REGNUM
    CC_NAME="tcc"
    CC_SRC_PATH=${PWD}/infrastructure/$ORBIS/$REGNUM/configuration
    CCAAS_DOCKER_RUN="true"
    CC_VERSION="1.0"
    CC_SEQUENCE="1"
    CC_INIT_FCN="init"
    CC_END_POLICY=""
    CC_COLL_CONFIG=""
    DELAY="3"
    MAX_RETRY="5"
    VERBOSE="false"

    CCAAS_SERVER_PORT=9999

    PEER_CONN_PARMS=()

    echo_info "executing with the following"
    echo_info "- CHANNEL_NAME: ${GREEN}${CHANNEL_NAME}${NC}"
    echo_info "- CC_NAME: ${GREEN}${CC_NAME}${NC}"
    echo_info "- CC_SRC_PATH: ${GREEN}${CC_SRC_PATH}${NC}"
    echo_info "- CC_VERSION: ${GREEN}${CC_VERSION}${NC}"
    echo_info "- CC_SEQUENCE: ${GREEN}${CC_SEQUENCE}${NC}"
    echo_info "- CC_END_POLICY: ${GREEN}${CC_END_POLICY}${NC}"
    echo_info "- CC_COLL_CONFIG: ${GREEN}${CC_COLL_CONFIG}${NC}"
    echo_info "- CC_INIT_FCN: ${GREEN}${CC_INIT_FCN}${NC}"
    echo_info "- CCAAS_DOCKER_RUN: ${GREEN}${CCAAS_DOCKER_RUN}${NC}"
    echo_info "- DELAY: ${GREEN}${DELAY}${NC}"
    echo_info "- MAX_RETRY: ${GREEN}${MAX_RETRY}${NC}"
    echo_info "- VERBOSE: ${GREEN}${VERBOSE}${NC}"

    FABRIC_CFG_PATH=$PWD/../../fabric/config/

    # Install chaincode on peers
    AGERS=$(yq eval ".Ager[] | select(.Administration.Parent == \"$REGNUM\") | .Name" $CONFIG_FILE)
    for AGER in $AGERS; do
        # Loop all orderer (if any), but only 1 needed to approve chaincode for AGER
        ORDERERS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[].Name" $CONFIG_FILE)
        for ORDERER in $ORDERERS; do
            ORDERER_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .IP" $CONFIG_FILE)
            ORDERER_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Port" $CONFIG_FILE)
            ORDERER_ADDRESS=$ORDERER_IP:$ORDERER_PORT
            ORDERER_TLSCACERT_FILE=$(basename $(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$ORDERER/tls/tlscacerts/*.pem))
            ORDERER_TLSCACERT=${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$ORDERER/tls/tlscacerts/$ORDERER_TLSCACERT_FILE

        done
        PEERS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[].Name" $CONFIG_FILE)
        for PEER in $PEERS; do
            echo ""
            echo_warn "Chaincode on $PEER installing..."
            PEER_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .IP" $CONFIG_FILE)
            PEER_PORT1=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .Port1" $CONFIG_FILE)
            PEER_ADDRESS=$PEER_IP:$PEER_PORT1
            TLS_TLSCACERT_FILE=$(basename $(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER/tls/tlscacerts/*.pem))
            PEER_ROOTCERT=${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER/tls/tlscacerts/$TLS_TLSCACERT_FILE

            # package the chaincode
            PACKAGE_ID=$(packageChaincode $PEER $CC_NAME $CC_VERSION $CCAAS_SERVER_PORT)
            echo_info "Package-ID für $PEER: ${GREEN}$PACKAGE_ID${NC}!!!"

            # install and approve the chaincode
            installChaincode $ORBIS $REGNUM $AGER $PEER $PEER_ADDRESS $PEER_ROOTCERT $ORDERER_ADDRESS $ORDERER_TLSCACERT
            echo_ok "Chaincode on $PEER installed..."

            # set peer connection parameters for later
            PEER_CONN_PARMS=("${PEER_CONN_PARMS[@]}" --peerAddresses $PEER_ADDRESS)
            PEER_CONN_PARMS=("${PEER_CONN_PARMS[@]}" --tlsRootCertFiles $PEER_ROOTCERT)
        done
    done

    # Committing chaincode 
    echo_warn "Chaincode committing"
    echo_info "executing with the following"
    echo_info "- PEER_CONN_PARMS: ${GREEN}${PEER_CONN_PARMS[@]}${NC}"
    # do commit
    peer lifecycle chaincode commit -o $ORDERER_ADDRESS --tls --cafile "$ORDERER_TLSCACERT" \
      --channelID $CHANNEL_NAME --name ${CC_NAME} "${PEER_CONN_PARMS[@]}" --version ${CC_VERSION} \
      --sequence ${CC_SEQUENCE} --init-required ${CC_INIT_FCN} ${CC_END_POLICY} ${CC_COLL_CONFIG}
    # query committed
    peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name ${CC_NAME}
    echo_ok "Chaincode committed"
 
    # Write the Dockerfile in the configuration-folder
    writeDockerfile

    # Build the docker image 
    CONTAINER_CLI="docker compose"
    buildDockerImages

    # Start CCAAS Docker containers
#    AGERS_2=$(yq eval ".Ager[] | select(.Administration.Parent == \"$REGNUM\") | .Name" $CONFIG_FILE)
    for AGER in $AGERS; do
        CCAAS_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CCAAS.Name" $CONFIG_FILE)
        CCAAS_NAME=${PEER}_${CC_NAME}_ccaas
        CCAAS_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CCAAS.IP" $CONFIG_FILE)
        CCAAS_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CCAAS.Port" $CONFIG_FILE)
        PEERS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[].Name" $CONFIG_FILE)
        for PEER in $PEERS; do
            echo_warn "CCAAS $CCAAS_NAME starting..."
            docker run -d \
                --name $CCAAS_NAME \
                --network $DOCKER_NETWORK_NAME \
                --ip $CCAAS_IP \
                $hosts_args \
                --restart=on-failure:1 \
                --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/infrastructure/src/fabric_logo.png" \
                -p $CCAAS_PORT:9999 \
                -e CHAINCODE_SERVER_ADDRESS=$CCAAS_IP:$CCAAS_PORT \
                -e CHAINCODE_ID=$PACKAGE_ID \
                -e CORE_CHAINCODE_ID_NAME=$PACKAGE_ID \
                ${CC_NAME}_ccaas_image:latest

            CheckContainer "$CCAAS_NAME" "$DOCKER_CONTAINER_WAIT"
            CheckContainerLog "$CCAAS_NAME" "Running Token Chaincode as service" "$DOCKER_CONTAINER_WAIT"
        done
        echo_ok "CCAAS $CCAAS_NAME started."
    done

    # Invoking chaincode
#    AGERS_3=$(yq eval ".Ager[] | select(.Administration.Parent == \"$REGNUM\") | .Name" $CONFIG_FILE)
    for AGER in $AGERS; do
        PEERS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[].Name" $CONFIG_FILE)
        for PEER in $PEERS; do
            echo_warn "Chaincode invokeing..."
            # Loop all orderer (if any), but only 1 needed to approve chaincode for AGER
            ORDERERS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[].Name" $CONFIG_FILE)
            for ORDERER in $ORDERERS; do
                ORDERER_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .IP" $CONFIG_FILE)
                ORDERER_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Port" $CONFIG_FILE)
                ORDERER_ADDRESS=$ORDERER_IP:$ORDERER_PORT
                ORDERER_TLSCACERT_FILE=$(basename $(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$ORDERER/tls/tlscacerts/*.pem))
                ORDERER_TLSCACERT=${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$ORDERER/tls/tlscacerts/$ORDERER_TLSCACERT_FILE
            done
            fcn_call='{"function":"'${CC_INIT_FCN}'","Args":[]}'
            peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile "$ORDERER_TLSCACERT" \
                -C $CHANNEL_NAME -n ${CC_NAME} "${PEER_CONN_PARMS[@]}" --isInit -c ${fcn_call}
            echo_ok "Chaincode invoked."
        done
    done
done






exit 0



# Install and start tokenchaincode as a service
#INIT_REQUIRED="--init-required" "$TEST_NETWORK_HOME/network.sh" deployCCAAS  -ccn tokenchaincode -ccp "$(pwd)/tokenchaincode" -cci "init" -ccs 1

# function deployCCAAS() {
#   scripts/deployCCAAS.sh $CHANNEL_NAME $CC_NAME $CC_SRC_PATH $CCAAS_DOCKER_RUN $CC_VERSION $CC_SEQUENCE $CC_INIT_FCN $CC_END_POLICY $CC_COLL_CONFIG $CLI_DELAY $MAX_RETRY $VERBOSE $CCAAS_DOCKER_RUN
#   ccn --> CC_NAME --> "tokenchaincode"
#   ccp --> CC_SRC_PATH --> "$(pwd)/tokenchaincode"
#   cci --> CC_INIT_FCN --> "init"
#   ccs --> CC_SEQUENCE --> 1

