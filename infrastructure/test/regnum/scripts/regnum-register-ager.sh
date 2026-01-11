###############################################################
#!/bin/bash
#
# This script register Identities for new Ager.
#
###############################################################
set -euo pipefail

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTDIR/utils.sh"

log_section "JEDO-Ecosystem - new Ager - Identities registering..."


###############################################################
# Usage / Argument-Handling
###############################################################
export LOGLEVEL="INFO"
export DEBUG=false
export FABRIC_CA_SERVER_LOGLEVEL="info"       # critical, fatal, warning, info, debug
export FABRIC_CA_CLIENT_LOGLEVEL="info"       # critical, fatal, warning, info, debug
export FABRIC_LOGGING_SPEC="INFO"             # FATAL, PANIC, ERROR, WARNING, INFO, DEBUG
export CORE_CHAINCODE_LOGGING_LEVEL="INFO"    # CRITICAL, ERROR, WARNING, NOTICE, INFO, DEBUG
export LISTONLY=false

TLS_PASS_RAW=""
MSP_PASS_RAW=""
AGER_CONFIG=""

usage() {
  log_error "Usage: $0 <tls-password> <msp-password> <config-filename> [--debug] [--listonly]" >&2
  exit 1
}

list_ca_identities(){
      # List all Identities
    log_info "List TLS Identities"
    docker run --rm \
      --network "${DOCKER_NETWORK}" \
      -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
      -v "${LOCAL_CLIENT_DIR}/bootstrap.${REGNUM_TLS_NAME}:${HOST_CLIENT_DIR}" \
      -e FABRIC_MSP_CLIENT_HOME="${HOST_CLIENT_DIR}" \
      -e FABRIC_CA_CLIENT_LOGLEVEL=${FABRIC_CA_CLIENT_LOGLEVEL} \
      hyperledger/fabric-ca:latest \
      fabric-ca-client identity list \
          -u ${TLS_CA_URL} \
          --tls.certfiles ${HOST_CAROOTS_DIR}/${REGNUM_TLS_NAME}.pem \
          --mspdir ${HOST_CLIENT_DIR}

    log_info "List MSP Identities"
    docker run --rm \
      --network "${DOCKER_NETWORK}" \
      -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
      -v "${LOCAL_CLIENT_DIR}/bootstrap.${REGNUM_MSP_NAME}:${HOST_CLIENT_DIR}" \
      -e FABRIC_MSP_CLIENT_HOME="${HOST_CLIENT_DIR}" \
      -e FABRIC_CA_CLIENT_LOGLEVEL=${FABRIC_CA_CLIENT_LOGLEVEL} \
      hyperledger/fabric-ca:latest \
      fabric-ca-client identity list \
          -u ${MSP_CA_URL} \
          --tls.certfiles ${HOST_CAROOTS_DIR}/${REGNUM_TLS_NAME}.pem \
          --mspdir ${HOST_CLIENT_DIR}
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
    --listonly)
      LISTONLY=true
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
      elif [[ -z "$AGER_CONFIG" ]]; then
        AGER_CONFIG="$1"
      else
        log_error "To many arguments: '$1'" >&2
        usage
      fi
      shift
      ;;
  esac
done

if [[ -z "$TLS_PASS_RAW" ]] || [[ -z "$MSP_PASS_RAW" ]] || [[ -z "$AGER_CONFIG" ]]; then
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

AGERCONFIGFILE="${SCRIPTDIR}/../config/${AGER_CONFIG}"

AGER_NAME=$(yq eval '.Ager.Name' "${AGERCONFIGFILE}")
AGER_MSP=$(yq eval '.Ager.msp.Name' "${AGERCONFIGFILE}")
AGER_ORDERERS=$(yq eval ".Ager.Orderers[].Name" $AGERCONFIGFILE)
AGER_PEERS=$(yq eval ".Ager.Peers[].Name" $AGERCONFIGFILE)
AGER_GATEWAY=$(yq eval ".Ager.Gateway.Name" $AGERCONFIGFILE)
AGER_SERVICES=$(yq eval ".Ager.Gateway.Services[].Name" $AGERCONFIGFILE)

