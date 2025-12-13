###############################################################
#!/bin/bash
#
# This script starts Wallet API Gateway
#
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/params.sh"
check_script

get_hosts

LOCAL_INFRA_DIR=${PWD}/infrastructure

###############################################################
# Build Service Image
###############################################################
build_microservice() {
    local SERVICE_NAME=$1
    local SERVICE_VERSION=$2
    local SERVICE_SRC_DIR=$3
    local SERVICE_IMAGE="$SERVICE_NAME:$SERVICE_VERSION"

    SERVICE_SRC_DIR="../$SERVICE_SRC_DIR"

    echo_debug "Checking Image..."

    # Simple check: Image exists?
    if ! docker images | grep -q "${SERVICE_IMAGE}"; then
        REBUILD_REQUIRED=true
        echo_debug "Image not found - will build"
    else
        REBUILD_REQUIRED=false
        echo_debug "Image exists"
        
    fi

    # Build if required
    if [ "$REBUILD_REQUIRED" = true ]; then
        echo_debug "Building ${SERVICE_IMAGE}..."
        
        # Install dependencies
        echo_debug "Installing dependencies..."
        (cd "${SERVICE_SRC_DIR}" && npm install) || { echo_error "npm install failed"; exit 1; }
        
    
        # Clean and build
        echo_debug "Building TypeScript..."
        (cd ${SERVICE_SRC_DIR} && rm -rf dist/ && npm run build) || { echo_error "Build failed"; exit 1; }
        
        # Build Docker image
        echo_debug "Building Docker image..."
        docker build -t ${SERVICE_IMAGE} ${SERVICE_SRC_DIR} || { echo_error "Docker build failed"; exit 1; }

        echo_debug "Image built"
    else
        echo_debug "Image up-to-date"
    fi
}


###############################################################
# Start Service
###############################################################
start_microservice() {
    local SERVICE_NAME=$1
    local SERVICE_VERSION=$2
    local SERVICE_IP=$3
    local SERVICE_PORT=$4
    local SERVICE_IMAGE="$SERVICE_NAME:$SERVICE_VERSION"
    local LOCAL_INFRA_DIR=${PWD}/infrastructure
    local LOCAL_SRV_DIR=$LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$SERVICE_NAME

    echo ""
    echo_info "Docker $SERVICE_NAME starting..."
    docker run -d \
        --user $(id -u):$(id -g) \
        --name $SERVICE_NAME \
        --network $DOCKER_NETWORK_NAME \
        --ip $SERVICE_IP \
        $hosts_args \
        --restart=on-failure:1 \
        --health-cmd="node -e \"require('http').get('http://$SERVICE_IP:${SERVICE_PORT}/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})\"" \
        --health-interval=30s \
        --health-timeout=10s \
        --health-start-period=40s \
        --health-retries=3 \
        -e PORT=$SERVICE_PORT \
        -p $SERVICE_PORT:$SERVICE_PORT \
        -v $LOCAL_SRV_DIR/.env:/app/.env \
        -v $LOCAL_INFRA_DIR:/app/infrastructure:ro \
        $SERVICE_IMAGE

    CheckContainer "$SERVICE_NAME" "$DOCKER_CONTAINER_WAIT"
    CheckContainerLog "$SERVICE_NAME" "JGET /health completed" "$DOCKER_CONTAINER_WAIT"

    echo ""
    echo_info "Microservice $SERVICE_NAME started."
}


###############################################################
# Write .env for ledger-service
###############################################################
writeenf_ledger-service() {
    local SERVICE_NAME=$1
    local SERVICE_VERSION=$2
    local SERVICE_IP=$3
    local SERVICE_PORT=$4
    local CC=$5
    local PEER_NAME=$6
    local PEER_IP=$7
    local PEER_PORT=$8
    local TLS_CERT_FULL=$9
    local TLS_ROOT_CERT_FULL=${10}
    local ADMIN_CERT_FULL=${11}
    local ADMIN_KEY_FULL=${12}
    local SERVICE_IMAGE="$SERVICE_NAME:$SERVICE_VERSION"
    local LOCAL_INFRA_DIR=${PWD}/infrastructure
    local LOCAL_SRV_DIR=$LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$SERVICE_NAME

    echo ""
    echo_info "Environment for $SERVICE_NAME writing..."
    cat <<EOF > $LOCAL_SRV_DIR/.env
# Service Config
NODE_ENV=$ORBIS_ENV
PORT=$SERVICE_PORT
HOST=0.0.0.0
SERVICE_NAME=$SERVICE_NAME

# Logging
LOG_LEVEL=info
LOG_PRETTY=true

# Security
REQUIRE_CLIENT_CERT=false
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX_REQUESTS=100
MAX_REQUEST_SIZE=10mb
CORS_ORIGIN=http://$SERVICE_IP:$SERVICE_PORT

# Hyperledger Fabric
FABRIC_NETWORK_NAME=$DOCKER_NETWORK_NAME
FABRIC_CHANNEL_NAME=$REGNUM
FABRIC_CHAINCODE_NAME=$CC
FABRIC_MSP_ID=$AGER

# Peer Connection
FABRIC_PEER_ENDPOINT=$PEER_IP:$PEER_PORT
FABRIC_PEER_HOST_ALIAS=$PEER_NAME

# TLS Certificates
FABRIC_PEER_TLS_CERT=$TLS_CERT_FULL
FABRIC_PEER_TLS_ROOT_CERT=$TLS_ROOT_CERT_FULL

# Gateway Identity (Admin for Service-to-Fabric Communication)
FABRIC_GATEWAY_CERT=$ADMIN_CERT_FULL
FABRIC_GATEWAY_KEY=$ADMIN_KEY_FULL

# Development Mode
SKIP_FABRIC_VALIDATION=false
EOF
}







