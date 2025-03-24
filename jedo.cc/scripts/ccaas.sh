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
ORBIS=$(yq eval ".Orbis.Name" "$CONFIG_FILE")


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
# Function startDockerContainer
###############################################################
startDockerContainer() {
  # start the docker container

#From Plexi:
docker run -d \
--name tokenchaincode_container \
-p 9999:9999 \
-v /etc/hyperledger/fabric-ca-client/infrastructure:/etc/hyperledger/fabric-ca-client/infrastructure \
-e CC_SERVER_PORT=9999 \
--restart unless-stopped \
tokenchaincode_ccaas_image:latest

#From TokenSDK-Sample
#   if [ "$CCAAS_DOCKER_RUN" = "true" ]; then
#     echo_info "Starting the Chaincode-as-a-Service docker container..."
#     set -x
#     ${CONTAINER_CLI} run --rm -d --name peer0org1_${CC_NAME}_ccaas  \
#                   --network fabric_test \
#                   -e CHAINCODE_SERVER_ADDRESS=0.0.0.0:${CCAAS_SERVER_PORT} \
#                   -e CHAINCODE_ID=$PACKAGE_ID -e CORE_CHAINCODE_ID_NAME=$PACKAGE_ID \
#                     ${CC_NAME}_ccaas_image:latest

#     ${CONTAINER_CLI} run  --rm -d --name peer0org2_${CC_NAME}_ccaas \
#                   --network fabric_test \
#                   -e CHAINCODE_SERVER_ADDRESS=0.0.0.0:${CCAAS_SERVER_PORT} \
#                   -e CHAINCODE_ID=$PACKAGE_ID -e CORE_CHAINCODE_ID_NAME=$PACKAGE_ID \
#                     ${CC_NAME}_ccaas_image:latest
#     res=$?
#     { set +x; } 2>/dev/null
#     cat log.txt
#     verifyResult $res "Failed to start the container container '${CC_NAME}_ccaas_image:latest' "
#     echo_ok "Docker container started succesfully '${CC_NAME}_ccaas_image:latest'" 
#   else
  
#     echo_info "Not starting docker containers; these are the commands we would have run"
#     echo_info "    ${CONTAINER_CLI} run --rm -d --name peer0org1_${CC_NAME}_ccaas  \
#                   --network fabric_test \
#                   -e CHAINCODE_SERVER_ADDRESS=0.0.0.0:${CCAAS_SERVER_PORT} \
#                   -e CHAINCODE_ID=$PACKAGE_ID -e CORE_CHAINCODE_ID_NAME=$PACKAGE_ID \
#                     ${CC_NAME}_ccaas_image:latest"
#     echo_info "    ${CONTAINER_CLI} run --rm -d --name peer0org2_${CC_NAME}_ccaas  \
#                   --network fabric_test \
#                   -e CHAINCODE_SERVER_ADDRESS=0.0.0.0:${CCAAS_SERVER_PORT} \
#                   -e CHAINCODE_ID=$PACKAGE_ID -e CORE_CHAINCODE_ID_NAME=$PACKAGE_ID \
#                     ${CC_NAME}_ccaas_image:latest"

#   fi
}


###############################################################
# Deploy CCAAS
###############################################################



REGNUMS=$(yq e ".Regnum[].Name" $CONFIG_FILE)
for REGNUM in $REGNUMS; do
    echo ""
    echo_warn "CCAAS for $REGNUM running..."

    CHANNEL_NAME=$REGNUM
    CC_NAME="tokenchaincode"
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

    # Write the Dockerfile in the configuration-folder
    writeDockerfile

    # Build the docker image 
    CONTAINER_CLI="docker compose"
    buildDockerImages

    # Install chaincode on peers
    AGERS=$(yq eval ".Ager[] | select(.Administration.Parent == \"$REGNUM\") | .Name" $CONFIG_FILE)
    for AGER in $AGERS; do
        PEERS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[].Name" $CONFIG_FILE)
        for PEER in $PEERS; do
            echo ""
            echo_warn "Chaincode on $PEER installing..."
            PEER_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .IP" $CONFIG_FILE)
            PEER_PORT1=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .Port1" $CONFIG_FILE)
            TLS_TLSCACERT_FILE=$(basename $(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER/tls/tlscacerts/*.pem))
            PEER_ROOTCERT=${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER/tls/tlscacerts/$TLS_TLSCACERT_FILE
            # package the chaincode
            PACKAGE_ID=$(packageChaincode $PEER $CC_NAME $CC_VERSION $CCAAS_SERVER_PORT)
            echo_info "Package-ID für $PEER: ${GREEN}$PACKAGE_ID${NC}!!!"
            # install the chaincode
            installChaincode $ORBIS $REGNUM $AGER $PEER $PEER_IP $PEER_PORT1 $PEER_ROOTCERT
        done
    done
done






exit 0



# Install and start tokenchaincode as a service
INIT_REQUIRED="--init-required" "$TEST_NETWORK_HOME/network.sh" deployCCAAS  -ccn tokenchaincode -ccp "$(pwd)/tokenchaincode" -cci "init" -ccs 1

function deployCCAAS() {
  scripts/deployCCAAS.sh $CHANNEL_NAME $CC_NAME $CC_SRC_PATH $CCAAS_DOCKER_RUN $CC_VERSION $CC_SEQUENCE $CC_INIT_FCN $CC_END_POLICY $CC_COLL_CONFIG $CLI_DELAY $MAX_RETRY $VERBOSE $CCAAS_DOCKER_RUN

# Build the docker image 
#buildDockerImages

## package the chaincode
#packageChaincode

## Install chaincode on peer0.org1 and peer0.org2
#infoln "Installing chaincode on peer0.org1..."
#installChaincode 1
#infoln "Install chaincode on peer0.org2..."
#installChaincode 2

resolveSequence

## query whether the chaincode is installed
queryInstalled 1

## approve the definition for org1
approveForMyOrg 1

## check whether the chaincode definition is ready to be committed
## expect org1 to have approved and org2 not to
checkCommitReadiness 1 "\"Org1MSP\": true" "\"Org2MSP\": false"
checkCommitReadiness 2 "\"Org1MSP\": true" "\"Org2MSP\": false"

## now approve also for org2
approveForMyOrg 2

## check whether the chaincode definition is ready to be committed
## expect them both to have approved
checkCommitReadiness 1 "\"Org1MSP\": true" "\"Org2MSP\": true"
checkCommitReadiness 2 "\"Org1MSP\": true" "\"Org2MSP\": true"

## now that we know for sure both orgs have approved, commit the definition
commitChaincodeDefinition 1 2

## query on both orgs to see that the definition committed successfully
queryCommitted 1
queryCommitted 2

# start the container
startDockerContainer

## Invoke the chaincode - this does require that the chaincode have the 'initLedger'
## method defined
if [ "$CC_INIT_FCN" = "NA" ]; then
  infoln "Chaincode initialization is not required"
else
  chaincodeInvokeInit 1 2
fi

exit 0
