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
# Params - from ./configinfrastructure-cc.yaml
###############################################################
CONFIG_FILE="$SCRIPT_DIR/infrastructure-cc.yaml"
FABRIC_BIN_PATH=$(yq eval '.Fabric.Path' "$CONFIG_FILE")
ORBIS=$(yq eval ".Orbis.Name" "$CONFIG_FILE")
REGNUMS=$(yq e ".Regnum[].Name" $CONFIG_FILE)

for REGNUM in $REGNUMS; do
    echo ""
    echo_warn "Channel $REGNUM joining..."

    ADMIN=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .Administration.Contact" $CONFIG_FILE)

    export PATH=$PATH:$FABRIC_BIN_PATH
    export FABRIC_CFG_PATH=${PWD}/infrastructure/$ORBIS/$REGNUM/configuration
    export OSN_TLS_CA_ROOT_CERT=$(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/_Admin/tls/tlscacerts/*.pem)
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
            # configtxlator proto_decode --input=$FABRIC_CFG_PATH/genesisblock --type=common.Block

            ORBIS_TOOLS_NAME=$(yq eval ".Orbis.Tools.Name" "$CONFIG_FILE")
            ORBIS_TOOLS_CACLI_DIR=/etc/hyperledger/fabric-ca-client

            export FABRIC_CFG_PATH=$ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/configuration

            export OSN_TLS_CA_ROOT_CERT_FILE=$(basename $(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/_Admin/tls/tlscacerts/*.pem))
            export OSN_TLS_CA_ROOT_CERT=$ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/_Admin/tls/tlscacerts/$OSN_TLS_CA_ROOT_CERT_FILE

            export ADMIN_TLS_SIGNCERT=$ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/_Admin/$ADMIN/tls/signcerts/cert.pem

            export ADMIN_TLS_PRIVATEKEY_FILE=$(basename $(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/_Admin/$ADMIN/tls/keystore/*_sk))
            export ADMIN_TLS_PRIVATEKEY=$ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/_Admin/$ADMIN/tls/keystore/$ADMIN_TLS_PRIVATEKEY_FILE

            echo ""
            echo_info "$ORDERER_NAME joins $REGNUM..."
            echo_info "docker exec -it $ORBIS_TOOLS_NAME osnadmin channel join \
                --channelID $REGNUM --config-block $FABRIC_CFG_PATH/genesisblock \
                -o $ORDERER_IP:$ORDERER_ADMINPORT \
                --ca-file $OSN_TLS_CA_ROOT_CERT --client-cert $ADMIN_TLS_SIGNCERT --client-key $ADMIN_TLS_PRIVATEKEY"

            docker exec -it $ORBIS_TOOLS_NAME osnadmin channel join \
                --channelID $REGNUM --config-block $FABRIC_CFG_PATH/genesisblock \
                -o $ORDERER_IP:$ORDERER_ADMINPORT \
                --ca-file $OSN_TLS_CA_ROOT_CERT --client-cert $ADMIN_TLS_SIGNCERT --client-key $ADMIN_TLS_PRIVATEKEY
        done
    done
done
echo ""
echo_warn "Joins to Channels completed..."



