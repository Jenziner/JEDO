###############################################################
#!/bin/bash
#
# This script starts ager peer docker container.
#
###############################################################
set -euo pipefail

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTDIR/utils.sh"

log_section "JEDO-Ecosystem - new Ager - Peer starting..."


###############################################################
# Usage / Argument-Handling
###############################################################
export LOGLEVEL="INFO"
export DEBUG=false
export FABRIC_CA_SERVER_LOGLEVEL="info"       # critical, fatal, warning, info, debug
export FABRIC_CA_CLIENT_LOGLEVEL="info"       # critical, fatal, warning, info, debug
export FABRIC_LOGGING_SPEC="INFO"             # FATAL, PANIC, ERROR, WARNING, INFO, DEBUG
export CORE_CHAINCODE_LOGGING_LEVEL="INFO"    # CRITICAL, ERROR, WARNING, NOTICE, INFO, DEBUG

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
      FABRIC_CA_SERVER_LOGLEVEL="debug"
      FABRIC_CA_CLIENT_LOGLEVEL="debug"
      FABRIC_LOGGING_SPEC="DEBUG"
      CORE_CHAINCODE_LOGGING_LEVEL="DEBUG"
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

PEERS=$(yq eval ".Ager.Peers[].Name" $INFRA_CONFIGFILE)

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

log_info "Peer starting ..."

# Start docker network if not running
if ! docker network ls --format '{{.Name}}' | grep -wq "$DOCKER_NETWORK"; then
    docker network create --subnet=$DOCKER_SUBNET --gateway=$DOCKER_GATEWAY "$DOCKER_NETWORK"
fi
docker network inspect "$DOCKER_NETWORK"

