#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

export JEDO_INITIATED="yes"
check_script

CONFIG_FILE="$SCRIPT_DIR/infrastructure-cc.yaml"
FABRIC_BIN_PATH=$(yq eval '.Fabric.Path' "$CONFIG_FILE")
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' "$CONFIG_FILE")

get_hosts

# Chaincode params
CHAINCODE_NAME="jedo-wallet"
CHAINCODE_VERSION="1.0"
CHAINCODE_SEQUENCE="1"

# Orbis/Regnum/Ager
ORBIS="jedo"
REGNUM="ea"
AGER_NAME="alps"

# Channel & Network
CHANNEL_NAME=$REGNUM
ORDERER_NAME="orderer.${AGER_NAME}.${REGNUM}.${ORBIS}.cc"
ORDERER_PORT=$(yq eval ".Ager[] | select(.Name == \"${AGER_NAME}\") | .Orderers[0].Port" "$CONFIG_FILE")
ORDERER_ADDRESS="${ORDERER_NAME}:${ORDERER_PORT}"
ORDERER_TLS_CERT="${PWD}/infrastructure/${ORBIS}/${REGNUM}/${AGER_NAME}/${ORDERER_NAME}/tls/signcerts/cert.pem"

# Peer params
PEER_NAME="peer.${AGER_NAME}.${REGNUM}.${ORBIS}.cc"
PEER_PORT=$(yq eval ".Ager[] | select(.Name == \"${AGER_NAME}\") | .Peers[0].Port1" "$CONFIG_FILE")
PEER_ADDRESS="${PEER_NAME}:${PEER_PORT}"
PEER_TLS_CERT="${PWD}/infrastructure/${ORBIS}/${REGNUM}/${AGER_NAME}/${PEER_NAME}/tls/tlscacerts/tls-tls-${ORBIS}-cc-51031.pem"
CORE_PEER_LOCALMSPID="${AGER_NAME}"
CORE_PEER_MSPCONFIGPATH="${PWD}/infrastructure/${ORBIS}/${REGNUM}/${AGER_NAME}/admin.${AGER_NAME}.${REGNUM}.${ORBIS}.cc/msp"

# CCAAS params
CCAAS_NAME="${CHAINCODE_NAME}.${AGER_NAME}.${REGNUM}.${ORBIS}.cc"
CCAAS_IP=$(yq eval ".Ager[] | select(.Name == \"${AGER_NAME}\") | .CCAAS[] | select(.Name == \"${CCAAS_NAME}\") | .IP" "$CONFIG_FILE")
CCAAS_PORT=$(yq eval ".Ager[] | select(.Name == \"${AGER_NAME}\") | .CCAAS[] | select(.Name == \"${CCAAS_NAME}\") | .Port" "$CONFIG_FILE")

if [ -z "$CCAAS_IP" ] || [ -z "$CCAAS_PORT" ]; then
    echo_error "CCAAS configuration not found for $CCAAS_NAME"
    echo_error "Expected in infrastructure-cc.yaml:"
    echo_error "  Ager.alps.CCAAS[].Name: ${CCAAS_NAME}"
    exit 1
fi

echo ""
echo "=========================================="
echo "Deploying Chaincode"
echo "=========================================="
echo "Chaincode:   $CHAINCODE_NAME v$CHAINCODE_VERSION"
echo "Channel:     $CHANNEL_NAME"
echo "Organization: $CORE_PEER_LOCALMSPID"
echo "Peer:        $PEER_ADDRESS"
echo "Orderer:     $ORDERER_ADDRESS"
echo "CCAAS:       $CCAAS_NAME"
echo "CCAAS IP:    $CCAAS_IP:$CCAAS_PORT"
echo "=========================================="

# Set Fabric environment
export PATH="${FABRIC_BIN_PATH}:$PATH"
export FABRIC_CFG_PATH="${PWD}/config"
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID
export CORE_PEER_TLS_ROOTCERT_FILE=$PEER_TLS_CERT
export CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH
export CORE_PEER_ADDRESS=$PEER_ADDRESS

