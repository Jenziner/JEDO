#!/bin/bash

###############################################################
#
# JEDO-Ecosystem - Initialize CA Directories and Certificates
#
###############################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Load variables from .env
set -a
source "${SCRIPT_DIR}/../.env"
set +a


###############################################################
# Usage / Argument-Handling
###############################################################
CA_TYPE_RAW=""

usage() {
  log_error "Usage: $0 <tls|msp> [--debug]" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)
      LOGLEVEL="DEBUG"
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
# Parameter
###############################################################
# Determine variables based on CA type
if [[ "$CA_TYPE" == "tls" ]]; then
    CA_NAME=${TLS_CA_NAME}
    CA_IP=${TLS_CA_IP}
    CA_PORT=${TLS_CA_PORT}
    CA_OPPORT=${TLS_CA_OPPORT}
    LOCAL_SRV_DIR=${LOCAL_TLS_SRV_DIR}
else
    CA_NAME=${MSP_CA_NAME}
    CA_IP=${MSP_CA_IP}
    CA_PORT=${MSP_CA_PORT}
    CA_OPPORT=${MSP_CA_OPPORT}
    LOCAL_SRV_DIR=${LOCAL_MSP_SRV_DIR}
fi

KEY_FILE="./ca/${CA_TYPE}/${CA_NAME}.key"
CERT_FILE="./ca/${CA_TYPE}/${CA_NAME}.cert.pem"
CHAIN_FILE="./ca/${CA_TYPE}/${CA_NAME}.chain.pem"


###############################################################
# Run
###############################################################
log_section  "JEDO-Ecosystem - REGNUM CA Initialization"

log_debug "Initializing ${CA_NAME}..."
log_debug "IP:" "${CA_IP}"
log_debug "Port:" "${CA_PORT}"
log_debug "OpPort:" "${CA_OPPORT}"

mkdir -p "${LOCAL_SRV_DIR}/ca"
mkdir -p "${LOCAL_CAROOTS_DIR}"


# =============================================================
# 1. Copy certificates
# =============================================================
log_debug "Installing certificates..."
cp "${KEY_FILE}" "${LOCAL_SRV_DIR}/ca/${CA_TYPE}-${REGNUM_NAME}-ca.key"
cp "${CERT_FILE}" "${LOCAL_SRV_DIR}/ca/cert.pem"
cp "${CHAIN_FILE}" "${LOCAL_SRV_DIR}/ca/chain.cert"
cp "${CERT_FILE}" "${LOCAL_CAROOTS_DIR}/${CA_NAME}.pem"
cp "${CHAIN_FILE}" "${LOCAL_CAROOTS_DIR}/${CA_NAME}-chain.cert"

log_debug "Generating fabric-ca-server-config.yaml..."


# =============================================================
# 2. Generate fabric-ca-server-config.yaml for TLS
# =============================================================
if [[ "${CA_TYPE}" == "tls" ]]; then
cat > "${LOCAL_SRV_DIR}/fabric-ca-server-config.yaml" <<EOF
version: 1.5.7
port: ${CA_PORT}

debug: false

crlsizelimit: 512000

tls:
  enabled: true
  clientauth:
    type: noclientcert        # after bootsrap enroll:  RequireAndVerifyClientCert
    certfiles:
      - "${HOST_CAROOTS_DIR}/${TLS_CA_NAME}.pem"

ca:
  name: ${CA_NAME}
  keyfile: ca/${CA_TYPE}-${REGNUM_NAME}-ca.key
  certfile: ca/cert.pem
  chainfile: ca/chain.cert

csr:
  cn: ${CA_NAME}
  keyrequest:
    algo: ecdsa
    size: 256
  names:
    - C: CH
      ST: Bern
      L: Bern
      O: ${ORBIS_NAME}
      OU: ${REGNUM_NAME}
  hosts:
    - ${CA_NAME}
    - localhost
  ca:
    expiry: 131400h
    pathlength: 1