AFFILIATION=$ORBIS_NAME.$REGNUM_NAME.$AGER_NAME

TLS_CA_URL=https://$REGNUM_TLS_NAME:$TLS_PASS_RAW@$REGNUM_TLS_NAME:$REGNUM_TLS_PORT
MSP_CA_URL=https://$REGNUM_MSP_NAME:$MSP_PASS_RAW@$REGNUM_MSP_NAME:$REGNUM_MSP_PORT

LOCAL_CAROOTS_DIR="${SCRIPTDIR}/../../infrastructure/tls-ca-roots"
HOST_CAROOTS_DIR="/etc/hyperledger/tls-ca-roots"

LOCAL_CLIENT_DIR="${SCRIPTDIR}/../../infrastructure/clients"
HOST_CLIENT_DIR="/etc/hyperledger/fabric-ca-client"


###############################################################
# Debug Logging
###############################################################
log_debug "Docker Network:" "${DOCKER_NETWORK} (${DOCKER_SUBNET})"
log_debug "Orbis Info:" "$ORBIS_NAME - $ORBIS_ENV - $ORBIS_TLD"
log_debug "Regnum Info:" "$REGNUM_NAME"
log_debug "- TLS:" "$TLS_CA_URL"
log_debug "- MSP:" "$MSP_CA_URL"
log_debug "Ager Info:" "$AGER_NAME"
log_debug "- MSP:" "$AGER_MSP"
log_debug "- Orderers:" "$AGER_ORDERERS"
log_debug "- Peers:" "$AGER_PEERS"
log_debug "Affiliation:" "$AFFILIATION"


###############################################################
# RUN
###############################################################
if [[ "$LISTONLY" == true ]]; then
  list_ca_identities
  exit 0
fi

$SCRIPTDIR/prereq.sh

# Add affiliation to CAs
log_info "Affiliation $AFFILIATION adding..."

docker run --rm \
    --network "${DOCKER_NETWORK}" \
    -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
    -v "${LOCAL_CLIENT_DIR}/bootstrap.${REGNUM_TLS_NAME}:${HOST_CLIENT_DIR}" \
    -e FABRIC_MSP_CLIENT_HOME="${HOST_CLIENT_DIR}" \
    -e FABRIC_CA_CLIENT_LOGLEVEL=${FABRIC_CA_CLIENT_LOGLEVEL} \
    hyperledger/fabric-ca:latest \
    fabric-ca-client affiliation add $AFFILIATION \
        -u ${TLS_CA_URL} \
        --tls.certfiles ${HOST_CAROOTS_DIR}/${REGNUM_TLS_NAME}.pem \
        --mspdir ${HOST_CLIENT_DIR}
log_debug "TLS-CA" "Affiliation $AFFILIATION added"

docker run --rm \
    --network "${DOCKER_NETWORK}" \
    -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
    -v "${LOCAL_CLIENT_DIR}/bootstrap.${REGNUM_MSP_NAME}:${HOST_CLIENT_DIR}" \
    -e FABRIC_MSP_CLIENT_HOME="${HOST_CLIENT_DIR}" \
    -e FABRIC_CA_CLIENT_LOGLEVEL=${FABRIC_CA_CLIENT_LOGLEVEL} \
    hyperledger/fabric-ca:latest \
    fabric-ca-client affiliation add $AFFILIATION \
        -u ${MSP_CA_URL} \
        --tls.certfiles ${HOST_CAROOTS_DIR}/${REGNUM_TLS_NAME}.pem \
        --mspdir ${HOST_CLIENT_DIR}
log_debug "MSP-CA" "Affiliation $AFFILIATION added"

# Register Ager-MSP identity
AGER_MSP_NAME=$AGER_MSP.$AGER_NAME.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD
AGER_MSP_SECRET=$(yq eval ".Ager.msp.Secret" "$AGERCONFIGFILE")
log_info "$AGER_MSP_NAME registering ..."

