###############################################################
#!/bin/bash
#
# This script enrolls Admin Material.
#
###############################################################
set -euo pipefail

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTDIR/utils.sh"

log_section "JEDO-Ecosystem - Admin enrolling..."


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
AGER_ORG_PASS_RAW=""

usage() {
  log_error "Usage: $0 <config-certs-filename> <config-infra-filename> <msp-org-password> [--debug]" >&2
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
      # first non-Option-Argument = TLS_PASS
      if [[ -z "$AGER_CERTS_CONFIG" ]]; then
        AGER_CERTS_CONFIG="$1"
      elif [[ -z "$AGER_INFRA_CONFIG" ]]; then
        AGER_INFRA_CONFIG="$1"
      elif [[ -z "$AGER_ORG_PASS_RAW" ]]; then
        AGER_ORG_PASS_RAW="$1"
      else
        log_error "To many arguments: '$1'" >&2
        usage
      fi
      shift
      ;;
  esac
done

if [[ -z "$AGER_CERTS_CONFIG" ]] || [[ -z "$AGER_INFRA_CONFIG" ]] || [[ -z "${AGER_ORG_PASS_RAW:-}" ]]; then
  usage
fi


###############################################################
# Config
###############################################################
CERTS_CONFIGFILE="${SCRIPTDIR}/../config/$AGER_CERTS_CONFIG"
INFRA_CONFIGFILE="${SCRIPTDIR}/../config/$AGER_INFRA_CONFIG"

DOCKER_NETWORK=$(yq eval '.Docker.Network' "${INFRA_CONFIGFILE}")
DOCKER_SUBNET=$(yq eval '.Docker.Subnet' "${INFRA_CONFIGFILE}")

ORBIS_NAME=$(yq eval '.Orbis.Name' "${INFRA_CONFIGFILE}")
ORBIS_ENV=$(yq eval '.Orbis.Env' "${INFRA_CONFIGFILE}")
ORBIS_TLD=$(yq eval '.Orbis.Tld' "${INFRA_CONFIGFILE}")

REGNUM_NAME=$(yq eval '.Regnum.Name' "${INFRA_CONFIGFILE}")
REGNUM_TLS_NAME=$(yq eval '.Regnum.tls.Name' "${INFRA_CONFIGFILE}")
REGNUM_TLS_NAME=$REGNUM_TLS_NAME.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD
REGNUM_TLS_PORT=$(yq eval '.Regnum.tls.Port' "${INFRA_CONFIGFILE}")
REGNUM_MSP_NAME=$(yq eval '.Regnum.msp.Name' "${INFRA_CONFIGFILE}")
REGNUM_MSP_NAME=$REGNUM_MSP_NAME.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD
REGNUM_MSP_PORT=$(yq eval '.Regnum.msp.Port' "${INFRA_CONFIGFILE}")

AGER_NAME=$(yq eval '.Ager.Name' "${CERTS_CONFIGFILE}")
AGER_ADMIN_NAME=Admin.$AGER_NAME.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD
AGER_ADMIN_CSR="C=XX,ST=$ORBIS_ENV,L=$REGNUM_NAME,O=$AGER_NAME"

LOCAL_CAROOTS_DIR="${SCRIPTDIR}/../../infrastructure/tls-ca-roots"
HOST_CAROOTS_DIR="/etc/hyperledger/tls-ca-roots"

LOCAL_CLIENT_DIR="${SCRIPTDIR}/../../infrastructure/clients/${AGER_ADMIN_NAME}"
HOST_CLIENT_DIR="/etc/hyperledger/fabric-ca-client"


###############################################################
# Debug Logging
###############################################################
log_debug "Docker Network:" "${DOCKER_NETWORK} (${DOCKER_SUBNET})"
log_debug "Orbis Info:" "$ORBIS_NAME - $ORBIS_ENV - $ORBIS_TLD"
log_debug "Regnum TLS Info:" "$REGNUM_TLS_NAME:$REGNUM_TLS_PORT"
log_debug "Regnum MSP Info:" "$REGNUM_MSP_NAME:$REGNUM_MSP_PORT"
log_debug "ORG MSP Info:" "$AGER_ADMIN_NAME / $AGER_ADMIN_CSR"
log_debug "CA-Roots Dir:" "$LOCAL_CAROOTS_DIR"
log_debug "Client Dir:" "$LOCAL_CLIENT_DIR"


###############################################################
# RUN
###############################################################
$SCRIPTDIR/prereq.sh

log_info "$AGER_ADMIN_NAME enrolling..."

# Enroll TLS-CA
docker run --rm \
  --network "${DOCKER_NETWORK}" \
  -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
  -v "${LOCAL_CLIENT_DIR}:${HOST_CLIENT_DIR}" \
  -e FABRIC_MSP_CLIENT_HOME="${HOST_CLIENT_DIR}" \
  -e FABRIC_CA_CLIENT_LOGLEVEL=${FABRIC_CA_CLIENT_LOGLEVEL} \
  hyperledger/fabric-ca:latest \
  fabric-ca-client enroll \
      -u https://${AGER_ADMIN_NAME}:${AGER_ORG_PASS_RAW}@$REGNUM_TLS_NAME:$REGNUM_TLS_PORT \
      --tls.certfiles ${HOST_CAROOTS_DIR}/${REGNUM_TLS_NAME}.pem \
      --mspdir ${HOST_CLIENT_DIR}/tls \
      --csr.hosts ${AGER_ADMIN_NAME} \
      --csr.cn $AGER_ADMIN_NAME --csr.names "$AGER_ADMIN_CSR"
log_debug "Admin-TLS enrolled"

# Enroll MSP-CA
docker run --rm \
  --network "${DOCKER_NETWORK}" \
  -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
  -v "${LOCAL_CLIENT_DIR}:${HOST_CLIENT_DIR}" \
  -e FABRIC_MSP_CLIENT_HOME="${HOST_CLIENT_DIR}" \
  -e FABRIC_CA_CLIENT_LOGLEVEL=${FABRIC_CA_CLIENT_LOGLEVEL} \
  hyperledger/fabric-ca:latest \
  fabric-ca-client enroll \
      -u https://${AGER_ADMIN_NAME}:${AGER_ORG_PASS_RAW}@$REGNUM_MSP_NAME:$REGNUM_MSP_PORT \
      --tls.certfiles ${HOST_CAROOTS_DIR}/${REGNUM_TLS_NAME}.pem \
      --mspdir ${HOST_CLIENT_DIR}/msp \
      --csr.hosts ${AGER_ADMIN_NAME} \
      --csr.cn $AGER_ADMIN_NAME --csr.names "$AGER_ADMIN_CSR"
log_debug "Admin-MSP enrolled"
        
# NodeOUs config
CA_CERT_FILE=$(ls $LOCAL_CLIENT_DIR/msp/intermediatecerts/*.pem)
cat <<EOF > $LOCAL_CLIENT_DIR/msp/config.yaml
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: intermediatecerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: intermediatecerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: intermediatecerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: intermediatecerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: orderer
EOF
log_debug "config.yaml written"

chmod -R 750 $SCRIPTDIR/../../infrastructure

log_ok "Org-MSP $AGER_ADMIN_NAME enrolled."

# chmod -R 777 /mnt/user/appdata/jedo/demo/infrastructure