###############################################################
# 1. Validate Chaincode Source
###############################################################
echo ""
echo_info "Validating chaincode source files..."

if [ ! -d "./chaincode/jedo-wallet" ]; then
    echo_error "Chaincode directory not found"
    exit 1
fi

if [ ! -f "./chaincode/jedo-wallet/go.mod" ]; then
    echo_error "go.mod not found"
    exit 1
fi

# Verify critical files exist
for file in main.go chaincode.go wallet.go transaction.go queries.go utils.go; do
    if [ ! -f "./chaincode/jedo-wallet/$file" ]; then
        echo_error "Missing source file: $file"
        exit 1
    fi
done

echo_ok "Chaincode source validated"

###############################################################
# 2. Build & Start CCAAS Docker Container
###############################################################
echo ""
echo_info "Building chaincode Docker image..."

docker build -t ${CHAINCODE_NAME}:${CHAINCODE_VERSION} ./chaincode

if [ $? -ne 0 ]; then
    echo_error "Docker build failed"
    exit 1
fi

echo ""
echo_info "Starting CCAAS container: $CCAAS_NAME"

docker run -d \
    --name $CCAAS_NAME \
    --hostname $CCAAS_NAME \
    --network $DOCKER_NETWORK_NAME \
    --ip $CCAAS_IP \
    $hosts_args \
    --restart=unless-stopped \
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/infrastructure/src/fabric_logo.png" \
    -e CORE_CHAINCODE_ID_NAME=${CHAINCODE_NAME}:latest \
    -e CHAINCODE_SERVER_ADDRESS=0.0.0.0:9999 \
    -e CORE_CHAINCODE_LOGGING_LEVEL=info \
    -e CORE_CHAINCODE_LOGGING_SHIM=warning \
    -e CORE_CHAINCODE_LOGGING_LEVEL=info \
    -p ${CCAAS_PORT}:9999 \
    ${CHAINCODE_NAME}:${CHAINCODE_VERSION}

CheckContainer "$CCAAS_NAME" 10

# Test if chaincode is reachable
echo_info "Testing CCAAS connectivity..."
sleep 2
docker logs $CCAAS_NAME | tail -5

###############################################################
# 3. Package Chaincode
###############################################################
echo ""
echo_info "Packaging chaincode..."
PACKAGE_DIR="${PWD}/chaincode/package"
mkdir -p "$PACKAGE_DIR"

# Create connection.json (use IP for direct connection)
cat > "${PACKAGE_DIR}/connection.json" <<EOF
{
  "address": "${CCAAS_IP}:9999",
  "dial_timeout": "10s",
  "tls_required": false
}
EOF

# Create metadata.json
cat > "${PACKAGE_DIR}/metadata.json" <<EOF
{
  "type": "ccaas",
  "label": "${CHAINCODE_NAME}_${CHAINCODE_VERSION}"
}
EOF

# Package
cd "$PACKAGE_DIR"
tar czf "connection.tar.gz" connection.json
tar czf "${CHAINCODE_NAME}.tar.gz" connection.tar.gz metadata.json

PACKAGE_FILE="${PACKAGE_DIR}/${CHAINCODE_NAME}.tar.gz"
echo_ok "Package created: $PACKAGE_FILE"

###############################################################
# 4. Install Chaincode on Peer
###############################################################
echo ""
echo_info "Installing chaincode on ${PEER_NAME}..."

cd "${PWD}"
peer lifecycle chaincode install "$PACKAGE_FILE"

if [ $? -ne 0 ]; then
    echo_error "Chaincode installation failed"
    exit 1
fi

# Get package ID
echo ""
echo_info "Querying installed chaincodes..."
sleep 2

