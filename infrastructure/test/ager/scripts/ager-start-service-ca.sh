###############################################################
#!/bin/bash
#
# This script starts ager peer docker container.
#
###############################################################
set -euo pipefail

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTDIR/utils.sh"
source "$SCRIPTDIR/ager-service-util.sh"

log_section "JEDO-Ecosystem - new Ager - CA-Service starting..."


###############################################################
# Usage / Argument-Handling
###############################################################
export LOGLEVEL="INFO"
export DEBUG=false
export FABRIC_CA_SERVER_LOGLEVEL="info"       # critical, fatal, warning, info, debug
export FABRIC_CA_CLIENT_LOGLEVEL="info"       # critical, fatal, warning, info, debug
export FABRIC_LOGGING_SPEC="INFO"             # FATAL, PANIC, ERROR, WARNING, INFO, DEBUG
export CORE_CHAINCODE_LOGGING_LEVEL="INFO"    # CRITICAL, ERROR, WARNING, NOTICE, INFO, DEBUG

AGER_CERTS_CONFIG=""
AGER_INFRA_CONFIG=""
AGER_ADMIN_NAME=""
AGER_ADMIN_PASS=""
HARBOR_USER='robot$cd'
HARBOR_PASS=""

usage() {
  log_error "Usage: $0 <config-certs-filename> <config-infra-filename> <admin> <admin-password> <harbor-password> [--debug]" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)
      DEBUG=true
      LOGLEVEL="DEBUG"
      FABRIC_CA_SERVER_LOGLEVEL="debug"
      FABRIC_CA_CLIENT_LOGLEVEL="debug"
      FABRIC_LOGGING_SPEC="DEBUG"
      CORE_CHAINCODE_LOGGING_LEVEL="DEBUG"
      shift
      ;;
    -*)
      log_error "Unkown Option: $1" >&2
      usage
      ;;
    *)
      # first non-Option-Argument = CA_TYPE
      if [[ -z "$AGER_CERTS_CONFIG" ]]; then
        AGER_CERTS_CONFIG="$1"
      elif [[ -z "$AGER_INFRA_CONFIG" ]]; then
        AGER_INFRA_CONFIG="$1"
      elif [[ -z "$AGER_ADMIN_NAME" ]]; then
        AGER_ADMIN_NAME="$1"
      elif [[ -z "$AGER_ADMIN_PASS" ]]; then
        AGER_ADMIN_PASS="$1"
      elif [[ -z "$HARBOR_PASS" ]]; then
        HARBOR_PASS="$1"
      else
        log_error "To many arguments: '$1'" >&2
        usage
      fi
      shift
      ;;
  esac
done

if [[ -z "$AGER_CERTS_CONFIG" ]] || [[ -z "$AGER_INFRA_CONFIG" ]] || [[ -z "$AGER_ADMIN_NAME" ]] || [[ -z "$AGER_ADMIN_PASS" ]] || [[ -z "$HARBOR_PASS" ]]; then
  usage
fi


###############################################################
# Config
###############################################################
CERTS_CONFIGFILE="${SCRIPTDIR}/../config/$AGER_CERTS_CONFIG"
INFRA_CONFIGFILE="${SCRIPTDIR}/../config/$AGER_INFRA_CONFIG"

DOCKER_NETWORK=$(yq eval '.Docker.Network' "${INFRA_CONFIGFILE}")
DOCKER_SUBNET=$(yq eval '.Docker.Subnet' "${INFRA_CONFIGFILE}")
DOCKER_GATEWAY=$(yq eval '.Docker.Gateway' "${INFRA_CONFIGFILE}")
DOCKER_WAIT=$(yq eval '.Docker.Wait' "${INFRA_CONFIGFILE}")

ORBIS_NAME=$(yq eval '.Orbis.Name' "${INFRA_CONFIGFILE}")
ORBIS_ENV=$(yq eval '.Orbis.Env' "${INFRA_CONFIGFILE}")
ORBIS_TLD=$(yq eval '.Orbis.Tld' "${INFRA_CONFIGFILE}")

