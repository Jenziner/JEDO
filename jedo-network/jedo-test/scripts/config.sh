###############################################################
#!/bin/bash
#
# This script generates configtx.yaml, based on network-config.yaml, and creates Genesis-Block and Channel-Configuration.
#
# Prerequisits:
#   - yq: 
#       - installation: sudo wget https://github.com/mikefarah/yq/releases/download/v4.6.3/yq_linux_amd64 -O /usr/local/bin/yq
#       - make it executable: chmod +x /usr/local/bin/yq
#
###############################################################
set -Eeuo pipefail
ls scripts/config.sh || { echo "ScriptInfo: run this script from the root directory: ./scripts/config.sh"; exit 1; }


###############################################################
# Definitions 
###############################################################
export FABRIC_CFG_PATH=./config
NETWORK_CONFIG_FILE="$FABRIC_CFG_PATH/network-config.yaml"
OUTPUT_CONFIGTX_FILE="$FABRIC_CFG_PATH/configtx.yaml"
FABRIC_PATH=$(yq eval '.Fabric.Path' "$NETWORK_CONFIG_FILE")
ORGANIZATIONS=$(yq e '.FabricNetwork.Organizations[].Name' $NETWORK_CONFIG_FILE)


###############################################################
# Start of configtx.yaml
###############################################################
echo "ScriptInfo: generating $OUTPUT_CONFIGTX_FILE"

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
    ORG_ADMIN=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Admin.Name" $NETWORK_CONFIG_FILE)
    ORDERERS=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Name" $NETWORK_CONFIG_FILE)
    PEERS=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[].Name" $NETWORK_CONFIG_FILE)
  
    ORDERER_ENDPOINTS=""
    if [[ -n "$ORDERERS" ]]; then
        ORDERER=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[0].Name" $NETWORK_CONFIG_FILE)
        ORDERER_PORT=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[0].Port" $NETWORK_CONFIG_FILE)
        ORDERER_ENDPOINTS="OrdererEndpoints:
      - $ORDERER:$ORDERER_PORT"
    fi

    ANCHOR_PEERS=""
    if [[ -n "$PEERS" ]]; then
        PEER=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[0].Name" $NETWORK_CONFIG_FILE)
        PEER_PORT=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[0].Port1" $NETWORK_CONFIG_FILE)
        ANCHOR_PEERS="AnchorPeers:
      - Host: $PEER
        Port: $PEER_PORT"
    fi

cat <<EOF >> $OUTPUT_CONFIGTX_FILE
  - &${ORGANIZATION}
    Name: $ORGANIZATION
    ID: ${ORGANIZATION}MSP
    MSPDir: $PWD/keys/$ORGANIZATION/$ORG_ADMIN/msp
    Policies:
      Readers:
        Type: Signature
        Rule: "OR('${ORGANIZATION}MSP.member')"
      Writers:
        Type: Signature
        Rule: "OR('${ORGANIZATION}MSP.member')"
      Admins:
        Type: Signature
        Rule: "OR('${ORGANIZATION}MSP.admin')"
      BlockValidation:
        Type: ImplicitMeta
        Rule: "ANY Writers"
      Endorsement:
        Type: Signature
        Rule: "OR('${ORGANIZATION}MSP.peer')"
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

RULE_MEMBER="OR("
RULE_ADMIN="OR("
RULE_PEER="OR("
for ORG in $ORGANIZATIONS; do
  ORG_MSP="${ORG}MSP"
  RULE_MEMBER="${RULE_MEMBER}'${ORG_MSP}.member', "
  RULE_ADMIN="${RULE_ADMIN}'${ORG_MSP}.admin', "
  RULE_PEER="${RULE_PEER}'${ORG_MSP}.peer', "
done
RULE_MEMBER="${RULE_MEMBER::-2})"
RULE_ADMIN="${RULE_ADMIN::-2})"
RULE_PEER="${RULE_PEER::-2})"

