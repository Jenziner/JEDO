###############################################################
#!/bin/bash
#
# This script joins peer nodes to a channel.
#
###############################################################
set -euo pipefail

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTDIR/utils.sh"

log_section "JEDO-Ecosystem - Peer joining a channel..."


###############################################################
# Usage / Argument-Handling
###############################################################
export LOGLEVEL="INFO"
export DEBUG=false
export FABRIC_CA_SERVER_LOGLEVEL="info"       # critical, fatal, warning, info, debug
export FABRIC_CA_CLIENT_LOGLEVEL="info"       # critical, fatal, warning, info, debug
export FABRIC_LOGGING_SPEC="INFO"             # FATAL, PANIC, ERROR, WARNING, INFO, DEBUG
export CORE_CHAINCODE_LOGGING_LEVEL="INFO"    # CRITICAL, ERROR, WARNING, NOTICE, INFO, DEBUG

export CONFIG_BLOCK="genesisblock"

export INFO=false
export LIST=false

AGER_INFRA_CONFIG=""
ORDERER_NAME=""                               # According ager-infra-yaml name, not CN!
PEER_NAME=""                                  # According ager-infra-yaml name, not CN!

usage() {
  log_error "Usage: $0 <config-infra-filename> <orderer-name> <peer-name> [--info | --list] [--debug]" >&2
  exit 1
}

channel_info() {
  local channel_name="$1"
  # Channel info of a peer
  log_info "Channel $channel_name info of $CORE_PEER_ADDRESS"
  peer channel getinfo -c "$channel_name"
}

channel_list() {
    # List all channels of a peer
    log_info "All Channels of $CORE_PEER_ADDRESS"
    peer channel list
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
    --info)
      INFO=true
      shift
      ;;
    --list)
      LIST=true
      shift
      ;;
    -*)
      log_error "Unkown Option: $1" >&2
      usage
      ;;
    *)
      # first non-Option-Argument = TLS_PASS
      if [[ -z "$AGER_INFRA_CONFIG" ]]; then
        AGER_INFRA_CONFIG="$1"
      elif [[ -z "$ORDERER_NAME" ]]; then
        ORDERER_NAME="$1"
      elif [[ -z "$PEER_NAME" ]]; then
        PEER_NAME="$1"
      else
        log_error "To many arguments: '$1'" >&2
        usage
      fi
      shift
      ;;
  esac
done

if [[ -z "$AGER_INFRA_CONFIG" ]] || [[ -z "${ORDERER_NAME:-}" ]] || [[ -z "${PEER_NAME:-}" ]]; then
  usage
fi


###############################################################
# Config
###############################################################
INFRA_CONFIGFILE="${SCRIPTDIR}/../config/$AGER_INFRA_CONFIG"

DOCKER_NETWORK=$(yq eval '.Docker.Network' "${INFRA_CONFIGFILE}")
DOCKER_SUBNET=$(yq eval '.Docker.Subnet' "${INFRA_CONFIGFILE}")

ORBIS_NAME=$(yq eval '.Orbis.Name' "${INFRA_CONFIGFILE}")
ORBIS_ENV=$(yq eval '.Orbis.Env' "${INFRA_CONFIGFILE}")
ORBIS_TLD=$(yq eval '.Orbis.Tld' "${INFRA_CONFIGFILE}")

REGNUM_NAME=$(yq eval '.Regnum.Name' "${INFRA_CONFIGFILE}")
REGNUM_TLS_NAME=tls.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD

AGER_NAME=$(yq eval '.Ager.Name' "${INFRA_CONFIGFILE}")

ADMIN_CN_NAME=Admin.${AGER_NAME}.${REGNUM_NAME}.${ORBIS_NAME}.${ORBIS_TLD}

ORDERER_CN_NAME=${ORDERER_NAME}.${AGER_NAME}.${REGNUM_NAME}.${ORBIS_NAME}.${ORBIS_TLD}
ORDERER_IP=$(yq eval ".Ager.Orderers[] | select(.Name == \"$ORDERER_NAME\") | .IP" $INFRA_CONFIGFILE)
ORDERER_PORT=$(yq eval ".Ager.Orderers[] | select(.Name == \"$ORDERER_NAME\") | .Port" $INFRA_CONFIGFILE)

