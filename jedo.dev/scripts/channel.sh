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
CHANNELS=$(yq e ".Channels[].Name" $CONFIG_FILE)

for CHANNEL in $CHANNELS; do
    echo ""
    echo_warn "Channel $CHANNEL joining..."

    ORGANIZATIONS=$(yq e ".Organizations[].Name" $CONFIG_FILE)
    for ORGANIZATION in $ORGANIZATIONS; do
        ADMIN=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Operators[] | select(.Type == \"admin\") | .Name" $CONFIG_FILE | head -n 1)

        ORDERERS=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Name" $CONFIG_FILE)
        for ORDERER in $ORDERERS; do
            ###############################################################
            # Channel
            ###############################################################
            ORDERER_NAME=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Name" $CONFIG_FILE)
            ORDERER_IP=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[] | select(.Name == \"$ORDERER\") | .IP" $CONFIG_FILE)
            ORDERER_ADMINPORT=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[] | select(.Name == \"$ORDERER\") | .AdminPort" $CONFIG_FILE)

            export PATH=$PATH:$FABRIC_BIN_PATH
            export FABRIC_CFG_PATH=${PWD}/configuration/$CHANNEL
            export OSN_TLS_CA_ROOT_CERT=$(ls ${PWD}/infrastructure/$ORGANIZATION/$ORDERER/keys/server/tls/tlscacerts/*.pem)
            export ADMIN_TLS_SIGNCERT=${PWD}/infrastructure/$ORGANIZATION/_Operators/$ADMIN/keys/tls/signcerts/cert.pem
            export ADMIN_TLS_PRIVATEKEY=$(ls ${PWD}/infrastructure/$ORGANIZATION/_Operators/$ADMIN/keys/tls/keystore/*_sk)

            echo ""
            echo_info "$ORDERER_NAME joins $CHANNEL..."
            osnadmin channel join \
            --channelID $CHANNEL --config-block $FABRIC_CFG_PATH/genesis_block.pb \
            -o $ORDERER_IP:$ORDERER_ADMINPORT \
            --ca-file $OSN_TLS_CA_ROOT_CERT --client-cert $ADMIN_TLS_SIGNCERT --client-key $ADMIN_TLS_PRIVATEKEY
echo_error "TEMP END"
exit 1
        done
    done
done
echo ""
echo_warn "Joins to Channels completed..."






# echo_info "osnadmin channel join --channelID $CHANNEL --config-block $FABRIC_CFG_PATH/genesis_block.pb -o $ORDERER_IP:$ORDERER_ADMINPORT --ca-file $OSN_TLS_CA_ROOT_CERT --client-cert $ADMIN_TLS_SIGN_CERT --client-key $ADMIN_TLS_PRIVATE_KEY"