cat <<EOF >> $OUTPUT_CONFIGTX_FILE
  Policies:
    Readers:
      Type: Signature
      Rule: $RULE_MEMBER
    Writers:
      Type: Signature
      Rule: $RULE_MEMBER
    Admins:
      Type: Signature
      Rule: $RULE_ADMIN
    LifecycleEndorsement:
      Type: Signature
      Rule: $RULE_PEER
    Endorsement:
      Type: Signature
      Rule: $RULE_PEER
  Capabilities:
    <<: *ApplicationCapabilities
EOF


###############################################################
# Section Orderer
###############################################################
cat <<EOF >> $OUTPUT_CONFIGTX_FILE
Orderer: &OrdererDefaults
  Addresses:
EOF

for ORGANIZATION in $ORGANIZATIONS; do
    ORDERERS=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Name" $NETWORK_CONFIG_FILE)
  
    if [[ -n "$ORDERERS" ]]; then
        ORDERER=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[0].Name" $NETWORK_CONFIG_FILE)
        ORDERER_PORT=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[0].Port" $NETWORK_CONFIG_FILE)
    fi
cat <<EOF >> $OUTPUT_CONFIGTX_FILE
    - $ORDERER:$ORDERER_PORT
EOF
done

cat <<EOF >> $OUTPUT_CONFIGTX_FILE
  OrdererType: etcdraft
  EtcdRaft:
    Consenters:
EOF

for ORGANIZATION in $ORGANIZATIONS; do
    ORDERERS=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Name" $NETWORK_CONFIG_FILE)
    if [[ -n "$ORDERERS" ]]; then
        ORDERER=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[0].Name" $NETWORK_CONFIG_FILE)
        ORDERER_PORT=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[0].Port" $NETWORK_CONFIG_FILE)
    fi
cat <<EOF >> $OUTPUT_CONFIGTX_FILE
      - Host: $ORDERER
        Port: $ORDERER_PORT
        ClientTLSCert: $PWD/keys/$ORGANIZATION/$ORDERER/tls/signcerts/cert.pem
        ServerTLSCert: $PWD/keys/$ORGANIZATION/$ORDERER/tls/signcerts/cert.pem
EOF
done

cat <<EOF >> $OUTPUT_CONFIGTX_FILE
  BatchTimeout: 2s
  BatchSize:
    MaxMessageCount: 10
    AbsoluteMaxBytes: 99 MB
    PreferredMaxBytes: 512 kB
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
      Rule: "MAJORITY Admins"
    BlockValidation:
      Type: ImplicitMeta
      Rule: "ANY Writers"
  Capabilities:
    V2_0: true
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
  JedoGenesis:
    <<: *ChannelDefaults
    Orderer:
      <<: *OrdererDefaults
      Capabilities: *OrdererCapabilities
    Consortiums:
      JEDO:
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

  JedoChannel:
    <<: *ChannelDefaults
    Consortium: JEDO
    Application:
      <<: *ApplicationDefaults
      Organizations:
EOF

for ORGANIZATION in $ORGANIZATIONS; do
cat <<EOF >> $OUTPUT_CONFIGTX_FILE
        - *$ORGANIZATION
EOF
done

cat <<EOF >> $OUTPUT_CONFIGTX_FILE
      Capabilities: 
        <<: *ApplicationCapabilities
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
        Endorsement:
          Type: ImplicitMeta
          Rule: "ANY Endorsement"      
EOF


###############################################################
# Generate GenesisBlock and ChannelConfiguration
###############################################################
CHANNEL=$(yq e '.FabricNetwork.Channel' $NETWORK_CONFIG_FILE)

echo "ScriptInfo: generating $FABRIC_CFG_PATH/$CHANNEL.genesisblock"
$FABRIC_PATH/bin/configtxgen -profile JedoGenesis -channelID system-channel -outputBlock $FABRIC_CFG_PATH/$CHANNEL.genesisblock

echo "ScriptInfo: generating $FABRIC_CFG_PATH/$CHANNEL.tx"
$FABRIC_PATH/bin/configtxgen -profile JedoChannel -channelID $CHANNEL -outputCreateChannelTx $FABRIC_CFG_PATH/$CHANNEL.tx

