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
export FABRIC_CA_SERVER_LOGLEVEL="info"

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
      FABRIC_CA_SERVER_LOGLEVEL="DEBUG"
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
REGNUM_IP=$(yq eval '.Regnum.'$CA_TYPE'.IP' "${CONFIGFILE}")
REGNUM_PORT=$(yq eval '.Regnum.'$CA_TYPE'.Port' "${CONFIGFILE}")
REGNUM_OPPORT=$(yq eval '.Regnum.'$CA_TYPE'.OpPort' "${CONFIGFILE}")

LOCAL_CA_DIR="${SCRIPTDIR}/../../infrastructure/$REGNUM_CA_NAME"
HOST_CA_DIR="/etc/hyperledger/fabric-ca-server"


###############################################################
# Debug Logging
###############################################################
log_debug "Password:" "${PASS_RAW}"
log_debug "Docker Network:" "${DOCKER_NETWORK} (${DOCKER_SUBNET})"
log_debug "Orbis Info:" "$ORBIS_NAME - $ORBIS_ENV - $ORBIS_TLD"
log_debug "Regnum Info:" "$REGNUM_CA_NAME - $REGNUM_IP - $REGNUM_PORT"
log_debug "Local CA Dir:" "$LOCAL_CA_DIR"
log_debug "Host CA Dir:" "$HOST_CA_DIR"


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
  --ip "${REGNUM_IP}" \
  -p "${REGNUM_PORT}:${REGNUM_PORT}" \
  -p "${REGNUM_OPPORT}:${REGNUM_OPPORT}" \
  -v "${LOCAL_CA_DIR}:${HOST_CA_DIR}" \
  -e FABRIC_CA_SERVER_LOGLEVEL=$LOGLEVEL \
  hyperledger/fabric-ca:latest \
  sh -c "fabric-ca-server start -b ${REGNUM_CA_NAME}:${PASS_RAW} --home ${HOST_CA_DIR}"

# Waiting Orbis-TLS Container startup
CheckContainer "$REGNUM_CA_NAME" "$DOCKER_WAIT"
CheckContainerLog "$REGNUM_CA_NAME" "Listening on https://0.0.0.0:$REGNUM_PORT" "$DOCKER_WAIT"

log_ok "$REGNUM_CA_NAME started."