docker run --rm \
    --network "${DOCKER_NETWORK}" \
    -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
    -v "${LOCAL_CLIENT_DIR}/bootstrap.${REGNUM_TLS_NAME}:${HOST_CLIENT_DIR}" \
    -e FABRIC_MSP_CLIENT_HOME="${HOST_CLIENT_DIR}" \
    -e FABRIC_CA_CLIENT_LOGLEVEL=${FABRIC_CA_CLIENT_LOGLEVEL} \
    hyperledger/fabric-ca:latest \
    fabric-ca-client register \
        -u ${TLS_CA_URL} \
        --tls.certfiles ${HOST_CAROOTS_DIR}/${REGNUM_TLS_NAME}.pem \
        --mspdir ${HOST_CLIENT_DIR} \
        --id.name $AGER_MSP_NAME --id.secret $AGER_MSP_SECRET --id.type client --id.affiliation $AFFILIATION
log_debug "$AGER_MSP_NAME registered @ TLS-CA"

docker run --rm \
    --network "${DOCKER_NETWORK}" \
    -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
    -v "${LOCAL_CLIENT_DIR}/bootstrap.${REGNUM_MSP_NAME}:${HOST_CLIENT_DIR}" \
    -e FABRIC_CA_CLIENT_LOGLEVEL=${FABRIC_CA_CLIENT_LOGLEVEL} \
    -e FABRIC_MSP_CLIENT_HOME="${HOST_CLIENT_DIR}" \
    hyperledger/fabric-ca:latest \
    fabric-ca-client register \
        -u ${MSP_CA_URL} \
        --tls.certfiles ${HOST_CAROOTS_DIR}/${REGNUM_TLS_NAME}.pem \
        --mspdir ${HOST_CLIENT_DIR} \
        --id.name $AGER_MSP_NAME --id.secret $AGER_MSP_SECRET --id.type client --id.affiliation $AFFILIATION \
        --id.attrs '"hf.Registrar.Roles=user,client",hf.Revoker=true,hf.IntermediateCA=false'
log_debug "$AGER_MSP_NAME registered @ MSP-CA"

# Register Ager-Admin identity
AGER_ADMIN_NAME=Admin.$AGER_NAME.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD
AGER_ADMIN_SECRET=$(yq eval ".Ager.msp.Secret" "$AGERCONFIGFILE")
log_info "$AGER_ADMIN_NAME registering ..."

docker run --rm \
    --network "${DOCKER_NETWORK}" \
    -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
    -v "${LOCAL_CLIENT_DIR}/bootstrap.${REGNUM_TLS_NAME}:${HOST_CLIENT_DIR}" \
    -e FABRIC_MSP_CLIENT_HOME="${HOST_CLIENT_DIR}" \
    -e FABRIC_CA_CLIENT_LOGLEVEL=${FABRIC_CA_CLIENT_LOGLEVEL} \
    hyperledger/fabric-ca:latest \
    fabric-ca-client register \
        -u ${TLS_CA_URL} \
        --tls.certfiles ${HOST_CAROOTS_DIR}/${REGNUM_TLS_NAME}.pem \
        --mspdir ${HOST_CLIENT_DIR} \
        --id.name $AGER_ADMIN_NAME --id.secret $AGER_ADMIN_SECRET --id.type admin --id.affiliation $AFFILIATION
log_debug "$AGER_ADMIN_NAME registered @ TLS-CA"

docker run --rm \
    --network "${DOCKER_NETWORK}" \
    -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
    -v "${LOCAL_CLIENT_DIR}/bootstrap.${REGNUM_MSP_NAME}:${HOST_CLIENT_DIR}" \
    -e FABRIC_CA_CLIENT_LOGLEVEL=${FABRIC_CA_CLIENT_LOGLEVEL} \
    -e FABRIC_MSP_CLIENT_HOME="${HOST_CLIENT_DIR}" \
    hyperledger/fabric-ca:latest \
    fabric-ca-client register \
        -u ${MSP_CA_URL} \
        --tls.certfiles ${HOST_CAROOTS_DIR}/${REGNUM_TLS_NAME}.pem \
        --mspdir ${HOST_CLIENT_DIR} \
        --id.name $AGER_ADMIN_NAME --id.secret $AGER_ADMIN_SECRET --id.type admin --id.affiliation $AFFILIATION \
        --id.attrs '"hf.Registrar.Roles=user,client",hf.Revoker=true,hf.IntermediateCA=false'