# Run per peer
for PEER in $PEERS; do
    ###############################################################
    # Config
    ###############################################################
    AGER_PEER_NAME=$(yq eval ".Ager.Peers[] | select(.Name == \"$PEER\") | .Name" $INFRA_CONFIGFILE)
    AGER_PEER_NAME=$AGER_PEER_NAME.$AGER_NAME.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD
    AGER_PEER_NAME_FORMATTED="${AGER_PEER_NAME//./-}"
    AGER_PEER_IP=$(yq eval ".Ager.Peers[] | select(.Name == \"$PEER\") | .IP" ${INFRA_CONFIGFILE})
    AGER_PEER_PORT1=$(yq eval ".Ager.Peers[] | select(.Name == \"$PEER\") | .Port1" ${INFRA_CONFIGFILE})
    AGER_PEER_PORT2=$(yq eval ".Ager.Peers[] | select(.Name == \"$PEER\") | .Port2" ${INFRA_CONFIGFILE})
    AGER_PEER_OPPORT=$(yq eval ".Ager.Peers[] | select(.Name == \"$PEER\") | .OpPort" ${INFRA_CONFIGFILE})
    AGER_PEER_SECRET=$(yq eval ".Ager.Peers[] | select(.Name == \"$PEER\") | .Secret" ${CERTS_CONFIGFILE})
    AGER_PEER_CSR="C=XX,ST=$ORBIS_ENV,L=$REGNUM_NAME,O=$AGER_NAME"

    AGER_PEER_DB_NAME=$(yq eval ".Ager.Peers[] | select(.Name == \"$PEER\") | .DB.Name" "$INFRA_CONFIGFILE")
    AGER_PEER_DB_IP=$(yq eval ".Ager.Peers[] | select(.Name == \"$PEER\") | .DB.IP" "$INFRA_CONFIGFILE")
    AGER_PEER_DB_PORT=$(yq eval ".Ager.Peers[] | select(.Name == \"$PEER\") | .DB.Port" "$INFRA_CONFIGFILE")

    LOCAL_CAROOTS_DIR="${SCRIPTDIR}/../../infrastructure/tls-ca-roots"
    HOST_CAROOTS_DIR="/etc/hyperledger/tls-ca-roots"

    LOCAL_SRV_DIR="${SCRIPTDIR}/../../infrastructure/servers/${AGER_PEER_NAME}"
    HOST_SRV_DIR="/etc/hyperledger/fabric-ca-server"

    LOCAL_CONFIG_DIR="${SCRIPTDIR}/../../configuration"
    LOCAL_DB_DIR="${SCRIPTDIR}/../../infrastructure/servers/${AGER_PEER_DB_NAME}"


    ###############################################################
    # Debug Logging
    ###############################################################
    log_debug "Peer Info:" "$AGER_PEER_NAME:$AGER_PEER_SECRET@$AGER_PEER_IP:$AGER_PEER_PORT1"
    log_debug "Peer DB Info:" "$AGER_PEER_DB_NAME:$AGER_PEER_SECRET@$AGER_PEER_DB_IP:$AGER_PEER_DB_PORT"
    log_debug "Peer CSR:" "$AGER_PEER_CSR"
    log_debug "Local Server Dir:" "$LOCAL_SRV_DIR"
    log_debug "Host Server Dir:" "$HOST_SRV_DIR"
    log_debug "Local Config Dir:" "$LOCAL_CONFIG_DIR"
    log_debug "Local DB Dir:" "$LOCAL_DB_DIR"


    ###############################################################
    # RUN
    ###############################################################
    # Enroll Ager-Peer
    log_info "$AGER_PEER_NAME enrolling server certificates..."

    # Enroll @ Regnum TLS-CA
    docker run --rm \
      --network "${DOCKER_NETWORK}" \
      -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
      -v "${LOCAL_SRV_DIR}:${HOST_SRV_DIR}" \
      -e FABRIC_MSP_CLIENT_HOME="${HOST_SRV_DIR}" \
      -e FABRIC_CA_CLIENT_LOGLEVEL=${FABRIC_CA_CLIENT_LOGLEVEL} \
      hyperledger/fabric-ca:latest \
      fabric-ca-client enroll \
          -u https://$AGER_PEER_NAME:$AGER_PEER_SECRET@$REGNUM_TLS_NAME:$REGNUM_TLS_PORT \
          --tls.certfiles ${HOST_CAROOTS_DIR}/${REGNUM_TLS_NAME}.pem \
          --mspdir ${HOST_SRV_DIR}/tls \
          --enrollment.profile tls \
          --csr.hosts ${AGER_PEER_NAME},${AGER_PEER_IP} \
          --csr.cn $AGER_PEER_NAME --csr.names "$AGER_PEER_CSR"
    log_debug "TLS-Peer enrolled"

    # Enroll @ Regnum MSP-CA
    docker run --rm \
      --network "${DOCKER_NETWORK}" \
      -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
      -v "${LOCAL_SRV_DIR}:${HOST_SRV_DIR}" \
      -e FABRIC_MSP_CLIENT_HOME="${HOST_SRV_DIR}" \
      -e FABRIC_CA_CLIENT_LOGLEVEL=${FABRIC_CA_CLIENT_LOGLEVEL} \
      hyperledger/fabric-ca:latest \
      fabric-ca-client enroll \
          -u https://$AGER_PEER_NAME:$AGER_PEER_SECRET@$REGNUM_MSP_NAME:$REGNUM_MSP_PORT \
          --tls.certfiles ${HOST_CAROOTS_DIR}/${REGNUM_TLS_NAME}.pem \
          --mspdir ${HOST_SRV_DIR}/msp \
          --csr.hosts ${AGER_PEER_NAME},${AGER_PEER_IP} \
          --csr.cn $AGER_PEER_NAME --csr.names "$AGER_PEER_CSR"
    log_debug "MSP-Peer enrolled"

    # Generating NodeOUs-File
    log_debug "NodeOUs-File writing..."
    PEER_CERT_FILE=$(ls $LOCAL_SRV_DIR/msp/cacerts/*.pem)
    log_debug "CA Cert-File:" "$PEER_CERT_FILE"
    cat <<EOF > $LOCAL_SRV_DIR/msp/config.yaml
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: intermediatecerts/$(basename $PEER_CERT_FILE)
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: intermediatecerts/$(basename $PEER_CERT_FILE)
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: intermediatecerts/$(basename $PEER_CERT_FILE)
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: intermediatecerts/$(basename $PEER_CERT_FILE)
    OrganizationalUnitIdentifier: orderer
EOF
    log_debug "NodeOUs-Files saved"

    # Write config: core.yaml
    TLS_PRIVATEKEY_FILE=$(basename $(ls $LOCAL_SRV_DIR/tls/keystore/*_sk))
    TLS_TLSCACERT_FILE=$(basename $(ls $LOCAL_SRV_DIR/tls/tlscacerts/*.pem))
    CLIENT_TLSCACERT_FILE=$(basename $(ls $LOCAL_SRV_DIR/tls/tlsintermediatecerts/*.pem))

    # Get all orderers for config.yaml
    ORDERERS=$(yq eval ".Ager.Orderers[].Name" $INFRA_CONFIGFILE)
    ADDRESS_OVERRIDES=""
    for ORDERER in $ORDERERS; do
        ORDERER_NAME=$(yq eval ".Ager.Orderers[] | select(.Name == \"$ORDERER\") | .Name" "$INFRA_CONFIGFILE")
        ORDERER_PORT=$(yq eval ".Ager.Orderers[] | select(.Name == \"$ORDERER\") | .Port" "$INFRA_CONFIGFILE")
        ADDRESS_OVERRIDES="${ADDRESS_OVERRIDES}
          - from: ${ORDERER_NAME}:${ORDERER_PORT}
            to: ${ORDERER_NAME}:${ORDERER_PORT}
            caCertsFile: /etc/hyperledger/fabric/tls/tlscacerts/${TLS_TLSCACERT_FILE}"
    done

    log_debug "Peer Config writing..."
    log_debug "TLS Cert:" "$TLS_TLSCACERT_FILE"
cat <<EOF > $LOCAL_SRV_DIR/core.yaml
---
peer:
  id: $AGER_PEER_NAME
  networkId: $DOCKER_NETWORK
  listenAddress: $AGER_PEER_IP:$AGER_PEER_PORT1
  chaincodeListenAddress: $AGER_PEER_IP:$AGER_PEER_PORT2
  chaincodeAddress: $AGER_PEER_IP:$AGER_PEER_PORT2
  address: $AGER_PEER_NAME:$AGER_PEER_PORT1
  addressAutoDetect: false
  gateway:
    enabled: true
    endorsementTimeout: 30s
    broadcastTimeout: 30s
    dialTimeout: 2m
  keepalive:
    interval: 7200s
    timeout: 20s
    minInterval: 60s
    client:
      interval: 60s
      timeout: 20s
    deliveryClient:
      interval: 60s
      timeout: 20s
  gossip:
    bootstrap: 127.0.0.1:$AGER_PEER_PORT1
    useLeaderElection: false
    orgLeader: true
    membershipTrackerInterval: 5s
    endpoint: $AGER_PEER_NAME:$AGER_PEER_PORT1
    maxBlockCountToStore: 10
    maxPropagationBurstLatency: 10ms
    maxPropagationBurstSize: 10
    propagateIterations: 1
    propagatePeerNum: 3
    pullInterval: 4s
    pullPeerNum: 3
    requestStateInfoInterval: 4s
    publishStateInfoInterval: 4s
    stateInfoRetentionInterval:
    publishCertPeriod: 10s
    skipBlockVerification: false
    dialTimeout: 3s
    connTimeout: 2s
    recvBuffSize: 20
    sendBuffSize: 200
    digestWaitTime: 1s
    requestWaitTime: 1500ms
    responseWaitTime: 2s
    aliveTimeInterval: 5s
    aliveExpirationTimeout: 25s
    reconnectInterval: 25s
    maxConnectionAttempts: 120
    msgExpirationFactor: 20
    externalEndpoint: $AGER_PEER_NAME:$AGER_PEER_PORT1
    election:
      startupGracePeriod: 15s
      membershipSampleInterval: 1s
      leaderAliveThreshold: 10s
      leaderElectionDuration: 5s
    pvtData:
      pullRetryThreshold: 60s
      transientstoreMaxBlockRetention: 20000
      pushAckTimeout: 3s
      btlPullMargin: 10
      reconcileBatchSize: 10
      reconcileSleepInterval: 1m
      reconciliationEnabled: true
      skipPullingInvalidTransactionsDuringCommit: false
      implicitCollectionDisseminationPolicy:
        requiredPeerCount: 0
        maxPeerCount: 1
    state:
      enabled: false
      checkInterval: 10s
      responseTimeout: 3s
      batchSize: 10
      blockBufferSize: 20
      maxRetries: 3
  tls:
    enabled: true
    clientAuthRequired: false
    cert:
      file: /etc/hyperledger/fabric/tls/signcerts/cert.pem
    key:
      file: /etc/hyperledger/fabric/tls/keystore/$TLS_PRIVATEKEY_FILE
    rootcert:
      file: /etc/hyperledger/fabric/tls/tlscacerts/$TLS_TLSCACERT_FILE
    clientRootCAs:
      files:
        - /etc/hyperledger/fabric/tls/tlsintermediatecerts/$CLIENT_TLSCACERT_FILE
    clientKey:
      file:
    clientCert:
      file:
  authentication:
    timewindow: 15m
  fileSystemPath: /var/hyperledger/production
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
      SoftwareVerify:
      Immutable:
      AltID:
      KeyIds:
  mspConfigPath: msp
  localMspId: ${AGER_NAME}
  client:
    connTimeout: 3s
  deliveryclient:
    blockGossipEnabled: false
    reconnectTotalTimeThreshold: 3600s
    connTimeout: 3s
    reConnectBackoffThreshold: 3600s
    blockCensorshipTimeoutKey: 30s
    minimalReconnectInterval: 100ms
    addressOverrides:${ADDRESS_OVERRIDES}
    policy: cluster
  localMspType: bccsp
  profile:
    enabled: false
    listenAddress: 0.0.0.0:6060
  handlers:
    authFilters:
      - name: DefaultAuth
      - name: ExpirationCheck # This filter checks identity x509 certificate expiration
    decorators:
      - name: DefaultDecorator
    endorsers:
      escc:
        name: DefaultEndorsement
        library:
    validators:
      vscc:
        name: DefaultValidation
        library:
  validatorPoolSize:
  discovery:
    enabled: true
    authCacheEnabled: true
    authCacheMaxSize: 1000
    authCachePurgeRetentionRatio: 0.75
    orgMembersAllowedAccess: false
  limits:
    concurrency:
      endorserService: 2500
      deliverService: 2500
      gatewayService: 500
  maxRecvMsgSize: 104857600
  maxSendMsgSize: 104857600
vm:
  endpoint: unix:///var/run/docker.sock
  docker:
    tls:
      enabled: false
      ca:
        file: docker/ca.crt
      cert:
        file: docker/tls.crt
      key:
        file: docker/tls.key
    attachStdout: false
    hostConfig:
      NetworkMode: host
      Dns:
        # - 192.168.0.1
      LogConfig:
        Type: json-file
        Config:
          max-size: "50m"
          max-file: "5"
      Memory: 2147483648
chaincode:
  id:
    path:
    name:
  builder: \$(DOCKER_NS)/fabric-ccenv:\$(TWO_DIGIT_VERSION)
  pull: false
  golang:
    runtime: \$(DOCKER_NS)/fabric-baseos:\$(TWO_DIGIT_VERSION)
    dynamicLink: false
  java:
    runtime: \$(DOCKER_NS)/fabric-javaenv:\$(TWO_DIGIT_VERSION)
  node:
    runtime: \$(DOCKER_NS)/fabric-nodeenv:\$(TWO_DIGIT_VERSION)
  externalBuilders:
    - name: ccaas_builder
      path: /opt/hyperledger/ccaas_builder
      propagateEnvironment:
        - CHAINCODE_AS_A_SERVICE_BUILDER_CONFIG
  installTimeout: 300s
  startuptimeout: 300s
  executetimeout: 300s
  mode: net
  keepalive: 0
  system:
    _lifecycle: enable
    cscc: enable
    lscc: enable
    qscc: enable
  logging:
    level: debug
    shim: warning
    format: "%{color}%{time:2006-01-02 15:04:05.000 MST} [%{module}] %{shortfunc} -> %{level:.4s} %{id:03x}%{color:reset} %{message}"
ledger:
  blockchain:
  state:
    stateDatabase: CouchDB
    totalQueryLimit: 100000
    couchDBConfig:
      couchDBAddress: $AGER_PEER_DB_IP:5984
      username: $AGER_PEER_DB_NAME
      password: $AGER_PEER_SECRET
      maxRetries: 3
      maxRetriesOnStartup: 10
      requestTimeout: 35s
      internalQueryLimit: 1000
      maxBatchUpdateSize: 1000
      createGlobalChangesDB: false
      cacheSize: 64
  history:
    enableHistoryDatabase: true
  pvtdataStore:
    collElgProcMaxDbBatchSize: 5000
    collElgProcDbBatchesInterval: 1000
    deprioritizedDataReconcilerInterval: 60m
    purgeInterval: 100
    purgedKeyAuditLogging: true
  snapshots:
    rootDir: /var/hyperledger/production/snapshots
operations:
  listenAddress: 127.0.0.1:9443
  tls:
    enabled: false
    cert:
      file:
    key:
      file:
    clientAuthRequired: false
    clientRootCAs:
      files: []
metrics:
  provider: disabled
  statsd:
    network: udp
    address: 127.0.0.1:8125
    writeInterval: 10s
    prefix:
EOF


    ###############################################################
    # CouchDB
    ###############################################################
    log_info "CouchDB $AGER_PEER_DB_NAME starting..."
    mkdir -p $LOCAL_DB_DIR
    chmod -R 750 $LOCAL_DB_DIR
    docker run -d \
        --user $(id -u):$(id -g) \
        --name $AGER_PEER_DB_NAME \
        --network $DOCKER_NETWORK \
        --ip $AGER_PEER_DB_IP \
        --label net.unraid.docker.icon="https://raw.githubusercontent.com/apache/couchdb/main/branding/logo/CouchDB_Logo_192px.png" \
        -e COUCHDB_USER=$AGER_PEER_DB_NAME \
        -e COUCHDB_PASSWORD=$AGER_PEER_SECRET \
        -v $LOCAL_DB_DIR:/opt/couchdb/data \
        -v $LOCAL_DB_DIR:/opt/couchdb/etc/local.d \
        -p $AGER_PEER_DB_PORT:5984 \
        --restart unless-stopped \
        couchdb:latest

    CheckContainer "$AGER_PEER_DB_NAME" "$DOCKER_WAIT"
    CheckCouchDB "$AGER_PEER_DB_NAME" "$AGER_PEER_DB_IP" "$DOCKER_WAIT"

    #create user-db
    curl -X PUT http://$AGER_PEER_DB_IP:5984/_users -u $AGER_PEER_DB_NAME:$AGER_PEER_SECRET


    ###############################################################
    # Peer
    ###############################################################
    log_info "Peer $AGER_PEER_NAME starting..."
    export FABRIC_CFG_PATH=/etc/hyperledger/fabric
    mkdir -p $LOCAL_SRV_DIR/production
    chmod -R 750 $LOCAL_SRV_DIR/production
    mkdir -p $LOCAL_CONFIG_DIR
    chmod -R 750 $LOCAL_CONFIG_DIR
    docker run -d \
        --user $(id -u):$(id -g) \
        --name $AGER_PEER_NAME \
        --network $DOCKER_NETWORK \
        --ip $AGER_PEER_IP \
        --restart=on-failure:1 \
        --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/infrastructure/src/fabric_logo.png" \
        -p $AGER_PEER_PORT1:$AGER_PEER_PORT1 \
        -p $AGER_PEER_PORT2:$AGER_PEER_PORT2 \
        -p $AGER_PEER_OPPORT:$AGER_PEER_OPPORT \
        -v $LOCAL_SRV_DIR:/etc/hyperledger/fabric \
        -v $LOCAL_SRV_DIR/production:/var/hyperledger/production \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v $LOCAL_CONFIG_DIR:/var/hyperledger/configuration \
        -e FABRIC_LOGGING_SPEC=$FABRIC_LOGGING_SPEC \
        -e FABRIC_CFG_PATH=/etc/hyperledger/fabric \
        -e CORE_VM_ENDPOINT=unix:///var/run/docker.sock \
        -e CORE_PEER_TLS_ENABLED=true \
        -e CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/signcerts/cert.pem \
        -e CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/keystore/$TLS_PRIVATEKEY_FILE \
        -e CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/tlscacerts/$TLS_TLSCACERT_FILE \
        -e CORE_PEER_TLS_CLIENTROOTCAS_FILES=/etc/hyperledger/fabric/tls/tlscacerts/$TLS_TLSCACERT_FILE \
        -e CORE_PEER_KEEPALIVE_CLIENT_INTERVAL=60s \
        -e CORE_PEER_KEEPALIVE_CLIENT_TIMEOUT=20s \
        -e CORE_PEER_KEEPALIVE_MININTERVAL=60s \
        hyperledger/fabric-peer:3.0

    CheckContainer "$AGER_PEER_NAME" "$DOCKER_WAIT"
    CheckContainerLog "$AGER_PEER_NAME" "Started peer with ID" "$DOCKER_WAIT"


    log_ok "Peer $AGER_PEER_NAME started."
done

chmod -R 750 $SCRIPTDIR/../../infrastructure

# chmod -R 777 /mnt/user/appdata/jedo/demo/infrastructure
