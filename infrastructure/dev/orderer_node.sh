###############################################################
#!/bin/bash
#
# This script starts Hyperledger Fabric Orderer
#
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/params.sh"
check_script


get_hosts


###############################################################
# Params for ager
###############################################################
for AGER in $AGERS; do

    REGNUM=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Administration.Parent" $CONFIG_FILE)
    AFFILIATION_NODE=$REGNUM.${AGER,,}

    ORDERERS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[].Name" $CONFIG_FILE)
    for ORDERER in $ORDERERS; do
        ###############################################################
        # Params
        ###############################################################
        ORDERER_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Name" $CONFIG_FILE)
        ORDERER_SUBJECT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Subject" $CONFIG_FILE)
        ORDERER_PASS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Pass" $CONFIG_FILE)
        ORDERER_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .IP" $CONFIG_FILE)
        ORDERER_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Port" $CONFIG_FILE)
        ORDERER_CLPORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .ClusterPort" $CONFIG_FILE)
        ORDERER_OPPORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .OpPort" $CONFIG_FILE)
        ORDERER_ADMPORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .AdminPort" $CONFIG_FILE)

        LOCAL_INFRA_DIR=${PWD}/infrastructure
        LOCAL_SRV_DIR=$LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$ORDERER/
        HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server


        ###############################################################
        # Write orderer.yaml
        ###############################################################
        TLS_PRIVATEKEY_FILE=$(basename $(ls $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$ORDERER_NAME/tls/keystore/*_sk))
        TLS_TLSCACERT_FILE=$(basename $(ls $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$ORDERER_NAME/tls/tlscacerts/*.pem))
        CLIENT_TLSCACERT_FILE=$(basename $(ls $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/_Admin/tls/tlscacerts/*.pem))

        echo ""
        if [[ $DEBUG == true ]]; then
            echo_debug "Executing with the following:"
            echo_value_debug "- Orderer Name:" "$ORDERER_NAME"
            echo_value_debug "- TLS Cert:" "$TLS_TLSCACERT_FILE"
        fi
        echo_info "Server-Config for $ORDERER_NAME writing..."
cat <<EOF > $LOCAL_SRV_DIR/orderer.yaml
---
General:
    ListenAddress: 0.0.0.0
    ListenPort: $ORDERER_PORT
    TLS:
        Enabled: true
        PrivateKey: /etc/hyperledger/orderer/tls/keystore/$TLS_PRIVATEKEY_FILE
        Certificate: /etc/hyperledger/orderer/tls/signcerts/cert.pem
        RootCAs:
          - /etc/hyperledger/orderer/tls/tlscacerts/$TLS_TLSCACERT_FILE
        ClientAuthRequired: false
        ClientRootCAs:
          - /etc/hyperledger/clientadmin/tls/$CLIENT_TLSCACERT_FILE
    Keepalive:
        ServerMinInterval: 60s
        ServerInterval: 7200s
        ServerTimeout: 20s
    MaxRecvMsgSize: 104857600
    MaxSendMsgSize: 104857600
    Cluster:
        SendBufferSize: 100
        ClientCertificate: /etc/hyperledger/orderer/tls/signcerts/cert.pem
        ClientPrivateKey: /etc/hyperledger/orderer/tls/keystore/$TLS_PRIVATEKEY_FILE
        ListenPort: $ORDERER_CLPORT
        ListenAddress: 0.0.0.0
        ServerCertificate: /etc/hyperledger/orderer/tls/signcerts/cert.pem
        ServerPrivateKey: /etc/hyperledger/orderer/tls/keystore/$TLS_PRIVATEKEY_FILE
        RootCAs:
          - /etc/hyperledger/orderer/tls/tlscacerts/$TLS_TLSCACERT_FILE
    LocalMSPDir: /etc/hyperledger/orderer/msp
    LocalMSPID: ${AGER}
    Profile:
        Enabled: false
        Address: 0.0.0.0:6060
    BCCSP:
        Default: SW
        SW:
            Hash: SHA2
            Security: 256
            FileKeyStore:
                KeyStore:
        PKCS11:
            Library:
            Label:
            Pin:
            Hash:
            Security:
            FileKeyStore:
                KeyStore:
    Authentication:
        TimeWindow: 15m
FileLedger:
    Location: /var/hyperledger/production/orderer
Debug:
    BroadcastTraceDir:
    DeliverTraceDir:
Operations:
    ListenAddress: 127.0.0.1:8443
    TLS:
        Enabled: false
        Certificate:
        PrivateKey:
        ClientAuthRequired: false
        ClientRootCAs: []
Metrics:
    Provider: disabled
    Statsd:
      Network: udp
      Address: 127.0.0.1:8125
      WriteInterval: 30s
      Prefix:
Admin:
    ListenAddress: $ORDERER_IP:$ORDERER_ADMPORT
    TLS:
        Enabled: true
        Certificate: /etc/hyperledger/orderer/tls/signcerts/cert.pem
        PrivateKey: /etc/hyperledger/orderer/tls/keystore/$TLS_PRIVATEKEY_FILE
        RootCAs: /etc/hyperledger/orderer/tls/tlscacerts/$TLS_TLSCACERT_FILE
        ClientAuthRequired: true
        ClientRootCAs: [/etc/hyperledger/clientadmin/tls/tlscacerts/$CLIENT_TLSCACERT_FILE]
ChannelParticipation:
    Enabled: true
    MaxRequestBodySize: 1 MB
Consensus:
    WALDir: /var/hyperledger/production/orderer/etcdraft/wal
    SnapDir: /var/hyperledger/production/orderer/etcdraft/snapshot
EOF


        ###############################################################
        # ORDERER
        ###############################################################
        echo ""
        echo_info "Docker $ORDERER_NAME starting..."
        export FABRIC_CFG_PATH=/etc/hyperledger/fabric
        mkdir -p $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$ORDERER_NAME/production
        chmod -R 750 $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$ORDERER_NAME/production
        docker run -d \
            --user $(id -u):$(id -g) \
            --name $ORDERER_NAME \
            --network $DOCKER_NETWORK_NAME \
            --ip $ORDERER_IP \
            $hosts_args \
            --restart=on-failure:1 \
            --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/infrastructure/src/fabric_logo.png" \
            -p $ORDERER_PORT:$ORDERER_PORT \
            -p $ORDERER_OPPORT:$ORDERER_OPPORT \
            -p $ORDERER_CLPORT:$ORDERER_CLPORT \
            -p $ORDERER_ADMPORT:$ORDERER_ADMPORT \
            -v $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$ORDERER_NAME:/etc/hyperledger/fabric \
            -v $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$ORDERER_NAME/msp:/etc/hyperledger/orderer/msp \
            -v $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$ORDERER_NAME/tls:/etc/hyperledger/orderer/tls \
            -v $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$ORDERER_NAME/production:/var/hyperledger/production/orderer \
            -v $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/_Admin/tls:/etc/hyperledger/clientadmin/tls \
            -e FABRIC_LOGGING_SPEC=$FABRIC_LOGGING_SPEC \
            -e ORDERER_GENERAL_LISTENADDRESS=0.0.0.0 \
            -e ORDERER_GENERAL_LISTENPORT=$ORDERER_PORT \
            -e ORDERER_GENERAL_TLS_ENABLED=true \
            -e ORDERER_GENERAL_TLS_PRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/$TLS_PRIVATEKEY_FILE \
            -e ORDERER_GENERAL_TLS_CERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem \
            -e ORDERER_GENERAL_TLS_ROOTCAS=[/etc/hyperledger/orderer/tls/tlscacerts/$TLS_TLSCACERT_FILE] \
            -e ORDERER_GENERAL_CLUSTER_LISTENADDRESS=0.0.0.0 \
            -e ORDERER_GENERAL_CLUSTER_LISTENPORT=$ORDERER_CLPORT \
            -e ORDERER_GENERAL_CLUSTER_CLIENTCERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem \
            -e ORDERER_GENERAL_CLUSTER_CLIENTPRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/$TLS_PRIVATEKEY_FILE \
            -e ORDERER_GENERAL_CLUSTER_ROOTCAS=[/etc/hyperledger/orderer/tls/tlscacerts/$TLS_TLSCACERT_FILE] \
            -e ORDERER_GENERAL_KEEPALIVE_SERVERMININTERVAL=60s \
            -e ORDERER_GENERAL_KEEPALIVE_SERVERINTERVAL=7200s \
            -e ORDERER_GENERAL_KEEPALIVE_SERVERTIMEOUT=20s \
            hyperledger/fabric-orderer:3.0

        CheckContainer "$ORDERER_NAME" "$DOCKER_CONTAINER_WAIT"
        CheckContainerLog "$ORDERER_NAME" "Beginning to serve requests" "$DOCKER_CONTAINER_WAIT"

        echo ""
        echo_info "Orderer $ORDERER started."
    done
done
###############################################################
# Last Tasks
###############################################################


