###############################################################
#!/bin/bash
#
# This script generates configtx.yaml, based on network-config.yaml, and creates Genesis-Block and Channel-Configuration.
#
#
###############################################################
source ./utils/utils.sh
source ./utils/help.sh
check_script

echo_ok "Generating Blockchain-Configuration - see Documentation here: https://hyperledger-fabric.readthedocs.io"


###############################################################
# Params - from ./config/network-config.yaml
###############################################################
CONFIG_FILE="./config/infrastructure-dev.yaml"
FABRIC_BIN_PATH=$(yq eval '.Fabric.Path' "$CONFIG_FILE")
CHANNELS=$(yq e ".FabricNetwork.Channels[].Name" $CONFIG_FILE)

for CHANNEL in $CHANNELS; do
    ###############################################################
    # Definitions 
    ###############################################################
    export FABRIC_CFG_PATH=${PWD}/config/$CHANNEL
    ORGANIZATIONS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[].Name" $CONFIG_FILE)
    OUTPUT_CONFIGTX_FILE="$FABRIC_CFG_PATH/configtx.yaml"


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
        CA_EXT=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Ext" $CONFIG_FILE)
        if [[ -n "$CA_EXT" ]]; then
            CA=$(yq eval ".. | select(has(\"CA\")) | .CA | select(.Name == \"$CA_EXT\") | .Name" "$CONFIG_FILE")
            CA_ORG=$(yq eval ".FabricNetwork.Channels[].Organizations[] | select(.CA.Name == \"$CA\") | .Name" "$CONFIG_FILE")
        else
            CA=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Name" $CONFIG_FILE)
            CA_ORG=$ORGANIZATION
        fi
        ORDERERS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Name" $CONFIG_FILE)
        PEERS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[].Name" $CONFIG_FILE)
      
        ORDERER_ENDPOINTS=""
        if [[ -n "$ORDERERS" ]]; then
            ORDERER=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[0].Name" $CONFIG_FILE)
            ORDERER_PORT=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[0].Port" $CONFIG_FILE)
            ORDERER_ENDPOINTS="OrdererEndpoints:
          - $ORDERER:$ORDERER_PORT"
        fi

cat <<EOF >> $OUTPUT_CONFIGTX_FILE
  - &${ORGANIZATION}
    Name: $ORGANIZATION
    ID: ${ORGANIZATION}
    MSPDir: $PWD/keys/$CHANNEL/_infrastructure/$CA_ORG/$CA/msp
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
        ORDERERS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Name" $CONFIG_FILE)
      
        if [[ -n "$ORDERERS" ]]; then
            ORDERER=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[0].Name" $CONFIG_FILE)
            ORDERER_PORT=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[0].Port" $CONFIG_FILE)
        fi
cat <<EOF >> $OUTPUT_CONFIGTX_FILE
    - $ORDERER:$ORDERER_PORT
EOF
    done

cat <<EOF >> $OUTPUT_CONFIGTX_FILE
  EtcdRaft:
    Consenters:
EOF

    for ORGANIZATION in $ORGANIZATIONS; do
        ORDERERS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Name" $CONFIG_FILE)
        if [[ -n "$ORDERERS" ]]; then
            ORDERER=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[0].Name" $CONFIG_FILE)
            ORDERER_PORT=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[0].Port" $CONFIG_FILE)
        fi
cat <<EOF >> $OUTPUT_CONFIGTX_FILE
      - Host: $ORDERER
        Port: $ORDERER_PORT
        ClientTLSCert: $PWD/keys/$CHANNEL/_infrastructure/$ORGANIZATION/$ORDERER/tls/signcerts/cert.pem
        ServerTLSCert: $PWD/keys/$CHANNEL/_infrastructure/$ORGANIZATION/$ORDERER/tls/signcerts/cert.pem
EOF
    done

cat <<EOF >> $OUTPUT_CONFIGTX_FILE
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
    $FABRIC_BIN_PATH/bin/configtxgen -profile JedoChannel -channelID $CHANNEL -outputBlock $FABRIC_CFG_PATH/genesis_block.pb

done

echo_ok "configtx.yaml, Genesis-Block and Channel-Configuration generated"