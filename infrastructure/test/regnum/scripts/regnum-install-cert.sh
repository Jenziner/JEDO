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
REGNUM_IP=$(yq eval '.Regnum.'$CA_TYPE'.IP' "${CONFIGFILE}")
REGNUM_PORT=$(yq eval '.Regnum.'$CA_TYPE'.Port' "${CONFIGFILE}")
REGNUM_OPPORT=$(yq eval '.Regnum.'$CA_TYPE'.OpPort' "${CONFIGFILE}")

TLSDIR="${SCRIPTDIR}/../../infrastructure/tls.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD"
OUTDIR="${SCRIPTDIR}/../../infrastructure/$REGNUM_CA_NAME"
BASEDIR=${OUTDIR}/${CA_TYPE}
FILENAME=$REGNUM_CA_NAME

KEYFILE="${SCRIPTDIR}/../ca/$CA_TYPE/${FILENAME}.key"
CERTFILE="${SCRIPTDIR}/../ca/$CA_TYPE/${FILENAME}.cert.pem"
CHAINFILE="${SCRIPTDIR}/../ca/$CA_TYPE/${FILENAME}.chain.pem"


###############################################################
# Debug Logging
###############################################################
log_debug "Password:" "${PASS_RAW}"
log_debug "Orbis Info:" "$ORBIS_NAME - $ORBIS_ENV - $ORBIS_TLD"
log_debug "Regnum Info:" "$REGNUM_CA_NAME - $REGNUM_IP - $REGNUM_PORT"
log_debug "Key File:" "$KEYFILE"
log_debug "Cert File:" "$CERTFILE"
log_debug "Chain File:" "$CHAINFILE"
log_debug "Output Dir:" "$OUTDIR"
log_debug "TLS Dir:" "$TLSDIR"


###############################################################
# RUN
###############################################################
$SCRIPTDIR/prereq.sh

log_info "Regnum certs installing ..."

mkdir -p "${OUTDIR}/ca"

cp "${KEYFILE}" "${OUTDIR}/ca/regnum-$CA_TYPE-ca.key"
cp "${CERTFILE}" "${OUTDIR}/ca/cert.pem"
cp "${CHAINFILE}" "${OUTDIR}/ca/chain.cert"

HOST_CA_DIR="/etc/hyperledger/fabric-ca-server"

# fabric-ca-server-config.yaml
log_info "Writing Config-File"

# TLS config-file
if [[ "${CA_TYPE}" == "tls" ]]; then
  log_info "Writing TLS Config-File..."
  cat > "${OUTDIR}/fabric-ca-server-config.yaml" <<EOF
---
version: 0.0.1
port: $REGNUM_PORT
tls:
    enabled: true
    clientauth:
      type: noclientcert
      certfiles:
ca:
    name: $REGNUM_CA_NAME
    keyfile: ca/regnum-$CA_TYPE-ca.key
    certfile: ca/cert.pem
    chainfile: ca/chain.cert
crl:
registry:
    maxenrollments: -1
    identities:
        - name: $REGNUM_CA_NAME
          pass: $PASS_RAW
          type: client
          affiliation: jedo.${REGNUM_NAME}
          attrs:
              hf.Registrar.Roles: "*"
              hf.Registrar.DelegateRoles: "*"
              hf.Revoker: true
              hf.IntermediateCA: true
              hf.GenCRL: true
              hf.Registrar.Attributes: "*"
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
        expiry: 8760h
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
            expiry: 8760h
csr:
    cn: $REGNUM_CA_NAME
    keyrequest:
        algo: ecdsa
        size: 384
    names:
        - C: XX
          ST: cc
          L:
          O: jedo
          OU:
    hosts:
        - $REGNUM_CA_NAME
        - $REGNUM_IP
    ca:
        expiry: 131400h
        pathlength: 1
idemix:
    curve: gurvy.Bn254
operations:
    listenAddress: $REGNUM_IP:$REGNUM_OPPORT
    tls:
        enabled: false
EOF
# MSP config-file
elif [[ "${CA_TYPE}" == "msp" ]]; then
  log_info "Copy TLS-Certs for MSP-CA"

  mkdir -p "${OUTDIR}/tls"
  
  cp "${TLSDIR}/${REGNUM_CA_NAME}"/keystore/*_sk "${OUTDIR}/tls/regnum-${CA_TYPE}-ca.key"
  cp "${TLSDIR}/${REGNUM_CA_NAME}"/signcerts/cert.pem "${OUTDIR}/tls/cert.pem"
  cp "${TLSDIR}/${REGNUM_CA_NAME}"/tlsintermediatecerts/*.pem "${OUTDIR}/tls/tls-ca-cert.pem"

  log_info "Writing MSP Config-File..."
  cat > "${OUTDIR}/fabric-ca-server-config.yaml" <<EOF
---
version: 0.0.1

port: ${REGNUM_PORT}

tls:
  enabled: true
  keyfile: ${HOST_CA_DIR}/tls/regnum-${CA_TYPE}-ca.key
  certfile: ${HOST_CA_DIR}/tls/cert.pem
  chainfile: ${HOST_CA_DIR}/tls/chain.cert

ca:
  name: ${REGNUM_CA_NAME}
  keyfile: ca/regnum-${CA_TYPE}-ca.key
  certfile: ca/cert.pem
  chainfile: ca/chain.cert

crl:
  expiry: 8760h

registry:
  maxenrollments: -1
  identities:
    - name: ${REGNUM_CA_NAME}
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
    expiry: 8760h
  profiles:
    ca:
      usage:
        - cert sign
        - crl sign
      expiry: 8760h
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
      O: jedo
      OU: 
  hosts:
    - ${REGNUM_CA_NAME}
    - ${REGNUM_IP}

operations:
  listenAddress: ${REGNUM_IP}:${REGNUM_OPPORT}
  tls:
    enabled: false
EOF
fi

log_ok "Regnum certs installed."