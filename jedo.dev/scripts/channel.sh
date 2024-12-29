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
ORBIS=$(yq eval ".Orbis.Name" "$CONFIG_FILE")
REGNUMS=$(yq e ".Regnum[].Name" $CONFIG_FILE)

for REGNUM in $REGNUMS; do
    echo ""
    echo_warn "Channel $REGNUM joining..."

    ADMIN=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .Administration.Contact" $CONFIG_FILE)

    export PATH=$PATH:$FABRIC_BIN_PATH
    export FABRIC_CFG_PATH=${PWD}/configuration/$REGNUM
    export TLS_CA_ROOT_CERT=$(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/_Admin/tls/tlscacerts/*.pem)
    export ADMIN_TLS_SIGNCERT=${PWD}/infrastructure/$ORBIS/$REGNUM/_Admin/$ADMIN/tls/signcerts/cert.pem
    export ADMIN_TLS_PRIVATEKEY=$(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/_Admin/$ADMIN/tls/keystore/*_sk)

    AGERS=$(yq eval ".Ager[] | select(.Administration.Parent == \"$REGNUM\") | .Name" $CONFIG_FILE)
    for AGER in $AGERS; do
        ORDERERS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[].Name" $CONFIG_FILE)
        for ORDERER in $ORDERERS; do
            ###############################################################
            # Channel Join for Orderers
            ###############################################################
            ORDERER_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Name" $CONFIG_FILE)
            ORDERER_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .IP" $CONFIG_FILE)
            ORDERER_ADMINPORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .AdminPort" $CONFIG_FILE)


            # Uncomment for genesis-file debug
            # echo_info "List Genesis-File"
            # configtxlator proto_decode --input=$FABRIC_CFG_PATH/genesis_block.pb --type=common.Block


            echo ""
            echo_info "$ORDERER_NAME joins $REGNUM..."
            echo_info "osnadmin channel join \
            --channelID $REGNUM --config-block $FABRIC_CFG_PATH/genesis_block.pb \
            -o $ORDERER_IP:$ORDERER_ADMINPORT \
            --ca-file $TLS_CA_ROOT_CERT --client-cert $ADMIN_TLS_SIGNCERT --client-key $ADMIN_TLS_PRIVATEKEY"

            
            osnadmin channel join \
            --channelID $REGNUM --config-block $FABRIC_CFG_PATH/genesis_block.pb \
            -o $ORDERER_IP:$ORDERER_ADMINPORT \
            --ca-file $TLS_CA_ROOT_CERT --client-cert $ADMIN_TLS_SIGNCERT --client-key $ADMIN_TLS_PRIVATEKEY
        done
    done
done
echo ""
echo_warn "Joins to Channels completed..."



