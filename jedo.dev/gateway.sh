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


###############################################################
# Build Gateway Image
###############################################################
GATEWAY_IMAGE="jedo-gateway:1.0"
GATEWAY_SRC_DIR="${PWD}/../gateway"
LOCAL_INFRA_DIR=${PWD}/infrastructure


echo_info "Checking Gateway..."

# Simple check: Image exists?
if ! docker images | grep -q "${GATEWAY_IMAGE}"; then
    REBUILD_REQUIRED=true
    echo_info "Image not found - will build"
else
    REBUILD_REQUIRED=false
    echo_info "Image exists"
    
fi

# Build if required
if [ "$REBUILD_REQUIRED" = true ]; then
    echo_info "Building ${GATEWAY_IMAGE}..."
    
    # Install dependencies
    echo_info "Installing dependencies..."
    (cd "${GATEWAY_SRC_DIR}" && npm install) || { echo_error "npm install failed"; exit 1; }
    
  
    # Clean and build
    echo_info "Building TypeScript..."
    (cd ${GATEWAY_SRC_DIR} && rm -rf dist/ && npm run build) || { echo_error "Build failed"; exit 1; }
    
    # Build Docker image
    echo_info "Building Docker image..."
    docker build -t ${GATEWAY_IMAGE} ${GATEWAY_SRC_DIR} || { echo_error "Docker build failed"; exit 1; }

    echo_info "Image built"
else
    echo_info "Image up-to-date"
fi


###############################################################
# Gateway
###############################################################
for REGNUM in $REGNUMS; do
    CCS=$(yq eval ".Chaincode[] | .Name" $CONFIG_FILE)
    for CC in $CCS; do
        CC_NAME=$(yq eval ".Chaincode[] | select(.Name == \"$CC\") | .Name" $CONFIG_FILE)
        for AGER in $AGERS; do
            ###############################################################
            # Params
            ###############################################################
            GATEWAY_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.Name" $CONFIG_FILE)
            GATEWAY_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.IP" $CONFIG_FILE)
            GATEWAY_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.Port" $CONFIG_FILE)

            # First Peer
            PEER_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[0].Name" $CONFIG_FILE)
            PEER_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[0].IP" $CONFIG_FILE)
            PEER_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[0].Port1" $CONFIG_FILE)

            # CA-API
            CAAPI_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.CAAPI.Name" $CONFIG_FILE)
            CAAPI_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.CAAPI.IP" $CONFIG_FILE)
            CAAPI_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.CAAPI.Port1" $CONFIG_FILE)

            echo ""
            if [[ $DEBUG == true ]]; then
                echo_debug "Executing with the following:"
                echo_value_debug "- Regnum Name:" "$REGNUM"
                echo_value_debug "- Chaincode:" "${CC_NAME}"
                echo_value_debug "- Gateway:" "${GATEWAY_NAME} (${GATEWAY_IP}:${GATEWAY_PORT})"
                echo_value_debug "- Peer:" "${PEER_NAME} (${PEER_IP}:${PEER_PORT})"
            fi
            echo_info "Docker $GATEWAY_NAME starting..."

            LOCAL_SRV_DIR=$LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$GATEWAY_NAME
            mkdir -p $LOCAL_SRV_DIR
            chmod -R 750 $LOCAL_SRV_DIR


            ###############################################################
            # Resolve file paths with wildcards
            ###############################################################
            # TLS Cert
            TLS_CERT_FULL=$(ls "$LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$PEER_NAME/tls/signcerts"/*.pem 2>/dev/null | head -1)
            if [ -z "$TLS_CERT_FULL" ]; then
                echo_error "TLS cert not found for $PEER_NAME"
                exit 1
            fi
            TLS_CERT_FILE=$(basename "$TLS_CERT_FULL")
            if [[ $DEBUG == true ]]; then
                echo_value_debug "- TLS Cert:" "$TLS_CERT_FILE"
            fi
            
            # TLS Root Cert
            TLS_ROOT_CERT_FULL=$(ls "$LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$PEER_NAME/tls/tlscacerts"/*.pem 2>/dev/null | head -1)
            if [ -z "$TLS_ROOT_CERT_FULL" ]; then
                echo_error "TLS root cert not found for $PEER_NAME"
                exit 1
            fi
            TLS_ROOT_CERT_FILE=$(basename "$TLS_ROOT_CERT_FULL")
            if [[ $DEBUG == true ]]; then
                echo_value_debug "- TLS Root:" "$TLS_ROOT_CERT_FILE"
            fi


            ###############################################################
            # Parse Services from YAML
            ###############################################################
            log_debug "" "Parsing services from infrastructure.yaml..."

            declare -A SERVICE_URLS
            SERVICES=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.Services[]" $CONFIG_FILE -o=json)

            while IFS= read -r service; do
                if [ -n "$service" ]; then
                    SVC_NAME=$(echo "$service" | jq -r '.Name')
                    SVC_IP=$(echo "$service" | jq -r '.IP')
                    SVC_PORT=$(echo "$service" | jq -r '.Port')
                    
                    # Extract Service-Typ from Name (ledger.via... -> LEDGER)
                    SVC_TYPE=$(echo "$SVC_NAME" | cut -d'.' -f1 | tr '[:lower:]' '[:upper:]')
                    
                    SERVICE_URLS["${SVC_TYPE}_API_URL"]="http://${SVC_IP}:${SVC_PORT}"
                    log_debug "${SVC_TYPE}_API_URL" "http://${SVC_IP}:${SVC_PORT}"
                fi
            done < <(echo "$SERVICES" | jq -c '.')


            ###############################################################
            # Write .env
            ###############################################################
            echo ""
            echo_info "Environment for $GATEWAY_NAME writing..."
cat <<EOF > $LOCAL_SRV_DIR/.env
# Server Configuration
NODE_ENV=$ORBIS_ENV
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
FABRIC_MSP_ID=$AGER

# Fabric Peer Connection
FABRIC_PEER_ENDPOINT=$PEER_NAME:$PEER_PORT
FABRIC_PEER_HOST_ALIAS=$PEER_NAME
FABRIC_PEER_TLS_CERT=./infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_NAME/tls/signcerts/$TLS_CERT_FILE
FABRIC_PEER_TLS_ROOT_CERT=./infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_NAME/tls/tlscacerts/$TLS_ROOT_CERT_FILE

# Fabric Peer Connection
FABRIC_AGER_MSP_CA_CERTS_PATH=./infrastructure/$ORBIS/$REGNUM/$AGER/msp/cacerts
FABRIC_AGER_MSP_INTERMEDIATE_CERTS_PATH=./infrastructure/$ORBIS/$REGNUM/$AGER/msp/intermediatecerts

# Microservices (dynamically generated)
EOF

for key in "${!SERVICE_URLS[@]}"; do
    echo "$key=${SERVICE_URLS[$key]}" >> $LOCAL_SRV_DIR/.env
done

cat <<EOF >> $LOCAL_SRV_DIR/.env

# CA-API für Certificate Management
#CA_API_URL=https://$CAAPI_NAME:$CAAPI_PORT
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
                --user $(id -u):$(id -g) \
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
                -v $LOCAL_INFRA_DIR:/app/infrastructure:ro \
                jedo-gateway:1.0

            CheckContainer "$GATEWAY_NAME" "$DOCKER_CONTAINER_WAIT"
            CheckContainerLog "$GATEWAY_NAME" "JEDO Gateway Server started successfully" "$DOCKER_CONTAINER_WAIT"

            echo ""
            echo_info "Gateway $GATEWAY_NAME started."
        done
    done
done
###############################################################
# Last Tasks
###############################################################


