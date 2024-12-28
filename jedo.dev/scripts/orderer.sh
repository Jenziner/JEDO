###############################################################
#!/bin/bash
#
# This script starts Hyperledger Fabric Orderer
#
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
check_script


###############################################################
# Params
###############################################################
CONFIG_FILE="$SCRIPT_DIR/infrastructure-dev.yaml"
FABRIC_BIN_PATH=$(yq eval '.Fabric.Path' "$CONFIG_FILE")
DOCKER_UNRAID=$(yq eval '.Docker.Unraid' $CONFIG_FILE)
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $CONFIG_FILE)

INFRA_DIR=/etc/hyperledger/infrastructure


get_hosts


###############################################################
# Get Orbis TLS-CA
###############################################################
ORBIS_TOOLS_NAME=$(yq eval ".Orbis.Tools.Name" "$CONFIG_FILE")
ORBIS_TOOLS_CACLI_DIR=/etc/hyperledger/fabric-ca-client

ORBIS_TLS_NAME=$(yq eval ".Orbis.TLS.Name" "$CONFIG_FILE")
ORBIS_TLS_PASS=$(yq eval ".Orbis.TLS.Pass" "$CONFIG_FILE")
ORBIS_TLS_PORT=$(yq eval ".Orbis.TLS.Port" "$CONFIG_FILE")

ORBIS=$(yq eval ".Orbis.Name" "$CONFIG_FILE")
ORBIS_CA_NAME=$(yq eval ".Orbis.CA.Name" "$CONFIG_FILE")
ORBIS_CA_PASS=$(yq eval ".Orbis.CA.Pass" "$CONFIG_FILE")
ORBIS_CA_IP=$(yq eval ".Orbis.CA.IP" "$CONFIG_FILE")
ORBIS_CA_PORT=$(yq eval ".Orbis.CA.Port" "$CONFIG_FILE")


