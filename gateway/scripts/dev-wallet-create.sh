#!/bin/bash
# JEDO Wallet Dev - Fabric Samples
# CreateWallet via Gateway → Ledger-Service

set -e

# Konfiguration
GATEWAY_URL="http://localhost:3000"

ADMIN_CERT_PATH="config/fabric-network/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp/signcerts/Admin@org1.example.com-cert.pem"
ADMIN_KEY_PATH="config/fabric-network/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp/keystore/priv_sk"

# Base64-Encode (eine Zeile)
ADMIN_CERT=$(cat "$ADMIN_CERT_PATH" | base64 -w 0)
ADMIN_KEY=$(cat "$ADMIN_KEY_PATH" | base64 -w 0)

echo "=== Health über Gateway ==="
curl -s -X GET "${GATEWAY_URL}/health" | jq .
echo ""

echo "=== Ledger-Service Health über Gateway ==="
curl -s -X GET "${GATEWAY_URL}/api/v1/ledger/health" | jq .
echo ""

echo "=== Create Wallet (Admin-only) ==="
curl -s -X POST "${GATEWAY_URL}/api/v1/ledger/api/v1/wallets" \
  -H "Content-Type: application/json" \
  -H "X-Fabric-Cert: ${ADMIN_CERT}" \
  -H "X-Fabric-Key: ${ADMIN_KEY}" \
  -d '{
    "walletId": "wallet-dev-001",
    "ownerId": "dev-user",
    "initialBalance": 1000
  }' | jq .
echo ""
