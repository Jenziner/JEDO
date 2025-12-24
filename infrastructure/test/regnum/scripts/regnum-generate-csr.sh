###############################################################
#!/bin/bash
#
# This script generates a new jedo-network according infrastructure.yaml
# Fabric Documentation: https://hyperledger-fabric.readthedocs.io
#
###############################################################
set -euo pipefail

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTDIR/utils.sh"

log_section "JEDO-Ecosystem - CSR generating..."

###############################################################
# Check Arguments
###############################################################
export LOGLEVEL="INFO"
export DEBUG=false
export FABRIC_CA_SERVER_LOGLEVEL="info"
CA_TYPE_RAW=""

usage() {
  log_error "Usage: $0 <tls|msp> [--debug]" >&2
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
        shift
      else
        log_error "To many arguments: '$1'" >&2
        usage
      fi
      ;;
  esac
done

if [[ -z "${CA_TYPE_RAW:-}" ]]; then
  usage
fi

CA_TYPE="${CA_TYPE_RAW,,}" # to lowercase

if [[ "$CA_TYPE" != "tls" && "$CA_TYPE" != "msp" ]]; then
  log_error "Wrong CA type: '$CA_TYPE'" >&2
  usage
fi

CONFIGFILE="${SCRIPTDIR}/../config/regnum.yaml"
DOCKER_NETWORKE=$(yq eval '.Docker.Network' "${CONFIGFILE}")
DOCKER_WAIT=$(yq eval '.Docker.Wait' "${CONFIGFILE}")
ORBIS_NAME=$(yq eval '.Orbis.Name' "${CONFIGFILE}")
ORBIS_ENV=$(yq eval '.Orbis.Env' "${CONFIGFILE}")
ORBIS_TLD=$(yq eval '.Orbis.Tld' "${CONFIGFILE}")
REGNUM_NAME=$(yq eval '.Regnum.Name' "${CONFIGFILE}")
REGNUM_MSP_NAME=$CA_TYPE.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD
REGNUM_ADMIN_SUBJECT="/C=XX/ST=$ORBIS_ENV/O=$REGNUM_NAME/CN=admin.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD"

OUTDIR="${SCRIPTDIR}/../ca/$CA_TYPE"
FILENAME="$CA_TYPE.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD"


###############################################################
# Debug Logging
###############################################################
log_debug "Orbis Info:" "$ORBIS_NAME - $ORBIS_ENV - $ORBIS_TLD"
log_debug "Regnum Info:" "$REGNUM_NAME"
log_debug "CA Name:" "$REGNUM_MSP_NAME"
log_debug "Admin Subject:" "$REGNUM_ADMIN_SUBJECT"
log_debug "Output Dir:" "$OUTDIR"
log_debug "Filename:" "$FILENAME"


###############################################################
# RUN
###############################################################
$SCRIPTDIR/prereq.sh

mkdir -p "${OUTDIR}"

log_info "Generation of Key + CSR for Regnum-CA: ${REGNUM_MSP_NAME}"
log_info "Subject: ${REGNUM_ADMIN_SUBJECT}"

# 1) Privat Key
openssl ecparam -name prime256v1 -genkey -noout -out "${OUTDIR}/$FILENAME.key"

# 2) CSR
openssl req -new -key "${OUTDIR}/$FILENAME.key" \
  -subj "${REGNUM_ADMIN_SUBJECT}" \
  -out "${OUTDIR}/$FILENAME.csr"

ls -l "${OUTDIR}"

log_info "==> Fertig. Bitte folgende CSR an Orbis-Offline-CA geben:"
log_info "    ${OUTDIR}/$FILENAME.csr"
log_info "==> Erwartete Rückgabe von Orbis:"
log_info "    - signiertes Intermediate-Zertifikat  ($FILENAME.cert.pem)"
log_info "    - komplette Chain inkl. Orbis-MSP-Chain ($FILENAME-chain.pem)"
