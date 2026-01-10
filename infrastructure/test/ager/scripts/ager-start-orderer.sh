###############################################################
#!/bin/bash
#
# This script starts ager orderer docker container.
#
###############################################################
set -euo pipefail

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTDIR/utils.sh"

log_section "JEDO-Ecosystem - new Ager - Orderer starting..."


###############################################################
# Usage / Argument-Handling
###############################################################
export LOGLEVEL="INFO"
export DEBUG=false
export FABRIC_CA_SERVER_LOGLEVEL="info"

AGER_CERTS_CONFIG=""
AGER_INFRA_CONFIG=""

usage() {
  log_error "Usage: $0 <config-certs-filename> <config-infra-filename> [--debug]" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)
      DEBUG=true
      LOGLEVEL="DEBUG"
      FABRIC_CA_SERVER_LOGLEVEL="DEBUG"
      shift
      ;;
    -*)
      log_error "Unkown Option: $1" >&2
      usage
      ;;
    *)
      # first non-Option-Argument = CA_TYPE
      if [[ -z "$AGER_CERTS_CONFIG" ]]; then
        AGER_CERTS_CONFIG="$1"
      elif [[ -z "$AGER_INFRA_CONFIG" ]]; then
        AGER_INFRA_CONFIG="$1"
      else
        log_error "To many arguments: '$1'" >&2
        usage
      fi
      shift
      ;;
  esac
done

if [[ -z "$AGER_CERTS_CONFIG" ]] || [[ -z "$AGER_INFRA_CONFIG" ]]; then
  usage
fi


###############################################################
# Config
###############################################################
CERTS_CONFIGFILE="${SCRIPTDIR}/../config/$AGER_CERTS_CONFIG"
INFRA_CONFIGFILE="${SCRIPTDIR}/../config/$AGER_INFRA_CONFIG"

DOCKER_NETWORK=$(yq eval '.Docker.Network' "${INFRA_CONFIGFILE}")
DOCKER_SUBNET=$(yq eval '.Docker.Subnet' "${INFRA_CONFIGFILE}")
DOCKER_GATEWAY=$(yq eval '.Docker.Gateway' "${INFRA_CONFIGFILE}")
DOCKER_WAIT=$(yq eval '.Docker.Wait' "${INFRA_CONFIGFILE}")

ORBIS_NAME=$(yq eval '.Orbis.Name' "${INFRA_CONFIGFILE}")
ORBIS_ENV=$(yq eval '.Orbis.Env' "${INFRA_CONFIGFILE}")
ORBIS_TLD=$(yq eval '.Orbis.Tld' "${INFRA_CONFIGFILE}")

REGNUM_NAME=$(yq eval '.Regnum.Name' "${INFRA_CONFIGFILE}")
REGNUM_TLS_NAME=$(yq eval '.Regnum.tls.Name' "${INFRA_CONFIGFILE}")
REGNUM_TLS_NAME=$REGNUM_TLS_NAME.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD
REGNUM_TLS_PORT=$(yq eval '.Regnum.tls.Port' "${INFRA_CONFIGFILE}")
REGNUM_MSP_NAME=$(yq eval '.Regnum.msp.Name' "${INFRA_CONFIGFILE}")
REGNUM_MSP_NAME=$REGNUM_MSP_NAME.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD
REGNUM_MSP_PORT=$(yq eval '.Regnum.msp.Port' "${INFRA_CONFIGFILE}")

AGER_NAME=$(yq eval '.Ager.Name' "${INFRA_CONFIGFILE}")

ORDERERS=$(yq eval ".Ager.Orderers[].Name" $INFRA_CONFIGFILE)

AFFILIATION=$ORBIS_NAME.$REGNUM_NAME.$AGER_NAME


###############################################################
# Debug Logging
###############################################################
log_debug "Docker Network:" "${DOCKER_NETWORK} (${DOCKER_SUBNET})"
log_debug "Orbis Info:" "$ORBIS_NAME - $ORBIS_ENV - $ORBIS_TLD"
log_debug "Regnum Info:" "$REGNUM_TLS_NAME:$REGNUM_TLS_PORT / $REGNUM_MSP_NAME:$REGNUM_MSP_PORT"