log_debug "$AGER_ADMIN_NAME registered @ MSP-CA"

# Register Ager-Orderer identity
for ORDERER in $AGER_ORDERERS; do
    ORDERER_NAME=$ORDERER.$AGER_NAME.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD
    ORDERER_SECRET=$(yq eval ".Ager.Orderers[] | select(.Name == \"$ORDERER\") | .Secret" $AGERCONFIGFILE)
    log_info "$ORDERER_NAME registering ..."

    docker run --rm \
        --network "${DOCKER_NETWORK}" \
        -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
        -v "${LOCAL_CLIENT_DIR}/bootstrap.${REGNUM_TLS_NAME}:${HOST_CLIENT_DIR}" \
        -e FABRIC_MSP_CLIENT_HOME="${HOST_CLIENT_DIR}" \
        -e FABRIC_CA_CLIENT_LOGLEVEL=${FABRIC_CA_CLIENT_LOGLEVEL} \
        hyperledger/fabric-ca:latest \
        fabric-ca-client register \
            -u ${TLS_CA_URL} \
            --tls.certfiles ${HOST_CAROOTS_DIR}/${REGNUM_TLS_NAME}.pem \
            --mspdir ${HOST_CLIENT_DIR} \
            --id.name $ORDERER_NAME --id.secret $ORDERER_SECRET --id.type client --id.affiliation $AFFILIATION
    log_debug "$ORDERER_NAME registered @ TLS-CA"

    docker run --rm \
        --network "${DOCKER_NETWORK}" \
        -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
        -v "${LOCAL_CLIENT_DIR}/bootstrap.${REGNUM_MSP_NAME}:${HOST_CLIENT_DIR}" \
        -e FABRIC_MSP_CLIENT_HOME="${HOST_CLIENT_DIR}" \
        -e FABRIC_CA_CLIENT_LOGLEVEL=${FABRIC_CA_CLIENT_LOGLEVEL} \
        hyperledger/fabric-ca:latest \
        fabric-ca-client register \
            -u ${MSP_CA_URL} \
            --tls.certfiles ${HOST_CAROOTS_DIR}/${REGNUM_TLS_NAME}.pem \
            --mspdir ${HOST_CLIENT_DIR} \
            --id.name $ORDERER_NAME --id.secret $ORDERER_SECRET --id.type orderer --id.affiliation $AFFILIATION
    log_debug "$ORDERER_NAME registered @ MSP-CA"
done

