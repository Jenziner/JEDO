# JEDO HOST - is a Linux app for HOST and MASTER. 

It is used for
- transaction processing
- Conversion of Bitcoin to JEDO
- Store of Bitcoin
- Participation in voting in the JEDO ecosystem

Based on Hyperledger Fabric (https://www.hyperledger.org/projects/fabric).

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
