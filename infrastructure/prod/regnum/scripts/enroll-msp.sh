#!/bin/bash

###############################################################
#
# JEDO-Ecosystem - MSP-CA Bootstrap Enrollment
#
############################################################### 
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Load .env
set -a
source "${SCRIPT_DIR}/../.env"
set +a


###############################################################
# Parameter
###############################################################


##############################################################
# Run
###############################################################
log_section  "JEDO-Ecosystem - MSP-CA Bootstrap Identity Enrollment"


# =============================================================
# 1. Enroll bootstrap identity
# =============================================================
docker run --rm \
    --network ${DOCKER_NETWORK} \
    -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
    -v "${LOCAL_MSP_CLIENT_DIR}:${HOST_CLIENT_DIR}" \
    -e FABRIC_CA_CLIENT_HOME="${HOST_CLIENT_DIR}" \
    -e FABRIC_CA_CLIENT_LOGLEVEL=${FABRIC_CA_CLIENT_LOGLEVEL} \
    ${FABRIC_CA_IMAGE} \
    fabric-ca-client enroll \
        -u https://bootstrap.${MSP_CA_NAME}:${MSP_CA_BOOTSTRAP_PASS}@${MSP_CA_NAME}:${MSP_CA_PORT} \
        --tls.certfiles ${HOST_CAROOTS_DIR}/${TLS_CA_NAME}.pem \
        --enrollment.profile ca \
        --mspdir ${HOST_CLIENT_DIR}

log_debug "Bootstrap identity enrolled successfully."


# =============================================================
# 2. Get CA info and generate MSP
# =============================================================
docker run --rm \
    --network ${DOCKER_NETWORK} \
    -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
    -v "${LOCAL_MSP_SRV_DIR}:${HOST_SRV_DIR}" \
    -v "${LOCAL_MSP_CLIENT_DIR}:${HOST_CLIENT_DIR}" \
    -e FABRIC_CA_CLIENT_HOME="${HOST_CLIENT_DIR}" \
    -e FABRIC_CA_CLIENT_LOGLEVEL=${FABRIC_CA_CLIENT_LOGLEVEL} \
    ${FABRIC_CA_IMAGE} \
    fabric-ca-client getcainfo \
        -u https://${MSP_CA_NAME}:${MSP_CA_PORT} \
        --tls.certfiles ${HOST_CAROOTS_DIR}/${TLS_CA_NAME}.pem \
        -M ${HOST_SRV_DIR}/msp

log_debug "CA certificates fetched successfully."


# =============================================================
# 3. Generate NodeOUs config
# =============================================================
CA_CERT_FILE=$(ls ${LOCAL_MSP_SRV_DIR}/msp/cacerts/*.pem | head -n 1)
CA_CERT_BASENAME=$(basename "$CA_CERT_FILE")

cat > "${LOCAL_MSP_SRV_DIR}/msp/config.yaml" <<EOF
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/${CA_CERT_BASENAME}
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/${CA_CERT_BASENAME}
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/${CA_CERT_BASENAME}
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/${CA_CERT_BASENAME}
    OrganizationalUnitIdentifier: orderer
EOF

log_debug "config.yaml generated successfully."


###############################################################
# Final tasks
###############################################################
chmod -R 750 "${LOCAL_MSP_SRV_DIR}"

log_info "MSP-CA Bootstrap Identity Enrollment completed."
