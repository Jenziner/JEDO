#!/bin/bash
set -e

CERT_DIR="config/fabric-network/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp/signcerts"
KEY_DIR="config/fabric-network/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp/keystore"

CERT_B64=$(cat $(ls $CERT_DIR/*.pem | head -1) | base64 -w 0)
KEY_B64=$(cat $(ls $KEY_DIR/*_sk | head -1) | base64 -w 0)

echo "🏦 Creating test wallet..."

curl -s -X POST http://localhost:3000/api/v1/wallets \
  -H "Content-Type: application/json" \
  -H "x-fabric-cert: $CERT_B64" \
  -H "x-fabric-key: $KEY_B64" \
  -d '{
    "walletId": "wallet-dev-001",
    "ownerId": "alice",
    "initialBalance": 1000
  }' | jq '.'

echo ""
echo "📖 Reading wallet..."

curl -s -X GET http://localhost:3000/api/v1/wallets/wallet-dev-001 \
  -H "x-fabric-cert: $CERT_B64" \
  -H "x-fabric-key: $KEY_B64" | jq '.'
