###############################################################
#!/bin/bash
#
# This script install crypto material for new regnum ca.
#
###############################################################
set -euo pipefail

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTDIR/utils.sh"

log_section "JEDO-Ecosystem - new Regnum - Crypto Material installing..."


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

if [[ -z "${CA_TYPE_RAW:-}" || -z "${PASS_RAW:-}" ]]; then
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

# LOCAL_CLIENT_DIR="${SCRIPTDIR}/../../infrastructure/clients"
# HOST_CLIENT_DIR="/etc/hyperledger/fabric-ca-client"

FILENAME=$REGNUM_CA_NAME
KEYFILE="${SCRIPTDIR}/../ca/$CA_TYPE/${REGNUM_CA_NAME}.key"
CERTFILE="${SCRIPTDIR}/../ca/$CA_TYPE/${REGNUM_CA_NAME}.cert.pem"
CHAINFILE="${SCRIPTDIR}/../ca/$CA_TYPE/${REGNUM_CA_NAME}.chain.pem"


###############################################################
# Debug Logging
###############################################################
log_debug "Orbis Info:" "$ORBIS_NAME - $ORBIS_ENV - $ORBIS_TLD"
log_debug "Regnum Info:" "$REGNUM_CA_NAME:$PASS_RAW@$REGNUM_CA_IP:$REGNUM_CA_PORT"
log_debug "Key File:" "$KEYFILE"
log_debug "Cert File:" "$CERTFILE"
log_debug "Chain File:" "$CHAINFILE"
log_debug "CA-Roots Dir:" "$LOCAL_CAROOTS_DIR"
log_debug "Server Dir:" "$LOCAL_SRV_DIR"


###############################################################
# RUN
###############################################################
$SCRIPTDIR/prereq.sh

log_info "Regnum certs installing ..."

# create folders needed
mkdir -p "${LOCAL_SRV_DIR}/ca"
mkdir -p "${LOCAL_CAROOTS_DIR}"

# copy ca-certs from Package to server and ca-roots
cp "${KEYFILE}" "${LOCAL_SRV_DIR}/ca/$CA_TYPE-$REGNUM_NAME-ca.key"  # from regnum-generate-csr.sh
cp "${CERTFILE}" "${LOCAL_SRV_DIR}/ca/cert.pem"                     # from Vault (signed)
cp "${CHAINFILE}" "${LOCAL_SRV_DIR}/ca/chain.cert"                  # from Vault (signed)
cp "${CERTFILE}" "${LOCAL_CAROOTS_DIR}/${REGNUM_CA_NAME}.pem"       # ca-cert to public TLS-Root-Certs for Client-Auth

# fabric-ca-server-config.yaml
log_info "Writing Config-File"

# TLS config-file
if [[ "${CA_TYPE}" == "tls" ]]; then
  log_debug "Writing TLS Config-File..."

  cat > "${LOCAL_SRV_DIR}/fabric-ca-server-config.yaml" <<EOF
---
version: 0.0.1

port: ${REGNUM_CA_PORT}

tls:
    enabled: true
    clientauth:
        type: noclientcert        # after bootsrap enroll:  RequireAndVerifyClientCert
        certfiles:
            - "${HOST_CAROOTS_DIR}/${REGNUM_CA_NAME}.pem"

ca:
    name: ${REGNUM_CA_NAME}
    keyfile: ca/${CA_TYPE}-${REGNUM_NAME}-ca.key
    certfile: ca/cert.pem
    chainfile: ca/chain.cert

crl:
    expiry: 8760h

registry:
    maxenrollments: -1
    identities:
        - name: bootstrap.${REGNUM_CA_NAME}
          pass: ${PASS_RAW}
          type: client
          affiliation: jedo.${REGNUM_NAME}
          attrs:
              hf.Registrar.Roles: "*"
              hf.Registrar.DelegateRoles: "*"
              hf.Registrar.Attributes: "*"
              hf.Revoker: true
              hf.GenCRL: true
              hf.IntermediateCA: true
              hf.AffiliationMgr: true

