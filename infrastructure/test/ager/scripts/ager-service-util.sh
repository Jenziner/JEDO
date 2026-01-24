#!/bin/bash


###############################################################
# Build Service Image
###############################################################
build_microservice() {
    local SERVICE_NAME=$1
    local SERVICE_VERSION=$2
    local SERVICE_SRC_DIR=$3
    local SERVICE_IMAGE="$SERVICE_NAME:$SERVICE_VERSION"

    SERVICE_SRC_DIR="../../$SERVICE_SRC_DIR"

    log_info "$SERVICE_NAME building..."

    # Simple check: Image exists?
    log_debug "Checking Image..."
    if ! docker images | grep -q "${SERVICE_IMAGE}"; then
        REBUILD_REQUIRED=true
        log_debug "Image not found - will build"
    else
        REBUILD_REQUIRED=false
        log_debug "Image exists"
        
    fi

    # Build if required
    if [ "$REBUILD_REQUIRED" = true ]; then
        log_debug "Building ${SERVICE_IMAGE}..."
        
        # Install dependencies
        log_debug "Installing dependencies..."
        (cd "${SERVICE_SRC_DIR}" && npm install) || { log_error "npm install failed"; exit 1; }
        
        # Check if TypeScript project (has tsconfig.json)
        if [ -f "${SERVICE_SRC_DIR}/tsconfig.json" ]; then
            log_debug "TypeScript project detected - building..."
            (cd ${SERVICE_SRC_DIR} && rm -rf dist/ && npm run build) || { log_error "TypeScript build failed"; exit 1; }
        fi

        # Build Docker image
        log_debug "Building Docker image..."
        docker build -t ${SERVICE_IMAGE} ${SERVICE_SRC_DIR} || { log_error "Docker build failed"; exit 1; }

        log_debug "Image built"
    else
        log_debug "Image up-to-date"
    fi

    log_ok "$SERVICE_NAME built."
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

    log_info "Docker $SERVICE_NAME starting..."
    mkdir -p $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$SERVICE_NAME/production
    chmod -R 750 $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$SERVICE_NAME/production
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
        -v $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$SERVICE_NAME/production:/app/production \
        $SERVICE_IMAGE

    CheckContainer "$SERVICE_NAME" "$DOCKER_CONTAINER_WAIT"
    if [[ $SERVICE_NAME == "ca.via.alps.ea.jedo.dev" ]]; then
        CheckContainerLog "$SERVICE_NAME" "CA Service started successfully" "$DOCKER_CONTAINER_WAIT"
    fi

    if [[ $SERVICE_NAME == "ledger.via.alps.ea.jedo.dev" ]]; then
        CheckContainerLog "$SERVICE_NAME" "GET /health completed" "$DOCKER_CONTAINER_WAIT"
    fi

    log_ok "Microservice $SERVICE_NAME started."
}