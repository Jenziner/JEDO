# JEDO HOST - is the Blockchain Network holding the Ledger.
This Document describes the setup of a Hyperledger Fabric (https://www.hyperledger.org/projects/fabric) Network for a test setup 

# Basics
1. Install Fabric according: https://hyperledger-fabric.readthedocs.io/en/latest/install.html
2. Run a Test Network according: https://hyperledger-fabric.readthedocs.io/en/latest/test_network.html


# JEDO-Test-Network
Schema: https://vectr.com/editor/f76ba3ed-411e-42fc-8524-4ba3539b23cd
Domain: test.jedo.btc
IP: 192.168.0.13
Orderer:
- orderer.test.jedo.btc
Org: 
- alps.test.jedo.btc
- mediterranean.test.jedo.btc
Peers:
- luke.alps.test.jedo.btc
- nik.mediterranean.test.jedo.btc
Channel: eu.test.jedo.btc (also af, as, na, sa)


# Setup Basics for UNRAID
1. open terminal in UNRAID
2. download hyperledger fabric samples `wget https://github.com/hyperledger/fabric/releases/download/v2.5.0/hyperledger-fabric-linux-amd64-2.5.0.tar.gz`
3. extract files `tar -xvzf hyperledger-fabric-linux-amd64-2.5.0.tar.gz`
4. create folder `mkdir -p /mnt/user/appdata/fabric/jedo-network/config`
5. move binaries from fabric `mv bin /mnt/user/appdata/fabric/` and `mv config /mnt/user/appdata/fabric/`
6. copy files from [config](https://github.com/Jenziner/JEDO/tree/main/host/jedo-network/config) to *config* folder:
    - **crypto-config.yaml**
    - **configtx.yaml**
7. goto jedo-network `cd /mnt/user/appdata/fabric/jedo-network`
8. create docker network `docker network create fabric-network`
9. inspect Network `docker network inspect fabric-network`


# Create CryptoConfig
1. create certificates `../bin/cryptogen generate --config=./config/crypto-config.yaml --output=./crypto-config/`
2. copy admincerts for alps `cp /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/alps.test.jedo.btc/users/Admin@alps.test.jedo.btc/msp/signcerts/Admin@alps.test.jedo.btc-cert.pem /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/alps.test.jedo.btc/msp/admincerts/`
3. copy admincerts for mediterranean `cp /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/mediterranean.test.jedo.btc/users/Admin@mediterranean.test.jedo.btc/msp/signcerts/Admin@mediterranean.test.jedo.btc-cert.pem /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/mediterranean.test.jedo.btc/msp/admincerts/`
4. double check generated structure and permission


# Setup CouchDB for a Peer (repeat for others)
1. Install couchDB 
  - use xx84 as Port, according to the desired port for the peer)
  - use a spare path for data and config
  - add variables for user (`COUCHDB_USER`, name according peer) and password (`COUCHDB_PASSWORD`, for test its *fabric*))
2. set docker network `docker network connect fabric-network CouchDB-ALPS` or `docker network connect fabric-network CouchDB-MEDITERRANEAN`
3. check Container, goto `http://192.168.0.13:8084/_utils/` and log in with user / pw


# Setup Peer ALPS
1. setup variables
  - `export FABRIC_CFG_PATH=./config`
