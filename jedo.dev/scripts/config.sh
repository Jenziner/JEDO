###############################################################
#!/bin/bash
#
# This script generates configtx.yaml, based on network-config.yaml, and creates Genesis-Block and Channel-Configuration.
#
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
check_script


###############################################################
# Params - from ./config/network-config.yaml
###############################################################
CONFIG_FILE="$SCRIPT_DIR/infrastructure-dev.yaml"
FABRIC_BIN_PATH=$(yq eval '.Fabric.Path' "$CONFIG_FILE")
ORBIS_NAME=$(yq eval ".Orbis.Name" "$CONFIG_FILE")
CHANNELS=$(yq e ".Regnum[].Name" $CONFIG_FILE)

for CHANNEL in $CHANNELS; do
    echo ""
    echo_warn "Channel $CHANNEL configuring..."

    export FABRIC_CFG_PATH=${PWD}/configuration/$CHANNEL
    mkdir -p $FABRIC_CFG_PATH
    OUTPUT_CONFIGTX_FILE="$FABRIC_CFG_PATH/configtx.yaml"
    ORGCA=$(yq eval ".Regnum[] | select(.Name == \"$CHANNEL\") | .CA.Name" $CONFIG_FILE)
    ORGANIZATION=$(yq eval ".Regnum[] | select(.Name == \"$CHANNEL\") | .Organization" $CONFIG_FILE)
    ORDERERS=$(yq eval ".Regnum[] | select(.Name == \"$CHANNEL\") | .Orderers[].Name" $CONFIG_FILE)


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
cat <<EOF > $OUTPUT_CONFIGTX_FILE
Organizations:
EOF

    ORDERER_ENDPOINTS="OrdererEndpoints:"
    for ORDERER in $ORDERERS; do
        ORDERER_PORT=$(yq eval ".Regnum[] | select(.Name == \"$CHANNEL\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Port" $CONFIG_FILE)
        ORDERER_ENDPOINTS="$ORDERER_ENDPOINTS"$'\n'"      - $ORDERER:$ORDERER_PORT"
    done


cat <<EOF >> $OUTPUT_CONFIGTX_FILE
  - &${ORGANIZATION}
    Name: $ORGANIZATION
    ID: ${ORGANIZATION}
    MSPDir: $PWD/infrastructure/$ORBIS_NAME/$CHANNEL/$ORGCA/msp
    Policies: &${ORGANIZATION}Policies
      Readers:
        Type: Signature
        Rule: "OR('${ORGANIZATION}.member')"
      Writers:
        Type: Signature
        Rule: "OR('${ORGANIZATION}.member')"
      Admins:
        Type: Signature
        Rule: "OR('${ORGANIZATION}.admin')"
      BlockValidation:
        Type: ImplicitMeta
        Rule: "ANY Writers"
      Endorsement:
        Type: Signature
        Rule: "OR('${ORGANIZATION}.member')"
    $ORDERER_ENDPOINTS
EOF


    ###############################################################
    # Section Capabilities
    ###############################################################
cat <<EOF >> $OUTPUT_CONFIGTX_FILE
Capabilities:
  Channel: &ChannelCapabilities
    V2_0: true
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
  Organizations:
    - *$ORGANIZATION
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
  OrdererType: etcdraft
EOF

    ORDERER_ADDRESSES="Addresses:"
    for ORDERER in $ORDERERS; do
        ORDERER_PORT=$(yq eval ".Regnum[] | select(.Name == \"$CHANNEL\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Port" $CONFIG_FILE)
        ORDERER_ADDRESSES="$ORDERER_ADDRESSES"$'\n'"    - $ORDERER:$ORDERER_PORT"
    done
cat <<EOF >> $OUTPUT_CONFIGTX_FILE
  $ORDERER_ADDRESSES
EOF

cat <<EOF >> $OUTPUT_CONFIGTX_FILE
  BatchTimeout: 2s
  BatchSize:
    MaxMessageCount: 500
    AbsoluteMaxBytes: 10 MB
    PreferredMaxBytes: 2 MB
  MaxChannels: 0
  EtcdRaft:
    Consenters:
EOF

    for ORDERER in $ORDERERS; do
        ORDERER_PORT=$(yq eval ".Regnum[] | select(.Name == \"$CHANNEL\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Port" $CONFIG_FILE)
cat <<EOF >> $OUTPUT_CONFIGTX_FILE
      - Host: $ORDERER
        Port: $ORDERER_PORT
        ClientTLSCert: ${PWD}/infrastructure/$ORBIS_NAME/$CHANNEL/$ORDERER/tls/signcerts/cert.pem
        ServerTLSCert: ${PWD}/infrastructure/$ORBIS_NAME/$CHANNEL/$ORDERER/tls/signcerts/cert.pem
EOF
    done

cat <<EOF >> $OUTPUT_CONFIGTX_FILE
    Options:
      TickInterval: 500ms
      ElectionTick: 10
      HeartbeatTick: 1
      MaxInflightBlocks: 5
      SnapshotIntervalSize: 16 MB
  Organizations:
      - *$ORGANIZATION
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
      OrdererType: etcdraft
      Organizations:
        - <<: *$ORGANIZATION
          Policies:
            <<: *${ORGANIZATION}Policies
            Admins:
              Type: Signature
              Rule: "OR('$ORGANIZATION.member')"
    Application:
      <<: *ApplicationDefaults
      Organizations:
        - <<: *$ORGANIZATION
          Policies:
            <<: *${ORGANIZATION}Policies
            Admins:
              Type: Signature
              Rule: "OR('$ORGANIZATION.member')"
EOF

    echo_info "Genesis block for $CHANNEL generating..."
    $FABRIC_BIN_PATH/bin/configtxgen -configPath $FABRIC_CFG_PATH -profile JedoChannel -channelID $CHANNEL -outputBlock $FABRIC_CFG_PATH/genesis_block.pb

    echo_ok "Channel $CHANNEL configured..."
done

