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
    CCAAS_SERVER_PORT=$4
    address="${PEER}_${CC_NAME}_ccaas:${CCAAS_SERVER_PORT}"
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

    local PACKAGE_ID
    PACKAGE_ID=$(peer lifecycle chaincode calculatepackageid ${CC_NAME}.tar.gz)
  
    echo "$PACKAGE_ID"
#    echo_info "Chaincode is packaged  ${GREEN}${address}${NC}"
}


###############################################################
# Function installChaincode on a PEER
###############################################################
function installChaincode() {
  ORBIS=$1
  REGNUM=$2
  AGER=$3
  PEER=$4
  PEER_IP=$5
  PEER_PORT=$6
  PEER_ROOTCERT=$7

  FABRIC_CFG_PATH=${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER
  export CORE_PEER_LOCALMSPID=$AGER
  export CORE_PEER_TLS_ROOTCERT_FILE=$PEER_ROOTCERT
  export CORE_PEER_MSPCONFIGPATH=${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER/msp
  export CORE_PEER_ADDRESS=$PEER_IP:$PEER_PORT

  echo_info "Installing chaincode with the following"
  echo_info "- LocalMSPID: ${GREEN}${CORE_PEER_LOCALMSPID}${NC}"
  echo_info "- RootCert: ${GREEN}${CORE_PEER_TLS_ROOTCERT_FILE}${NC}"
  echo_info "- MSPConfigPath: ${GREEN}${CORE_PEER_MSPCONFIGPATH}${NC}"
  echo_info "- PEER: ${GREEN}${CORE_PEER_ADDRESS}${NC}"
  echo_info "- PackageID: ${GREEN}${PACKAGE_ID}${NC}"

  if ! PACKAGE_FOUND=$(peer lifecycle chaincode queryinstalled --output json | jq -e -r '.installed_chaincodes[].package_id // empty' | grep -F -x "${PACKAGE_ID}"); then
    echo_info "Installing chaincode ${PACKAGE_ID}..."
    peer lifecycle chaincode install ${CC_NAME}.tar.gz
    verifyResult $? "Chaincode installation on $PEER has failed"
  else
    echo_ok "Chaincode already installed: ${PACKAGE_ID}"
  fi
}

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

# approveForMyOrg VERSION PEER ORG
function approveForMyOrg() {
  ORG=$1
  setGlobals $ORG
  set -x
  peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile "$ORDERER_CA" --channelID $CHANNEL_NAME --name ${CC_NAME} --version ${CC_VERSION} --package-id ${PACKAGE_ID} --sequence ${CC_SEQUENCE} ${INIT_REQUIRED} ${CC_END_POLICY} ${CC_COLL_CONFIG} >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
  verifyResult $res "Chaincode definition approved on peer0.org${ORG} on channel '$CHANNEL_NAME' failed"
  successln "Chaincode definition approved on peer0.org${ORG} on channel '$CHANNEL_NAME'"
}

# checkCommitReadiness VERSION PEER ORG
function checkCommitReadiness() {
  ORG=$1
  shift 1
  setGlobals $ORG
  infoln "Checking the commit readiness of the chaincode definition on peer0.org${ORG} on channel '$CHANNEL_NAME'..."
  local rc=1
  local COUNTER=1
  # continue to poll
  # we either get a successful response, or reach MAX RETRY
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    sleep $DELAY
    infoln "Attempting to check the commit readiness of the chaincode definition on peer0.org${ORG}, Retry after $DELAY seconds."
    set -x
    peer lifecycle chaincode checkcommitreadiness --channelID $CHANNEL_NAME --name ${CC_NAME} --version ${CC_VERSION} --sequence ${CC_SEQUENCE} ${INIT_REQUIRED} ${CC_END_POLICY} ${CC_COLL_CONFIG} --output json >&log.txt
    res=$?
    { set +x; } 2>/dev/null
    let rc=0
    for var in "$@"; do
      grep "$var" log.txt &>/dev/null || let rc=1
    done
    COUNTER=$(expr $COUNTER + 1)
  done
  cat log.txt
  if test $rc -eq 0; then
    infoln "Checking the commit readiness of the chaincode definition successful on peer0.org${ORG} on channel '$CHANNEL_NAME'"
  else
    fatalln "After $MAX_RETRY attempts, Check commit readiness result on peer0.org${ORG} is INVALID!"
  fi
}

# commitChaincodeDefinition VERSION PEER ORG (PEER ORG)...
function commitChaincodeDefinition() {
  parsePeerConnectionParameters $@
  res=$?
  verifyResult $res "Invoke transaction failed on channel '$CHANNEL_NAME' due to uneven number of peer and org parameters "

  # while 'peer chaincode' command can get the orderer endpoint from the
  # peer (if join was successful), let's supply it directly as we know
  # it using the "-o" option
  set -x
  peer lifecycle chaincode commit -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile "$ORDERER_CA" --channelID $CHANNEL_NAME --name ${CC_NAME} "${PEER_CONN_PARMS[@]}" --version ${CC_VERSION} --sequence ${CC_SEQUENCE} ${INIT_REQUIRED} ${CC_END_POLICY} ${CC_COLL_CONFIG} >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
  verifyResult $res "Chaincode definition commit failed on peer0.org${ORG} on channel '$CHANNEL_NAME' failed"
  successln "Chaincode definition committed on channel '$CHANNEL_NAME'"
}

# queryCommitted ORG
function queryCommitted() {
  ORG=$1
  setGlobals $ORG
  EXPECTED_RESULT="Version: ${CC_VERSION}, Sequence: ${CC_SEQUENCE}, Endorsement Plugin: escc, Validation Plugin: vscc"
  infoln "Querying chaincode definition on peer0.org${ORG} on channel '$CHANNEL_NAME'..."
  local rc=1
  local COUNTER=1
  # continue to poll
  # we either get a successful response, or reach MAX RETRY
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    sleep $DELAY
    infoln "Attempting to Query committed status on peer0.org${ORG}, Retry after $DELAY seconds."
    set -x
    peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name ${CC_NAME} >&log.txt
    res=$?
    { set +x; } 2>/dev/null
    test $res -eq 0 && VALUE=$(cat log.txt | grep -o '^Version: '$CC_VERSION', Sequence: [0-9]*, Endorsement Plugin: escc, Validation Plugin: vscc')
    test "$VALUE" = "$EXPECTED_RESULT" && let rc=0
    COUNTER=$(expr $COUNTER + 1)
  done
  cat log.txt
  if test $rc -eq 0; then
    successln "Query chaincode definition successful on peer0.org${ORG} on channel '$CHANNEL_NAME'"
  else
    fatalln "After $MAX_RETRY attempts, Query chaincode definition result on peer0.org${ORG} is INVALID!"
  fi
}

function chaincodeInvokeInit() {
  parsePeerConnectionParameters $@
  res=$?
  verifyResult $res "Invoke transaction failed on channel '$CHANNEL_NAME' due to uneven number of peer and org parameters "

  local rc=1
  local COUNTER=1
  local fcn_call='{"function":"'${CC_INIT_FCN}'","Args":[]}'
  # continue to poll
  # we either get a successful response, or reach MAX RETRY
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    sleep $DELAY
    # while 'peer chaincode' command can get the orderer endpoint from the
    # peer (if join was successful), let's supply it directly as we know
    # it using the "-o" option
    set -x
    infoln "invoke fcn call:${fcn_call}"
    peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile "$ORDERER_CA" -C $CHANNEL_NAME -n ${CC_NAME} "${PEER_CONN_PARMS[@]}" --isInit -c ${fcn_call} >&log.txt
    res=$?
    { set +x; } 2>/dev/null
    let rc=$res
    COUNTER=$(expr $COUNTER + 1)
  done
  cat log.txt
  verifyResult $res "Invoke execution on $PEERS failed "
  successln "Invoke transaction successful on $PEERS on channel '$CHANNEL_NAME'"
}

function chaincodeQuery() {
  ORG=$1
  setGlobals $ORG
  infoln "Querying on peer0.org${ORG} on channel '$CHANNEL_NAME'..."
  local rc=1
  local COUNTER=1
  # continue to poll
  # we either get a successful response, or reach MAX RETRY
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    sleep $DELAY
    infoln "Attempting to Query peer0.org${ORG}, Retry after $DELAY seconds."
    set -x
    peer chaincode query -C $CHANNEL_NAME -n ${CC_NAME} -c '{"Args":["org.hyperledger.fabric:GetMetadata"]}' >&log.txt
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

#. scripts/envVar.sh

queryInstalledOnPeer() {

  local rc=1
  local COUNTER=1
  # continue to poll
  # we either get a successful response, or reach MAX RETRY
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    #sleep $DELAY
    #infoln "Attempting to list on peer0.org${ORG}, Retry after $DELAY seconds."
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
    #sleep $DELAY
    #infoln "Attempting to list on peer0.org${ORG}, Retry after $DELAY seconds."
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