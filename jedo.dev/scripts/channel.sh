###############################################################
#!/bin/bash
#
# This script creates Channel
#
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
check_script


###############################################################
# Params - from ./configinfrastructure-dev.yaml
###############################################################
CONFIG_FILE="$SCRIPT_DIR/infrastructure-dev.yaml"
FABRIC_BIN_PATH=$(yq eval '.Fabric.Path' "$CONFIG_FILE")
ORBIS_NAME=$(yq eval ".Orbis.Name" "$CONFIG_FILE")
CHANNELS=$(yq e ".Regnum[].Name" $CONFIG_FILE)

for CHANNEL in $CHANNELS; do
    echo ""
    echo_warn "Channel $CHANNEL joining..."

    ORGANIZATION=$(yq eval ".Regnum[] | select(.Name == \"$CHANNEL\") | .Administration.Organization" $CONFIG_FILE)
    ADMIN=$(yq eval ".Regnum[] | select(.Name == \"$CHANNEL\") | .Administration.Contact" $CONFIG_FILE)

    export PATH=$PATH:$FABRIC_BIN_PATH
    export FABRIC_CFG_PATH=${PWD}/configuration/$CHANNEL
    export OSN_TLS_CA_ROOT_CERT=$(ls ${PWD}/infrastructure/$ORBIS_NAME/$CHANNEL/_Admin/tls/tlscacerts/*.pem)
    export ADMIN_TLS_SIGNCERT=${PWD}/infrastructure/$ORBIS_NAME/$CHANNEL/_Admin/$ADMIN/tls/signcerts/cert.pem
    export ADMIN_TLS_PRIVATEKEY=$(ls ${PWD}/infrastructure/$ORBIS_NAME/$CHANNEL/_Admin/$ADMIN/tls/keystore/*_sk)

    ORDERERS=$(yq eval ".Regnum[] | select(.Name == \"$CHANNEL\") | .Orderers[].Name" $CONFIG_FILE)
    for ORDERER in $ORDERERS; do
        ###############################################################
        # Channel Join for Orderers
        ###############################################################
        ORDERER_NAME=$(yq eval ".Regnum[] | select(.Name == \"$CHANNEL\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Name" $CONFIG_FILE)
        ORDERER_IP=$(yq eval ".Regnum[] | select(.Name == \"$CHANNEL\") | .Orderers[] | select(.Name == \"$ORDERER\") | .IP" $CONFIG_FILE)
        ORDERER_ADMINPORT=$(yq eval ".Regnum[] | select(.Name == \"$CHANNEL\") | .Orderers[] | select(.Name == \"$ORDERER\") | .AdminPort" $CONFIG_FILE)


        # Uncomment for genesis-file debug
        # echo_info "List Genesis-File"
        # configtxlator proto_decode --input=$FABRIC_CFG_PATH/genesis_block.pb --type=common.Block


        echo ""
        echo_info "$ORDERER_NAME joins $CHANNEL..."
        osnadmin channel join \
        --channelID $CHANNEL --config-block $FABRIC_CFG_PATH/genesis_block.pb \
        -o $ORDERER_IP:$ORDERER_ADMINPORT \
        --ca-file $OSN_TLS_CA_ROOT_CERT --client-cert $ADMIN_TLS_SIGNCERT --client-key $ADMIN_TLS_PRIVATEKEY
    done
done
echo ""
echo_warn "Joins to Channels completed..."