REGNUM_NAME=$(yq eval '.Regnum.Name' "${INFRA_CONFIGFILE}")
REGNUM_TLS_NAME=$(yq eval '.Regnum.tls.Name' "${INFRA_CONFIGFILE}")
REGNUM_TLS_NAME=$REGNUM_TLS_NAME.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD
REGNUM_TLS_PORT=$(yq eval '.Regnum.tls.Port' "${INFRA_CONFIGFILE}")

AGER_NAME=$(yq eval '.Ager.Name' "${INFRA_CONFIGFILE}")
AGER_CA_NAME=$(yq eval '.Ager.msp.Name' "${INFRA_CONFIGFILE}")
AGER_CA_NAME=$AGER_CA_NAME.$AGER_NAME.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD
AGER_CA_IP=$(yq eval '.Ager.msp.IP' "${INFRA_CONFIGFILE}")
AGER_CA_PORT=$(yq eval '.Ager.msp.Port' "${INFRA_CONFIGFILE}")

AFFILIATION=$ORBIS_NAME.$REGNUM_NAME.$AGER_NAME

# Service Config
GATEWAY_NAME=$(yq eval ".Ager.Gateway.Name" $INFRA_CONFIGFILE)
SERVICE_NAME=$(yq eval ".Ager.Gateway.CA-Service.Name" $INFRA_CONFIGFILE)
SERVICE_NAME=$SERVICE_NAME.$GATEWAY_NAME.$AGER_NAME.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD
SERVICE_SOURCE=$(yq eval ".Ager.Gateway.CA-Service.Source" $INFRA_CONFIGFILE)
SERVICE_VERSION=$(yq eval ".Ager.Gateway.CA-Service.Version" $INFRA_CONFIGFILE)
SERVICE_IP=$(yq eval ".Ager.Gateway.CA-Service.IP" $INFRA_CONFIGFILE)
SERVICE_PORT=$(yq eval ".Ager.Gateway.CA-Service.Port" $INFRA_CONFIGFILE)
SERVICE_SECRET=$(yq eval ".Ager.Gateway.CA-Service.Secret" ${CERTS_CONFIGFILE})
SERVICE_CSR="C=XX,ST=$ORBIS_ENV,L=$REGNUM_NAME,O=$AGER_NAME"

LOCAL_CAROOTS_DIR="${SCRIPTDIR}/../../infrastructure/tls-ca-roots"
HOST_CAROOTS_DIR="/etc/hyperledger/tls-ca-roots"

LOCAL_SRV_DIR="${SCRIPTDIR}/../../infrastructure/servers/${SERVICE_NAME}"
HOST_SRV_DIR="/etc/hyperledger/fabric-ca-server"



###############################################################
# Debug Logging
###############################################################
log_debug "Docker Network:" "${DOCKER_NETWORK} (${DOCKER_SUBNET})"
log_debug "Orbis Info:" "$ORBIS_NAME - $ORBIS_ENV - $ORBIS_TLD"
log_debug "Regnum Name:" "${REGNUM_NAME}"
log_debug "Ager Name:" "${AGER_NAME}"
log_debug "CA Info:" "$AGER_CA_NAME:$AGER_CA_PORT"
log_debug "Service:" "${SERVICE_NAME}:V${SERVICE_VERSION}"
log_debug "- Source:" "${SERVICE_SOURCE}"
log_debug "- IP:" "${SERVICE_IP}"
log_debug "- Port:" "${SERVICE_PORT}"
log_debug "Regnum TLS Info:" "$REGNUM_TLS_NAME:$REGNUM_TLS_PORT"
log_debug "Service Cert Info:" "$SERVICE_NAME:$SERVICE_SECRET@$SERVICE_IP:$SERVICE_PORT"
log_debug "Service CSR:" "$SERVICE_CSR"
log_debug "Local Server Dir:" "$LOCAL_SRV_DIR"
log_debug "Host Server Dir:" "$HOST_SRV_DIR"


###############################################################
# RUN
###############################################################
log_info "CA-Service starting ..."

$SCRIPTDIR/prereq.sh