affiliations:
    jedo:
        - ea
        - as
        - af
        - na
        - sa

signing:
    default:
        usage:
            - digital signature
        expiry: 26280h          # 3 years
    profiles:
        tls:
            usage:
                - cert sign
                - crl sign
                - signing
                - key encipherment
                - server auth
                - client auth
                - key agreement
            expiry: 26280h      # 3 years

csr:
    cn: ${REGNUM_CA_NAME}
    keyrequest:
        algo: ecdsa
        size: 384
    names:
        - C: XX
          ST: ${ORBIS_ENV}
          L: ${REGNUM_NAME}
          O:
          OU:
    hosts:
        - ${REGNUM_CA_NAME}
        - ${REGNUM_CA_IP}
    ca:
        expiry: 43800h          # 5 years
        pathlength: 0
idemix:
    curve: gurvy.Bn254
operations:
    listenAddress: ${REGNUM_CA_IP}:${REGNUM_CA_OPPORT}
    tls:
        enabled: false
EOF

# MSP config-file
elif [[ "${CA_TYPE}" == "msp" ]]; then
  log_debug "Writing MSP Config-File..."

  KEYFILE=$(basename $(ls ${LOCAL_SRV_DIR}/tls/keystore/*_sk | head -n 1))
  CHAINFILE=$(basename $(ls ${LOCAL_SRV_DIR}/tls/tlsintermediatecerts/*.pem | head -n 1))
  log_debug "Key-File:" "$KEYFILE"
  log_debug "Chain-File:" "$CHAINFILE"

  cat > "${LOCAL_SRV_DIR}/fabric-ca-server-config.yaml" <<EOF
---
version: 0.0.1

port: ${REGNUM_CA_PORT}

tls:
    enabled: true
    clientauth:
        type: noclientcert        # after bootsrap enroll:  RequireAndVerifyClientCert
        certfiles:
            - "${HOST_CAROOTS_DIR}/${REGNUM_CA_NAME}.pem"
    keyfile: ${HOST_SRV_DIR}/tls/keystore/$KEYFILE
    certfile: ${HOST_SRV_DIR}/tls/signcerts/cert.pem
    chainfile: ${HOST_SRV_DIR}/tls/tlsintermediatecerts/$CHAINFILE


ca:
    name: ${REGNUM_CA_NAME}
    keyfile: ca/$CA_TYPE-$REGNUM_NAME-ca.key
    certfile: ca/cert.pem
    chainfile: ca/chain.cert

crl:
    expiry: 8760h

registry:
    maxenrollments: -1
    identities:
        - name: bootstrap.${REGNUM_CA_NAME}
          pass: ${PASS_RAW}
          type: client
          affiliation: jedo.${REGNUM_NAME}
          attrs:
              hf.Registrar.Roles: "client,user,admin,peer,orderer"
              hf.Registrar.DelegateRoles: "client,user,peer,orderer"
              hf.Registrar.Attributes: "*"
              hf.Revoker: true
              hf.GenCRL: true
              hf.IntermediateCA: true
              hf.AffiliationMgr: true

affiliations:
    jedo:
        - ea
        - as
        - af
        - na
        - sa

signing:
    default:
        usage:
            - digital signature
        expiry: 26280h        # 3 years
    profiles:
        ca:
            usage:
                - cert sign
                - crl sign
            expiry: 26280h      # 3 years
            caconstraint:
                isca: true
                maxpathlen: 0
                copyextensions: true

csr:
    cn: ${REGNUM_CA_NAME}
    names:
        - C: XX
          ST: ${ORBIS_ENV}
          L: ${REGNUM_NAME}
          O:
          OU:
    hosts:
        - ${REGNUM_CA_NAME}
        - ${REGNUM_CA_IP}
    ca:
        expiry: 43800h        # 5 years
        pathlength: 1

operations:
    listenAddress: ${REGNUM_CA_IP}:${REGNUM_CA_OPPORT}
    tls:
        enabled: false
EOF
fi

log_ok "Regnum certs installed."