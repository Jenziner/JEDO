#!/bin/bash

###############################################################
#
# JEDO-Ecosystem - Generate .csr-FIle
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
# Parameter
###############################################################
# Determine variables based on CA type
if [[ "$CA_TYPE" == "tls" ]]; then
    CA_IP=${TLS_CA_IP}
    CA_PORT=${TLS_CA_PORT}
    CA_OPPORT=${TLS_CA_OPPORT}
    LOCAL_SRV_DIR=${LOCAL_TLS_SRV_DIR}
else
    CA_IP=${MSP_CA_IP}
    CA_PORT=${MSP_CA_PORT}
    CA_OPPORT=${MSP_CA_OPPORT}
    LOCAL_SRV_DIR=${LOCAL_MSP_SRV_DIR}
fi

CN=$CA_TYPE.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD
SUBJECT="/C=XX/ST=$ORBIS_ENV/O=$REGNUM_NAME/CN=$CN"
SAN_DNS=("${CN}" "localhost")
SAN_IPS=("127.0.0.1")
SAN_IPS+=("${CA_IP}")

OUTPUT_DIR="${SCRIPT_DIR}/../ca/$CA_TYPE"
PACKAGE_DIR="${SCRIPT_DIR}/../package"

CNF_FILE="${OUTPUT_DIR}/${CN}.cnf"
KEY_FILE="${OUTPUT_DIR}/${CN}.key"
CSR_FILE="${OUTPUT_DIR}/${CN}.csr"
TAR_FILE="${PACKAGE_DIR}/${CN}-csr.tar.gz"
ENC_FILE="${TAR_FILE}.enc"


###############################################################
# RUN
###############################################################
log_section "JEDO-Ecosystem - new REGNUM - CSR generating..."

log_debug "Mode:" "${MODE}"
log_debug "Orbis Info:" "$ORBIS_NAME - $ORBIS_ENV - $ORBIS_TLD"
log_debug "Regnum Info:" "$REGNUM_NAME - $CA_IP"
log_debug "Subject:" "$SUBJECT"
log_debug "Output Dir:" "$OUTPUT_DIR"
log_debug "CNF-file:" "$CNF_FILE"
log_debug "CSR-file:" "$CSR_FILE"
log_debug "Encrypted .tar-file:" "$ENC_FILE"

mkdir -p "${OUTPUT_DIR}"

log_info "Creating crypto material for Regnum-CA: ${REGNUM_NAME} with subject: ${SUBJECT}"


# =============================================================
# 1. Privat Key new or renew
# =============================================================
if [[ "${MODE}" == "new" ]]; then
  log_debug "Mode 'new': generating NEW private key and CSR..."
  openssl ecparam -name prime256v1 -genkey -noout -out "${KEY_FILE}"
  log_debug "New key generated:" "${KEY_FILE}"

elif [[ "${MODE}" == "renew" ]]; then
  log_debug "Mode 'renew':" "reusing EXISTING private key to generate new CSR..."
  if [[ ! -f "${KEY_FILE}" ]]; then
    log_error "Key file not found for renew mode:" "${KEY_FILE}" >&2
    exit 2
  fi
  log_debug "Using existing key:" "${KEY_FILE}"
fi


# =============================================================
# 2. Create OpenSSL Config with SANs
# =============================================================
log_debug "Generating OpenSSL config:" "${CNF_FILE}"
cat > "${CNF_FILE}" <<EOF
[ req ]
default_bits       = 2048
default_md         = sha256
prompt             = no
encrypt_key        = no
distinguished_name = req_distinguished_name
req_extensions     = req_ext

[ req_distinguished_name ]
C = XX
ST = $ORBIS_ENV
O = $REGNUM_NAME
CN = $CN

[ req_ext ]
subjectAltName = @alt_names
basicConstraints = CA:TRUE
keyUsage = critical, keyCertSign, cRLSign, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth

[ alt_names ]
EOF

# Add DNS entries
for i in "${!SAN_DNS[@]}"; do
  echo "DNS.$((i+1)) = ${SAN_DNS[$i]}" >> "${CNF_FILE}"
done

# Add IP entries
for i in "${!SAN_IPS[@]}"; do
  echo "IP.$((i+1)) = ${SAN_IPS[$i]}" >> "${CNF_FILE}"
done

log_debug "OpenSSL config created with:" "$(( ${#SAN_DNS[@]} + ${#SAN_IPS[@]} )) SAN entries."


# =============================================================
# 3. CSR
# =============================================================
openssl req -new \
  -key "${KEY_FILE}" \
  -out "${CSR_FILE}" \
  -config "${CNF_FILE}" \
  -reqexts req_ext
log_debug "CSR generated:" "${CSR_FILE}"


# =============================================================
# 4. Encrypted TAR for Orbis
# =============================================================
mkdir -p "${PACKAGE_DIR}"

log_info "Creating encrypted tar-file with .csr-file and regnum.yaml"
tar -czf "${TAR_FILE}" -C "${OUTPUT_DIR}" "${CSR_FILE}"
log_debug "${TAR_FILE} generated"

# Password (A-Z, a-z, 0-9)
PASSWORD="$(openssl rand -base64 16 | tr -dc 'A-Za-z0-9' | cut -c1-16)"
log_debug "Password:" "${PASSWORD}"

# Encrypt tar with AES-256-CBC
openssl enc -aes-256-cbc -salt -pbkdf2 \
  -in "${TAR_FILE}" \
  -out "${ENC_FILE}" \
  -pass pass:"${PASSWORD}"
rm -f "${TAR_FILE}"
log_debug "${ENC_FILE} generated"


###############################################################
# Final tasks
###############################################################
log_warn "Send:"
log_warn "1. via e-mail: ${ENC_FILE}"
log_warn "2. password via sms: ${PASSWORD}"
log_warn "to the orbis contact."