# Start docker network if not running
if ! docker network ls --format '{{.Name}}' | grep -wq "$DOCKER_NETWORK"; then
    docker network create --subnet=$DOCKER_SUBNET --gateway=$DOCKER_GATEWAY "$DOCKER_NETWORK"
fi
docker network inspect "$DOCKER_NETWORK"

# Prepare local directory
mkdir -p $LOCAL_SRV_DIR
chmod -R 750 $LOCAL_SRV_DIR

# Enroll Ager-CA-Service
log_info "$SERVICE_NAME enrolling server certificates..."

# Enroll @ Regnum TLS-CA
# docker run --rm \
#   --network "${DOCKER_NETWORK}" \
#   -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
#   -v "${LOCAL_SRV_DIR}:${HOST_SRV_DIR}" \
#   -e FABRIC_MSP_CLIENT_HOME="${HOST_SRV_DIR}" \
#   -e FABRIC_CA_CLIENT_LOGLEVEL=${FABRIC_CA_CLIENT_LOGLEVEL} \
#   hyperledger/fabric-ca:latest \
#   fabric-ca-client enroll \
#       -u https://$SERVICE_NAME:$SERVICE_SECRET@$REGNUM_TLS_NAME:$REGNUM_TLS_PORT \
#       --tls.certfiles ${HOST_CAROOTS_DIR}/${REGNUM_TLS_NAME}.pem \
#       --mspdir ${HOST_SRV_DIR}/tls \
#       --enrollment.profile tls \
#       --csr.hosts ${SERVICE_NAME},${SERVICE_IP} \
#       --csr.cn $SERVICE_NAME --csr.names "$SERVICE_CSR"
log_debug "TLS-CA-Service enrolled"

