#!/bin/bash

###############################################################
#
# JEDO-Ecosystem - MSP-CA Registration
#
############################################################### 
set -euo pipefail

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Load .env
set -a
source "${SCRIPTDIR}/../.env"
set +a

###############################################################
# Parameter
###############################################################


##############################################################
# Run
###############################################################
log_section  "JEDO-Ecosystem - MSP-CA Registration"


# =============================================================
# 1. Register MSP identity
# =============================================================
docker run --rm \
    --network ${DOCKER_NETWORK} \
    -v "${LOCAL_MSP_SRV_DIR}:${HOST_SRV_DIR}" \
    -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
    -v "${LOCAL_TLS_CLIENT_DIR}:${HOST_CLIENT_DIR}" \
    -e FABRIC_CA_CLIENT_HOME="${HOST_CLIENT_DIR}" \
    -e FABRIC_CA_CLIENT_LOGLEVEL=${FABRIC_CA_CLIENT_LOGLEVEL} \
    ${FABRIC_CA_IMAGE} \
    fabric-ca-client register \
        -u https://${TLS_CA_NAME}:${TLS_CA_PORT} \
        --tls.certfiles ${HOST_CAROOTS_DIR}/${TLS_CA_NAME}.pem \
        --mspdir ${HOST_CLIENT_DIR} \
        --id.name ${MSP_CA_NAME} \
        --id.secret ${MSP_CA_BOOTSTRAP_PASS} \
        --id.type client \
        --id.affiliation jedo.${REGNUM_NAME}

log_debug "MSP-CA identity registered successfully."


# =============================================================
# 1. Enroll MSP identity
# =============================================================
docker run --rm \
    --network ${DOCKER_NETWORK} \
    -v "${LOCAL_MSP_SRV_DIR}:${HOST_SRV_DIR}" \
    -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
    -v "${LOCAL_TLS_CLIENT_DIR}:${HOST_CLIENT_DIR}" \
    -e FABRIC_CA_CLIENT_HOME="${HOST_CLIENT_DIR}" \
    -e FABRIC_CA_CLIENT_LOGLEVEL=${FABRIC_CA_CLIENT_LOGLEVEL} \
    ${FABRIC_CA_IMAGE} \
    fabric-ca-client enroll \
        -u https://${MSP_CA_NAME}:${MSP_CA_BOOTSTRAP_PASS}@${TLS_CA_NAME}:${TLS_CA_PORT} \
        --tls.certfiles ${HOST_CAROOTS_DIR}/${TLS_CA_NAME}.pem \
        --mspdir ${HOST_SRV_DIR}/tls \
        --enrollment.profile tls \
        --csr.hosts ${MSP_CA_NAME}

log_debug "MSP-CA identity enrolled successfully."


###############################################################
# Final tasks
###############################################################
chmod -R 750 "${LOCAL_MSP_SRV_DIR}"

log_info "MSP-CA Registration completed."