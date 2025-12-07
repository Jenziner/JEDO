#!/bin/bash

# ✅ Env vars werden als -e flags übergeben!

echo "=== Test 1: Query installed ==="
docker exec \
  -e CORE_PEER_TLS_ENABLED=true \
  -e CORE_PEER_LOCALMSPID=alps \
  -e CORE_PEER_TLS_ROOTCERT_FILE=/var/hyperledger/infrastructure/jedo/ea/alps/peer.alps.ea.jedo.cc/tls/tlscacerts/tls-tls-jedo-cc-51031.pem \
  -e CORE_PEER_MSPCONFIGPATH=/var/hyperledger/infrastructure/jedo/ea/alps/admin.alps.ea.jedo.cc/msp \
  -e CORE_PEER_ADDRESS=peer.alps.ea.jedo.cc:53511 \
  cli.peer.alps.ea.jedo.cc \
  peer lifecycle chaincode queryinstalled

echo ""
echo "=== Test 2: Get channel info ==="
docker exec \
  -e CORE_PEER_TLS_ENABLED=true \
  -e CORE_PEER_LOCALMSPID=alps \
  -e CORE_PEER_TLS_ROOTCERT_FILE=/var/hyperledger/infrastructure/jedo/ea/alps/peer.alps.ea.jedo.cc/tls/tlscacerts/tls-tls-jedo-cc-51031.pem \
  -e CORE_PEER_MSPCONFIGPATH=/var/hyperledger/infrastructure/jedo/ea/alps/admin.alps.ea.jedo.cc/msp \
  -e CORE_PEER_ADDRESS=peer.alps.ea.jedo.cc:53511 \
  cli.peer.alps.ea.jedo.cc \
  peer channel getinfo -c ea

echo ""
echo "=== Test 3: Query committed ==="
docker exec \
  -e CORE_PEER_TLS_ENABLED=true \
  -e CORE_PEER_LOCALMSPID=alps \
  -e CORE_PEER_TLS_ROOTCERT_FILE=/var/hyperledger/infrastructure/jedo/ea/alps/peer.alps.ea.jedo.cc/tls/tlscacerts/tls-tls-jedo-cc-51031.pem \
  -e CORE_PEER_MSPCONFIGPATH=/var/hyperledger/infrastructure/jedo/ea/alps/admin.alps.ea.jedo.cc/msp \
  -e CORE_PEER_ADDRESS=peer.alps.ea.jedo.cc:53511 \
  cli.peer.alps.ea.jedo.cc \
  peer lifecycle chaincode querycommitted -C ea

echo ""
echo "=== Check Peer MSP ==="
docker exec cli.peer.alps.ea.jedo.cc ls -la /var/hyperledger/infrastructure/jedo/ea/alps/peer.alps.ea.jedo.cc/msp/

echo ""
echo "=== Check Peer MSP config ==="
docker exec cli.peer.alps.ea.jedo.cc cat /var/hyperledger/infrastructure/jedo/ea/alps/peer.alps.ea.jedo.cc/msp/config.yaml

echo ""
echo "=== Check Admin MSP in CLI ==="
docker exec cli.peer.alps.ea.jedo.cc ls -la /var/hyperledger/infrastructure/jedo/ea/alps/admin.alps.ea.jedo.cc/msp/