###############################################################
# RUN
###############################################################
$SCRIPTDIR/prereq.sh

log_info "Orderer starting ..."

# Start docker network if not running
if ! docker network ls --format '{{.Name}}' | grep -wq "$DOCKER_NETWORK"; then
    docker network create --subnet=$DOCKER_SUBNET --gateway=$DOCKER_GATEWAY "$DOCKER_NETWORK"
fi
docker network inspect "$DOCKER_NETWORK"

# Run per orderer
for ORDERER in $ORDERERS; do
    ###############################################################
    # Config
    ###############################################################
    AGER_ORDERER_NAME=$(yq eval ".Ager.Orderers[] | select(.Name == \"$ORDERER\") | .Name" $INFRA_CONFIGFILE)
    AGER_ORDERER_NAME=$AGER_ORDERER_NAME.$AGER_NAME.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD
    AGER_ORDERER_NAME_FORMATTED="${AGER_ORDERER_NAME//./-}"
    AGER_ORDERER_IP=$(yq eval ".Ager.Orderers[] | select(.Name == \"$ORDERER\") | .IP" ${INFRA_CONFIGFILE})
    AGER_ORDERER_PORT=$(yq eval ".Ager.Orderers[] | select(.Name == \"$ORDERER\") | .Port" ${INFRA_CONFIGFILE})
    AGER_ORDERER_CLUSTERPORT=$(yq eval ".Ager.Orderers[] | select(.Name == \"$ORDERER\") | .ClusterPort" ${INFRA_CONFIGFILE})
    AGER_ORDERER_OPPORT=$(yq eval ".Ager.Orderers[] | select(.Name == \"$ORDERER\") | .OpPort" ${INFRA_CONFIGFILE})
    AGER_ORDERER_ADMINPORT=$(yq eval ".Ager.Orderers[] | select(.Name == \"$ORDERER\") | .AdminPort" ${INFRA_CONFIGFILE})
    AGER_ORDERER_SECRET=$(yq eval ".Ager.Orderers[] | select(.Name == \"$ORDERER\") | .Secret" ${CERTS_CONFIGFILE})
    AGER_ORDERER_CSR="C=XX,ST=$ORBIS_ENV,L=$REGNUM_NAME,O=$AGER_NAME"

    LOCAL_CAROOTS_DIR="${SCRIPTDIR}/../../infrastructure/tls-ca-roots"
    HOST_CAROOTS_DIR="/etc/hyperledger/tls-ca-roots"

    LOCAL_SRV_DIR="${SCRIPTDIR}/../../infrastructure/servers/${AGER_ORDERER_NAME}"
    HOST_SRV_DIR="/etc/hyperledger/fabric-ca-server"


    ###############################################################
    # Debug Logging
    ###############################################################
    log_debug "Orderer Info:" "$AGER_ORDERER_NAME:$AGER_ORDERER_SECRET@$AGER_ORDERER_IP:$AGER_ORDERER_PORT"
    log_debug "Orderer CSR:" "$AGER_ORDERER_CSR"
    log_debug "Local Server Dir:" "$LOCAL_SRV_DIR"
    log_debug "Host Server Dir:" "$HOST_SRV_DIR"


    ###############################################################
    # RUN
    ###############################################################
    # Enroll Ager-Orderer
    log_info "$AGER_ORDERER_NAME enrolling server certificates..."

    # Enroll @ Regnum TLS-CA
    docker run --rm \
      --network "${DOCKER_NETWORK}" \
      -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
      -v "${LOCAL_SRV_DIR}:${HOST_SRV_DIR}" \
      -e FABRIC_MSP_CLIENT_HOME="${HOST_SRV_DIR}" \
      -e FABRIC_MSP_SERVER_LOGLEVEL=${LOGLEVEL} \
      hyperledger/fabric-ca:latest \
      fabric-ca-client enroll \
          -u https://$AGER_ORDERER_NAME:$AGER_ORDERER_SECRET@$REGNUM_TLS_NAME:$REGNUM_TLS_PORT \
          --tls.certfiles ${HOST_CAROOTS_DIR}/${REGNUM_TLS_NAME}.pem \
          --mspdir ${HOST_SRV_DIR}/tls \
          --enrollment.profile tls \
          --csr.hosts ${AGER_ORDERER_NAME},${AGER_ORDERER_IP} \
          --csr.cn $AGER_ORDERER_NAME --csr.names "$AGER_ORDERER_CSR"
    log_debug "TLS-Orderer enrolled"

    # Enroll @ Regnum MSP-CA
    docker run --rm \
      --network "${DOCKER_NETWORK}" \
      -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
      -v "${LOCAL_SRV_DIR}:${HOST_SRV_DIR}" \
      -e FABRIC_MSP_CLIENT_HOME="${HOST_SRV_DIR}" \
      -e FABRIC_MSP_SERVER_LOGLEVEL=${LOGLEVEL} \
      hyperledger/fabric-ca:latest \
      fabric-ca-client enroll \
          -u https://$AGER_ORDERER_NAME:$AGER_ORDERER_SECRET@$REGNUM_MSP_NAME:$REGNUM_MSP_PORT \
          --tls.certfiles ${HOST_CAROOTS_DIR}/${REGNUM_TLS_NAME}.pem \
          --mspdir ${HOST_SRV_DIR}/msp \
          --csr.hosts ${AGER_ORDERER_NAME},${AGER_ORDERER_IP} \
          --csr.cn $AGER_ORDERER_NAME --csr.names "$AGER_ORDERER_CSR"
    log_debug "MSP-Orderer enrolled"

    # Generating NodeOUs-File
    log_debug "NodeOUs-File writing..."
    ORDERER_CERT_FILE=$(ls $LOCAL_SRV_DIR/msp/cacerts/*.pem)
    log_debug "CA Cert-File:" "$ORDERER_CERT_FILE"
    cat <<EOF > $LOCAL_SRV_DIR/msp/config.yaml
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: intermediatecerts/$(basename $ORDERER_CERT_FILE)
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: intermediatecerts/$(basename $ORDERER_CERT_FILE)
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: intermediatecerts/$(basename $ORDERER_CERT_FILE)
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: intermediatecerts/$(basename $ORDERER_CERT_FILE)
    OrganizationalUnitIdentifier: orderer
EOF
    log_debug "NodeOUs-Files saved"

    # Write config: orderer.yaml
    TLS_PRIVATEKEY_FILE=$(basename $(ls $LOCAL_SRV_DIR/tls/keystore/*_sk))
    TLS_TLSCACERT_FILE=$(basename $(ls $LOCAL_SRV_DIR/tls/tlscacerts/*.pem))
    CLIENT_TLSCACERT_FILE=$(basename $(ls $LOCAL_SRV_DIR/tls/tlsintermediatecerts/*.pem))

    log_debug "Orderer Config writing..."
    log_debug "TLS Cert:" "$TLS_TLSCACERT_FILE"
cat <<EOF > $LOCAL_SRV_DIR/orderer.yaml
---
General:
    ListenAddress: 0.0.0.0
    ListenPort: $AGER_ORDERER_PORT
    TLS:
        Enabled: true
        PrivateKey: /etc/hyperledger/orderer/tls/keystore/$TLS_PRIVATEKEY_FILE
        Certificate: /etc/hyperledger/orderer/tls/signcerts/cert.pem
        RootCAs:
          - /etc/hyperledger/orderer/tls/tlscacerts/$TLS_TLSCACERT_FILE
        ClientAuthRequired: false
        ClientRootCAs:
          - /etc/hyperledger/orderer/tls/tlsintermediatecerts/$CLIENT_TLSCACERT_FILE
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
        ListenPort: $AGER_ORDERER_CLUSTERPORT
        ListenAddress: 0.0.0.0
        ServerCertificate: /etc/hyperledger/orderer/tls/signcerts/cert.pem
        ServerPrivateKey: /etc/hyperledger/orderer/tls/keystore/$TLS_PRIVATEKEY_FILE
        RootCAs:
          - /etc/hyperledger/orderer/tls/tlscacerts/$TLS_TLSCACERT_FILE
    LocalMSPDir: /etc/hyperledger/orderer/msp
    LocalMSPID: ${AGER_NAME}
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
    ListenAddress: $AGER_ORDERER_IP:$AGER_ORDERER_ADMINPORT
    TLS:
        Enabled: true
        Certificate: /etc/hyperledger/orderer/tls/signcerts/cert.pem
        PrivateKey: /etc/hyperledger/orderer/tls/keystore/$TLS_PRIVATEKEY_FILE
        RootCAs: /etc/hyperledger/orderer/tls/tlscacerts/$TLS_TLSCACERT_FILE
        ClientAuthRequired: true
        ClientRootCAs: [/etc/hyperledger/orderer/tls/tlsintermediatecerts/$CLIENT_TLSCACERT_FILE]
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
    log_debug "- Docker Container" "$AGER_ORDERER_NAME"
    log_debug "- Local Dir:" "$LOCAL_SRV_DIR"
    log_info "Docker Container $AGER_ORDERER_NAME starting..."
    export FABRIC_CFG_PATH=/etc/hyperledger/fabric
    mkdir -p $LOCAL_SRV_DIR/production
    chmod -R 750 $LOCAL_SRV_DIR/production
    docker run -d \
        --user $(id -u):$(id -g) \
        --name $AGER_ORDERER_NAME \
        --network $DOCKER_NETWORK \
        --ip $AGER_ORDERER_IP \
        --restart=on-failure:1 \
        --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/infrastructure/src/fabric_logo.png" \
        -p $AGER_ORDERER_PORT:$AGER_ORDERER_PORT \
        -p $AGER_ORDERER_OPPORT:$AGER_ORDERER_OPPORT \
        -p $AGER_ORDERER_CLUSTERPORT:$AGER_ORDERER_CLUSTERPORT \
        -p $AGER_ORDERER_ADMINPORT:$AGER_ORDERER_ADMINPORT \
        -v $LOCAL_SRV_DIR:/etc/hyperledger/fabric \
        -v $LOCAL_SRV_DIR/msp:/etc/hyperledger/orderer/msp \
        -v $LOCAL_SRV_DIR/tls:/etc/hyperledger/orderer/tls \
        -v $LOCAL_SRV_DIR/production:/var/hyperledger/production/orderer \
        -e FABRIC_LOGGING_SPEC=$LOGLEVEL \
        -e ORDERER_GENERAL_LISTENADDRESS=0.0.0.0 \
        -e ORDERER_GENERAL_LISTENPORT=$AGER_ORDERER_PORT \
        -e ORDERER_GENERAL_TLS_ENABLED=true \
        -e ORDERER_GENERAL_TLS_PRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/$TLS_PRIVATEKEY_FILE \
        -e ORDERER_GENERAL_TLS_CERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem \
        -e ORDERER_GENERAL_TLS_ROOTCAS=[/etc/hyperledger/orderer/tls/tlscacerts/$TLS_TLSCACERT_FILE] \
        -e ORDERER_GENERAL_CLUSTER_LISTENADDRESS=0.0.0.0 \
        -e ORDERER_GENERAL_CLUSTER_LISTENPORT=$AGER_ORDERER_CLUSTERPORT \
        -e ORDERER_GENERAL_CLUSTER_CLIENTCERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem \
        -e ORDERER_GENERAL_CLUSTER_CLIENTPRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/$TLS_PRIVATEKEY_FILE \
        -e ORDERER_GENERAL_CLUSTER_ROOTCAS=[/etc/hyperledger/orderer/tls/tlscacerts/$TLS_TLSCACERT_FILE] \
        -e ORDERER_GENERAL_KEEPALIVE_SERVERMININTERVAL=60s \
        -e ORDERER_GENERAL_KEEPALIVE_SERVERINTERVAL=7200s \
        -e ORDERER_GENERAL_KEEPALIVE_SERVERTIMEOUT=20s \
        hyperledger/fabric-orderer:3.0

    CheckContainer "$AGER_ORDERER_NAME" "$DOCKER_WAIT"
    CheckContainerLog "$AGER_ORDERER_NAME" "Beginning to serve requests" "$DOCKER_WAIT"

    log_ok "Orderer $AGER_ORDERER_NAME started."
done

chmod -R 750 $SCRIPTDIR/../../infrastructure

# chmod -R 777 /mnt/user/appdata/jedo/demo/infrastructure
