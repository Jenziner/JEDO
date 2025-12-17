###############################################################
#!/bin/bash
#
# This script starts Hyperledger Fabric Peer
#
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/params.sh"
check_script


get_hosts


###############################################################
# Get Orbis TLS-CA
###############################################################
ORBIS_TLS_NAME=$(yq eval ".Orbis.TLS.Name" "$CONFIG_FILE")
ORBIS_TLS_PASS=$(yq eval ".Orbis.TLS.Pass" "$CONFIG_FILE")
ORBIS_TLS_PORT=$(yq eval ".Orbis.TLS.Port" "$CONFIG_FILE")
ORBIS_TLS_DIR=/etc/hyperledger/fabric-ca-server
ORBIS_TLS_INFRA=/etc/hyperledger/infrastructure
ORBIS_TLS_CERT=$ORBIS_TLS_INFRA/$ORBIS/$ORBIS_TLS_NAME/ca-cert.pem

ORBIS_MSP_NAME=$(yq eval ".Orbis.MSP.Name" "$CONFIG_FILE")
ORBIS_MSP_PASS=$(yq eval ".Orbis.MSP.Pass" "$CONFIG_FILE")
ORBIS_MSP_IP=$(yq eval ".Orbis.MSP.IP" "$CONFIG_FILE")
ORBIS_MSP_PORT=$(yq eval ".Orbis.MSP.Port" "$CONFIG_FILE")
ORBIS_MSP_DIR=/etc/hyperledger/fabric-ca-server
ORBIS_MSP_INFRA=/etc/hyperledger/infrastructure