2. start peer
```
    docker run -d \
    --name nik.alps.test.jedo.btc \
    --network fabric-network \
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/host/jedo-network/src/fabric_logo.png" \
    -e CORE_PEER_ID=nik.alps.test.jedo.btc \
    -e CORE_PEER_LISTENADDRESS=0.0.0.0:8051 \
    -e CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:8052 \
    -e CORE_PEER_ADDRESS=nik.alps.test.jedo.btc:8051 \
    -e CORE_PEER_LOCALMSPID=AlpsOrgMSP \
    -e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/peer/msp \
    -e CORE_PEER_GOSSIP_BOOTSTRAP=127.0.0.1:8051 \
    -e CORE_PEER_GOSSIP_ENDPOINT=0.0.0.0:8051 \
    -e CORE_PEER_GOSSIP_EXTERNALENDPOINT=0.0.0.0:8051 \
    -e CORE_PEER_TLS_ENABLED=true \
    -e CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt \
    -e CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/server.key \
    -e CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt \
    -e CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=192.168.0.13:8084 \
    -e CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=nik.alps.test.jedo.btc \
    -e CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=fabric \
    -v /mnt/user/appdata/fabric/config/core.yaml:/etc/hyperledger/fabric/core.yaml \
    -v /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/alps.test.jedo.btc/peers/nik.alps.test.jedo.btc/msp:/etc/hyperledger/peer/msp \
    -v /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/alps.test.jedo.btc/peers/nik.alps.test.jedo.btc/tls:/etc/hyperledger/fabric/tls \
    -v /mnt/user/appdata/fabric/jedo-network/alps:/var/hyperledger/production \
    -p 8051:8051 \
    -p 8052:8052 \
    hyperledger/fabric-peer:latest
```
3. check Logs `docker logs nik.alps.test.jedo.btc`
4. start cli-nik
```
    docker run -d \
    --name cli-nik \
    --network fabric-network \
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/host/jedo-network/src/fabric_logo.png" \
    -e GOPATH=/opt/gopath \
    -e CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock \
    -e CORE_PEER_ID=cli-nik \
    -e CORE_PEER_ADDRESS=nik.alps.test.jedo.btc:8051 \
    -e CORE_PEER_LOCALMSPID=AlpsOrgMSP \
    -e CORE_PEER_TLS_ENABLED=true \
    -e CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt \
    -e CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt \
    -e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/peer/msp \
    -e FABRIC_LOGGING_SPEC=DEBUG \
    -v /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/alps.test.jedo.btc/peers/nik.alps.test.jedo.btc/tls:/etc/hyperledger/fabric/tls \
    -v /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/alps.test.jedo.btc/users/Admin@alps.test.jedo.btc/msp:/etc/hyperledger/peer/msp \
    -v /mnt/user/appdata/fabric/jedo-network/crypto-config/ordererOrganizations/test.jedo.btc/orderers/orderer.test.jedo.btc/tls:/etc/hyperledger/orderer/tls \
    -v /mnt/user/appdata/fabric/jedo-network/chaincode:/opt/gopath/src/github.com/hyperledger/fabric/chaincode \
    -v /mnt/user/appdata/fabric/jedo-network/ledger:/var/hyperledger/production \
    -v /mnt/user/appdata/fabric/jedo-network:/tmp/jedo-network \
    -v /var/run/docker.sock:/host/var/run/docker.sock \
    -w /opt/gopath/src/github.com/hyperledger/fabric \
    -it \
    hyperledger/fabric-tools:latest
```
5. optinal: check Logs `docker logs cli-nik` (should be empty)
6. optional: run cli-nik sh `docker exec -it cli-nik sh`


# Setup Peer MEDITERRANEAN
1. setup variables
  - `export FABRIC_CFG_PATH=./config`