###############################################################
# Services
###############################################################
for REGNUM in $REGNUMS; do
    CCS=$(yq eval ".Chaincode[] | .Name" $CONFIG_FILE)
    for CC in $CCS; do
        CC_NAME=$(yq eval ".Chaincode[] | select(.Name == \"$CC\") | .Name" $CONFIG_FILE)
        for AGER in $AGERS; do
            SERVICES=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.Services[].Name" $CONFIG_FILE)
            for SERVICE in $SERVICES; do
                ###############################################################
                # Params
                ###############################################################
                SERVICE_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.Services[] | select(.Name == \"$SERVICE\") | .Name" $CONFIG_FILE)
                SERVICE_SOURCE=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.Services[] | select(.Name == \"$SERVICE\") | .Source" $CONFIG_FILE)
                SERVICE_VERSION=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.Services[] | select(.Name == \"$SERVICE\") | .Version" $CONFIG_FILE)
                SERVICE_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.Services[] | select(.Name == \"$SERVICE\") | .IP" $CONFIG_FILE)
                SERVICE_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.Services[] | select(.Name == \"$SERVICE\") | .Port" $CONFIG_FILE)

                # First Peer
                PEER_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[0].Name" $CONFIG_FILE)
                PEER_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[0].IP" $CONFIG_FILE)
                PEER_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[0].Port1" $CONFIG_FILE)

                # Crypto Material
                TLS_CERT_FULL=$(ls "$LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$PEER_NAME/tls/signcerts"/*.pem 2>/dev/null | head -1)
                TLS_CERT_FILE=$(basename "$TLS_CERT_FULL")
                TLS_CERT_DOCKER=/app/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_NAME/tls/signcerts/$TLS_CERT_FILE
                TLS_ROOT_CERT_FULL=$(ls "$LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$PEER_NAME/tls/tlscacerts"/*.pem 2>/dev/null | head -1)
                TLS_ROOT_CERT_FILE=$(basename "$TLS_ROOT_CERT_FULL")
                TLS_ROOT_CERT_DOCKER=/app/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_NAME/tls/tlscacerts/$TLS_ROOT_CERT_FILE
                ADMIN_CERT_FULL=$(ls "$LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/admin.$AGER.$REGNUM.$ORBIS.$ORBIS_ENV/msp/signcerts"/*.pem 2>/dev/null | head -1)
                ADMIN_CERT_FILE=$(basename "$ADMIN_CERT_FULL")
                ADMIN_CERT_DOCKER=/app/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_NAME/msp/signcerts/$ADMIN_CERT_FILE
                ADMIN_KEY_FULL=$(ls "$LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/admin.$AGER.$REGNUM.$ORBIS.$ORBIS_ENV/msp/keystore"/*_sk 2>/dev/null | head -1)
                ADMIN_KEY_FILE=$(basename "$ADMIN_KEY_FULL")
                ADMIN_KEY_DOCKER=/app/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_NAME/msp/keystore/$ADMIN_KEY_FILE

                echo ""
                if [[ $DEBUG == true ]]; then
                    echo_debug "Executing with the following:"
                    echo_value_debug "- Regnum Name:" "${REGNUM}"
                    echo_value_debug "- Ager Name:" "${AGER}"
                    echo_value_debug "- Service:" "${SERVICE_NAME}"
                    echo_value_debug "  - Source:" "${SERVICE_SOURCE}"
                    echo_value_debug "  - Version:" "${SERVICE_VERSION}"
                    echo_value_debug "  - IP:" "${SERVICE_IP}"
                    echo_value_debug "  - Port:" "${SERVICE_PORT}"
                    echo_value_debug "- Chaincode:" "${CC_NAME}"
                    echo_value_debug "- Peer:" "${PEER_NAME} (${PEER_IP}:${PEER_PORT})"
                    echo_value_debug "- TLS Cert:" "$TLS_CERT_FILE"
                    echo_value_debug "- TLS Root:" "$TLS_ROOT_CERT_FILE"
                    echo_value_debug "- Admin Cert:" "$ADMIN_CERT_FILE"
                    echo_value_debug "- Admin Key:" "$ADMIN_KEY_FILE"
                fi
                echo_info "Docker $SERVICE_NAME starting..."

                LOCAL_SRV_DIR=$LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$SERVICE_NAME
                mkdir -p $LOCAL_SRV_DIR
                chmod -R 750 $LOCAL_SRV_DIR

                build_microservice $SERVICE_NAME $SERVICE_VERSION $SERVICE_SOURCE

                if [[ $SERVICE_NAME == "ledger.via.alps.ea.jedo.dev" ]]; then
                    writeenf_ledger-service $SERVICE_NAME $SERVICE_VERSION $SERVICE_IP $SERVICE_PORT $CC_NAME \
                        $PEER_NAME $PEER_IP $PEER_PORT \
                        $TLS_CERT_DOCKER $TLS_ROOT_CERT_DOCKER $ADMIN_CERT_DOCKER $ADMIN_KEY_DOCKER
                fi

                start_microservice $SERVICE_NAME $SERVICE_VERSION $SERVICE_IP $SERVICE_PORT


            done
        done
    done
done
###############################################################
# Last Tasks
###############################################################