###############################################################
# Params for ager
###############################################################
for AGER in $AGERS; do

    REGNUM=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Administration.Parent" $CONFIG_FILE)

    PEERS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[].Name" $CONFIG_FILE)
    for PEER in $PEERS; do
        ###############################################################
        # Params
        ###############################################################
        PEER_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .Name" "$CONFIG_FILE")
        PEER_SUBJECT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .Subject" "$CONFIG_FILE")
        PEER_PASS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .Pass" "$CONFIG_FILE")
        PEER_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .IP" "$CONFIG_FILE")
        PEER_PORT1=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .Port1" "$CONFIG_FILE")
        PEER_PORT2=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .Port2" "$CONFIG_FILE")
        PEER_OPPORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .OpPort" "$CONFIG_FILE")
        PEER_CLI=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .CLI" "$CONFIG_FILE")

        PEER_DB_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .DB.Name" "$CONFIG_FILE")
        PEER_DB_PASS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .DB.Pass" "$CONFIG_FILE")
        PEER_DB_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .DB.IP" "$CONFIG_FILE")
        PEER_DB_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .DB.Port" "$CONFIG_FILE")

        FIRST_ORDERER_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[0].Name" "$CONFIG_FILE")
        FIRST_ORDERER_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[0].Port" "$CONFIG_FILE")

        LOCAL_INFRA_DIR=${PWD}/infrastructure
        LOCAL_SRV_DIR=$LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$PEER

        # Extract fields from subject
        C=$(echo "$PEER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
        ST=$(echo "$PEER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
        L=$(echo "$PEER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')
        CN=$(echo "$PEER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^CN=/) {sub(/^CN=/, "", $i); print $i}}')
        CSR_NAMES=$(echo "$PEER_SUBJECT" | sed 's/,CN=[^,]*//')
        AFFILIATION=$ORBIS.$REGNUM


        ###############################################################
        # Enroll peer @ ORBIS-CA
        ###############################################################
        echo ""
        echo_info "Peer $PEER starting..."
        echo ""
        if [[ $DEBUG == true ]]; then
            echo_debug "Executing with the following:"
            echo_value_debug "- TLS Cert:" "$ORBIS_TLS_CERT"
            echo_value_debug "- Orbis MSP Name:" "$ORBIS_MSP_NAME"
            echo_value_debug "***" "***"
            echo_value_debug "- Peer Name:" "$PEER_NAME"
            echo_value_debug "- MSP Affiliation:" "$AFFILIATION"
        fi
        echo ""
        echo_info "$PEER_NAME registering and enrolling at Orbis-MSP..."

        # Register and enroll MSP-ID
        docker exec -it $ORBIS_MSP_NAME fabric-ca-client register -u https://$ORBIS_MSP_NAME:$ORBIS_MSP_PASS@$ORBIS_MSP_NAME:$ORBIS_MSP_PORT \
            --home $ORBIS_MSP_DIR \
            --tls.certfiles "$ORBIS_TLS_CERT" \
            --mspdir $ORBIS_MSP_INFRA/$ORBIS/$ORBIS_MSP_NAME/msp \
            --id.name $PEER_NAME --id.secret $PEER_PASS --id.type peer --id.affiliation $AFFILIATION
        docker exec -it $ORBIS_MSP_NAME fabric-ca-client enroll -u https://$PEER_NAME:$PEER_PASS@$ORBIS_MSP_NAME:$ORBIS_MSP_PORT \
            --home $ORBIS_MSP_DIR \
            --tls.certfiles "$ORBIS_TLS_CERT" \
            --mspdir $ORBIS_MSP_INFRA/$ORBIS/$REGNUM/$AGER/$PEER_NAME/msp \
            --csr.hosts ${PEER_NAME},${PEER_IP},*.$ORBIS.$ORBIS_ENV \
            --csr.cn $CN --csr.names "$CSR_NAMES"
            
        # Register and enroll TLS-ID
        docker exec -it $ORBIS_TLS_NAME fabric-ca-client register -u https://$ORBIS_TLS_NAME:$ORBIS_TLS_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
            --home $ORBIS_TLS_DIR \
            --tls.certfiles "$ORBIS_TLS_CERT" \
            --mspdir $ORBIS_TLS_INFRA/$ORBIS/$ORBIS_TLS_NAME/tls \
            --id.name $PEER_NAME --id.secret $PEER_PASS --id.type client --id.affiliation $AFFILIATION
        
        docker exec -it $ORBIS_TLS_NAME fabric-ca-client enroll -u https://$PEER_NAME:$PEER_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
            --home $ORBIS_TLS_DIR \
            --tls.certfiles "$ORBIS_TLS_CERT" \
            --mspdir $ORBIS_TLS_INFRA/$ORBIS/$REGNUM/$AGER/$PEER_NAME/tls \
            --csr.hosts ${PEER_NAME},${PEER_IP},*.$ORBIS.$ORBIS_ENV \
            --csr.cn $CN --csr.names "$CSR_NAMES" \
            --enrollment.profile tls

        # Generating NodeOUs-File
        echo ""
        echo_info "NodeOUs-File writing..."
        CA_CERT_FILE=$(ls $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$PEER_NAME/msp/intermediatecerts/*.pem)
        
        cat <<EOF > $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$PEER_NAME/msp/config.yaml
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

        chmod -R 750 infrastructure

        echo ""
        echo_info "$PEER_NAME registered and enrolled."


        ###############################################################
        # Write core.yaml
        ###############################################################
        TLS_PRIVATEKEY_FILE=$(basename $(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_NAME/tls/keystore/*_sk))
        TLS_TLSCACERT_FILE=$(basename $(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_NAME/tls/tlscacerts/*.pem))

        # Get all orderers for config.yaml
        ORDERERS=$(yq eval ".Ager[].Orderers[].Name" $CONFIG_FILE)
        ADDRESS_OVERRIDES=""
        for ORDERER in $ORDERERS; do
            ORDERER_NAME=$(yq eval ".Ager[].Orderers[] | select(.Name == \"$ORDERER\") | .Name" "$CONFIG_FILE")
            ORDERER_PORT=$(yq eval ".Ager[].Orderers[] | select(.Name == \"$ORDERER\") | .Port" "$CONFIG_FILE")
            ADDRESS_OVERRIDES="${ADDRESS_OVERRIDES}
              - from: ${ORDERER_NAME}:${ORDERER_PORT}
                to: ${ORDERER_NAME}:${ORDERER_PORT}
                caCertsFile: /etc/hyperledger/fabric/tls/tlscacerts/${TLS_TLSCACERT_FILE}"
        done

        echo ""
        if [[ $DEBUG == true ]]; then
            echo_debug "Executing with the following:"
            echo_value_debug "- Peer Name:" "$PEER_NAME"
            echo_value_debug "- TLS Cert:" "$TLS_TLSCACERT_FILE"
        fi
        echo_info "Server-Config for $PEER_NAME writing..."
cat <<EOF > $LOCAL_SRV_DIR/core.yaml
---
peer:
  id: $PEER_NAME
  networkId: $DOCKER_NETWORK_NAME
  listenAddress: $PEER_IP:$PEER_PORT1
  chaincodeListenAddress: $PEER_IP:$PEER_PORT2
  chaincodeAddress: $PEER_IP:$PEER_PORT2
  address: $PEER_NAME:$PEER_PORT1
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
    bootstrap: 127.0.0.1:$PEER_PORT1
    useLeaderElection: false
    orgLeader: true
    membershipTrackerInterval: 5s
    endpoint: $PEER_NAME:$PEER_PORT1
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
    externalEndpoint: $PEER_NAME:$PEER_PORT1
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
        - /etc/hyperledger/fabric/tls/tlscacerts/$TLS_TLSCACERT_FILE
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
  localMspId: ${AGER}
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
      couchDBAddress: $PEER_DB_IP:5984
      username: $PEER_DB_NAME
      password: $PEER_DB_PASS
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
        echo ""
        echo_info "CouchDB $PEER_DB_NAME starting..."
        mkdir -p $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$PEER_DB_NAME
        chmod -R 750 $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$PEER_DB_NAME
        docker run -d \
            --user $(id -u):$(id -g) \
            --name $PEER_DB_NAME \
            --network $DOCKER_NETWORK_NAME \
            --ip $PEER_DB_IP \
            $hosts_args \
            --label net.unraid.docker.icon="https://raw.githubusercontent.com/apache/couchdb/main/branding/logo/CouchDB_Logo_192px.png" \
            -e COUCHDB_USER=$PEER_DB_NAME \
            -e COUCHDB_PASSWORD=$PEER_DB_PASS \
            -v $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$PEER_DB_NAME:/opt/couchdb/data \
            -v $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$PEER_DB_NAME:/opt/couchdb/etc/local.d \
            -p $PEER_DB_PORT:5984 \
            --restart unless-stopped \
            couchdb:latest

        CheckContainer "$PEER_DB_NAME" "$DOCKER_CONTAINER_WAIT"
        CheckCouchDB "$PEER_DB_NAME" "$PEER_DB_IP" "$DOCKER_CONTAINER_WAIT"

        #create user-db
        curl -X PUT http://$PEER_DB_IP:5984/_users -u $PEER_DB_NAME:$PEER_DB_PASS


        ###############################################################
        # Peer
        ###############################################################
        echo ""
        echo_info "Peer $PEER_NAME starting..."
        export FABRIC_CFG_PATH=/etc/hyperledger/fabric
        mkdir -p $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$PEER_NAME/production
        chmod -R 750 $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$PEER_NAME/production
        mkdir -p $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/configuration
        chmod -R 750 $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/configuration
        docker run -d \
            --user $(id -u):$(id -g) \
            --name $PEER_NAME \
            --network $DOCKER_NETWORK_NAME \
            --ip $PEER_IP \
            $hosts_args \
            --restart=on-failure:1 \
            --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/infrastructure/src/fabric_logo.png" \
            -p $PEER_PORT1:$PEER_PORT1 \
            -p $PEER_PORT2:$PEER_PORT2 \
            -p $PEER_OPPORT:$PEER_OPPORT \
            -v $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$PEER_NAME:/etc/hyperledger/fabric \
            -v $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$PEER_NAME/production:/var/hyperledger/production \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v $LOCAL_INFRA_DIR:/var/hyperledger/infrastructure \
            -v $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/configuration:/var/hyperledger/configuration \
            -v $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$FIRST_ORDERER_NAME/tls:/var/hyperledger/orderer/tls \
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

        CheckContainer "$PEER_NAME" "$DOCKER_CONTAINER_WAIT"
        CheckContainerLog "$PEER_NAME" "Started peer with ID" "$DOCKER_CONTAINER_WAIT"

        echo ""
        echo_info "Peer $PEER started."
    done
done
###############################################################
# Last Tasks
###############################################################