2. start peer
```
    docker run -d \
    --name luke.mediterranean.test.jedo.btc \
    --network fabric-network \
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/host/jedo-network/src/fabric_logo.png" \
    -e CORE_PEER_ID=luke.mediterranean.test.jedo.btc \
    -e CORE_PEER_LISTENADDRESS=0.0.0.0:9051 \
    -e CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:9052 \
    -e CORE_PEER_ADDRESS=luke.mediterranean.test.jedo.btc:9051 \
    -e CORE_PEER_LOCALMSPID=MediterraneanOrgMSP \
    -e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/peer/msp \
    -e CORE_PEER_GOSSIP_BOOTSTRAP=127.0.0.1:9051 \
    -e CORE_PEER_GOSSIP_ENDPOINT=0.0.0.0:9051 \
    -e CORE_PEER_GOSSIP_EXTERNALENDPOINT=0.0.0.0:9051 \
    -e CORE_PEER_TLS_ENABLED=true \
    -e CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt \
    -e CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/server.key \
    -e CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt \
    -e CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=192.168.0.13:9084 \
    -e CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=luke.mediterranean.test.jedo.btc \
    -e CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=fabric \
    -v /mnt/user/appdata/fabric/config/core.yaml:/etc/hyperledger/fabric/core.yaml \
    -v /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/mediterranean.test.jedo.btc/peers/luke.mediterranean.test.jedo.btc/msp:/etc/hyperledger/peer/msp \
    -v /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/mediterranean.test.jedo.btc/peers/luke.mediterranean.test.jedo.btc/tls:/etc/hyperledger/fabric/tls \
    -v /mnt/user/appdata/fabric/jedo-network/mediterranean:/var/hyperledger/production \
    -p 9051:9051 \
    -p 9052:9052 \
    hyperledger/fabric-peer:latest
```
3. check Logs `docker logs luke.mediterranean.test.jedo.btc`
4. start cli-luke
```
    docker run -d \
    --name cli-luke \
    --network fabric-network \
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/host/jedo-network/src/fabric_logo.png" \
    -e GOPATH=/opt/gopath \
    -e CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock \
    -e CORE_PEER_ID=cli-luke \
    -e CORE_PEER_ADDRESS=luke.mediterranean.test.jedo.btc:9051 \
    -e CORE_PEER_LOCALMSPID=MediterraneanOrgMSP \
    -e CORE_PEER_TLS_ENABLED=true \
    -e CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt \
    -e CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt \
    -e CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/peer/msp \
    -e FABRIC_LOGGING_SPEC=DEBUG \
    -v /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/mediterranean.test.jedo.btc/peers/luke.mediterranean.test.jedo.btc/tls:/etc/hyperledger/fabric/tls \
    -v /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/mediterranean.test.jedo.btc/users/Admin@mediterranean.test.jedo.btc/msp:/etc/hyperledger/peer/msp \
    -v /mnt/user/appdata/fabric/jedo-network/crypto-config/ordererOrganizations/test.jedo.btc/orderers/orderer.test.jedo.btc/tls:/etc/hyperledger/orderer/tls \
    -v /mnt/user/appdata/fabric/jedo-network/chaincode:/opt/gopath/src/github.com/hyperledger/fabric/chaincode \
    -v /mnt/user/appdata/fabric/jedo-network/ledger:/var/hyperledger/production \
    -v /mnt/user/appdata/fabric/jedo-network:/tmp/jedo-network \
    -v /var/run/docker.sock:/host/var/run/docker.sock \
    -w /opt/gopath/src/github.com/hyperledger/fabric \
    -it \
    hyperledger/fabric-tools:latest
```
5. optinal: check Logs `docker logs cli-nik` (should be empty)
6. optional: run cli-nik sh `docker exec -it cli-nik sh`


# Setup ConfigTX (Genesis Block and Channel Config)
1. setup variables
  -  `export FABRIC_CFG_PATH=./config`
2. create genesis block 
```
    ../bin/configtxgen -profile JedoOrdererGenesis -channelID system-channel -outputBlock ./configtx/genesis.block
```
3. create channel config 
```
    ../bin/configtxgen -profile JedoChannel -outputCreateChannelTx ./configtx/eu.tx -channelID eu
```
4. sign channelconfig with alps 
```
    docker exec -it cli-nik peer channel signconfigtx -f /tmp/jedo-network/configtx/eu.tx
```
5. sign channelconfig with mediterranean
```
    docker exec -it cli-luke peer channel signconfigtx -f /tmp/jedo-network/configtx/eu.tx
```


# Setup Orderer
1. start orderer
```
    docker run -d \
    --name orderer.test.jedo.btc \
    --network fabric-network \
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/host/jedo-network/src/fabric_logo.png" \
    -e ORDERER_GENERAL_LISTENADDRESS=0.0.0.0 \
    -e ORDERER_GENERAL_GENESISMETHOD=file \
    -e ORDERER_GENERAL_GENESISFILE=/etc/hyperledger/fabric/genesis.block \
    -e ORDERER_GENERAL_LOCALMSPID=JedoOrgMSP \
    -e ORDERER_GENERAL_LOCALMSPDIR=/etc/hyperledger/orderer/msp \
    -e ORDERER_GENERAL_TLS_ENABLED=true \
    -e ORDERER_GENERAL_TLS_CERTIFICATE=/etc/hyperledger/orderer/tls/server.crt \
    -e ORDERER_GENERAL_TLS_PRIVATEKEY=/etc/hyperledger/orderer/tls/server.key \
    -e ORDERER_GENERAL_TLS_ROOTCAS=[/etc/hyperledger/orderer/tls/ca.crt] \
    -v /mnt/user/appdata/fabric/config/orderer.yaml:/etc/hyperledger/fabric/orderer.yaml \
    -v /mnt/user/appdata/fabric/jedo-network/configtx/genesis.block:/etc/hyperledger/fabric/genesis.block \
    -v /mnt/user/appdata/fabric/jedo-network/crypto-config/ordererOrganizations/test.jedo.btc/orderers/orderer.test.jedo.btc/tls:/etc/hyperledger/orderer/tls \
    -v /mnt/user/appdata/fabric/jedo-network/crypto-config/ordererOrganizations/test.jedo.btc/orderers/orderer.test.jedo.btc/msp:/etc/hyperledger/orderer/msp \
    -v /mnt/user/appdata/fabric/jedo-network/ledger:/var/hyperledger/production \
    -p 7050:7050 \
    hyperledger/fabric-orderer:latest
```
2. check Logs `docker logs orderer.test.jedo.btc`


