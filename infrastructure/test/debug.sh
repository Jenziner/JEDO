#!/bin/bash

ADMIN_CERT_PATH="infrastructure/jedo/ea/alps/admin.alps.ea.jedo.cc/msp/signcerts/cert.pem"
ADMIN_KEY_PATH="infrastructure/jedo/ea/alps/admin.alps.ea.jedo.cc/msp/keystore"

echo "=== 1. Admin Certificate ==="
if [ -f "$ADMIN_CERT_PATH" ]; then
    echo "✅ Certificate exists"
    openssl x509 -in "$ADMIN_CERT_PATH" -text -noout | grep -A2 "Subject:"
    openssl x509 -in "$ADMIN_CERT_PATH" -text -noout | grep -A1 "Issuer:"
    echo ""
    echo "Certificate (first 5 lines):"
    head -5 "$ADMIN_CERT_PATH"
else
    echo "❌ Certificate NOT found at $ADMIN_CERT_PATH"
fi

echo ""
echo "=== 2. Admin Private Key ==="
KEY_FILE=$(ls -1 $ADMIN_KEY_PATH/*_sk 2>/dev/null | head -1)
if [ -f "$KEY_FILE" ]; then
    echo "✅ Private key exists: $KEY_FILE"
    head -2 "$KEY_FILE"
else
    echo "❌ Private key NOT found in $ADMIN_KEY_PATH"
fi

echo ""
echo "=== 3. MSP Config ==="
MSP_CONFIG="infrastructure/jedo/ea/alps/msp/config.yaml"
if [ -f "$MSP_CONFIG" ]; then
    echo "✅ MSP config exists"
    cat "$MSP_CONFIG"
else
    echo "❌ MSP config NOT found"
fi

echo ""
echo "=== 4. Base64 Encoded (what Gateway receives) ==="
ADMIN_CERT_B64=$(cat "$ADMIN_CERT_PATH" | base64 -w 0)
echo "Cert length: ${#ADMIN_CERT_B64}"
echo "First 100 chars: ${ADMIN_CERT_B64:0:100}"

KEY_B64=$(cat "$KEY_FILE" | base64 -w 0)
echo "Key length: ${#KEY_B64}"
echo "First 100 chars: ${KEY_B64:0:100}"



echo ""
echo "=== 5. chaincode invoke ==="
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="alps"
export CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric-ca-client/infrastructure/jedo/ea/alps/peer.alps.ea.jedo.cc/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric-ca-client/infrastructure/jedo/ea/alps/admin.alps.ea.jedo.cc/msp
export CORE_PEER_ADDRESS=peer.alps.ea.jedo.cc:53511

docker exec -it \
    -e CORE_PEER_TLS_ENABLED=$CORE_PEER_TLS_ENABLED \
    -e CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID \
    -e CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE \
    -e CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH \
    -e CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS \
    tools.jedo.cc \
    peer chaincode invoke \
    -o orderer.alps.ea.jedo.cc:53611 \
    --ordererTLSHostnameOverride orderer.alps.ea.jedo.cc \
    --tls \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/jedo/ea/alps/orderer.alps.ea.jedo.cc/msp/tlscacerts/tlsca.alps.ea.jedo.cc-cert.pem \
    -C ea \
    -n jedo-wallet \
    -c '{"function":"Ping","Args":[]}'


echo ""
echo "=== 6. MSP ==="
echo "=== Admin MSP Structure ==="
tree ./infrastructure/jedo/ea/alps/admin.alps.ea.jedo.cc/msp

echo ""
echo "=== Channel MSP Structure ==="
tree ./infrastructure/jedo/ea/alps/msp

