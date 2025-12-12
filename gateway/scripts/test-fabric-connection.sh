#!/bin/bash
set -e

echo "🧪 Testing Fabric Gateway Connection..."

# 1. Zertifikate aus Test Network laden (mit Wildcard)
CERT_DIR="config/fabric-network/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp/signcerts"
KEY_DIR="config/fabric-network/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp/keystore"

# Finde erstes .pem Zertifikat
CERT_FILE=$(ls $CERT_DIR/*.pem 2>/dev/null | head -1)
if [ -z "$CERT_FILE" ]; then
  echo "❌ Certificate not found in: $CERT_DIR"
  exit 1
fi

# Finde privaten Schlüssel
KEY_FILE=$(ls $KEY_DIR/*_sk 2>/dev/null | head -1)
if [ -z "$KEY_FILE" ]; then
  echo "❌ Private key not found in: $KEY_DIR"
  exit 1
fi

# Base64 encode (single line)
CERT_B64=$(cat "$CERT_FILE" | base64 -w 0)
KEY_B64=$(cat "$KEY_FILE" | base64 -w 0)

echo "✅ Certificates loaded"
echo "   Cert: $(basename $CERT_FILE)"
echo "   Key:  $(basename $KEY_FILE)"

# 2. Test Health Endpoint
echo ""
echo "📊 Testing Health Endpoint..."
curl -s http://localhost:3000/health | jq '.'

# 3. Test Wallet Query
echo ""
echo "📖 Testing Wallet Query (GetWallet)..."
curl -s -X GET http://localhost:3000/api/v1/wallets/test-wallet-1 \
  -H "Content-Type: application/json" \
  -H "x-fabric-cert: $CERT_B64" \
  -H "x-fabric-key: $KEY_B64" | jq '.'

echo ""
echo "✅ Test completed!"
