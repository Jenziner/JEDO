###############################################################
#!/bin/bash
#
# This script creates Channel
#
#
###############################################################
source ./utils/utils.sh
source ./utils/help.sh
check_script

echo_ok "Creating Channel - see Documentation here: https://hyperledger-fabric.readthedocs.io"


###############################################################
# Params - from ./configinfrastructure-dev.yaml
###############################################################
CONFIG_FILE="./config/infrastructure-dev.yaml"
FABRIC_BIN_PATH=$(yq eval '.Fabric.Path' "$CONFIG_FILE")
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $CONFIG_FILE)
CHANNELS=$(yq e ".FabricNetwork.Channels[].Name" $CONFIG_FILE)


echo ""
echo_warn "Joins to Channels starting..."
for CHANNEL in $CHANNELS; do
    ORGANIZATIONS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[].Name" $CONFIG_FILE)
    for ORGANIZATION in $ORGANIZATIONS; do
        ADMIN=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Admin.Name" $CONFIG_FILE)
        ORDERERS=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Name" $CONFIG_FILE)
        for ORDERER in $ORDERERS; do
            ###############################################################
            # Channel
            ###############################################################
            ORDERER_NAME=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Name" $CONFIG_FILE)
            ORDERER_IP=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[] | select(.Name == \"$ORDERER\") | .IP" $CONFIG_FILE)
            ORDERER_ADMINPORT=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Admin.Port" $CONFIG_FILE)

            export PATH=$PATH:$FABRIC_BIN_PATH
            export FABRIC_CFG_PATH=${PWD}/config/$CHANNEL
            export OSN_TLS_CA_ROOT_CERT=$(ls ${PWD}/keys/$CHANNEL/_infrastructure/$ORGANIZATION/$ORDERER/tls/tlsintermediatecerts/*.pem)
            export ADMIN_TLS_SIGN_CERT=${PWD}/keys/$CHANNEL/_infrastructure/$ORGANIZATION/$ADMIN/msp/signcerts/cert.pem
            export ADMIN_TLS_PRIVATE_KEY=$(ls ${PWD}/keys/$CHANNEL/_infrastructure/$ORGANIZATION/$ADMIN/msp/keystore/*_sk)


echo_info "osnadmin channel join --channelID $CHANNEL --config-block $FABRIC_CFG_PATH/genesis_block.pb -o $ORDERER_IP:$ORDERER_ADMINPORT --ca-file $OSN_TLS_CA_ROOT_CERT --client-cert $ADMIN_TLS_SIGN_CERT --client-key $ADMIN_TLS_PRIVATE_KEY"

            echo ""
            echo_info "$ORDERER_NAME joins $CHANNEL..."
            osnadmin channel join \
            --channelID $CHANNEL --config-block $FABRIC_CFG_PATH/genesis_block.pb \
            -o $ORDERER_IP:$ORDERER_ADMINPORT \
            --ca-file $OSN_TLS_CA_ROOT_CERT --client-cert $ADMIN_TLS_SIGN_CERT --client-key $ADMIN_TLS_PRIVATE_KEY
echo_error "TEMP END"
exit 1
        done
    done
done
echo ""
echo_warn "Joins to Channels completed..."







