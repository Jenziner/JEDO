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
5. open terminal: `cd /mnt/user/appdata/fabric/jedo-network`

# Create CryptoConfig
1. create certificates `../bin/cryptogen generate --config=./config/crypto-config.yaml --output=./crypto-config/`
2. rename orderer signcerts `mv /mnt/user/appdata/fabric/jedo-network/crypto-config/ordererOrganizations/test.jedo.btc/orderers/orderer.test.jedo.btc/msp/signcerts/orderer.test.jedo.btc-cert.pem /mnt/user/appdata/fabric/jedo-network/crypto-config/ordererOrganizations/test.jedo.btc/orderers/orderer.test.jedo.btc/msp/signcerts/cert.pem`
3. correct permissions `chmod 644 /mnt/user/appdata/fabric/jedo-network/crypto-config/ordererOrganizations/test.jedo.btc/orderers/orderer.test.jedo.btc/tls/server.key`
4. Double check generated structure and permission

# Setup Orderer
1. add path `export FABRIC_CFG_PATH=./config`
2. create genesis block ```../bin/configtxgen -profile JedoOrdererGenesis -channelID system-channel -outputBlock ./config/genesisblock```
3. start orderer
```
    docker run -d \
    --name orderer.test.jedo.btc \
    -v /mnt/user/appdata/fabric/jedo-network/config/orderer.yaml:/etc/hyperledger/fabric/orderer.yaml \
    -v /mnt/user/appdata/fabric/jedo-network/config/genesisblock:/etc/hyperledger/fabric/genesisblock \
    -v /mnt/user/appdata/fabric/jedo-network/crypto-config/ordererOrganizations/test.jedo.btc/orderers/orderer.test.jedo.btc/tls:/etc/hyperledger/orderer/tls \
    -v /mnt/user/appdata/fabric/jedo-network/crypto-config/ordererOrganizations/test.jedo.btc/orderers/orderer.test.jedo.btc/msp:/etc/hyperledger/orderer/msp \
    -v /mnt/user/appdata/fabric/jedo-network/ledger:/var/hyperledger/production \
    -p 7050:7050 \
    hyperledger/fabric-orderer:latest
```
4. check Logs `docker logs orderer.test.jedo.btc`

# Setup CouchDB for a Peer


PEERS
-----
- start peer alps:
docker run -d \
  --name peer0.alps.test.jedo.btc \
  -v /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/alps.test.jedo.btc/msp:/var/hyperledger/peer/msp \
  -v /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/alps.test.jedo.btc/tls:/var/hyperledger/peer/tls \
  -v /mnt/user/appdata/fabric/jedo-network/production:/var/hyperledger/alps \
  hyperledger/fabric-peer:2.5

- create channel config: ../bin/configtxgen -profile JedoChannel -outputCreateChannelTx ./eu.tx -channelID eu
- create channel: ../bin/peer channel create -o orderer.test.jedo.btc:7050 -c eu -f ./eu.tx --tls --cafile /mnt/user/appdata/fabric/jedo-network/crypto-config/ordererOrganizations/test.jedo.btc/orderers/orderer.test.jedo.btc/tls/ca.crt




#######
# DEBUG
#######
- dubug until running:
-e CORE_LOGGING_LEVEL=debug \
    - 
    - docker logs peer0.alps.test.jedo.btc
    - docker logs peer0.mediterranean.test.jedo.btc
    - docker ps
    - docker start orderer.test.jedo.btc
    - docker stop orderer.test.jedo.btc
    - docker rm orderer.test.jedo.btc

