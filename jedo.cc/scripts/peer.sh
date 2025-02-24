###############################################################
#!/bin/bash
#
# This script starts Hyperledger Fabric Peer
#
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
check_script


###############################################################
# Params
###############################################################
CONFIG_FILE="$SCRIPT_DIR/infrastructure-cc.yaml"
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

    PEERS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[].Name" $CONFIG_FILE)
    for PEER in $PEERS; do
        ###############################################################
        # Params
        ###############################################################
        echo ""
        echo_warn "Peer $PEER starting..."
        PEER_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .Name" $CONFIG_FILE)
        PEER_SUBJECT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .Subject" $CONFIG_FILE)
        PEER_PASS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .Pass" $CONFIG_FILE)
        PEER_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .IP" $CONFIG_FILE)
        PEER_PORT1=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .Port1" $CONFIG_FILE)
        PEER_PORT2=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .Port2" $CONFIG_FILE)
        PEER_OPPORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .OpPort" $CONFIG_FILE)
        PEER_CLI=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .CLI" $CONFIG_FILE)

        PEER_DB_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .DB.Name" $CONFIG_FILE)
        PEER_DB_PASS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .DB.Pass" $CONFIG_FILE)
        PEER_DB_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .DB.IP" $CONFIG_FILE)
        PEER_DB_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .DB.Port" $CONFIG_FILE)

        FIRST_ORDERER_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[0].Name" $CONFIG_FILE)
        FIRST_ORDERER_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[0].Port" $CONFIG_FILE)

        LOCAL_SRV_DIR=${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER
        HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server

 
        # Extract fields from subject
        C=$(echo "$PEER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
        ST=$(echo "$PEER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
        L=$(echo "$PEER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')
        CN=$(echo "$PEER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^CN=/) {sub(/^CN=/, "", $i); print $i}}')
        CSR_NAMES=$(echo "$PEER_SUBJECT" | sed 's/,CN=[^,]*//')
        AFFILIATION=$ORBIS.$REGNUM


        ###############################################################
        # Enroll peer @ orbis
        ###############################################################
        echo ""
        echo_info "$PEER_NAME registering and enrolling..."
        docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$ORBIS_CA_NAME:$ORBIS_CA_PASS@$ORBIS_CA_NAME:$ORBIS_CA_PORT \
            --home $ORBIS_TOOLS_CACLI_DIR \
            --tls.certfiles tls-root-cert/tls-ca-cert.pem \
            --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$ORBIS_CA_NAME/msp \
            --id.name $PEER_NAME --id.secret $PEER_PASS --id.type peer --id.affiliation $AFFILIATION
        docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$PEER_NAME:$PEER_PASS@$ORBIS_CA_NAME:$ORBIS_CA_PORT \
            --home $ORBIS_TOOLS_CACLI_DIR \
            --tls.certfiles tls-root-cert/tls-ca-cert.pem \
            --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_NAME/msp \
            --csr.hosts ${PEER_NAME},${PEER_IP},*.jedo.cc,*.jedo.me \
            --csr.cn $CN --csr.names "$CSR_NAMES"


        # Register and enroll TLS-ID
        docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$ORBIS_TLS_NAME:$ORBIS_TLS_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
            --home $ORBIS_TOOLS_CACLI_DIR \
            --tls.certfiles tls-root-cert/tls-ca-cert.pem \
            --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$ORBIS_TLS_NAME/tls \
            --id.name $PEER_NAME --id.secret $PEER_PASS --id.type client --id.affiliation $AFFILIATION
        docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$PEER_NAME:$PEER_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
            --home $ORBIS_TOOLS_CACLI_DIR \
            --tls.certfiles tls-root-cert/tls-ca-cert.pem \
            --enrollment.profile tls \
            --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_NAME/tls \
            --csr.hosts ${PEER_NAME},${PEER_IP},*.jedo.cc,*.jedo.me \
            --csr.cn $CN --csr.names "$CSR_NAMES"


        # Generating NodeOUs-File
        echo ""
        echo_info "NodeOUs-File writing..."
        CA_CERT_FILE=$(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_NAME/msp/intermediatecerts/*.pem)
        cat <<EOF > ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_NAME/msp/config.yaml
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
        # Write core.yaml
        ###############################################################
        TLS_PRIVATEKEY_FILE=$(basename $(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_NAME/tls/keystore/*_sk))
        TLS_TLSCACERT_FILE=$(basename $(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_NAME/tls/tlscacerts/*.pem))

        echo ""
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
  mspConfigPath: /etc/hyperledger/peer/msp
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
    addressOverrides:
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
  builder: "$(DOCKER_NS)/fabric-ccenv:$(TWO_DIGIT_VERSION)"
  pull: false
  golang:
    runtime: "$(DOCKER_NS)/fabric-baseos:$(TWO_DIGIT_VERSION)"
    dynamicLink: false
  java:
    runtime: "$(DOCKER_NS)/fabric-javaenv:2.5"
  node:
    runtime: "$(DOCKER_NS)/fabric-nodeenv:2.5"
  externalBuilders:
    - name: ccaas_builder
      path: /opt/hyperledger/ccaas_builder
      propagateEnvironment:
        - CHAINCODE_AS_A_SERVICE_BUILDER_CONFIG
  installTimeout: 300s
  startuptimeout: 300s
  executetimeout: 30s
  mode: net
  keepalive: 0
  system:
    _lifecycle: enable
    cscc: enable
    lscc: enable
    qscc: enable
  logging:
    level: info
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
        docker run -d \
        --name $PEER_DB_NAME \
        --network $DOCKER_NETWORK_NAME \
        --ip $PEER_DB_IP \
        $hosts_args \
        --label net.unraid.docker.icon="https://raw.githubusercontent.com/apache/couchdb/main/branding/logo/CouchDB_Logo_192px.png" \
        -e COUCHDB_USER=$PEER_DB_NAME \
        -e COUCHDB_PASSWORD=$PEER_DB_PASS \
        -v ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_DB_NAME:/opt/couchdb/data \
        -v ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_DB_NAME:/opt/couchdb/etc/local.d \
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
        docker run -d \
            --name $PEER_NAME \
            --network $DOCKER_NETWORK_NAME \
            --ip $PEER_IP \
            $hosts_args \
            --restart=on-failure:1 \
            --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/infrastructure/src/fabric_logo.png" \
            -p $PEER_PORT1:$PEER_PORT1 \
            -p $PEER_PORT2:$PEER_PORT2 \
            -p $PEER_OPPORT:$PEER_OPPORT \
            -v ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_NAME:/etc/hyperledger/fabric \
            -v ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_NAME/msp:/etc/hyperledger/peer/msp \
            -v ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_NAME/tls:/etc/hyperledger/fabric/tls \
            -v ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$FIRST_ORDERER_NAME/tls:/etc/hyperledger/orderer/tls \
            -v ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_NAME/production:/var/hyperledger/production \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -e CORE_VM_ENDPOINT=unix:///var/run/docker.sock \
            hyperledger/fabric-peer:latest

        CheckContainer "$PEER_NAME" "$DOCKER_CONTAINER_WAIT"
        CheckContainerLog "$PEER_NAME" "Started peer with ID" "$DOCKER_CONTAINER_WAIT"


        ###############################################################
        # Peer CLI
        ###############################################################
        echo ""
        echo_info "CLI  cli.$PEER_NAME starting..."

        export TLS_CA_ROOT_CERT=$(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/_Admin/tls/tlscacerts/*.pem)
        export FABRIC_CFG_PATH=/etc/hyperledger/fabric

        docker run -d \
            --name cli.$PEER_NAME \
            --network $DOCKER_NETWORK_NAME \
            --ip $PEER_CLI \
            $hosts_args \
            --restart=on-failure:1 \
            --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/infrastructure/src/fabric_cli_logo.png" \
            -v ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_NAME/msp:/etc/hyperledger/peer/msp \
            -v ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_NAME/tls:/etc/hyperledger/fabric/tls \
            -v ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$FIRST_ORDERER_NAME/tls:/etc/hyperledger/orderer/tls \
            -v ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_NAME/production:/var/hyperledger/production \
            -v ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$PEER_NAME:/opt/gopath/src/github.com/hyperledger/fabric/chaincode \
            -v ${PWD}/infrastructure:/var/hyperledger/infrastructure \
            -v ${PWD}/configuration:/var/hyperledger/configuration \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -w /opt/gopath/src/github.com/hyperledger/fabric \
            -e GOPATH=/opt/gopath \
            -e CORE_PEER_ID=cli.$PEER_NAME \
            -e CORE_PEER_ADDRESS=$PEER_NAME:$PEER_PORT1 \
            -e CORE_PEER_LOCALMSPID=${AGER} \
            -e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/peer/msp \
            -e CORE_PEER_TLS_ENABLED=true \
            -e CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/signcerts/cert.pem \
            -e CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/tlscacerts/$TLS_TLSCACERT_FILE \
            -e CORE_ORDERER_ADDRESS=$FIRST_ORDERER_NAME:$FIRST_ORDERER_PORT \
            -e CORE_ORDERER_TLS_ENABLED=true \
            -e CORE_ORDERER_TLS_CERT_FILE=/etc/hyperledger/orderer/tls/signcerts/cert.pem \
            -e FABRIC_LOGGING_SPEC=DEBUG \
            -it \
            hyperledger/fabric-tools:latest

        CheckContainer "cli.$PEER_NAME" "$DOCKER_CONTAINER_WAIT"


        echo_error "TEST: Channel List"
        docker exec -it cli.$PEER_NAME /usr/local/bin/peer channel list --orderer $FIRST_ORDERER_NAME:$FIRST_ORDERER_PORT \
        --tls --cafile $TLS_CA_ROOT_CERT

# TEMP: continue work when channel exists
        # echo_error "TEST: Channel Fetch"
        # docker exec -it cli.$PEER_NAME /usr/local/bin/peer channel fetch config genesis_block.pb --channelID $REGNUM --orderer $FIRST_ORDERER_NAME:$FIRST_ORDERER_PORT \
        # --tls --cafile /var/hyperledger/infrastructure/$ORBIS_NAME/$REGNUM/_Organization/msp/tlscacerts/$ORG_TLSCACERT_FILE
        
#        bash peer channel list

# 2024-12-09 17:07:47.133 UTC 0032 WARN [msp] validateIdentity -> Could not validate identity: could not validate identity's OUs: certifiersIdentifier does not match: 
# [jedo(86F565D2037187C9) peer(86F565D2037187C9) root(86F565D2037187C9)], 
# MSP: [ea] (certificate subject=CN=peer1.ea.jedo.dev,OU=jedo+OU=peer+OU=root,O=ea,ST=dev,C=jd issuer=CN=ca.jedo.dev,O=JEDO,L=orbis,ST=dev,C=XX serialnumber=480824256698855961778230763129674567072230188588)

# 2024-12-09 17:07:47.135 UTC 0033 WARN [orderer.common.msgprocessor] Apply -> SigFilter evaluation failed error="implicit policy evaluation failed - 0 sub-policies were satisfied, but this policy requires 1 of the 'Readers' sub-policies to be satisfied" 
# ConsensusState=STATE_NORMAL policyName=/Channel/Readers signingIdentity=
# "(mspid=ea subject=CN=peer1.ea.jedo.dev,OU=jedo+OU=peer+OU=root,O=ea,ST=dev,C=jd issuer=CN=ca.jedo.dev,O=JEDO,L=orbis,ST=dev,C=XX serialnumber=480824256698855961778230763129674567072230188588)"

# 2024-12-09 17:07:47.135 UTC 0034 WARN [common.deliver] deliverBlocks -> [channel: ea.jedo.dev] Client 172.25.2.53:43990 is not authorized: implicit policy evaluation failed - 
# 0 sub-policies were satisfied, but this policy requires 1 of the 'Readers' sub-policies to be satisfied: permission denied

        echo ""
        echo_ok "Peer $PEER started."
    done
done
###############################################################
# Last Tasks
###############################################################


# ###############################################################
# # sign channelconfig
# ###############################################################
# echo ""
# echo_info "Channelconfig $CHANNEL with $PEER_NAME signing..."
# docker exec -it cli.$PEER_NAME peer channel signconfigtx -f /etc/hyperledger/config/$CHANNEL.tx
# echo_ok "Channelconfig $CHANNEL with $PEER_NAME signed."