# Setup a Channel with CLI
1. create channel
```
    docker exec -it cli-nik peer channel create -c eu -f /tmp/jedo-network/configtx/eu.tx -o orderer.test.jedo.btc:7050 --outputBlock /tmp/jedo-network/configtx/eu.block --tls --cafile /etc/hyperledger/orderer/tls/ca.crt
```
2. check Logs `docker logs orderer.test.jedo.btc`
3. join channel as nik@alps
```
    docker exec -it cli-nik peer channel join -b /tmp/jedo-network/configtx/eu.block -o orderer.test.jedo.btc:7050 --tls --cafile /etc/hyperledger/orderer/tls/ca.crt
```
4. join channel as luke@mediterranean
```
    docker exec -it cli-luke peer channel join -b /tmp/jedo-network/configtx/eu.block -o orderer.test.jedo.btc:7050 --tls --cafile /etc/hyperledger/orderer/tls/ca.crt
```


# DEBUG
## Docker
- inspect docker container `docker ps`
- inspect docker network `docker network inspect fabric-network`
- start docker shell `docker exec -it orderer.test.jedo.btc /bin/sh`
- inspect environment variables `docker exec -it nik.alps.test.jedo.btc env`
- list directory (within shell) `ls -l /etc/hyperledger/orderer/config`
- show content (within shell) `cat /etc/hyperledger/fabric/genesisblock` / `cat /var/hyperledger/production/logs/*.log`
- test connection (cli to peer) `docker exec -it cli-nik curl -v nik.alps.test.jedo.btc:8051`


## Configs
- start configtxlator-service `../bin/configtxlator start &`
- decode genesis block and channel configs
```
    curl -X POST --data-binary @./configtx/genesis.block http://localhost:7059/protolator/decode/common.Block > genesis.json
    curl -X POST --data-binary @./configtx/eu.tx http://localhost:7059/protolator/decode/common.ConfigUpdate > channel_tx.json
    curl -X POST --data-binary @./configtx/eu.block http://localhost:7059/protolator/decode/common.Block > channel.json
```


## Test certificates
- cat crypto-config/ordererOrganizations/test.jedo.btc/users/Admin@test.jedo.btc/msp/admincerts/Admin@test.jedo.btc-cert.pem
- cat crypto-config/peerOrganizations/alps.test.jedo.btc/users/Admin@alps.test.jedo.btc/msp/admincerts/Admin@alps.test.jedo.btc-cert.pem
- cat crypto-config/peerOrganizations/mediterranean.test.jedo.btc/users/Admin@mediterranean.test.jedo.btc/msp/admincerts/Admin@mediterranean.test.jedo.btc-cert.pem
- openssl x509 -in crypto-config/ordererOrganizations/test.jedo.btc/users/Admin@test.jedo.btc/msp/admincerts/Admin@test.jedo.btc-cert.pem -text -noout
- openssl x509 -in crypto-config/peerOrganizations/alps.test.jedo.btc/users/Admin@alps.test.jedo.btc/msp/admincerts/Admin@alps.test.jedo.btc-cert.pem -text -noout
- openssl x509 -in crypto-config/peerOrganizations/mediterranean.test.jedo.btc/users/Admin@mediterranean.test.jedo.btc/msp/admincerts/Admin@mediterranean.test.jedo.btc-cert.pem -text -noout
- openssl x509 -in /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/alps.test.jedo.btc/peers/nik.alps.test.jedo.btc/tls/ca.crt -text -noout


## Test network
- `docker exec -it cli-nik peer channel list`
- `docker exec -it cli-nik peer channel getinfo -c eu`