# Crypto Material
TLS_CERT_FULL=$(ls "$LOCAL_SRV_DIR/tls/signcerts"/*.pem 2>/dev/null | head -1)
TLS_CERT_FILE=$(basename "$TLS_CERT_FULL")
TLS_CERT_DOCKER=/app/tls/signcerts/$TLS_CERT_FILE
TLS_KEY_FULL=$(ls "$LOCAL_SRV_DIR/tls/keystore"/*_sk 2>/dev/null | head -1)
TLS_KEY_FILE=$(basename "$TLS_KEY_FULL")
TLS_KEY_DOCKER=/app/tls/keystore/$TLS_KEY_FILE
TLS_CA_FULL=$(ls "$LOCAL_SRV_DIR/tls/tlscacerts"/*.pem 2>/dev/null | head -1)
TLS_CA_FILE=$(basename "$TLS_CA_FULL")
TLS_CA_DOCKER=/app/tls/tlscacerts/$TLS_CA_FILE

# Debug Logging
log_debug "Service TLS Cert:" "$TLS_CERT_DOCKER"
log_debug "Service TLS Server Cert:" "$TLS_CA_DOCKER"


# Write .env for ca-service
log_info "Environment for $SERVICE_NAME writing..."
cat <<EOF > $LOCAL_SRV_DIR/.env
# ========================================
# CA-SERVICE CONFIGURATION
# ========================================
# Server Configuration
NODE_ENV=$ORBIS_ENV
PORT=$SERVICE_PORT
HOST=0.0.0.0
SERVICE_NAME=$SERVICE_NAME
MSP_CA_PATH=/app/msp-ca

# Logging
LOG_LEVEL=$LOGLEVEL
LOG_PRETTY=true

# Security
REQUIRE_CLIENT_CERT=false
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX_REQUESTS=20
MAX_REQUEST_SIZE=10mb
CORS_ORIGIN=http://$SERVICE_IP:$SERVICE_PORT

# ========================================
# SERVER TLS (HTTPS Server für API)
# ========================================
TLS_ENABLED=true
TLS_CERT_PATH=$TLS_CERT_DOCKER
TLS_KEY_PATH=$TLS_KEY_DOCKER
TLS_CA_PATH=$TLS_CA_DOCKER

# ========================================
# FABRIC CA CLIENT CONFIG
# ========================================
# CA Configuration
FABRIC_CA_NAME=$AGER_CA_NAME
FABRIC_CA_URL=https://$AGER_CA_NAME:$AGER_CA_PORT
FABRIC_CA_ADMIN_USER=$AGER_ADMIN_NAME
FABRIC_CA_ADMIN_PASS=$AGER_ADMIN_PASS
FABRIC_MSP_ID=$AGER_NAME

# Idemix Configuration
FABRIC_CA_IDEMIX_CURVE=gurvy.Bn254

# ========================================
# FABRIC CA TLS (Client → Fabric CA)
# ========================================
FABRIC_CA_TLS_CERT_PATH=${HOST_CAROOTS_DIR}/tls-chain.pem
FABRIC_CA_TLS_VERIFY=true

# ========================================
# HIERARCHY
# ========================================
FABRIC_ORBIS_NAME=$ORBIS_NAME
FABRIC_REGNUM_NAME=$REGNUM_NAME
FABRIC_AGER_NAME=$AGER_NAME

# ========================================
# CRYPTO PATH
# ========================================
CRYPTO_PATH=/app/production
EOF

# Harbor Login
log_info "Logging in to Harbor..."
echo "$HARBOR_PASS" | docker login harbor.jedo.me \
    --username $HARBOR_USER \
    --password-stdin || {
    log_error "Harbor login failed"
    exit 1
}

# Harbor Registry Configuration
HARBOR_REGISTRY="harbor.jedo.me"
HARBOR_PROJECT="services"
SERVICE_IMAGE_LOCAL="$SERVICE_NAME:$SERVICE_VERSION"
# SERVICE_IMAGE_HARBOR="$HARBOR_REGISTRY/$HARBOR_PROJECT/ca-service:${SERVICE_VERSION}"
SERVICE_IMAGE_HARBOR="$HARBOR_REGISTRY/$HARBOR_PROJECT/ca-service:latest"

LOCAL_INFRA_DIR=${PWD}/infrastructure

# Pull from Harbor Registry
log_info "Pulling $SERVICE_NAME from Harbor..."
docker pull $SERVICE_IMAGE_HARBOR || {
    log_error "Failed to pull image from Harbor"
    exit 1
}

# Tag for local use (optional, falls du lokale Namen nutzen willst)
docker tag $SERVICE_IMAGE_HARBOR $SERVICE_IMAGE_LOCAL

log_info "Docker $SERVICE_NAME starting..."
mkdir -p $LOCAL_INFRA_DIR/$SERVICE_NAME/production
chmod -R 750 $LOCAL_INFRA_DIR/$SERVICE_NAME/production

docker run -d \
    --user $(id -u):$(id -g) \
    --name $SERVICE_NAME \
    --network $DOCKER_NETWORK \
    --ip $SERVICE_IP \
    --restart=on-failure:1 \
    --health-cmd="node -e \"require('http').get('http://$SERVICE_IP:${SERVICE_PORT}/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})\"" \
    --health-interval=30s \
    --health-timeout=10s \
    --health-start-period=40s \
    --health-retries=3 \
    -e PORT=$SERVICE_PORT \
    -p $SERVICE_PORT:$SERVICE_PORT \
    --env-file $LOCAL_SRV_DIR/.env \
    -v $LOCAL_CAROOTS_DIR:$HOST_CAROOTS_DIR:ro \
    -v $LOCAL_SRV_DIR/tls:/app/tls:ro \
    -v $LOCAL_SRV_DIR/production:/app/production \
    -v $LOCAL_SRV_DIR/../$AGER_CA_NAME:/app/msp-ca:ro \
    $SERVICE_IMAGE_HARBOR  # Harbor Image direkt nutzen

CheckContainer "$SERVICE_NAME" "$DOCKER_WAIT"
CheckContainerLog "$SERVICE_NAME" "CA Service started successfully" "$DOCKER_WAIT"


log_ok "CA-Service $SERVICE_NAME started."

chmod -R 750 $SCRIPTDIR/../../infrastructure

 chmod -R 777 /mnt/user/appdata/jedo/demo/infrastructure
