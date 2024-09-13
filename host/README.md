# JEDO HOST - is the Blockchain Network holding the Ledger.
This Document describes the setup of a Hyperledger Fabric (https://www.hyperledger.org/projects/fabric) Network for a test setup 

# JEDO-Test-Network
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

# Setup Basics
1. copy fabric **bin** & **config** to a **fabric** folder
2. create folder **jedo-network** within *fabric* folder
3. create folder **config** within *jedo-network*
4. copy files to *config* folder:
    - **crypto-config.yaml**
    - **configtx.yaml**
    - **orderer.yaml**
    - **core.yaml**
5. open terminal `cd /mnt/user/appdata/fabric/jedo-network`
6. create docker network `docker network create fabric-network`

# Create CryptoConfig
1. create certificates `../bin/cryptogen generate --config=./config/crypto-config.yaml --output=./crypto-config/`
2. rename orderer signcerts `mv /mnt/user/appdata/fabric/jedo-network/crypto-config/ordererOrganizations/test.jedo.btc/orderers/orderer.test.jedo.btc/msp/signcerts/orderer.test.jedo.btc-cert.pem /mnt/user/appdata/fabric/jedo-network/crypto-config/ordererOrganizations/test.jedo.btc/orderers/orderer.test.jedo.btc/msp/signcerts/cert.pem`
3. rename peer alps signcerts `mv /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/alps.test.jedo.btc/peers/peer0.alps.test.jedo.btc/msp/signcerts/peer0.alps.test.jedo.btc-cert.pem /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/alps.test.jedo.btc/peers/peer0.alps.test.jedo.btc/msp/signcerts/cert.pem`
4. correct permissions `chmod 644 /mnt/user/appdata/fabric/jedo-network/crypto-config/ordererOrganizations/test.jedo.btc/orderers/orderer.test.jedo.btc/tls/server.key`
5. double check generated structure and permission

# Setup Orderer
1. setup variables
-  `export FABRIC_CFG_PATH=./config`
2. create genesis block `../bin/configtxgen -profile JedoOrdererGenesis -channelID system-channel -outputBlock ./config/genesisblock`
3. start orderer
```
    docker run -d \
    --name orderer.test.jedo.btc \
    --label net.unraid.docker.icon="/boot/config/plugins/icons/fabric_logo.png" \
    -v /mnt/user/appdata/fabric/jedo-network/config/orderer.yaml:/etc/hyperledger/fabric/orderer.yaml \
    -v /mnt/user/appdata/fabric/jedo-network/config/genesisblock:/etc/hyperledger/fabric/genesisblock \
    -v /mnt/user/appdata/fabric/jedo-network/crypto-config/ordererOrganizations/test.jedo.btc/orderers/orderer.test.jedo.btc/tls:/etc/hyperledger/orderer/tls \
    -v /mnt/user/appdata/fabric/jedo-network/crypto-config/ordererOrganizations/test.jedo.btc/orderers/orderer.test.jedo.btc/msp:/etc/hyperledger/orderer/msp \
    -v /mnt/user/appdata/fabric/jedo-network/ledger:/var/hyperledger/production \
    -p 7050:7050 \
    hyperledger/fabric-orderer:latest
```
3. set docker network `docker network connect fabric-network orderer.test.jedo.btc`
4. restart docker `docker restart orderer.test.jedo.btc`
4. check Logs `docker logs orderer.test.jedo.btc`

# Setup CouchDB for a Peer
1. Install couchDB 
- use xx84 as Port, according to the desired port for the peer)
- use a spare path for data and config
- add variables for user (`COUCHDB_USER`, name according peer) and password (`COUCHDB_PASSWORD`, for test its *fabric*))
2. set docker network `docker network connect fabric-network CouchDB-ALPS` or `docker network connect fabric-network CouchDB-MEDITERRANEAN`
3. check Container, goto `http://192.168.0.13:8054/_utils/` and log in with user / pw


