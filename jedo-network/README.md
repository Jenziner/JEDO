# JEDO NETWORK - is the Blockchain Network Configuration of JEDO.
This Document describes the setup of a Hyperledger Fabric (https://www.hyperledger.org/projects/fabric) Network for a test setup 

# Basics
1. Install Fabric according: https://hyperledger-fabric.readthedocs.io/en/latest/install.html
2. Run a Test Network according: https://hyperledger-fabric.readthedocs.io/en/latest/test_network.html


# JEDO-Test-Network
- ![Network-Schema](network.drawio.svg)
## Network 
- Test - jedo.tst - 192.168.0.13
- Production - jedo.me
## Channel
- eu.jedo.me
- as.jedo.me
- af.jedo.me
- na.jedo.me
- sa.jedo.me
## Organisation
- JenzinerOrg - jenziner.jedo.me
## Certification Authority
- CA1 - alps
- CA2 - mediterranean
## Orderer
- orderer.jenziner.jedo.me:7050
## Peers
- peer0.jenziner.jedo.me:8051/52 | peer0db:8084
- peer1.jenziner.jedo.me:9050/52 | peer1db:9084
## SmartContract
- Fabric Token SDK Chaincode
## Application
- JEDO-WALLET
## CLI
- cli.peer0.jenziner.jedo.me
- cli.peer1.jenziner.jedo.me
## Token-Network
-           alps.eu.jedo.me (Token)
-       aud.alps.eu.jedo.me (Auditor)
-       iss.alps.eu.jedo.me (Issuer)
-      worb.alps.eu.jedo.me (Owner)
-   do@worb.alps.eu.jedo.me (User)
-   ra@worb.alps.eu.jedo.me (User)
-    biglen.alps.eu.jedo.me (Owner)
- lu@biglen.alps.eu.jedo.me (User)
- is@biglen.alps.eu.jedo.me (User)


# Setup Basics for UNRAID
1. open terminal in UNRAID
2. download hyperledger fabric samples `wget https://github.com/hyperledger/fabric/releases/download/v2.5.0/hyperledger-fabric-linux-amd64-2.5.0.tar.gz`
3. extract files `tar -xvzf hyperledger-fabric-linux-amd64-2.5.0.tar.gz`
4. create folder `mkdir -p /mnt/user/appdata/fabric/jedo-network/config`
5. move binaries from fabric `mv bin /mnt/user/appdata/fabric/` and `mv config /mnt/user/appdata/fabric/`
6. copy files from [config](https://github.com/Jenziner/JEDO/tree/main/jedo-network/config) to *config* folder:
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


# ALT: Create Hyperledger Fabric CA
1. create folder `mkdir -p /mnt/user/appdata/fabric-ca`
2. get CA docker image `docker pull hyperledger/fabric-ca:latest`
3. start CA
```
    docker run -d \
    --name jedo-ca.jedo.btc \
    --network fabric-network \
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/jedo-network/src/fabric_logo.png" \
    -v /mnt/user/appdata/fabric-ca:/etc/hyperledger/fabric-ca \
    -p 7054:7054 \
    hyperledger/fabric-ca:latest \
    sh -c 'fabric-ca-server start -b admin:Test1 -d'
```
4. check logs `docker logs jedo-ca.jedo.btc`
5. start fabric-ca-client 
```
    docker run -it --network fabric-network \
    --name jedo-ca-client \
    -v /mnt/user/appdata/fabric-ca/crypto-config:/etc/hyperledger/fabric-ca-server \
    hyperledger/fabric-ca:latest bash
```
6. do stuff:
6.1. enroll an admin `fabric-ca-client enroll -u http://admin:Test1@jedo-ca.jedo.btc:7054`
6.1. register new user `fabric-ca-client register --id.name nik --id.secret Test1 --id.type client -u http://jedo-ca.jedo.btc:7054`
6.3. enroll new user `fabric-ca-client enroll -u http://nik:Test1@jedo-ca.jedo.btc:7054 -M /etc/hyperledger/fabric-ca-server/nik`
6.4. in spare unraid terminal update permissions `chmod -R 755 /mnt/user/appdata/fabric-ca/crypto-config/nik`
6.5. copy msp files for use as orderer
6.5.1. copy root ca-cert `cp /etc/hyperledger/fabric-ca-server/nik/cacerts/jedo-ca-jedo-btc-7054.pem crypto-config/ordererOrganizations/example.com/orderers/orderer1.example.com/msp/cacerts/`
6.5.2. copy private key `cp /etc/hyperledger/fabric-ca-server/nik/keystore/<private_key>.pem crypto-config/ordererOrganizations/example.com/orderers/orderer1.example.com/msp/keystore/`
6.5.3. copy public key `cp /etc/hyperledger/fabric-ca-server/nik/signcerts/cert.pem crypto-config/ordererOrganizations/example.com/orderers/orderer1.example.com/msp/signcerts/`
6.6. enroll tls `fabric-ca-client enroll -u http://orderer1:password@<tls-ca-url>:<tls-ca-port> --csr.hosts orderer1.example.com -M /etc/hyperledger/fabric-ca-server/tls/orderer1`
6.6.1. copy TLS-cert `cp /etc/hyperledger/fabric-ca-server/tls/orderer1/signcerts/cert.pem crypto-config/ordererOrganizations/example.com/orderers/orderer1.example.com/tls/server.crt`
6.6.2. copy private key `cp /etc/hyperledger/fabric-ca-server/tls/orderer1/keystore/<private_key>.pem crypto-config/ordererOrganizations/example.com/orderers/orderer1.example.com/tls/server.key`
6.6.3. copy TLS-CA-root `cp /etc/hyperledger/fabric-ca-server/tls/orderer1/cacerts/<tls-root-cert>.pem crypto-config/ordererOrganizations/example.com/orderers/orderer1.example.com/tls/ca.crt`


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
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/jedo-network/src/fabric_logo.png" \
    -e CORE_VM_ENDPOINT=unix:///var/run/docker.sock \
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
    -v /mnt/user/appdata/fabric/jedo-network/production/alps:/var/hyperledger/production \
    -v /var/run/docker.sock:/var/run/docker.sock \
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
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/jedo-network/src/fabric_logo.png" \
    -e GOPATH=/opt/gopath \
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
    -v /mnt/user/appdata/fabric/jedo-network/production:/var/hyperledger/production \
    -v /mnt/user/appdata/fabric/jedo-network:/tmp/jedo-network \
    -v /var/run/docker.sock:/var/run/docker.sock \
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
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/jedo-network/src/fabric_logo.png" \
    -e CORE_VM_ENDPOINT=unix:///var/run/docker.sock \
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
    -v /mnt/user/appdata/fabric/jedo-network/production/mediterranean:/var/hyperledger/production \
    -v /var/run/docker.sock:/var/run/docker.sock \
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
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/jedo-network/src/fabric_logo.png" \
    -e GOPATH=/opt/gopath \
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
    -v /mnt/user/appdata/fabric/jedo-network/production:/var/hyperledger/production \
    -v /mnt/user/appdata/fabric/jedo-network:/tmp/jedo-network \
    -v /var/run/docker.sock:/var/run/docker.sock \
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
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/jedo-network/src/fabric_logo.png" \
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
    -v /mnt/user/appdata/fabric/jedo-network/production:/var/hyperledger/production \
    -p 7050:7050 \
    hyperledger/fabric-orderer:latest
```
2. check Logs `docker logs orderer.test.jedo.btc`


# Setup a Channel with CLI
1. check UTF-8 compatibility
```
    iconv -f UTF-8 -t UTF-8 ./config/configtx.yaml -o ./config/configtx.yaml
```
2. create channel
```
    docker exec -it cli-nik peer channel create -c eu -f /tmp/jedo-network/configtx/eu.tx -o orderer.test.jedo.btc:7050 --outputBlock /tmp/jedo-network/configtx/eu.block --tls --cafile /etc/hyperledger/orderer/tls/ca.crt
```
3. check Logs `docker logs orderer.test.jedo.btc`
4. join channel as nik@alps
```
    docker exec -it cli-nik peer channel join -b /tmp/jedo-network/configtx/eu.block -o orderer.test.jedo.btc:7050 --tls --cafile /etc/hyperledger/orderer/tls/ca.crt
```
5. join channel as luke@mediterranean
```
    docker exec -it cli-luke peer channel join -b /tmp/jedo-network/configtx/eu.block -o orderer.test.jedo.btc:7050 --tls --cafile /etc/hyperledger/orderer/tls/ca.crt
```


# Install Chaincode
1. package chaincode on alps
```
    docker exec -it cli-nik peer lifecycle chaincode package nft_chaincode.tar.gz --path /opt/gopath/src/github.com/hyperledger/fabric/chaincode/nft_chaincode --label nft_chaincode_1
    docker exec -it cli-nik peer lifecycle chaincode package fab_sdk_tcc.tar.gz --path /opt/gopath/src/github.com/hyperledger/fabric/chaincode/fab_sdk_tcc --label fab_sdk_tcc_1
    docker exec -it cli-nik peer lifecycle chaincode package fab_sdk_tcc.tar.gz --path /opt/gopath/src/github.com/hyperledger/fabric/chaincode/fab_sdk_tcc --lang external --label fab_sdk_tcc_1
```
2. install chaincode on alps
```
    docker exec -it cli-nik peer lifecycle chaincode install nft_chaincode.tar.gz
    docker exec -it cli-nik peer lifecycle chaincode install fab_sdk_tcc.tar.gz
```
3. package chaincode on mediterranean
```
    docker exec -it cli-luke peer lifecycle chaincode package nft_chaincode.tar.gz --path /opt/gopath/src/github.com/hyperledger/fabric/chaincode/nft_chaincode --label nft_chaincode_1
    docker exec -it cli-luke peer lifecycle chaincode package fab_sdk_tcc.tar.gz --path /opt/gopath/src/github.com/hyperledger/fabric/chaincode/fab_sdk_tcc --label fab_sdk_tcc_1
```
4. install chaincode on mediterranean
```
    docker exec -it cli-luke peer lifecycle chaincode install nft_chaincode.tar.gz
    docker exec -it cli-luke peer lifecycle chaincode install fab_sdk_tcc.tar.gz
```
5. optional on any peer: query package ID
```
    docker exec -it cli-nik peer lifecycle chaincode queryinstalled
```
6. approve chaincode on alps
```
    docker exec -it cli-nik peer lifecycle chaincode approveformyorg \
    --channelID eu \
    --name nft_chaincode \
    --version 1 \
    --sequence 1 \
    --package-id nft_chaincode_1:939752b1bc590ab464232edff8e170f1c9d711f1355ce3252c08580ce2dcf7bc \
    --orderer orderer.test.jedo.btc:7050 \
    --tls \
    --cafile /etc/hyperledger/orderer/tls/ca.crt \
    --peerAddresses nik.alps.test.jedo.btc:8051 --tlsRootCertFiles /etc/hyperledger/fabric/tls/ca.crt
```
7. approve chaincode on mediterranean
```
    docker exec -it cli-luke peer lifecycle chaincode approveformyorg \
    --channelID eu \
    --name nft_chaincode \
    --version 1 \
    --sequence 1 \
    --package-id nft_chaincode_1:939752b1bc590ab464232edff8e170f1c9d711f1355ce3252c08580ce2dcf7bc \
    --orderer orderer.test.jedo.btc:7050 \
    --tls \
    --cafile /etc/hyperledger/orderer/tls/ca.crt \
    --peerAddresses luke.mediterranean.test.jedo.btc:9051 --tlsRootCertFiles /etc/hyperledger/fabric/tls/ca.crt
```
8. optional on any peer: check approval state
```
    docker exec -it cli-nik peer lifecycle chaincode checkcommitreadiness \
    --channelID eu \
    --name nft_chaincode \
    --version 1 \
    --sequence 1 \
    --tls \
    --cafile /etc/hyperledger/orderer/tls/ca.crt
```
9. commit chaincode
```
    docker exec -it cli-nik peer lifecycle chaincode commit \
    --channelID eu \
    --name nft_chaincode \
    --version 1 \
    --sequence 1 \
    --orderer orderer.test.jedo.btc:7050 \
    --tls \
    --cafile /etc/hyperledger/orderer/tls/ca.crt \
    --peerAddresses nik.alps.test.jedo.btc:8051 \
    --tlsRootCertFiles /tmp/jedo-network/crypto-config/peerOrganizations/alps.test.jedo.btc/peers/nik.alps.test.jedo.btc/tls/ca.crt \
    --peerAddresses luke.mediterranean.test.jedo.btc:9051 \
    --tlsRootCertFiles /tmp/jedo-network/crypto-config/peerOrganizations/mediterranean.test.jedo.btc/peers/luke.mediterranean.test.jedo.btc/tls/ca.crt
```
10. optional on any peer: query installation
```
    docker exec -it cli-nik peer lifecycle chaincode querycommitted --channelID eu --name nft_chaincode
```
11. test chaincode - write NFT
```
    docker exec -it cli-nik peer chaincode invoke \
    --channelID eu \
    --name nft_chaincode \
    --orderer orderer.test.jedo.btc:7050 \
    --tls \
    --cafile /etc/hyperledger/orderer/tls/ca.crt \
    --peerAddresses nik.alps.test.jedo.btc:8051 \
    --tlsRootCertFiles /tmp/jedo-network/crypto-config/peerOrganizations/alps.test.jedo.btc/peers/nik.alps.test.jedo.btc/tls/ca.crt \
    --peerAddresses luke.mediterranean.test.jedo.btc:9051 \
    --tlsRootCertFiles /tmp/jedo-network/crypto-config/peerOrganizations/mediterranean.test.jedo.btc/peers/luke.mediterranean.test.jedo.btc/tls/ca.crt \
    -c '{"function":"CreateNFT","Args":["44297237-10f1-4a79-bf88-40a68e313a06", "Jenziner", "{\"balance\":1000, \"otp\":[\"123456\", \"456789\", \"789123\"]}"]}' \
    --waitForEvent
```
12. test chaincode - read NFT
```
    docker exec -it cli-nik peer chaincode query \
    --channelID eu \
    --name nft_chaincode \
    --peerAddresses nik.alps.test.jedo.btc:8051 \
    --tlsRootCertFiles /tmp/jedo-network/crypto-config/peerOrganizations/alps.test.jedo.btc/peers/nik.alps.test.jedo.btc/tls/ca.crt \
    -c '{"function":"ReadNFT","Args":["44297237-10f1-4a79-bf88-40a68e313a06"]}'
```


# Update Channel
docker exec -it cli-nik peer channel fetch config config_block.pb -o orderer.test.jedo.btc:7050 -c eu --tls --cafile /etc/hyperledger/orderer/tls/ca.crt
docker exec -it cli-nik configtxlator proto_decode --input config_block.pb --type common.Block --output config_block.json
docker cp cli-nik:/opt/gopath/src/github.com/hyperledger/fabric/config_block.json /mnt/user/appdata/fabric/jedo-network/config_block.json
jq .data.data[0].payload.data.config /mnt/user/appdata/fabric/jedo-network/config_block.json > /mnt/user/appdata/fabric/jedo-network/config.json
do configtx.yaml changes in config.json
docker cp /mnt/user/appdata/fabric/jedo-network/config.json cli-nik:/opt/gopath/src/github.com/hyperledger/fabric/config.json
docker exec -it cli-nik configtxlator proto_encode --input config.json --type common.Config --output modified_config.pb
docker exec -it cli-nik configtxlator compute_update --channel_id eu --original config_block.pb --updated modified_config.pb --output config_update.pb
docker exec -it cli-nik configtxlator proto_decode --input config_update.pb --type common.ConfigUpdate --output config_update.json
docker exec -it cli-nik bash
echo '{"payload":{"header":{"channel_header":{"channel_id":"eu", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' | jq . > config_update_in_envelope.json
configtxlator proto_encode --input config_update_in_envelope.json --type common.Envelope --output config_update_in_envelope.pb
Check: ls -l config_update_in_envelope.pb


docker exec -it cli-nik peer channel update -f config_update_in_envelope.pb -c eu -o orderer.test.jedo.btc:7050 --tls --cafile /etc/hyperledger/orderer/tls/ca.crt
docker exec -it cli-nik peer channel fetch config config_block.pb -o orderer.test.jedo.btc:7050 -c eu --tls --cafile /etc/hyperledger/orderer/tls/ca.crt
docker exec -it cli-nik configtxlator proto_decode --input config_block.pb --type common.Block --output config_block.json



docker cp cli-nik:/opt/gopath/src/github.com/hyperledger/fabric/config_update.json /mnt/user/appdata/fabric/jedo-network/config_update.json
docker cp /mnt/user/appdata/fabric/jedo-network/config.json cli-nik:/opt/gopath/src/github.com/hyperledger/fabric/config.json








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

## Remove Channel
rm -f ./configtx/eu.tx ./configtx/eu.pb ./configtx/eu.block
docker exec -it nik.alps.test.jedo.btc bash
rm -rf /var/hyperledger/production/ledgersData/chains/chains/eu
exit
docker exec -it luke.mediterranean.test.jedo.btc bash
rm -rf /var/hyperledger/production/ledgersData/chains/chains/eu
exit
docker exec -it orderer.test.jedo.btc bash
rm -rf /var/hyperledger/production/orderer/chains/eu
exit



# Fabric Token SDK
- start swagger UI `docker run -p 8080:8080 -e URL=/swagger.yaml -v /home/jenziner/Entwicklung/fabric/fabric-samples/token-sdk/swagger.yaml:/usr/share/nginx/html/swagger.yaml swaggerapi/swagger-ui` --> http://localhost:8080

