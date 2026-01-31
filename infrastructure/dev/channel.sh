###############################################################
#!/bin/bash
#
# This script creates Channel
#
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/params.sh"
check_script


###############################################################
# REGNUM Channel
###############################################################
LOCAL_INFRA_DIR=${PWD}/infrastructure
for REGNUM in $REGNUMS; do
    log_info "Joins to Channel $REGNUM started..."

    ADMIN=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .Administration.Contact" $CONFIG_FILE)

    export FABRIC_CFG_PATH=$LOCAL_INFRA_DIR/$ORBIS/$REGNUM/configuration
    export OSN_TLS_CA_ROOT_CERT=$(ls $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/_Admin/tls/tlscacerts/*.pem)
    export ADMIN_TLS_SIGNCERT=$LOCAL_INFRA_DIR/$ORBIS/$REGNUM/_Admin/$ADMIN/tls/signcerts/cert.pem
    export ADMIN_TLS_PRIVATEKEY=$(ls $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/_Admin/$ADMIN/tls/keystore/*_sk)

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

#            export FABRIC_CFG_PATH=$ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/configuration

            export OSN_TLS_CA_ROOT_CERT_FILE=$(basename $(ls $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/_Admin/tls/tlscacerts/*.pem))
            export OSN_TLS_CA_ROOT_CERT=$LOCAL_INFRA_DIR/$ORBIS/$REGNUM/_Admin/tls/tlscacerts/$OSN_TLS_CA_ROOT_CERT_FILE

            export ADMIN_TLS_SIGNCERT=$LOCAL_INFRA_DIR/$ORBIS/$REGNUM/_Admin/$ADMIN/tls/signcerts/cert.pem

            export ADMIN_TLS_PRIVATEKEY_FILE=$(basename $(ls $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/_Admin/$ADMIN/tls/keystore/*_sk))
            export ADMIN_TLS_PRIVATEKEY=$LOCAL_INFRA_DIR/$ORBIS/$REGNUM/_Admin/$ADMIN/tls/keystore/$ADMIN_TLS_PRIVATEKEY_FILE

            log_info "$ORDERER_NAME joins $REGNUM..."
            log_debug "Regnum Name:" "$REGNUM"
            log_debug "Ager Name:" "$AGER"
            log_debug "Orderer Name:" "$ORDERER"
            log_debug "CA-File:" "$OSN_TLS_CA_ROOT_CERT"
            osnadmin channel join \
                --channelID $REGNUM --config-block $FABRIC_CFG_PATH/genesisBlockRegnum \
                -o $ORDERER_IP:$ORDERER_ADMINPORT \
                --ca-file $OSN_TLS_CA_ROOT_CERT --client-cert $ADMIN_TLS_SIGNCERT --client-key $ADMIN_TLS_PRIVATEKEY
        done


        PEERS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[].Name" $CONFIG_FILE)
        for PEER in $PEERS; do
            ###############################################################
            # Channel Join for Peers - useing last orderer joined channel
            ###############################################################
            PEER_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .Name" $CONFIG_FILE)

            log_info "$PEER_NAME joins $REGNUM..."
            log_debug "Regnum Name:" "$REGNUM"
            log_debug "Ager Name:" "$AGER"
            log_debug "Peer Name:" "$PEER"
            log_debug "CA-File:" "$OSN_TLS_CA_ROOT_CERT"
            docker exec \
                -e CORE_PEER_MSPCONFIGPATH=/var/hyperledger/infrastructure/$ORBIS/$REGNUM/$AGER/admin.$AGER.$REGNUM.$ORBIS.$ORBIS_ENV/msp \
                $PEER_NAME peer channel join -b /var/hyperledger/configuration/genesisBlockRegnum
        done
    done
    log_ok "Joins to Channel $REGNUM completed..."
done

###############################################################
# ORBIS Channel
###############################################################
log_info "Joins to Channel $ORBIS started..."

for REGNUM in $REGNUMS; do
    ADMIN=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .Administration.Contact" $CONFIG_FILE)

    export FABRIC_CFG_PATH=$LOCAL_INFRA_DIR/$ORBIS/configuration
    export OSN_TLS_CA_ROOT_CERT=$(ls $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/_Admin/tls/tlscacerts/*.pem)
    export ADMIN_TLS_SIGNCERT=$LOCAL_INFRA_DIR/$ORBIS/$REGNUM/_Admin/$ADMIN/tls/signcerts/cert.pem
    export ADMIN_TLS_PRIVATEKEY=$(ls $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/_Admin/$ADMIN/tls/keystore/*_sk)

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

    #            export FABRIC_CFG_PATH=$ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/configuration

            export OSN_TLS_CA_ROOT_CERT_FILE=$(basename $(ls $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/_Admin/tls/tlscacerts/*.pem))
            export OSN_TLS_CA_ROOT_CERT=$LOCAL_INFRA_DIR/$ORBIS/$REGNUM/_Admin/tls/tlscacerts/$OSN_TLS_CA_ROOT_CERT_FILE

            export ADMIN_TLS_SIGNCERT=$LOCAL_INFRA_DIR/$ORBIS/$REGNUM/_Admin/$ADMIN/tls/signcerts/cert.pem

            export ADMIN_TLS_PRIVATEKEY_FILE=$(basename $(ls $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/_Admin/$ADMIN/tls/keystore/*_sk))
            export ADMIN_TLS_PRIVATEKEY=$LOCAL_INFRA_DIR/$ORBIS/$REGNUM/_Admin/$ADMIN/tls/keystore/$ADMIN_TLS_PRIVATEKEY_FILE

            log_info "$ORDERER_NAME joins $ORBIS..."
            log_debug "Regnum Name:" "$REGNUM"
            log_debug "Ager Name:" "$AGER"
            log_debug "Orderer Name:" "$ORDERER"
            log_debug "CA-File:" "$OSN_TLS_CA_ROOT_CERT"
            osnadmin channel join \
                --channelID $ORBIS --config-block $FABRIC_CFG_PATH/genesisBlockOrbis \
                -o $ORDERER_IP:$ORDERER_ADMINPORT \
                --ca-file $OSN_TLS_CA_ROOT_CERT --client-cert $ADMIN_TLS_SIGNCERT --client-key $ADMIN_TLS_PRIVATEKEY
        done


        PEERS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[].Name" $CONFIG_FILE)
        for PEER in $PEERS; do
            ###############################################################
            # Channel Join for Peers - useing last orderer joined channel
            ###############################################################
            PEER_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .Name" $CONFIG_FILE)

            log_info "$PEER_NAME joins $ORBIS..."
            log_debug "Regnum Name:" "$REGNUM"
            log_debug "Ager Name:" "$AGER"
            log_debug "Peer Name:" "$PEER"
            log_debug "CA-File:" "$OSN_TLS_CA_ROOT_CERT"
            cp $LOCAL_INFRA_DIR/$ORBIS/configuration/genesisBlockOrbis $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/configuration/genesisBlockOrbis
            docker exec \
                -e CORE_PEER_MSPCONFIGPATH=/var/hyperledger/infrastructure/$ORBIS/$REGNUM/$AGER/admin.$AGER.$REGNUM.$ORBIS.$ORBIS_ENV/msp \
                $PEER_NAME peer channel join -b /var/hyperledger/configuration/genesisBlockOrbis
        done
    done
done
log_ok "Joins to Channel $ORBIS completed..."