if [[ $PEER_NAME != "" ]]; then
    PEER_CN_NAME=${PEER_NAME}.${AGER_NAME}.${REGNUM_NAME}.${ORBIS_NAME}.${ORBIS_TLD}
    PEER_IP=$(yq eval ".Ager.Peers[] | select(.Name == \"$PEER_NAME\") | .IP" $INFRA_CONFIGFILE)
    PEER_PORT=$(yq eval ".Ager.Peers[] | select(.Name == \"$PEER_NAME\") | .Port1" $INFRA_CONFIGFILE)
fi

export PATH="/mnt/user/appdata/fabric/bin:$PATH"

LOCAL_CONFIG_DIR="${SCRIPTDIR}/../../configuration"

LOCAL_CAROOTS_DIR="${SCRIPTDIR}/../../infrastructure/tls-ca-roots"
TLS_CA_ROOT_CERT=${LOCAL_CAROOTS_DIR}/${REGNUM_TLS_NAME}.pem

LOCAL_PEER_TLS_DIR="${SCRIPTDIR}/../../infrastructure/servers/${PEER_CN_NAME}"
PEER_TLS_SIGNCERT="${LOCAL_PEER_TLS_DIR}/tls/signcerts/cert.pem"
PEER_TLS_PRIVATEKEY_FILE=$(basename $(ls $LOCAL_PEER_TLS_DIR/tls/keystore/*_sk))
PEER_TLS_PRIVATEKEY="${LOCAL_PEER_TLS_DIR}/tls/keystore/$PEER_TLS_PRIVATEKEY_FILE"

CONFIG_BLOCK="configblock"

export FABRIC_CFG_PATH="${SCRIPTDIR}/../../infrastructure/servers/$PEER_CN_NAME"

export CORE_PEER_LOCALMSPID=$AGER_NAME
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_TLS_ROOTCERT_FILE=$TLS_CA_ROOT_CERT
export CORE_PEER_TLS_CLIENTCERT_FILE="$PEER_TLS_SIGNCERT"
export CORE_PEER_TLS_CLIENTKEY_FILE="$PEER_TLS_PRIVATEKEY"
export CORE_PEER_MSPCONFIGPATH="${SCRIPTDIR}/../../infrastructure/clients/${ADMIN_CN_NAME}/msp"
export CORE_PEER_ADDRESS=$PEER_IP:$PEER_PORT


###############################################################
# Debug Logging
###############################################################
log_debug "Docker Network:" "${DOCKER_NETWORK} (${DOCKER_SUBNET})"
log_debug "Orbis Info:" "$ORBIS_NAME - $ORBIS_ENV - $ORBIS_TLD"
log_debug "Regnum Info:" "$REGNUM_NAME"
log_debug "Ager Info:" "$AGER_NAME"
log_debug "Admin Info:" "$ADMIN_CN_NAME"
log_debug "Orderer Info:" "$ORDERER_CN_NAME@$ORDERER_IP:$ORDERER_PORT"
log_debug "Configuration Path:" "$LOCAL_CONFIG_DIR"
log_debug "CA Root Cert:" "$TLS_CA_ROOT_CERT"


###############################################################
# RUN
###############################################################
if [[ "$INFO" == true ]]; then
  channel_info "$REGNUM_NAME"
  exit 0
fi

if [[ "$LIST" == true ]]; then
  channel_list
  exit 0
fi

$SCRIPTDIR/prereq.sh

log_info "$PEER_CN_NAME joins $REGNUM_NAME..."

# Fetch current Config Block
log_debug "Fetch config block"
log_debug "Peer Address:" "$CORE_PEER_ADDRESS"
log_debug "Peer MSP Config Path:" "$CORE_PEER_MSPCONFIGPATH"
log_debug "Peer Cert:" "$PEER_TLS_SIGNCERT"
peer channel fetch config "$LOCAL_CONFIG_DIR/$CONFIG_BLOCK" \
    --orderer "$ORDERER_IP:$ORDERER_PORT" \
    --ordererTLSHostnameOverride "$ORDERER_CN_NAME" \
    --channelID "$REGNUM_NAME" \
    --tls \
    --cafile "$TLS_CA_ROOT_CERT"

# Channel join with config-block
log_debug "Join channel"
peer channel join -b "$LOCAL_CONFIG_DIR/$CONFIG_BLOCK"

log_ok "$PEER_CN_NAME joined $REGNUM_NAME."
