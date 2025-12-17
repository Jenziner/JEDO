#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

CONFIG_FILE="$SCRIPT_DIR/infrastructure-cc.yaml"
FABRIC_BIN_PATH=$(yq eval '.Fabric.Path' "$CONFIG_FILE")

# Chaincode params
CHAINCODE_NAME="jedo-wallet"
CHANNEL_NAME="ea"
ORDERER_ADDRESS="orderer.alps.ea.jedo.cc:53111"
ORDERER_TLS_CERT="${PWD}/infrastructure/jedo/ea/alps/orderer.alps.ea.jedo.cc/tls/signcerts/cert.pem"

# Peer params
PEER_NAME="peer.alps.ea.jedo.cc"
PEER_ADDRESS="${PEER_NAME}:53511"
PEER_TLS_CERT="${PWD}/infrastructure/jedo/ea/alps/${PEER_NAME}/tls/signcerts/cert.pem"
CORE_PEER_LOCALMSPID="alps"
CORE_PEER_MSPCONFIGPATH="${PWD}/infrastructure/jedo/ea/alps/admin.alps.ea.jedo.cc/msp"

# Set environment
export PATH="${FABRIC_BIN_PATH}:$PATH"
export FABRIC_CFG_PATH="${PWD}/config"
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID
export CORE_PEER_TLS_ROOTCERT_FILE=$PEER_TLS_CERT
export CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH
export CORE_PEER_ADDRESS=$PEER_ADDRESS

echo ""
echo "=========================================="
echo "Testing Chaincode: $CHAINCODE_NAME"
echo "=========================================="

# Test 1: Ping
echo ""
echo_info "Test 1: Ping"
peer chaincode query -C $CHANNEL_NAME -n $CHAINCODE_NAME -c '{"Args":["Ping"]}'

# Test 2: Create Wallet
echo ""
echo_info "Test 2: Create Wallet (test-wallet-001)"
peer chaincode invoke \
    -o $ORDERER_ADDRESS \
    --ordererTLSHostnameOverride orderer.alps.ea.jedo.cc \
    --tls --cafile $ORDERER_TLS_CERT \
    -C $CHANNEL_NAME \
    -n $CHAINCODE_NAME \
    --peerAddresses $PEER_ADDRESS \
    --tlsRootCertFiles $PEER_TLS_CERT \
    -c '{"function":"CreateWallet","Args":["test-wallet-001", "worb.alps.ea.jedo.cc", "1000", ""]}'

sleep 3

# Test 3: Get Balance
echo ""
echo_info "Test 3: Get Balance"
peer chaincode query -C $CHANNEL_NAME -n $CHAINCODE_NAME \
    -c '{"Args":["GetBalance","test-wallet-001"]}'

# Test 4: Get Wallet
echo ""
echo_info "Test 4: Get Wallet Details"
peer chaincode query -C $CHANNEL_NAME -n $CHAINCODE_NAME \
    -c '{"Args":["GetWallet","test-wallet-001"]}'

# Test 5: Wallet Exists
echo ""
echo_info "Test 5: Check Wallet Exists"
peer chaincode query -C $CHANNEL_NAME -n $CHAINCODE_NAME \
    -c '{"Args":["WalletExists","test-wallet-001"]}'

echo ""
echo_ok "Chaincode tests completed!"