PACKAGE_ID=$(peer lifecycle chaincode queryinstalled | grep "${CHAINCODE_NAME}_${CHAINCODE_VERSION}" | awk -F'[, ]' '{for(i=1;i<=NF;i++) if($i ~ /^Package/) print $(i+2)}' | head -1)

if [ -z "$PACKAGE_ID" ]; then
    echo_error "Failed to get package ID"
    peer lifecycle chaincode queryinstalled
    exit 1
fi

echo_ok "Package ID: $PACKAGE_ID"

###############################################################
# 5. Approve Chaincode for Organization
###############################################################
echo ""
echo_info "Approving chaincode for organization $CORE_PEER_LOCALMSPID..."

peer lifecycle chaincode approveformyorg \
    -o $ORDERER_ADDRESS \
    --ordererTLSHostnameOverride $ORDERER_NAME \
    --tls --cafile $ORDERER_TLS_CERT \
    --channelID $CHANNEL_NAME \
    --name $CHAINCODE_NAME \
    --version $CHAINCODE_VERSION \
    --package-id $PACKAGE_ID \
    --sequence $CHAINCODE_SEQUENCE

if [ $? -ne 0 ]; then
    echo_error "Chaincode approval failed"
    exit 1
fi

echo_ok "Chaincode approved"

###############################################################
# 6. Check Commit Readiness
###############################################################
echo ""
echo_info "Checking commit readiness..."

peer lifecycle chaincode checkcommitreadiness \
    --channelID $CHANNEL_NAME \
    --name $CHAINCODE_NAME \
    --version $CHAINCODE_VERSION \
    --sequence $CHAINCODE_SEQUENCE \
    --output json | jq '.'

###############################################################
# 7. Commit Chaincode Definition
###############################################################
echo ""
echo_info "Committing chaincode definition..."

peer lifecycle chaincode commit \
    -o $ORDERER_ADDRESS \
    --ordererTLSHostnameOverride $ORDERER_NAME \
    --tls --cafile $ORDERER_TLS_CERT \
    --channelID $CHANNEL_NAME \
    --name $CHAINCODE_NAME \
    --version $CHAINCODE_VERSION \
    --sequence $CHAINCODE_SEQUENCE \
    --peerAddresses $PEER_ADDRESS \
    --tlsRootCertFiles $PEER_TLS_CERT

if [ $? -ne 0 ]; then
    echo_error "Chaincode commit failed"
    exit 1
fi

echo_ok "Chaincode committed"

###############################################################
# 8. Query Committed Chaincodes
###############################################################
echo ""
echo_info "Querying committed chaincodes..."

peer lifecycle chaincode querycommitted \
    --channelID $CHANNEL_NAME \
    --name $CHAINCODE_NAME

###############################################################
# 9. Initialize Ledger
###############################################################
echo ""
echo_info "Initializing ledger..."

peer chaincode invoke \
    -o $ORDERER_ADDRESS \
    --ordererTLSHostnameOverride $ORDERER_NAME \
    --tls --cafile $ORDERER_TLS_CERT \
    -C $CHANNEL_NAME \
    -n $CHAINCODE_NAME \
    --peerAddresses $PEER_ADDRESS \
    --tlsRootCertFiles $PEER_TLS_CERT \
    -c '{"function":"InitLedger","Args":[]}'

sleep 3

###############################################################
# Final Status
###############################################################
echo ""
echo_ok "=========================================="
echo_ok "Chaincode Deployment Completed!"
echo_ok "=========================================="
echo ""
echo "Chaincode Name:     $CHAINCODE_NAME"
echo "Version:            $CHAINCODE_VERSION"
echo "Sequence:           $CHAINCODE_SEQUENCE"
echo "Package ID:         $PACKAGE_ID"
echo "Channel:            $CHANNEL_NAME"
echo "Organization:       $CORE_PEER_LOCALMSPID"
echo "CCAAS Container:    $CCAAS_NAME"
echo "CCAAS Address:      $CCAAS_IP:$CCAAS_PORT"
echo ""
echo_ok "=========================================="
