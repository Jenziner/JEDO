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
CHANNELS=$(yq e ".Channels[].Name" $CONFIG_FILE)

for CHANNEL in $CHANNELS; do
    echo ""
    echo_warn "Channel $CHANNEL configuring..."

    export FABRIC_CFG_PATH=${PWD}/configuration/$CHANNEL
    mkdir -p $FABRIC_CFG_PATH
    OUTPUT_CONFIGTX_FILE="$FABRIC_CFG_PATH/configtx.yaml"
    ORGANIZATIONS=$(yq eval ".Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[].Name" $CONFIG_FILE)


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

    for ORGANIZATION in $ORGANIZATIONS; do
        CA_EXT=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .ORG-CA.Ext" $CONFIG_FILE)
        if [[ -n "$CA_EXT" ]]; then
            CA=$(yq eval ".. | select(has(\"CA\")) | .ORG-CA | select(.Name == \"$CA_EXT\") | .Name" "$CONFIG_FILE")
            CA_ORG=$(yq eval ".Organizations[] | select(.ORG-CA.Name == \"$CA\") | .Name" "$CONFIG_FILE")
        else
            CA=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .ORG-CA.Name" $CONFIG_FILE)
            CA_ORG=$ORGANIZATION
        fi

        ORDERERS=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Name" $CONFIG_FILE)
        PEERS=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[].Name" $CONFIG_FILE)
        ORDERER_ENDPOINTS=""
        if [[ -n "$ORDERERS" ]]; then
            ORDERER=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[0].Name" $CONFIG_FILE)
            ORDERER_PORT=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[0].Port" $CONFIG_FILE)
            ORDERER_ENDPOINTS="OrdererEndpoints:
          - $ORDERER:$ORDERER_PORT"
        fi
        ANCHOR_PEERS=""
        if [[ -n "$PEERS" ]]; then
            PEER=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[0].Name" $CONFIG_FILE)
            PEER_PORT=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[0].Port" $CONFIG_FILE)
            ANCHOR_PEERS="AnchorPeers:
          - Host: $ORDERER
            Port: $ORDERER_PORT"
        fi


cat <<EOF >> $OUTPUT_CONFIGTX_FILE
  - &${ORGANIZATION}
    Name: $ORGANIZATION
    ID: ${ORGANIZATION}
    MSPDir: $PWD/infrastructure/$CA_ORG/$CA/keys/server/msp
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
    $ANCHOR_PEERS
EOF
    done


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
EOF

    for ORGANIZATION in $ORGANIZATIONS; do
cat <<EOF >> $OUTPUT_CONFIGTX_FILE
    - *$ORGANIZATION
EOF
    done

cat <<EOF >> $OUTPUT_CONFIGTX_FILE
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
  Addresses:
EOF

    for ORGANIZATION in $ORGANIZATIONS; do
        ORDERERS=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Name" $CONFIG_FILE)
      
        if [[ -n "$ORDERERS" ]]; then
            ORDERER=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[0].Name" $CONFIG_FILE)
            ORDERER_PORT=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[0].Port" $CONFIG_FILE)
        fi
cat <<EOF >> $OUTPUT_CONFIGTX_FILE
    - $ORDERER:$ORDERER_PORT
EOF
    done

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

    for ORGANIZATION in $ORGANIZATIONS; do
        ORDERERS=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Name" $CONFIG_FILE)
        if [[ -n "$ORDERERS" ]]; then
            ORDERER=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[0].Name" $CONFIG_FILE)
            ORDERER_PORT=$(yq e ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[0].Port" $CONFIG_FILE)
        fi
cat <<EOF >> $OUTPUT_CONFIGTX_FILE
      - Host: $ORDERER
        Port: $ORDERER_PORT
        ClientTLSCert: ${PWD}/infrastructure/$ORGANIZATION/$ORDERER/keys/server/tls/signcerts/cert.pem
        ServerTLSCert: ${PWD}/infrastructure/$ORGANIZATION/$ORDERER/keys/server/tls/signcerts/cert.pem
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
EOF

    for ORGANIZATION in $ORGANIZATIONS; do
cat <<EOF >> $OUTPUT_CONFIGTX_FILE
      - *$ORGANIZATION
EOF
    done

cat <<EOF >> $OUTPUT_CONFIGTX_FILE
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
EOF

    for ORGANIZATION in $ORGANIZATIONS; do
cat <<EOF >> $OUTPUT_CONFIGTX_FILE
        - <<: *$ORGANIZATION
          Policies:
            <<: *${ORGANIZATION}Policies
            Admins:
              Type: Signature
              Rule: "OR('$ORGANIZATION.member')"
EOF
    done

cat <<EOF >> $OUTPUT_CONFIGTX_FILE
    Application:
      <<: *ApplicationDefaults
      Organizations:
EOF

    for ORGANIZATION in $ORGANIZATIONS; do
cat <<EOF >> $OUTPUT_CONFIGTX_FILE
        - <<: *$ORGANIZATION
          Policies:
            <<: *${ORGANIZATION}Policies
            Admins:
              Type: Signature
              Rule: "OR('$ORGANIZATION.member')"
EOF
    done

    echo_info "Genesis block for $CHANNEL generating..."
    $FABRIC_BIN_PATH/bin/configtxgen -configPath $FABRIC_CFG_PATH -profile JedoChannel -channelID $CHANNEL -outputBlock $FABRIC_CFG_PATH/genesis_block.pb

    echo_ok "Channel $CHANNEL configured..."
done