# Setup Peer ALPS
1. setup variables
- `export FABRIC_CFG_PATH=./config`
2. start peer
```
    docker run -d \
    --name peer0.alps.test.jedo.btc \
    --label net.unraid.docker.icon="/boot/config/plugins/icons/fabric_logo.png" \
    -e CORE_PEER_ID=nik.alps.test.jedo.btc \
    -e CORE_PEER_LISTENADDRESS=0.0.0.0:8051 \
    -e CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:8052 \
    -e CORE_PEER_ADDRESS=192.168.0.13:8051 \
    -e CORE_PEER_LOCALMSPID=AlpsMSP \
    -e CORE_PEER_GOSSIP_BOOTSTRAP=127.0.0.1:8051 \
    -e CORE_PEER_GOSSIP_ENDPOINT=0.0.0.0:8051 \
    -e CORE_PEER_GOSSIP_EXTERNALENDPOINT=0.0.0.0:8051 \
    -e CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt \
    -e CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/server.key \
    -e CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt \
    -e CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=192.168.0.13:8084 \
    -e CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=peer0.alps.test.jedo.btc \
    -e CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=fabric \
    -v /mnt/user/appdata/fabric/jedo-network/config/core.yaml:/etc/hyperledger/fabric/core.yaml \
    -v /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/alps.test.jedo.btc/peers/peer0.alps.test.jedo.btc/msp:/etc/hyperledger/peer/msp \
    -v /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/alps.test.jedo.btc/peers/peer0.alps.test.jedo.btc/tls:/etc/hyperledger/fabric/tls \
    -v /mnt/user/appdata/fabric/jedo-network/alps:/var/hyperledger/production \
    hyperledger/fabric-peer:latest
```
3. set docker network `docker network connect fabric-network peer0.alps.test.jedo.btc`
4. restart docker `docker restart peer0.alps.test.jedo.btc`
5. check Logs `docker logs peer0.alps.test.jedo.btc`

# Setup Peer MEDITERRANEAN
1. setup variables
- `export FABRIC_CFG_PATH=./config`
2. start peer
```
    docker run -d \
    --name peer0.mediterranean.test.jedo.btc \
    --label net.unraid.docker.icon="/boot/config/plugins/icons/fabric_logo.png" \
    -e CORE_PEER_ID=luke.mediterranean.test.jedo.btc \
    -e CORE_PEER_LISTENADDRESS=0.0.0.0:9051 \
    -e CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:9052 \
    -e CORE_PEER_ADDRESS=192.168.0.13:9051 \
    -e CORE_PEER_LOCALMSPID=MediterraneanMSP \
    -e CORE_PEER_GOSSIP_BOOTSTRAP=127.0.0.1:9051 \
    -e CORE_PEER_GOSSIP_ENDPOINT=0.0.0.0:9051 \
    -e CORE_PEER_GOSSIP_EXTERNALENDPOINT=0.0.0.0:9051 \
    -e CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt \
    -e CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/server.key \
    -e CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt \
    -e CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=192.168.0.13:9084 \
    -e CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=peer0.mediterranean.test.jedo.btc \
    -e CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=fabric \
    -v /mnt/user/appdata/fabric/jedo-network/config/core.yaml:/etc/hyperledger/fabric/core.yaml \
    -v /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/mediterranean.test.jedo.btc/peers/peer0.mediterranean.test.jedo.btc/msp:/etc/hyperledger/peer/msp \
    -v /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/mediterranean.test.jedo.btc/peers/peer0.mediterranean.test.jedo.btc/tls:/etc/hyperledger/fabric/tls \
    -v /mnt/user/appdata/fabric/jedo-network/mediterranean:/var/hyperledger/production \
    hyperledger/fabric-peer:latest
```
3. set docker network `docker network connect fabric-network peer0.mediterranean.test.jedo.btc`
4. restart docker `docker restart peer0.mediterranean.test.jedo.btc`
5. check Logs `docker logs peer0.mediterranean.test.jedo.btc`


- create channel config: ../bin/configtxgen -profile JedoChannel -outputCreateChannelTx ./eu.tx -channelID eu
- create channel: ../bin/peer channel create -o orderer.test.jedo.btc:7050 -c eu -f ./eu.tx --tls --cafile /mnt/user/appdata/fabric/jedo-network/crypto-config/ordererOrganizations/test.jedo.btc/orderers/orderer.test.jedo.btc/tls/ca.crt

- create channel: 
../bin/peer channel create -o orderer.test.jedo.btc:7050 -c eu -f ./eu.tx --outputBlock ./eu.block
../bin/peer channel create -o 192.168.0.13:7050 -c eu -f ./eu.tx --outputBlock ./eu.block



