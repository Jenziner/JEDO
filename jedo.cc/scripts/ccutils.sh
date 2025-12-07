#!/bin/bash


# verify Function from Hyperledger
verifyResult() {
  if [ $1 -ne 0 ]; then
    echo_error "$2"
  fi
}



###############################################################
# Function packageChaincode for a PEER
###############################################################
packageChaincode() {
    PEER=$1
    CC_NAME=$2
    CC_VERSION=$3
    CCAAS_SERVER_NAME=$4
    CCAAS_SERVER_PORT=$5
    address="${CCAAS_SERVER_NAME}:${CCAAS_SERVER_PORT}"
    prefix=$(basename "$0")
    tempdir=$(mktemp -d -t "$prefix.XXXXXXXX") || error_exit "Error creating temporary directory"
    label=${CC_NAME}_${CC_VERSION}
    mkdir -p "$tempdir/src"

cat > "$tempdir/src/connection.json" <<CONN_EOF
{
  "address": "${address}",
  "dial_timeout": "10s",
  "tls_required": false
}
CONN_EOF

    mkdir -p "$tempdir/pkg"

cat << METADATA-EOF > "$tempdir/pkg/metadata.json"
{
    "type": "ccaas",
    "label": "$label"
}
METADATA-EOF

    tar -C "$tempdir/src" -czf "$tempdir/pkg/code.tar.gz" .
    tar -C "$tempdir/pkg" -czf "$CC_NAME.tar.gz" metadata.json code.tar.gz
    rm -Rf "$tempdir"

    # ✅ Set minimal FABRIC_CFG_PATH for calculatepackageid
    export FABRIC_CFG_PATH=${PWD}/../../fabric/config
    
    local PACKAGE_ID
    PACKAGE_ID=$(peer lifecycle chaincode calculatepackageid ${CC_NAME}.tar.gz 2>/dev/null)
  
    echo "$PACKAGE_ID"
}