###############################################################
# Params for ager
###############################################################
AGERS=$(yq eval '.Ager[] | .Name' "$CONFIG_FILE")
for AGER in $AGERS; do

    REGNUM=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Administration.Parent" $CONFIG_FILE)
    AFFILIATION_NODE=$REGNUM.${AGER,,}

    ORDERERS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[].Name" $CONFIG_FILE)
    for ORDERER in $ORDERERS; do
        ###############################################################
        # Params
        ###############################################################
        echo ""
        echo_warn "Orderer $ORDERER starting..."
        ORDERER_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Name" $CONFIG_FILE)
        ORDERER_SUBJECT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Subject" $CONFIG_FILE)
        ORDERER_PASS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Pass" $CONFIG_FILE)
        ORDERER_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .IP" $CONFIG_FILE)
        ORDERER_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Port" $CONFIG_FILE)
        ORDERER_CLPORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .ClusterPort" $CONFIG_FILE)
        ORDERER_OPPORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .OpPort" $CONFIG_FILE)
        ORDERER_ADMPORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .AdminPort" $CONFIG_FILE)

        LOCAL_SRV_DIR=${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$ORDERER/
        HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server

        # Extract fields from subject
        C=$(echo "$ORDERER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
        ST=$(echo "$ORDERER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
        L=$(echo "$ORDERER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')
        CN=$(echo "$ORDERER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^CN=/) {sub(/^CN=/, "", $i); print $i}}')
        CSR_NAMES=$(echo "$ORDERER_SUBJECT" | sed 's/,CN=[^,]*//')


        ###############################################################
        # Enroll orderer
        ###############################################################
        echo ""
        echo_info "$ORDERER_NAME registering and enrolling..."
        docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$ORBIS_CA_NAME:$ORBIS_CA_PASS@$ORBIS_CA_NAME:$ORBIS_CA_PORT \
            --home $ORBIS_TOOLS_CACLI_DIR \
            --tls.certfiles tls-root-cert/tls-ca-cert.pem \
            --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$ORBIS_CA_NAME/msp \
            --id.name $ORDERER_NAME --id.secret $ORDERER_PASS --id.type orderer --id.affiliation jedo.root #ToDo Affiliation
        docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$ORDERER_NAME:$ORDERER_PASS@$ORBIS_CA_NAME:$ORBIS_CA_PORT \
            --home $ORBIS_TOOLS_CACLI_DIR \
            --tls.certfiles tls-root-cert/tls-ca-cert.pem \
            --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$ORDERER_NAME/msp \
            --csr.hosts ${ORDERER_NAME},${ORDERER_IP},*.jedo.dev,*.jedo.me \
            --csr.cn $CN --csr.names "$CSR_NAMES"


        # Register and enroll TLS-ID
        docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$ORBIS_TLS_NAME:$ORBIS_TLS_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
            --home $ORBIS_TOOLS_CACLI_DIR \
            --tls.certfiles tls-root-cert/tls-ca-cert.pem \
            --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$ORBIS_TLS_NAME/tls \
            --id.name $ORDERER_NAME --id.secret $ORDERER_PASS --id.type client --id.affiliation jedo.root
        docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$ORDERER_NAME:$ORDERER_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
            --home $ORBIS_TOOLS_CACLI_DIR \
            --tls.certfiles tls-root-cert/tls-ca-cert.pem \
            --enrollment.profile tls \
            --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$ORDERER_NAME/tls \
            --csr.hosts ${ORDERER_NAME},${ORDERER_IP},*.jedo.dev,*.jedo.me \
            --csr.cn $CN --csr.names "$CSR_NAMES"


        # Generating NodeOUs-File
        echo ""
        echo_info "NodeOUs-File writing..."
        CA_CERT_FILE=$(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$ORDERER_NAME/msp/intermediatecerts/*.pem)
        cat <<EOF > ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$ORDERER_NAME/msp/config.yaml
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: intermediatecerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: intermediatecerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: intermediatecerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: intermediatecerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: orderer
EOF

        chmod -R 777 infrastructure


        ###############################################################
        # Write orderer.yaml
        ###############################################################
        TLS_PRIVATEKEY_FILE=$(basename $(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$ORDERER_NAME/tls/keystore/*_sk))
        TLS_TLSCACERT_FILE=$(basename $(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$ORDERER_NAME/tls/tlscacerts/*.pem))
        CLIENT_TLSCACERT_FILE=$(basename $(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/_Admin/tls/tlscacerts/*.pem))

        echo ""
        echo_info "Server-Config for $ORDERER_NAME writing..."
cat <<EOF > $LOCAL_SRV_DIR/orderer.yaml
---
General:
    ListenAddress: $ORDERER_IP
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
        ClientCertificate: 
        ClientPrivateKey: 
        ListenPort: 
        ListenAddress: 
        ServerCertificate: 
        ServerPrivateKey: 
        ReplicationPolicy: consensus
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
        docker run -d \
            --name $ORDERER_NAME \
            --network $DOCKER_NETWORK_NAME \
            --ip $ORDERER_IP \
            $hosts_args \
            --restart=on-failure:1 \
            --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/infrastructure/src/fabric_logo.png" \
            -e FABRIC_LOGGING_SPEC=DEBUG \
            -p $ORDERER_PORT:$ORDERER_PORT \
            -p $ORDERER_OPPORT:$ORDERER_OPPORT \
            -p $ORDERER_CLPORT:$ORDERER_CLPORT \
            -p $ORDERER_ADMPORT:$ORDERER_ADMPORT \
            -v ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$ORDERER_NAME:/etc/hyperledger/fabric \
            -v ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$ORDERER_NAME/msp:/etc/hyperledger/orderer/msp \
            -v ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$ORDERER_NAME/tls:/etc/hyperledger/orderer/tls \
            -v ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$ORDERER_NAME/production:/var/hyperledger/production \
            -v ${PWD}/infrastructure/$ORBIS/$REGNUM/_Admin/tls:/etc/hyperledger/clientadmin/tls \
            hyperledger/fabric-orderer:latest

        CheckContainer "$ORDERER_NAME" "$DOCKER_CONTAINER_WAIT"
        CheckContainerLog "$ORDERER_NAME" "Beginning to serve requests" "$DOCKER_CONTAINER_WAIT"

        echo ""
        echo_ok "Orderer $ORDERER started."
    done
done
###############################################################
# Last Tasks
###############################################################