# DEBUG
    `-e CORE_LOGGING_LEVEL=debug \`

    - Check logs
      - `docker logs peer0.alps.test.jedo.btc`
      - `docker logs peer0.mediterranean.test.jedo.btc`
    - Check container `docker ps`
    - Inspect Network `docker network inspect fabric-network`
    - Start/Stop Container
      - `docker start orderer.test.jedo.btc`
      - `docker stop orderer.test.jedo.btc`
      - `docker rm orderer.test.jedo.btc`
    - start shell `docker exec -it orderer.test.jedo.btc /bin/sh`
    - several checks in docker shell:
      - `ls -l /etc/hyperledger/fabric/`
      - `cat /etc/hyperledger/fabric/genesisblock`
      - `df -h`
      - `ls -l /etc/hyperledger/orderer/config`
      - `ls -l /etc/hyperledger/orderer/sec`
      - `ls -l /etc/hyperledger/orderer/sec/tls/`
      - `ls -l /etc/hyperledger/orderer/sec/msp`
      - `ls -l /var/hyperledger/production`
      - `cat /var/hyperledger/production/logs/*.log`
    - test communication: `docker exec -it peer0.alps.test.jedo.btc sh -c "CORE_PEER_CONFIG_FILE=/etc/hyperledger/fabric/core.yaml peer channel list"`




#OLD TESTS
Run new Fabric Blockchain:
1. Install Fabric according: https://hyperledger-fabric.readthedocs.io/en/latest/install.html
2. Run a Test Network according: https://hyperledger-fabric.readthedocs.io/en/latest/test_network.html


Check, if network is alive: 
1. cd fabric-samples/test-network 
2. ./network.sh cc list

Shutodown: ./network.sh down

Start: ./network.sh up createChannel


Package chaincode (According: https://hyperledger-fabric.readthedocs.io/en/release-2.5/deploy_chaincode.html):
1. ./network.sh up createChannel
2. cd ../asset-transfer-basic/chaincode-javascript
3. npm install
4. cd ../../test-network
5. export PATH=${PWD}/../bin:$PATH
6. export FABRIC_CFG_PATH=$PWD/../config/
7. peer lifecycle chaincode package basic.tar.gz --path ../asset-transfer-basic/chaincode-javascript/ --lang node --label basic_1.0

Install chaincode (repeat for each org, following org1):
1. export CORE_PEER_TLS_ENABLED=true
2. export CORE_PEER_LOCALMSPID="Org1MSP"
3. export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
4. export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
5. export CORE_PEER_ADDRESS=localhost:7051
6. peer lifecycle chaincode install basic.tar.gz
7. SAVE ID (eg: basic_1.0:cd1739dd34d7c7c4a4613364df7e44182ea07d11be6168408c5ef7106363c535)
8. UPDATE ID AND RUN: export CC_PACKAGE_ID=basic_1.0:cd1739dd34d7c7c4a4613364df7e44182ea07d11be6168408c5ef7106363c535
9. APPROVAL: peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name basic --version 1.0 --package-id $CC_PACKAGE_ID --sequence 1 --tls --cafile "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"

Changes for Org2:
2. export CORE_PEER_LOCALMSPID="Org2MSP"
3. export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
4. export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
5. export CORE_PEER_ADDRESS=localhost:9051

Committ chaincode:
1. peer lifecycle chaincode commit -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name basic --version 1.0 --sequence 1 --tls --cafile "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem" --peerAddresses localhost:7051 --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt" --peerAddresses localhost:9051 --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt"

Invoke chaincode:
1. peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem" -C mychannel -n basic --peerAddresses localhost:7051 --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt" --peerAddresses localhost:9051 --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt" -c '{"function":"InitLedger","Args":[]}'


Checks:
- check binary version: peer version
- check installed packages (to get ID of installed chaincode): peer lifecycle chaincode queryinstalled
- check approval: peer lifecycle chaincode checkcommitreadiness --channelID mychannel --name basic --version 1.0 --sequence 1 --tls --cafile "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem" --output json
- check chaincode: peer lifecycle chaincode querycommitted --channelID mychannel --name basic --cafile "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"
- Query chaincode: peer chaincode query -C mychannel -n basic -c '{"Args":["GetAllAssets"]}'




Tests mit asset-transfer-basic
API-Setup:
1. REST-API im test-network erstellen --> siehe server.js
2. node enrollAdmin.js
3. node registerUser.js
4. node server.js --> API hört auf Port 3000

Neues Terminal, Test API:
1. curl http://localhost:3000/asset/asset1



