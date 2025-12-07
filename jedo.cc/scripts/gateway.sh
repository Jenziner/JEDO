###############################################################
#!/bin/bash
#
# This script starts Wallet API Gateway
#
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
check_script


###############################################################
# Params
###############################################################
CONFIG_FILE="$SCRIPT_DIR/infrastructure-cc.yaml"
FABRIC_BIN_PATH=$(yq eval '.Fabric.Path' "$CONFIG_FILE")
DOCKER_UNRAID=$(yq eval '.Docker.Unraid' $CONFIG_FILE)
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $CONFIG_FILE)

get_hosts


###############################################################
# Build Gateway Image
###############################################################
GATEWAY_IMAGE="jedo-gateway:1.0"
GATEWAY_SRC_DIR="${PWD}/gateway"

echo_info "Checking Gateway..."

# Simple check: Image exists?
if ! docker images | grep -q "${GATEWAY_IMAGE}"; then
    REBUILD_REQUIRED=true
    echo_warn "Image not found - will build"
else
    REBUILD_REQUIRED=false
    echo_ok "Image exists"
    
    # Optional: Always rebuild if src/ changed in last hour
    if find ${GATEWAY_SRC_DIR}/src -type f -mmin -60 | grep -q .; then
        echo_warn "Source changed recently - will rebuild"
        REBUILD_REQUIRED=true
    fi
fi

# Build if required
if [ "$REBUILD_REQUIRED" = true ]; then
    echo_warn "Building ${GATEWAY_IMAGE}..."
    cd ${GATEWAY_SRC_DIR}
    
    # Install dependencies
    echo_info "Installing dependencies..."
    npm install
    
    # Clean and build
    echo_info "Building TypeScript..."
    rm -rf dist/
    npm run build || { echo_error "Build failed"; exit 1; }
    
    # Build Docker image
    echo_info "Building Docker image..."
    docker build -t ${GATEWAY_IMAGE} . || { echo_error "Docker build failed"; exit 1; }
    
    cd ..
    echo_ok "Image built"
else
    echo_ok "Image up-to-date"
fi


