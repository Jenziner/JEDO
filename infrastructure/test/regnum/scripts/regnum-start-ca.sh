###############################################################
#!/bin/bash
#
# This script starts regnum ca docker container.
#
###############################################################
set -euo pipefail

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTDIR/utils.sh"

log_section "JEDO-Ecosystem - new Regnum - CA starting..."


###############################################################
# Usage / Argument-Handling
###############################################################
export LOGLEVEL="INFO"
export DEBUG=false
export FABRIC_CA_SERVER_LOGLEVEL="info"       # critical, fatal, warning, info, debug
export FABRIC_CA_CLIENT_LOGLEVEL="info"       # critical, fatal, warning, info, debug
export FABRIC_LOGGING_SPEC="INFO"             # FATAL, PANIC, ERROR, WARNING, INFO, DEBUG
export CORE_CHAINCODE_LOGGING_LEVEL="INFO"    # CRITICAL, ERROR, WARNING, NOTICE, INFO, DEBUG

CA_TYPE_RAW=""
PASS_RAW=""

usage() {
  log_error "Usage: $0 <tls|msp> <password> [--debug]" >&2
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
      if [[ -z "$CA_TYPE_RAW" ]]; then
        CA_TYPE_RAW="$1"
      elif [[ -z "$PASS_RAW" ]]; then
        PASS_RAW="$1"
      else
        log_error "To many arguments: '$1'" >&2
        usage
      fi
      shift
      ;;
  esac
done

if [[ -z "${CA_TYPE_RAW:-}" ]]; then
  usage
fi

CA_TYPE="${CA_TYPE_RAW,,}"   # to lowercase

if [[ "$CA_TYPE" != "tls" && "$CA_TYPE" != "msp" ]]; then
  log_error "Wrong CA type: '$CA_TYPE'" >&2
  usage
fi


###############################################################
# Config
###############################################################
CONFIGFILE="${SCRIPTDIR}/../config/regnum.yaml"

DOCKER_NETWORK=$(yq eval '.Docker.Network' "${CONFIGFILE}")
DOCKER_SUBNET=$(yq eval '.Docker.Subnet' "${CONFIGFILE}")
DOCKER_GATEWAY=$(yq eval '.Docker.Gateway' "${CONFIGFILE}")
DOCKER_WAIT=$(yq eval '.Docker.Wait' "${CONFIGFILE}")

ORBIS_NAME=$(yq eval '.Orbis.Name' "${CONFIGFILE}")
ORBIS_ENV=$(yq eval '.Orbis.Env' "${CONFIGFILE}")
ORBIS_TLD=$(yq eval '.Orbis.Tld' "${CONFIGFILE}")

REGNUM_NAME=$(yq eval '.Regnum.Name' "${CONFIGFILE}")
REGNUM_CA_NAME=$CA_TYPE.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD
REGNUM_CA_IP=$(yq eval '.Regnum.'$CA_TYPE'.IP' "${CONFIGFILE}")
REGNUM_CA_PORT=$(yq eval '.Regnum.'$CA_TYPE'.Port' "${CONFIGFILE}")
REGNUM_CA_OPPORT=$(yq eval '.Regnum.'$CA_TYPE'.OpPort' "${CONFIGFILE}")

LOCAL_CAROOTS_DIR="${SCRIPTDIR}/../../infrastructure/tls-ca-roots"
HOST_CAROOTS_DIR="/etc/hyperledger/tls-ca-roots"

LOCAL_SRV_DIR="${SCRIPTDIR}/../../infrastructure/servers/${REGNUM_CA_NAME}"
HOST_SRV_DIR="/etc/hyperledger/fabric-ca-server"

LOCAL_CLIENT_DIR="${SCRIPTDIR}/../../infrastructure/clients/bootstrap.${REGNUM_CA_NAME}"
HOST_CLIENT_DIR="/etc/hyperledger/fabric-ca-client"


###############################################################
# Debug Logging
###############################################################
log_debug "Docker Network:" "${DOCKER_NETWORK} (${DOCKER_SUBNET})"
log_debug "Orbis Info:" "$ORBIS_NAME - $ORBIS_ENV - $ORBIS_TLD"
log_debug "Regnum Info:" "$REGNUM_CA_NAME:$PASS_RAW@$REGNUM_CA_IP:$REGNUM_CA_PORT"
log_debug "CA-Roots Dir:" "$LOCAL_CAROOTS_DIR"
log_debug "Server Dir:" "$LOCAL_SRV_DIR"


###############################################################
# RUN
###############################################################
$SCRIPTDIR/prereq.sh

log_info "$REGNUM_CA_NAME starting ..."

# Start docker network if not running
if ! docker network ls --format '{{.Name}}' | grep -wq "$DOCKER_NETWORK"; then
    docker network create --subnet=$DOCKER_SUBNET --gateway=$DOCKER_GATEWAY "$DOCKER_NETWORK"
fi
docker network inspect "$DOCKER_NETWORK"

# Docker Container starten
docker run -d \
  --name "${REGNUM_CA_NAME}" \
  --network "${DOCKER_NETWORK}" \
  --ip "${REGNUM_CA_IP}" \
  -p "${REGNUM_CA_PORT}:${REGNUM_CA_PORT}" \
  -p "${REGNUM_CA_OPPORT}:${REGNUM_CA_OPPORT}" \
  -v "${LOCAL_SRV_DIR}:${HOST_SRV_DIR}" \
  -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
  -e FABRIC_CA_SERVER_LOGLEVEL=$FABRIC_CA_SERVER_LOGLEVEL \
  hyperledger/fabric-ca:latest \
  fabric-ca-server start -b bootstrap.${REGNUM_CA_NAME}:${PASS_RAW}
log_debug "Regnum-CA started"

# Waiting Orbis-TLS Container startup
CheckContainer "$REGNUM_CA_NAME" "$DOCKER_WAIT"
CheckContainerLog "$REGNUM_CA_NAME" "Listening on https://0.0.0.0:$REGNUM_CA_PORT" "$DOCKER_WAIT"

# define profile used
if [[ "${CA_TYPE}" == "tls" ]]; then
  CA_PROFILE="tls"
elif [[ "${CA_TYPE}" == "msp" ]]; then
  CA_PROFILE="ca"
fi

# Enroll Bootstrap
log_info "Enrolling bootstrap..${REGNUM_CA_NAME}..."
docker run --rm \
  --network "${DOCKER_NETWORK}" \
  -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
  -v "${LOCAL_CLIENT_DIR}:${HOST_CLIENT_DIR}" \
  -e FABRIC_MSP_CLIENT_HOME="${HOST_CLIENT_DIR}" \
  -e FABRIC_CA_CLIENT_LOGLEVEL=${FABRIC_CA_CLIENT_LOGLEVEL} \
  hyperledger/fabric-ca:latest \
  fabric-ca-client enroll \
      -u https://bootstrap.${REGNUM_CA_NAME}:${PASS_RAW}@${REGNUM_CA_NAME}:${REGNUM_CA_PORT} \
      --tls.certfiles ${HOST_CAROOTS_DIR}/tls.${REGNUM_NAME}.${ORBIS_NAME}.${ORBIS_TLD}.pem \
      --enrollment.profile ${CA_PROFILE} \
      --mspdir ${HOST_CLIENT_DIR}
log_debug "Bootstrap enrolled"

# Generating ca-certs in server
docker run --rm \
  --network "${DOCKER_NETWORK}" \
  -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
  -v "${LOCAL_SRV_DIR}:${HOST_SRV_DIR}" \
  -v "${LOCAL_CLIENT_DIR}:${HOST_CLIENT_DIR}" \
  -e FABRIC_MSP_CLIENT_HOME="${HOST_CLIENT_DIR}" \
  -e FABRIC_CA_CLIENT_LOGLEVEL=${FABRIC_CA_CLIENT_LOGLEVEL} \
  hyperledger/fabric-ca:latest \
  fabric-ca-client getcainfo \
      -u https://${REGNUM_CA_NAME}:${REGNUM_CA_PORT} \
      --tls.certfiles ${HOST_CAROOTS_DIR}/tls.${REGNUM_NAME}.${ORBIS_NAME}.${ORBIS_TLD}.pem \
      -M ${HOST_SRV_DIR}/msp
log_debug "CA-Certs generated"

CA_CERT_FILE=$(ls $LOCAL_SRV_DIR/msp/cacerts/*.pem)
log_debug "CA Cert-File:" "$CA_CERT_FILE"
cat <<EOF > $LOCAL_SRV_DIR/msp/config.yaml
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: orderer
EOF
log_debug "NodeOUs-Files generated"

chmod -R 750 $SCRIPTDIR/../../infrastructure

log_ok "$REGNUM_CA_NAME started."