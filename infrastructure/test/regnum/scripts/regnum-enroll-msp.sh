###############################################################
#!/bin/bash
#
# This script register and enroll TLS-Material for MSP-CA.
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

TLS_PASS_RAW=""
MSP_PASS_RAW=""

usage() {
  log_error "Usage: $0 <tls-password> <new-msp-password> [--debug]" >&2
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
      # first non-Option-Argument = TLS_PASS
      if [[ -z "$TLS_PASS_RAW" ]]; then
        TLS_PASS_RAW="$1"
      elif [[ -z "$MSP_PASS_RAW" ]]; then
        MSP_PASS_RAW="$1"
      else
        log_error "To many arguments: '$1'" >&2
        usage
      fi
      shift
      ;;
  esac
done

if [[ -z "${TLS_PASS_RAW:-}" ]]; then
  usage
fi

if [[ -z "${MSP_PASS_RAW:-}" ]]; then
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

REGNUM_TLS_NAME=tls.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD
REGNUM_TLS_IP=$(yq eval '.Regnum.tls.IP' "${CONFIGFILE}")
REGNUM_TLS_PORT=$(yq eval '.Regnum.tls.Port' "${CONFIGFILE}")

REGNUM_MSP_NAME=msp.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD
REGNUM_MSP_IP=$(yq eval '.Regnum.msp.IP' "${CONFIGFILE}")
REGNUM_MSP_PORT=$(yq eval '.Regnum.msp.Port' "${CONFIGFILE}")

TLS_CA_URL=https://$REGNUM_TLS_NAME:$REGNUM_TLS_PORT
TLS_CHAIN=/etc/hyperledger/fabric-ca-server/ca/chain.cert
TLS_CLIENT_HOME=/etc/hyperledger/fabric-ca-server/client-tls-admin
HOST_CA_DIR="/etc/hyperledger/fabric-ca-server"
LOCAL_MSP_DIR=/etc/hyperledger/fabric-ca-server/$REGNUM_MSP_NAME


###############################################################
# Debug Logging
###############################################################
log_debug "Docker Network:" "${DOCKER_NETWORK} (${DOCKER_SUBNET})"
log_debug "Orbis Info:" "$ORBIS_NAME - $ORBIS_ENV - $ORBIS_TLD"
log_debug "TLS Info:" "$REGNUM_TLS_NAME - $TLS_PASS_RAW @ $REGNUM_TLS_IP:$REGNUM_TLS_PORT"
log_debug "MSP Info:" "$REGNUM_MSP_NAME - $MSP_PASS_RAW @ $REGNUM_MSP_IP:$REGNUM_MSP_PORT"
log_debug "Local MSP Dir:" "$LOCAL_MSP_DIR"
log_debug "Host CA Dir:" "$HOST_CA_DIR"


###############################################################
# RUN
###############################################################
$SCRIPTDIR/prereq.sh

log_info "$REGNUM_MSP_NAME enrolling ..."

# Enroll TLS-Admin
docker exec "${REGNUM_TLS_NAME}" \
  sh -c "export FABRIC_CA_CLIENT_HOME=${TLS_CLIENT_HOME} && \
         fabric-ca-client enroll \
           -u https://$REGNUM_TLS_NAME:$TLS_PASS_RAW@$REGNUM_TLS_NAME:$REGNUM_TLS_PORT \
           --tls.certfiles ${TLS_CHAIN}"
log_debug "TLS-Admin enrolled"

# Register MSP-CA @ TLS-CA
docker exec "${REGNUM_TLS_NAME}" \
  sh -c "export FABRIC_CA_CLIENT_HOME=${TLS_CLIENT_HOME} && \
         fabric-ca-client register \
           -u ${TLS_CA_URL} \
           --tls.certfiles ${TLS_CHAIN} \
           --id.name ${REGNUM_MSP_NAME} \
           --id.secret ${MSP_PASS_RAW} \
           --id.type client \
           --id.affiliation jedo.$REGNUM_NAME"
log_debug "MSP-CA registered"

# Enroll MSP-CA
docker exec "${REGNUM_TLS_NAME}" \
  sh -c "export FABRIC_CA_CLIENT_HOME=${TLS_CLIENT_HOME} && \
         fabric-ca-client enroll \
           -u https://${REGNUM_MSP_NAME}:${MSP_PASS_RAW}@$REGNUM_TLS_NAME:$REGNUM_TLS_PORT \
           --tls.certfiles ${TLS_CHAIN} \
           --mspdir ${LOCAL_MSP_DIR} \
           --enrollment.profile tls \
           --csr.hosts ${REGNUM_MSP_NAME},$REGNUM_MSP_IP"
log_debug "MSP-CA enrolled"

chmod -R 750 $LOCAL_MSP_DIR

log_ok "$REGNUM_MSP_NAME enrolled."