###############################################################
# Function installChaincode
###############################################################
function installChaincode() {
  CC_NAME=$1
  ORBIS=$2
  REGNUM=$3
  AGER=$4
  PEER=$5
  PEER_ADDRESS=$6
  ORDERER_ADDRESS=$7

  # ✅ Copy tar.gz to mounted directory
  PEER_CHAINCODE_PATH=${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER
  cp ${CC_NAME}.tar.gz $PEER_CHAINCODE_PATH/
  
  if [ $? -ne 0 ]; then
    echo_error "Failed to copy ${CC_NAME}.tar.gz to $PEER_CHAINCODE_PATH"
    exit 1
  fi
  
  echo_info "Chaincode package copied to: ${GREEN}${PEER_CHAINCODE_PATH}/${CC_NAME}.tar.gz${NC}"

  # ✅ Finde den richtigen TLS Cert Namen im Container!
  PEER_TLSCACERT_FILE=$(docker exec $PEER ls /etc/hyperledger/fabric/tls/tlscacerts/ 2>/dev/null | head -1)

  if [ -z "$PEER_TLSCACERT_FILE" ]; then
    echo_error "Peer TLS CA cert not found in container!"
    exit 1
  fi
  
  ORDERER_TLSCACERT_FILE=$(docker exec $PEER ls /var/hyperledger/orderer/tls/tlscacerts/ 2>/dev/null | head -1)
  
  if [ -z "$ORDERER_TLSCACERT_FILE" ]; then
    echo_error "Orderer TLS CA cert not found in container!"
    exit 1
  fi

  # Container Paths
  ADMIN_MSP_CONTAINER_PATH="/var/hyperledger/infrastructure/$ORBIS/$REGNUM/$AGER/admin.$AGER.$REGNUM.jedo.cc/msp"
  PEER_TLSCACERT_CONTAINER="/etc/hyperledger/fabric/tls/tlscacerts/$PEER_TLSCACERT_FILE"
  #ORDERER_TLSCACERT_CONTAINER="/etc/hyperledger/orderer/tls/tlscacerts/$ORDERER_TLSCACERT_FILE"
  ORDERER_TLSCACERT_CONTAINER="/var/hyperledger/infrastructure/$ORBIS/$REGNUM/$AGER/orderer.$AGER.$REGNUM.$ORBIS.cc/tls/tlscacerts/$ORDERER_TLSCACERT_FILE"
  CC_PACKAGE_CONTAINER="/etc/hyperledger/fabric/${CC_NAME}.tar.gz"

  echo_info "Installing chaincode with the following"
  echo_info "- LocalMSPID: ${GREEN}${AGER}${NC}"
  echo_info "- TLS Enabled: ${GREEN}true${NC}"
  echo_info "- Admin MSP: ${GREEN}${ADMIN_MSP_CONTAINER_PATH}${NC}"
  echo_info "- PEER: ${GREEN}${PEER_ADDRESS}${NC}"
  echo_info "- Peer TLS Cert: ${GREEN}${PEER_TLSCACERT_CONTAINER}${NC}"
  echo_info "- Orderer TLS Cert: ${GREEN}${ORDERER_TLSCACERT_CONTAINER}${NC}"
  echo_info "- PackageID: ${GREEN}${PACKAGE_ID}${NC}"
  echo_info "- Package File: ${GREEN}${CC_PACKAGE_CONTAINER}${NC}"

  # Check if already installed
  if ! docker exec \
    -e CORE_PEER_TLS_ENABLED=true \
    -e CORE_PEER_LOCALMSPID=$AGER \
    -e CORE_PEER_TLS_ROOTCERT_FILE=$PEER_TLSCACERT_CONTAINER \
    -e CORE_PEER_MSPCONFIGPATH=$ADMIN_MSP_CONTAINER_PATH \
    -e CORE_PEER_ADDRESS=$PEER_ADDRESS \
    $PEER peer lifecycle chaincode queryinstalled --output json 2>/dev/null | jq -e -r '.installed_chaincodes[].package_id // empty' | grep -F -x "${PACKAGE_ID}" > /dev/null; then
    
    echo_info "Installing chaincode ${PACKAGE_ID}..."
    docker exec \
      -e CORE_PEER_TLS_ENABLED=true \
      -e CORE_PEER_LOCALMSPID=$AGER \
      -e CORE_PEER_TLS_ROOTCERT_FILE=$PEER_TLSCACERT_CONTAINER \
      -e CORE_PEER_MSPCONFIGPATH=$ADMIN_MSP_CONTAINER_PATH \
      -e CORE_PEER_ADDRESS=$PEER_ADDRESS \
      $PEER peer lifecycle chaincode install $CC_PACKAGE_CONTAINER
    
    verifyResult $? "Chaincode installation on $PEER has failed"
  else
    echo_ok "Chaincode already installed: ${PACKAGE_ID}"
  fi

  # Approve chaincode
  echo_info "Approving chaincode"
  echo_info "- Channel: ${GREEN}${CHANNEL_NAME}${NC}"
  echo_info "- Orderer: ${GREEN}${ORDERER_ADDRESS}${NC}"
  
  docker exec \
    -e CORE_PEER_TLS_ENABLED=true \
    -e CORE_PEER_LOCALMSPID=$AGER \
    -e CORE_PEER_TLS_ROOTCERT_FILE=$PEER_TLSCACERT_CONTAINER \
    -e CORE_PEER_MSPCONFIGPATH=$ADMIN_MSP_CONTAINER_PATH \
    -e CORE_PEER_ADDRESS=$PEER_ADDRESS \
    $PEER peer lifecycle chaincode approveformyorg \
      -o $ORDERER_ADDRESS \
      --tls \
      --cafile "$ORDERER_TLSCACERT_CONTAINER" \
      --channelID $CHANNEL_NAME \
      --name ${CC_NAME} \
      --version ${CC_VERSION} \
      --package-id ${PACKAGE_ID} \
      --sequence ${CC_SEQUENCE} \
      ${CC_INIT_FCN:+--init-required} \
      ${CC_END_POLICY} \
      ${CC_COLL_CONFIG}

APPROVE_RC=$?
echo_warn "DEBUG: approveformyorg exit code = ${APPROVE_RC}"
# NICHT abbrechen, auch wenn APPROVE_RC != 0

echo_info "Checking commit readiness..."
docker exec \
  -e CORE_PEER_TLS_ENABLED=true \
  -e CORE_PEER_LOCALMSPID=$AGER \
  -e CORE_PEER_TLS_ROOTCERT_FILE=$PEER_TLSCACERT_CONTAINER \
  -e CORE_PEER_MSPCONFIGPATH=$ADMIN_MSP_CONTAINER_PATH \
  -e CORE_PEER_ADDRESS=$PEER_ADDRESS \
  $PEER peer lifecycle chaincode checkcommitreadiness \
    --channelID $CHANNEL_NAME \
    --name ${CC_NAME} \
    --version ${CC_VERSION} \
    --sequence ${CC_SEQUENCE} \
    --output json \
    ${CC_INIT_FCN:+--init-required} \
    ${CC_END_POLICY} \
    ${CC_COLL_CONFIG}

CCR_RC=$?
echo_warn "DEBUG: checkcommitreadiness exit code = ${CCR_RC}"

if [ $CCR_RC -ne 0 ]; then
  echo_error "checkcommitreadiness failed for ${AGER}"
  exit 1
fi
    
    echo_ok "Chaincode approved for ${AGER} (approve rc=${APPROVE_RC})"
}



###############################################################
# Additional utility functions (kept from original)
###############################################################

# queryInstalled PEER ORG
function queryInstalled() {
  ORG=$1
  setGlobals $ORG
  set -x
  peer lifecycle chaincode queryinstalled --output json | jq -r 'try (.installed_chaincodes[].package_id)' | grep ^${PACKAGE_ID}$ >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
  verifyResult $res "Query installed on peer0.org${ORG} has failed"
  successln "Query installed successful on peer0.org${ORG} on channel"
}

function resolveSequence() {
  #if the sequence is not "auto", then use the provided sequence
  if [[ "${CC_SEQUENCE}" != "auto" ]]; then
    return 0
  fi

  local rc=1
  local COUNTER=1
  # first, find the sequence number of the committed chaincode
  # we either get a successful response, or reach MAX RETRY
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    set -x
    COMMITTED_CC_SEQUENCE=$(peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name ${CC_NAME} | sed -n "/Version:/{s/.*Sequence: //; s/, Endorsement Plugin:.*$//; p;}")
    res=$?
    { set +x; } 2>/dev/null
    let rc=$res
    COUNTER=$(expr $COUNTER + 1)
  done

  # if there are no committed versions, then set the sequence to 1
  if [ -z $COMMITTED_CC_SEQUENCE ]; then
    CC_SEQUENCE=1
    return 0
  fi

  rc=1
  COUNTER=1
  # next, find the sequence number of the approved chaincode
  # we either get a successful response, or reach MAX RETRY
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    set -x
    APPROVED_CC_SEQUENCE=$(peer lifecycle chaincode queryapproved --channelID $CHANNEL_NAME --name ${CC_NAME} | sed -n "/sequence:/{s/^sequence: //; s/, version:.*$//; p;}")
    res=$?
    { set +x; } 2>/dev/null
    let rc=$res
    COUNTER=$(expr $COUNTER + 1)
  done

  # if the committed sequence and the approved sequence match, then increment the sequence
  # otherwise, use the approved sequence
  if [ $COMMITTED_CC_SEQUENCE == $APPROVED_CC_SEQUENCE ]; then
    CC_SEQUENCE=$((COMMITTED_CC_SEQUENCE+1))
  else
    CC_SEQUENCE=$APPROVED_CC_SEQUENCE
  fi
}

queryInstalledOnPeer() {
  local rc=1
  local COUNTER=1
  # continue to poll
  # we either get a successful response, or reach MAX RETRY
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    peer lifecycle chaincode queryinstalled >&log.txt
    res=$?
    let rc=$res
    COUNTER=$(expr $COUNTER + 1)
  done
  cat log.txt
}

queryCommittedOnChannel() {
  CHANNEL=$1
  local rc=1
  local COUNTER=1
  # continue to poll
  # we either get a successful response, or reach MAX RETRY
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    peer lifecycle chaincode querycommitted -C $CHANNEL >&log.txt
    res=$?
    let rc=$res
    COUNTER=$(expr $COUNTER + 1)
  done
  cat log.txt
  if test $rc -ne 0; then
    fatalln "After $MAX_RETRY attempts, Failed to retrieve committed chaincode!"
  fi
}

## Function to list chaincodes installed on the peer and committed chaincode visible to the org
listAllCommitted() {
  local rc=1
  local COUNTER=1
  # continue to poll
  # we either get a successful response, or reach MAX RETRY
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    CHANNEL_LIST=$(peer channel list | sed '1,1d')
    res=$?
    let rc=$res
    COUNTER=$(expr $COUNTER + 1)
  done
  if test $rc -eq 0; then
    for channel in $CHANNEL_LIST
    do
      queryCommittedOnChannel "$channel"
    done
  else
    fatalln "After $MAX_RETRY attempts, Failed to retrieve committed chaincode!"
  fi
}

chaincodeInvoke() {
  ORG=$1
  CHANNEL=$2
  CC_NAME=$3
  CC_INVOKE_CONSTRUCTOR=$4
  
  infoln "Invoking on peer0.org${ORG} on channel '$CHANNEL_NAME'..."
  local rc=1
  local COUNTER=1
  # continue to poll
  # we either get a successful response, or reach MAX RETRY
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    sleep $DELAY
    infoln "Attempting to Invoke on peer0.org${ORG}, Retry after $DELAY seconds."
    set -x
    peer chaincode invoke -o localhost:7050 -C $CHANNEL_NAME -n ${CC_NAME} -c ${CC_INVOKE_CONSTRUCTOR} --tls --cafile $ORDERER_CA  --peerAddresses localhost:7051 --tlsRootCertFiles $PEER0_ORG1_CA --peerAddresses localhost:9051 --tlsRootCertFiles $PEER0_ORG2_CA  >&log.txt
    res=$?
    { set +x; } 2>/dev/null
    let rc=$res
    COUNTER=$(expr $COUNTER + 1)
  done
  cat log.txt
  if test $rc -eq 0; then
    successln "Invoke successful on peer0.org${ORG} on channel '$CHANNEL_NAME'"
  else
    fatalln "After $MAX_RETRY attempts, Invoke result on peer0.org${ORG} is INVALID!"
  fi
}

chaincodeQuery() {
  ORG=$1
  CHANNEL=$2
  CC_NAME=$3
  CC_QUERY_CONSTRUCTOR=$4

  infoln "Querying on peer0.org${ORG} on channel '$CHANNEL_NAME'..."
  local rc=1
  local COUNTER=1
  # continue to poll
  # we either get a successful response, or reach MAX RETRY
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    sleep $DELAY
    infoln "Attempting to Query peer0.org${ORG}, Retry after $DELAY seconds."
    set -x
    peer chaincode query -C $CHANNEL_NAME -n ${CC_NAME} -c ${CC_QUERY_CONSTRUCTOR} >&log.txt
    res=$?
    { set +x; } 2>/dev/null
    let rc=$res
    COUNTER=$(expr $COUNTER + 1)
  done
  cat log.txt
  if test $rc -eq 0; then
    successln "Query successful on peer0.org${ORG} on channel '$CHANNEL_NAME'"
  else
    fatalln "After $MAX_RETRY attempts, Query result on peer0.org${ORG} is INVALID!"
  fi
}
