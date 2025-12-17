#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
check_script

CHAINCODE_DIR="${SCRIPT_DIR}/../chaincode"
CONFIG_FILE="${SCRIPT_DIR}/infrastructure-cc.yaml"

# Params
CHAINCODE_NAME="jedo-wallet"
CHAINCODE_VERSION="1.0"
CHAINCODE_SEQUENCE="1"

# Orbis/Regnum/Ager
ORBIS="jedo"
REGNUM="ea"
AGER_NAME="alps"

# CCAAS params
CCAAS_NAME="${CHAINCODE_NAME}.${AGER_NAME}.${REGNUM}.${ORBIS}.cc"
CCAAS_IP=$(yq eval ".Ager[] | select(.Name == \"${AGER_NAME}\") | .CCAAS[] | select(.Name == \"${CCAAS_NAME}\") | .IP" "$CONFIG_FILE")
CCAAS_PORT=$(yq eval ".Ager[] | select(.Name == \"${AGER_NAME}\") | .CCAAS[] | select(.Name == \"${CCAAS_NAME}\") | .Port" "$CONFIG_FILE")

if [ -z "$CCAAS_IP" ] || [ -z "$CCAAS_PORT" ]; then
    echo_error "CCAAS configuration not found for $CCAAS_NAME in infrastructure-cc.yaml"
    echo_error "Expected: Ager[alps].CCAAS[].Name = ${CCAAS_NAME}"
    exit 1
fi

echo ""
echo "=========================================="
echo "Packaging Chaincode: $CHAINCODE_NAME"
echo "=========================================="
echo "CCAAS Name: $CCAAS_NAME"
echo "CCAAS IP:   $CCAAS_IP"
echo "CCAAS Port: $CCAAS_PORT"
echo "=========================================="

# Create package directory
PACKAGE_DIR="${CHAINCODE_DIR}/package"
mkdir -p "$PACKAGE_DIR"

# Navigate to chaincode directory
cd "${CHAINCODE_DIR}/jedo-wallet"

# Check if go.mod exists
if [ ! -f "go.mod" ]; then
    echo_error "go.mod not found in ${CHAINCODE_DIR}/jedo-wallet"
    exit 1
fi

# Ensure go.mod and go.sum are up to date
echo ""
echo_info "Downloading Go dependencies..."
go mod tidy

if [ $? -ne 0 ]; then
    echo_error "go mod tidy failed"
    exit 1
fi

go mod vendor

if [ $? -ne 0 ]; then
    echo_error "go mod vendor failed"
    exit 1
fi

# Create tar.gz of source code (optional, not needed for CCAAS)
echo ""
echo_info "Creating source code archive..."
cd ..
tar czf "${PACKAGE_DIR}/code.tar.gz" jedo-wallet/

# Create connection.json with IP address
echo ""
echo_info "Creating connection.json..."
cat > "${PACKAGE_DIR}/connection.json" <<EOF
{
  "address": "${CCAAS_IP}:9999",
  "dial_timeout": "10s",
  "tls_required": false
}
EOF

echo_ok "connection.json created with address: ${CCAAS_IP}:9999"

# Create metadata.json
echo ""
echo_info "Creating metadata.json..."
cat > "${PACKAGE_DIR}/metadata.json" <<EOF
{
  "type": "ccaas",
  "label": "${CHAINCODE_NAME}_${CHAINCODE_VERSION}"
}
EOF

# Package everything
echo ""
echo_info "Packaging chaincode..."
cd "$PACKAGE_DIR"

# For CCAAS, we only need connection.json and metadata.json
tar czf "connection.tar.gz" connection.json
tar czf "${CHAINCODE_NAME}.tar.gz" connection.tar.gz metadata.json

# Verify package
if [ -f "${CHAINCODE_NAME}.tar.gz" ]; then
    echo ""
    echo_ok "=========================================="
    echo_ok "Chaincode Package Created Successfully!"
    echo_ok "=========================================="
    echo ""
    echo "Package File:       ${PACKAGE_DIR}/${CHAINCODE_NAME}.tar.gz"
    echo "Package Label:      ${CHAINCODE_NAME}_${CHAINCODE_VERSION}"
    echo "Connection Address: ${CCAAS_IP}:9999"
    echo "CCAAS Container:    ${CCAAS_NAME}"
    echo ""
    echo "Package Contents:"
    tar -tzf "${CHAINCODE_NAME}.tar.gz"
    echo ""
    echo_ok "=========================================="
else
    echo_error "Failed to create package"
    exit 1
fi

# Cleanup intermediate files
rm -f connection
