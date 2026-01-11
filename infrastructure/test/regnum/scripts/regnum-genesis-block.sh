###############################################################
#!/bin/bash
#
# This script generates configtx.yaml, based on regnum.yaml, and creates Genesis-Block and Channel-Configuration.
#
#
###############################################################
set -euo pipefail

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTDIR/utils.sh"

log_section "JEDO-Ecosystem - new Regnum - Genesisblock CA configuring..."


###############################################################
# Usage / Argument-Handling
###############################################################
export LOGLEVEL="INFO"
export DEBUG=false
export FABRIC_CA_SERVER_LOGLEVEL="info"       # critical, fatal, warning, info, debug
export FABRIC_CA_CLIENT_LOGLEVEL="info"       # critical, fatal, warning, info, debug
export FABRIC_LOGGING_SPEC="INFO"             # FATAL, PANIC, ERROR, WARNING, INFO, DEBUG
export CORE_CHAINCODE_LOGGING_LEVEL="INFO"    # CRITICAL, ERROR, WARNING, NOTICE, INFO, DEBUG

usage() {
  log_error "Usage: $0 [--debug]" >&2
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
      shift
      ;;
  esac
done


###############################################################
# Config
###############################################################
CONFIGFILE="${SCRIPTDIR}/../config/regnum.yaml"

ORBIS_NAME=$(yq eval '.Orbis.Name' "${CONFIGFILE}")
ORBIS_ENV=$(yq eval '.Orbis.Env' "${CONFIGFILE}")
ORBIS_TLD=$(yq eval '.Orbis.Tld' "${CONFIGFILE}")

REGNUM_NAME=$(yq eval '.Regnum.Name' "${CONFIGFILE}")

LOCAL_FABRIC_DIR="/mnt/user/appdata/fabric/bin"
LOCAL_CONFIG_DIR="${SCRIPTDIR}/../../configuration"

export FABRIC_CFG_PATH=$LOCAL_CONFIG_DIR
OUTPUT_CONFIGTX_FILE="$FABRIC_CFG_PATH/configtx.yaml"


###############################################################
# Debug Logging
###############################################################
log_debug "Orbis Info:" "$ORBIS_NAME - $ORBIS_ENV - $ORBIS_TLD"
log_debug "Regnum Info:" "$REGNUM_NAME"
log_debug "Config File:" "$OUTPUT_CONFIGTX_FILE"
log_debug "Fabric Bin:" "$LOCAL_FABRIC_DIR"


###############################################################
# RUN
###############################################################
$SCRIPTDIR/prereq.sh

# Write configtx.yaml
log_info "$OUTPUT_CONFIGTX_FILE writing..."
cat <<EOF >> $OUTPUT_CONFIGTX_FILE
---
Organizations:
  - &alps
    Name: alps
    ID: alps
    MSPDir: /mnt/user/appdata/jedo/demo/infrastructure/clients/msp.alps.ea.jedo.cc/msp
    Policies: &alpsPolicies
      Readers:
        Type: Signature
        Rule: "OR('alps.member')"
      Writers:
        Type: Signature
        Rule: "OR('alps.member')"
      Admins:
        Type: Signature
        Rule: "OR('alps.admin')"
      Endorsement:
        Type: Signature
        Rule: "OR('alps.member')"
    OrdererEndpoints:
      - "orderer.alps.ea.jedo.dev:53111"

Capabilities:
  Channel: &ChannelCapabilities
    V3_0: true
  Orderer: &OrdererCapabilities
    V2_0: true
  Application: &ApplicationCapabilities
    V2_5: true

Application: &ApplicationDefaults
  Organizations:
    - *alps
  Policies: &ApplicationDefaultPolicies
    LifecycleEndorsement:
      Type: ImplicitMeta
      Rule: "MAJORITY Endorsement"
    Endorsement:
      Type: ImplicitMeta
      Rule: "MAJORITY Endorsement"
    Readers:
      Type: ImplicitMeta
      Rule: "ANY Readers"
    Writers:
      Type: ImplicitMeta
      Rule: "ANY Writers"
    Admins:
      Type: ImplicitMeta
      Rule: "ANY Admins"
  Capabilities:
    <<: *ApplicationCapabilities

Orderer: &OrdererDefaults
  OrdererType: BFT
  BatchTimeout: 2s
  BatchSize:
    MaxMessageCount: 500
    AbsoluteMaxBytes: 10 MB
    PreferredMaxBytes: 2 MB
  MaxChannels: 0
  SmartBFT:
    RequestBatchMaxInterval: 200ms
    RequestForwardTimeout: 5s
    RequestComplainTimeout: 20s
    RequestAutoRemoveTimeout: 3m0s
    ViewChangeResendInterval: 5s
    ViewChangeTimeout: 20s
    LeaderHeartbeatTimeout: 1m0s
    CollectTimeout: 1s
    IncomingMessageBufferSize: 200
    RequestPoolSize: 100000
    LeaderHeartbeatCount: 10
  ConsenterMapping:
    - ID: 1
      Host: orderer.alps.ea.jedo.dev
      Port: 53111
      MSPID: alps
      Identity: /mnt/user/appdata/jedo/demo/infrastructure/servers/orderer.alps.ea.jedo.cc/msp/signcerts/cert.pem
      ClientTLSCert: /mnt/user/appdata/jedo/demo/infrastructure/servers/orderer.alps.ea.jedo.cc/tls/signcerts/cert.pem
      ServerTLSCert: /mnt/user/appdata/jedo/demo/infrastructure/servers/orderer.alps.ea.jedo.cc/tls/signcerts/cert.pem
  Organizations:
    - *alps
  Policies:
    Readers:
      Type: ImplicitMeta
      Rule: "ANY Readers"
    Writers:
      Type: ImplicitMeta
      Rule: "ANY Writers"
    Admins:
      Type: ImplicitMeta
      Rule: "ANY Admins"
    BlockValidation:
      Type: ImplicitMeta
      Rule: "ANY Writers"
  Capabilities:
    <<: *OrdererCapabilities
Channel: &ChannelDefaults
  Policies:
    Readers:
      Type: ImplicitMeta
      Rule: "ANY Readers"
    Writers:
      Type: ImplicitMeta
      Rule: "ANY Writers"
    Admins:
      Type: ImplicitMeta
      Rule: "ANY Admins"
  Capabilities:
    <<: *ChannelCapabilities
Profiles:
  JedoChannel:
    <<: *ChannelDefaults
    Orderer:
      <<: *OrdererDefaults
      Organizations:
        - <<: *alps
          Policies:
            <<: *alpsPolicies
            Admins:
              Type: Signature
              Rule: "OR('alps.admin')"
    Application:
      <<: *ApplicationDefaults
      Organizations:
        - <<: *alps
          Policies:
            <<: *alpsPolicies
            Admins:
              Type: Signature
              Rule: "OR('alps.admin')"
EOF

log_info "Genesis block for $REGNUM_NAME generating..."
FABRIC_LOGGING_SPEC=$FABRIC_LOGGING_SPEC
$LOCAL_FABRIC_DIR/configtxgen -configPath $FABRIC_CFG_PATH -profile JedoChannel -channelID $REGNUM_NAME -outputBlock $FABRIC_CFG_PATH/genesisblock

log_ok "Channel $REGNUM_NAME configured..."

# chmod -R 777 /mnt/user/appdata/jedo/demo/configuration