registry:
  maxenrollments: -1
  identities:
    - name: bootstrap.${CA_NAME}
      pass: ${TLS_CA_BOOTSTRAP_PASS}
      type: client
      affiliation: ""
      attrs:
        hf.Registrar.Roles: "*"
        hf.Registrar.DelegateRoles: "*"
        hf.Revoker: true
        hf.IntermediateCA: true
        hf.GenCRL: true
        hf.Registrar.Attributes: "*"
        hf.AffiliationMgr: true

db:
  type: sqlite3
  datasource: fabric-ca-server.db
  tls:
    enabled: false

affiliations:
  ${ORBIS_NAME}:
    - ${REGNUM_NAME}

signing:
  default:
    usage:
      - digital signature
    expiry: 8760h
  profiles:
    ca:
      usage:
        - cert sign
        - crl sign
      expiry: 43800h
      caconstraint:
        isca: true
        maxpathlen: 0
    tls:
      usage:
        - signing
        - key encipherment
        - server auth
        - client auth
        - key agreement
      expiry: 8760h

operations:
  listenAddress: ${CA_IP}:${CA_OPPORT}
  tls:
    enabled: false
EOF


# =============================================================
# 3. Generate fabric-ca-server-config.yaml for MSP
# =============================================================
else 
  KEY_FILE=$(basename $(ls ${LOCAL_SRV_DIR}/tls/keystore/*_sk | head -n 1))
  CHAIN_FILE=$(basename $(ls ${LOCAL_SRV_DIR}/tls/tlsintermediatecerts/*.pem | head -n 1))
  log_debug "Key-File:" "$KEY_FILE"
  log_debug "Chain-File:" "$CHAIN_FILE"

cat > "${LOCAL_SRV_DIR}/fabric-ca-server-config.yaml" <<EOF
version: 1.5.7
port: ${CA_PORT}

debug: false

crlsizelimit: 512000

tls:
  enabled: true
  keyfile: ${HOST_SRV_DIR}/tls/keystore/$KEY_FILE
  certfile: ${HOST_SRV_DIR}/tls/signcerts/cert.pem
  chainfile: ${HOST_SRV_DIR}/tls/tlsintermediatecerts/$CHAIN_FILE
  clientauth:
    type: noclientcert        # after bootsrap enroll:  RequireAndVerifyClientCert
    certfiles:
      - "${HOST_CAROOTS_DIR}/${TLS_CA_NAME}.pem"

ca:
  name: ${CA_NAME}
  keyfile: ca/${CA_TYPE}-${REGNUM_NAME}-ca.key
  certfile: ca/cert.pem
  chainfile: ca/chain.cert

csr:
  cn: ${CA_NAME}
  keyrequest:
    algo: ecdsa
    size: 256
  names:
    - C: CH
      ST: Bern
      L: Bern
      O: ${ORBIS_NAME}
      OU: ${REGNUM_NAME}
  hosts:
    - ${CA_NAME}
    - localhost
  ca:
    expiry: 131400h
    pathlength: 0

registry:
  maxenrollments: -1
  identities:
    - name: bootstrap.${CA_NAME}
      pass: ${MSP_CA_BOOTSTRAP_PASS}
      type: client
      affiliation: ""
      attrs:
        hf.Registrar.Roles: "*"
        hf.Registrar.DelegateRoles: "*"
        hf.Revoker: true
        hf.IntermediateCA: true
        hf.GenCRL: true
        hf.Registrar.Attributes: "*"
        hf.AffiliationMgr: true

db:
  type: sqlite3
  datasource: fabric-ca-server.db
  tls:
    enabled: false

affiliations:
  ${ORBIS_NAME}:
    - ${REGNUM_NAME}

signing:
  default:
    usage:
      - digital signature
    expiry: 8760h
  profiles:
    ca:
      usage:
        - cert sign
        - crl sign
      expiry: 43800h
      caconstraint:
        isca: true
        maxpathlen: 0
    tls:
      usage:
        - signing
        - key encipherment
        - server auth
        - client auth
        - key agreement
      expiry: 8760h

operations:
  listenAddress: ${CA_IP}:${CA_OPPORT}
  tls:
    enabled: false
EOF
fi


###############################################################
# Final tasks
###############################################################
chmod -R 750 "${SCRIPT_DIR}/../infrastructure"

log_info "REGNUM CA Initialization completed for ${CA_NAME}."
