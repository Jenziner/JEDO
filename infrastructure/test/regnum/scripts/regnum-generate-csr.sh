###############################################################
#!/bin/bash
#
# This script generates new regnum .csr-FIle, ready to send to
# Orbis for signing.
#
###############################################################
set -euo pipefail

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTDIR/utils.sh"

log_section "JEDO-Ecosystem - new Regnum - CSR generating..."


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
MODE_RAW=""

usage() {
  log_error "Usage: $0 <tls|msp> <new|renew> [--debug]" >&2
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
      elif [[ -z "$MODE_RAW" ]]; then
        MODE_RAW="$1"
      else
        log_error "To many arguments: '$1'" >&2
        usage
      fi
      shift
      ;;
  esac
done

if [[ -z "${CA_TYPE_RAW:-}" || -z "${MODE_RAW:-}" ]]; then
  usage
fi

CA_TYPE="${CA_TYPE_RAW,,}"   # to lowercase
MODE="${MODE_RAW,,}"         # to lowercase

if [[ "$CA_TYPE" != "tls" && "$CA_TYPE" != "msp" ]]; then
  log_error "Wrong CA type: '$CA_TYPE'" >&2
  usage
fi

if [[ "$MODE" != "new" && "$MODE" != "renew" ]]; then
  log_error "Wrong mode: '$MODE'" >&2
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
REGNUM_SUBJECT="/C=XX/ST=$ORBIS_ENV/O=$REGNUM_NAME/CN=$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD"

OUTDIR="${SCRIPTDIR}/../ca/$CA_TYPE"
FILENAME="$CA_TYPE.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD"

KEYFILE="${OUTDIR}/${FILENAME}.key"
CSRFILE="${OUTDIR}/${FILENAME}.csr"

PACKAGE_DIR="${SCRIPTDIR}/../package"
TARFILE="${PACKAGE_DIR}/${FILENAME}-csr.tar.gz"
ENCFILE="${TARFILE}.enc"
CONFIGFILE_LOCAL="${SCRIPTDIR}/../config/regnum.yaml"


###############################################################
# Debug Logging
###############################################################
log_debug "Mode:" "${MODE}"
log_debug "Orbis Info:" "$ORBIS_NAME - $ORBIS_ENV - $ORBIS_TLD"
log_debug "Regnum Info:" "$REGNUM_NAME"
log_debug "Subject:" "$REGNUM_SUBJECT"
log_debug "Output Dir:" "$OUTDIR"
log_debug "Filename:" "$FILENAME"
log_debug "Encrypted .tar-file:" "$ENCFILE"

###############################################################
# RUN
###############################################################
$SCRIPTDIR/prereq.sh

mkdir -p "${OUTDIR}"

log_info "Creating crypto material for Regnum-CA: ${REGNUM_NAME} with subject: ${REGNUM_SUBJECT}"

# 1) Privat Key new or renew
if [[ "${MODE}" == "new" ]]; then
  log_info "Mode 'new': generating NEW private key and CSR..."
  # 1) New private key
  openssl ecparam -name prime256v1 -genkey -noout -out "${KEYFILE}"
  log_debug "new key generated"
elif [[ "${MODE}" == "renew" ]]; then
  log_info "Mode 'renew': reusing EXISTING private key to generate new CSR..."
  if [[ ! -f "${KEYFILE}" ]]; then
    log_error "Key file not found for renew mode: ${KEYFILE}" >&2
    exit 2
  fi
  log_debug "no key generated, use existing"
fi


# 2) CSR
openssl req -new -key "${KEYFILE}" \
  -subj "${REGNUM_SUBJECT}" \
  -out "${CSRFILE}"
log_debug "${CSRFILE} generated"


###############################################################
# Encrypted TAR for Orbis
###############################################################
mkdir -p "${PACKAGE_DIR}"

log_info "Creating encrypted tar-file with .csr-file and regnum.yaml"

if [[ -f "${CONFIGFILE_LOCAL}" ]]; then
  tar -czf "${TARFILE}" -C "${OUTDIR}" "${FILENAME}.csr" \
      -C "${SCRIPTDIR}/../config" "regnum.yaml"
else
  tar -czf "${TARFILE}" -C "${OUTDIR}" "${FILENAME}.csr"
fi
log_debug "${TARFILE} generated"

# Password (A-Z, a-z, 0-9)
PASSWORD="$(openssl rand -base64 16 | tr -dc 'A-Za-z0-9' | cut -c1-16)"
log_debug "Password:" "${PASSWORD}"

# Encrypt tar with AES-256-CBC
openssl enc -aes-256-cbc -salt -pbkdf2 \
  -in "${TARFILE}" \
  -out "${ENCFILE}" \
  -pass pass:"${PASSWORD}"
rm -f "${TARFILE}"
log_debug "${ENCFILE} generated"

log_warn "Send:"
log_warn "1. via e-mail: ${ENCFILE}"
log_warn "2. password via sms: ${PASSWORD}"
log_warn "to the orbis contact."



