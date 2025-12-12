###############################################################
#!/bin/bash
#
# This script generates configtx.yaml, based on network-config.yaml, and creates Genesis-Block and Channel-Configuration.
#
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/params.sh"
check_script


###############################################################
# Params for regnum
###############################################################
for REGNUM in $REGNUMS; do
    echo ""
    echo_info "Channel $REGNUM configuring..."

    LOCAL_INFRA_DIR=${PWD}/infrastructure
    export FABRIC_CFG_PATH=$LOCAL_INFRA_DIR/$ORBIS/$REGNUM/configuration
    OUTPUT_CONFIGTX_FILE="$FABRIC_CFG_PATH/configtx.yaml"
    ORGANIZATIONS=$(yq eval ".Ager[] | select(.Administration.Parent == \"$REGNUM\") | .Name" $CONFIG_FILE)


    ###############################################################
    # Start of configtx.yaml
    ###############################################################
    echo_info "$OUTPUT_CONFIGTX_FILE generating..."

cat <<EOF > $OUTPUT_CONFIGTX_FILE
---
EOF


    ###############################################################
    # Section Organization
    ###############################################################
cat <<EOF >> $OUTPUT_CONFIGTX_FILE
Organizations:
EOF


    ORGANIZATIONS="Organizations:"
    CONSENTER_MAPPING="ConsenterMapping:"
    CONSENTER_ID=1
    PROFILE_ORGANIZATIONS="Organizations:"
    AGERS=$(yq eval ".Ager[] | select(.Administration.Parent == \"$REGNUM\") | .Name" $CONFIG_FILE)
    for AGER in $AGERS; do
        ORGANIZATIONS="$ORGANIZATIONS"$'\n'"    - *$AGER"
        ORDERERS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[].Name" $CONFIG_FILE)
        ORDERER_ENDPOINTS="OrdererEndpoints:"
        for ORDERER in $ORDERERS; do
            ORDERER_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Name" $CONFIG_FILE)
            ORDERER_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Port" $CONFIG_FILE)
            ORDERER_ENDPOINTS="$ORDERER_ENDPOINTS"$'\n'"      - \"$ORDERER_NAME:$ORDERER_PORT\""
            CONSENTER_MAPPING="$CONSENTER_MAPPING"$'\n'"    - ID: $CONSENTER_ID"
            CONSENTER_MAPPING="$CONSENTER_MAPPING"$'\n'"      Host: $ORDERER_NAME"
            CONSENTER_MAPPING="$CONSENTER_MAPPING"$'\n'"      Port: $ORDERER_PORT"
            CONSENTER_MAPPING="$CONSENTER_MAPPING"$'\n'"      MSPID: $AGER"
            CONSENTER_MAPPING="$CONSENTER_MAPPING"$'\n'"      Identity: $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$ORDERER_NAME/msp/signcerts/cert.pem"
            CONSENTER_MAPPING="$CONSENTER_MAPPING"$'\n'"      ClientTLSCert: $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$ORDERER_NAME/tls/signcerts/cert.pem"
            CONSENTER_MAPPING="$CONSENTER_MAPPING"$'\n'"      ServerTLSCert: $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$ORDERER_NAME/tls/signcerts/cert.pem"
            ((CONSENTER_ID++))
        done
        PEERS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[].Name" $CONFIG_FILE)
        ANCHOR_PEERS="AnchorPeers:"
        for PEER in $PEERS; do
            PEER_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .Name" $CONFIG_FILE)
            PEER_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .Port1" $CONFIG_FILE)
            ANCHOR_PEERS="$ANCHOR_PEERS"$'\n'"      - Host: $PEER_NAME"
            ANCHOR_PEERS="$ANCHOR_PEERS"$'\n'"        Port: $PEER_PORT"
        done
        PROFILE_ORGANIZATIONS="$PROFILE_ORGANIZATIONS"$'\n'"        - <<: *$AGER"
        PROFILE_ORGANIZATIONS="$PROFILE_ORGANIZATIONS"$'\n'"          Policies:"
        PROFILE_ORGANIZATIONS="$PROFILE_ORGANIZATIONS"$'\n'"            <<: *${AGER}Policies"
        PROFILE_ORGANIZATIONS="$PROFILE_ORGANIZATIONS"$'\n'"            Admins:"
        PROFILE_ORGANIZATIONS="$PROFILE_ORGANIZATIONS"$'\n'"              Type: Signature"
        PROFILE_ORGANIZATIONS="$PROFILE_ORGANIZATIONS"$'\n'"              Rule: \"OR('$AGER.member')\""


cat <<EOF >> $OUTPUT_CONFIGTX_FILE
  - &${AGER}
    Name: $AGER
    ID: ${AGER}
    MSPDir: $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/msp
    Policies: &${AGER}Policies
      Readers:
        Type: Signature
        Rule: "OR('${AGER}.member')"
      Writers:
        Type: Signature
        Rule: "OR('${AGER}.member')"
      Admins:
        Type: Signature
        Rule: "OR('${AGER}.admin')"
      BlockValidation:
        Type: ImplicitMeta
        Rule: "ANY Writers"
      Endorsement:
        Type: Signature
        Rule: "OR('${AGER}.member')"
    $ORDERER_ENDPOINTS
EOF
    done
# TODO: Remove code
#    $ANCHOR_PEERS


    ###############################################################
    # Section Capabilities
    ###############################################################
cat <<EOF >> $OUTPUT_CONFIGTX_FILE
Capabilities:
  Channel: &ChannelCapabilities
    V3_0: true
  Orderer: &OrdererCapabilities
    V2_0: true
  Application: &ApplicationCapabilities
    V2_5: true
EOF


    ###############################################################
    # Section Application
    ###############################################################
cat <<EOF >> $OUTPUT_CONFIGTX_FILE
Application: &ApplicationDefaults
  $ORGANIZATIONS
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
EOF


    ###############################################################
    # Section Orderer
    ###############################################################
cat <<EOF >> $OUTPUT_CONFIGTX_FILE
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
  $CONSENTER_MAPPING
  $ORGANIZATIONS
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
EOF


    ###############################################################
    # Section Channel
    ###############################################################
cat <<EOF >> $OUTPUT_CONFIGTX_FILE
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
EOF


    ###############################################################
    # Profile
    ###############################################################
cat <<EOF >> $OUTPUT_CONFIGTX_FILE
Profiles:
  JedoChannel:
    <<: *ChannelDefaults
    Orderer:
      <<: *OrdererDefaults
      $PROFILE_ORGANIZATIONS
    Application:
      <<: *ApplicationDefaults
      $PROFILE_ORGANIZATIONS
EOF

    echo_info "Genesis block for $REGNUM generating..."
    FABRIC_LOGGING_SPEC=$FABRIC_LOGGING_SPEC
    configtxgen -configPath $FABRIC_CFG_PATH -profile JedoChannel -channelID $REGNUM -outputBlock $FABRIC_CFG_PATH/genesisblock

    echo_info "Channel $REGNUM configured..."
done