###############################################################
# Gateway
###############################################################
ORBIS=$(yq eval ".Orbis.Name" "$CONFIG_FILE")
REGNUMS=$(yq e ".Regnum[].Name" $CONFIG_FILE)
for REGNUM in $REGNUMS; do
    AGERS=$(yq eval ".Ager[] | select(.Administration.Parent == \"$REGNUM\") | .Name" $CONFIG_FILE)
    for AGER in $AGERS; do
        ###############################################################
        # Params
        ###############################################################
        GATEWAY_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.Name" $CONFIG_FILE)
        GATEWAY_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.IP" $CONFIG_FILE)
        GATEWAY_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.Port" $CONFIG_FILE)
        GATEWAY_CC=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.CC" $CONFIG_FILE)

        # First Peer
        PEER_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[0].Name" $CONFIG_FILE)
        PEER_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[0].IP" $CONFIG_FILE)
        PEER_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[0].Port1" $CONFIG_FILE)

        # CA-API
        CAAPI_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.CAAPI.Name" $CONFIG_FILE)
        CAAPI_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.CAAPI.IP" $CONFIG_FILE)
        CAAPI_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.CAAPI.Port1" $CONFIG_FILE)

        echo ""
        echo_warn "Docker $GATEWAY_NAME starting..."
        echo_info "Executing with the following:"
        echo_info "- Chaincode: ${GREEN}${GATEWAY_CC}${NC}"
        echo_info "- Gateway: ${GREEN}${GATEWAY_NAME} (${GATEWAY_IP}:${GATEWAY_PORT})${NC}"
        echo_info "- Peer: ${GREEN}${PEER_NAME} (${PEER_IP}:${PEER_PORT})${NC}"

        LOCAL_SRV_DIR=${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$GATEWAY_NAME
        mkdir -p $LOCAL_SRV_DIR


        ###############################################################
        # Resolve file paths with wildcards
        ###############################################################
        # TLS Cert
        TLS_CERT_FULL=$(ls "${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_NAME/tls/signcerts"/*.pem 2>/dev/null | head -1)
        if [ -z "$TLS_CERT_FULL" ]; then
            echo_error "TLS cert not found for $PEER_NAME"
            exit 1
        fi
        TLS_CERT_FILE=$(basename "$TLS_CERT_FULL")
        echo_info "- TLS Cert: $TLS_CERT_FILE"
        
        # TLS Root Cert
        TLS_ROOT_CERT_FULL=$(ls "${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_NAME/tls/tlscacerts"/*.pem 2>/dev/null | head -1)
        if [ -z "$TLS_ROOT_CERT_FULL" ]; then
            echo_error "TLS root cert not found for $PEER_NAME"
            exit 1
        fi
        TLS_ROOT_CERT_FILE=$(basename "$TLS_ROOT_CERT_FULL")
        echo_info "- TLS Root: $TLS_ROOT_CERT_FILE"


        ###############################################################
        # Write .env
        ###############################################################
        echo ""
        echo_info "Environment for $GATEWAY_NAME writing..."
cat <<EOF > $LOCAL_SRV_DIR/.env
# Server Configuration
NODE_ENV=cc
PORT=$GATEWAY_PORT
HOST=0.0.0.0
SERVICE_NAME=$GATEWAY_NAME

# Logging
LOG_LEVEL=info
LOG_PRETTY=true

# Security
REQUIRE_CLIENT_CERT=true
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100
MAX_REQUEST_SIZE=1mb

# CORS - Needs to be changed in PROD
CORS_ORIGIN=*

# Hyperledger Fabric
FABRIC_NETWORK_NAME=$DOCKER_NETWORK_NAME
FABRIC_CHANNEL_NAME=$REGNUM
FABRIC_CHAINCODE_NAME=$GATEWAY_CC
FABRIC_MSP_ID=$AGER

# Fabric Peer Connection
FABRIC_PEER_ENDPOINT=$PEER_NAME:$PEER_PORT
FABRIC_PEER_HOST_ALIAS=$PEER_NAME
FABRIC_PEER_TLS_CERT=./infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_NAME/tls/signcerts/$TLS_CERT_FILE
FABRIC_PEER_TLS_ROOT_CERT=./infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_NAME/tls/tlscacerts/$TLS_ROOT_CERT_FILE

# Fabric Peer Connection
FABRIC_AGER_MSP_CA_CERTS_PATH=./infrastructure/$ORBIS/$REGNUM/$AGER/msp/cacerts
FABRIC_AGER_MSP_INTERMEDIATE_CERTS_PATH=./infrastructure/$ORBIS/$REGNUM/$AGER/msp/intermediatecerts

# CA-API für Certificate Management
CA_API_URL=https://$CAAPI_NAME:$CAAPI_PORT
#CA_API_TLS_CERT=./infrastructure/$ORBIS/$REGNUM/$AGER/$CAAPI_NAME/tls/signcerts/cert.pem --> Gibts noch nicht

# Audit Logging
AUDIT_LOG_PATH=./logs/audit.log
AUDIT_LOG_LEVEL=info
EOF


        ###############################################################
        # GATEWAY
        ###############################################################
        echo ""
        echo_info "Docker $GATEWAY_NAME starting..."
        docker run -d \
            --name $GATEWAY_NAME \
            --network $DOCKER_NETWORK_NAME \
            --ip $GATEWAY_IP \
            $hosts_args \
            --restart=on-failure:1 \
            --health-cmd="node -e \"require('http').get('http://localhost:${GATEWAY_PORT}/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})\"" \
            --health-interval=30s \
            --health-timeout=10s \
            --health-start-period=40s \
            --health-retries=3 \
            -e PORT=$GATEWAY_PORT \
            -p $GATEWAY_PORT:$GATEWAY_PORT \
            -v $LOCAL_SRV_DIR/.env:/app/.env \
            -v ${PWD}/infrastructure:/app/infrastructure:ro \
            jedo-gateway:1.0

        CheckContainer "$GATEWAY_NAME" "$DOCKER_CONTAINER_WAIT"
        CheckContainerLog "$GATEWAY_NAME" "Health check available at" "$DOCKER_CONTAINER_WAIT"

        echo ""
        echo_ok "Gateway $GATEWAY_NAME started."
    done
done
###############################################################
# Last Tasks
###############################################################