- Infinit run:
docker run -d \
  --name orderer.test.jedo.btc \
  -v /mnt/user/appdata/fabric/jedo-network/config/orderer.yaml:/etc/hyperledger/fabric/orderer.yaml \
  -v /mnt/user/appdata/fabric/jedo-network/config/genesisblock:/etc/hyperledger/fabric/genesisblock \
  -v /mnt/user/appdata/fabric/jedo-network/crypto-config/ordererOrganizations/test.jedo.btc/orderers/orderer.test.jedo.btc/tls:/etc/hyperledger/orderer/tls \
  -v /mnt/user/appdata/fabric/jedo-network/crypto-config/ordererOrganizations/test.jedo.btc/orderers/orderer.test.jedo.btc/msp:/etc/hyperledger/orderer/msp \
  -v /mnt/user/appdata/fabric/jedo-network/ledger:/var/hyperledger/production \
  hyperledger/fabric-orderer:latest
  /bin/sh -c "while true; do sleep 1000; done"
- shell starten:
docker exec -it orderer.test.jedo.btc /bin/sh
- several checks:
ls -l /etc/hyperledger/fabric/
cat /etc/hyperledger/fabric/genesisblock
df -h
ls -l /etc/hyperledger/orderer/config
ls -l /etc/hyperledger/orderer/sec
ls -l /etc/hyperledger/orderer/sec/tls/
ls -l /etc/hyperledger/orderer/sec/msp
ls -l /var/hyperledger/production
cat /var/hyperledger/production/logs/*.log





PEERs:
------
- add 'peer-alps.yaml' to config folder
- start peer alps:
docker run -d \
  --name peer0.alps.test.jedo.btc \
  -v /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/alps.test.jedo.btc/msp:/var/hyperledger/peer/msp \
  -v /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/alps.test.jedo.btc/tls:/var/hyperledger/peer/tls \
  -v /mnt/user/appdata/fabric/jedo-network/production:/var/hyperledger/alps \
  hyperledger/fabric-peer:2.5
- add 'peer-mediterranean.yaml' to config folder
- start peer mediterranean:
docker run -d \
  --name peer0.mediterranean.test.jedo.btc \
  -v /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/mediterranean.test.jedo.btc/msp:/var/hyperledger/peer/msp \
  -v /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/alps.mediterranean.jedo.btc/tls:/var/hyperledger/peer/tls \
  -v /mnt/user/appdata/fabric/jedo-network/production:/var/hyperledger/mediterranien \
  hyperledger/fabric-peer:2.5






- test communication: docker exec -it peer0.alps.test.jedo.btc sh -c "CORE_PEER_CONFIG_FILE=/mnt/user/appdata/fabric/jedo-network/config/peer-alps.yaml peer channel list"



 

- add 'core.yaml'



- add signcerts folder in alps: mkdir -p /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/alps.test.jedo.btc/msp/signcerts
- add signcerts folder in medi: mkdir -p /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/mediterranean.test.jedo.btc/msp/signcerts
- copy certificates for alps: cp /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/alps.test.jedo.btc/peers/peer0.alps.test.jedo.btc/msp/signcerts/peer0.alps.test.jedo.btc-cert.pem /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/alps.test.jedo.btc/msp/signcerts/
- copy certificates for medi: cp /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/mediterranean.test.jedo.btc/peers/peer0.mediterranean.test.jedo.btc/msp/signcerts/peer0.mediterranean.test.jedo.btc-cert.pem /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/mediterranean.test.jedo.btc/msp/signcerts/
- copy keystor for alps: cp /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/alps.test.jedo.btc/peers/peer0.alps.test.jedo.btc/msp/keystore/* /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/alps.test.jedo.btc/msp/keystore/
- copy keystor for medi: cp /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/mediterranean.test.jedo.btc/peers/peer0.mediterranean.test.jedo.btc/msp/keystore/* /mnt/user/appdata/fabric/jedo-network/crypto-config/peerOrganizations/mediterranean.test.jedo.btc/msp/keystore/



- create channel: ../bin/peer channel create -o orderer.test.jedo.btc:7050 -c eu -f ./eu.tx --outputBlock ./eu.block
../bin/peer channel create -o 192.168.0.13:7050 -c eu -f ./eu.tx --outputBlock ./eu.block






OLD TESTS
=========
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