# Register Ager-Peer identity
for PEER in $AGER_PEERS; do
    PEER_NAME=$PEER.$AGER_NAME.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD
    PEER_SECRET=$(yq eval ".Ager.Peers[] | select(.Name == \"$PEER\") | .Secret" $AGERCONFIGFILE)
    log_info "$PEER_NAME registering ..."

    docker run --rm \
        --network "${DOCKER_NETWORK}" \
        -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
        -v "${LOCAL_CLIENT_DIR}/bootstrap.${REGNUM_TLS_NAME}:${HOST_CLIENT_DIR}" \
        -e FABRIC_MSP_CLIENT_HOME="${HOST_CLIENT_DIR}" \
        -e FABRIC_CA_CLIENT_LOGLEVEL=${FABRIC_CA_CLIENT_LOGLEVEL} \
        hyperledger/fabric-ca:latest \
        fabric-ca-client register \
            -u ${TLS_CA_URL} \
            --tls.certfiles ${HOST_CAROOTS_DIR}/${REGNUM_TLS_NAME}.pem \
            --mspdir ${HOST_CLIENT_DIR} \
            --id.name $PEER_NAME --id.secret $PEER_SECRET --id.type client --id.affiliation $AFFILIATION
    log_debug "$PEER_NAME registered @ TLS-CA"

    docker run --rm \
        --network "${DOCKER_NETWORK}" \
        -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
        -v "${LOCAL_CLIENT_DIR}/bootstrap.${REGNUM_MSP_NAME}:${HOST_CLIENT_DIR}" \
        -e FABRIC_MSP_CLIENT_HOME="${HOST_CLIENT_DIR}" \
        -e FABRIC_CA_CLIENT_LOGLEVEL=${FABRIC_CA_CLIENT_LOGLEVEL} \
        hyperledger/fabric-ca:latest \
        fabric-ca-client register \
            -u ${MSP_CA_URL} \
            --tls.certfiles ${HOST_CAROOTS_DIR}/${REGNUM_TLS_NAME}.pem \
            --mspdir ${HOST_CLIENT_DIR} \
            --id.name $PEER_NAME --id.secret $PEER_SECRET --id.type peer --id.affiliation $AFFILIATION
    log_debug "$PEER_NAME registered @ MSP-CA"
done

# Register Ager-Gateway identity
AGER_GATEWAY_NAME=$AGER_GATEWAY.$AGER_NAME.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD
AGER_GATEWAY_SECRET=$(yq eval ".Ager.Gateway.Secret" "$AGERCONFIGFILE")
log_info "$AGER_GATEWAY_NAME registering ..."

docker run --rm \
    --network "${DOCKER_NETWORK}" \
    -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
    -v "${LOCAL_CLIENT_DIR}/bootstrap.${REGNUM_TLS_NAME}:${HOST_CLIENT_DIR}" \
    -e FABRIC_MSP_CLIENT_HOME="${HOST_CLIENT_DIR}" \
    -e FABRIC_CA_CLIENT_LOGLEVEL=${FABRIC_CA_CLIENT_LOGLEVEL} \
    hyperledger/fabric-ca:latest \
    fabric-ca-client register \
        -u ${TLS_CA_URL} \
        --tls.certfiles ${HOST_CAROOTS_DIR}/${REGNUM_TLS_NAME}.pem \
        --mspdir ${HOST_CLIENT_DIR} \
        --id.name $AGER_GATEWAY_NAME --id.secret $AGER_GATEWAY_SECRET --id.type client --id.affiliation $AFFILIATION
log_debug "$AGER_GATEWAY_NAME registered @ TLS-CA"

# Register Ager-Services identity
for SERVICE in $AGER_SERVICES; do
    SERVICE_NAME=$SERVICE.$AGER_NAME.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD
    SERVICE_SECRET=$(yq eval ".Ager.Gateway.Services[] | select(.Name == \"$SERVICE\") | .Secret" $AGERCONFIGFILE)
    log_info "$SERVICE_NAME registering ..."

    docker run --rm \
        --network "${DOCKER_NETWORK}" \
        -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
        -v "${LOCAL_CLIENT_DIR}/bootstrap.${REGNUM_TLS_NAME}:${HOST_CLIENT_DIR}" \
        -e FABRIC_MSP_CLIENT_HOME="${HOST_CLIENT_DIR}" \
        -e FABRIC_CA_CLIENT_LOGLEVEL=${FABRIC_CA_CLIENT_LOGLEVEL} \
        hyperledger/fabric-ca:latest \
        fabric-ca-client register \
            -u ${TLS_CA_URL} \
            --tls.certfiles ${HOST_CAROOTS_DIR}/${REGNUM_TLS_NAME}.pem \
            --mspdir ${HOST_CLIENT_DIR} \
            --id.name $SERVICE_NAME --id.secret $SERVICE_SECRET --id.type client --id.affiliation $AFFILIATION
    log_debug "$SERVICE_NAME registered @ TLS-CA"
done

chmod -R 750 $SCRIPTDIR/../../infrastructure

log_ok "Identities for Ager registered."

