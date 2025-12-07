#!/bin/bash
# JEDO Wallet Gateway - Curl Test Examples
# All wallet endpoints require X-Fabric-Cert and X-Fabric-Key headers

set -e

# Configuration
GATEWAY_URL="http://via.alps.ea.jedo.cc:53911"
GATEWAY_URL="http://192.168.0.13:53911"
ADMIN_CERT_PATH="infrastructure/jedo/ea/alps/admin.alps.ea.jedo.cc/msp/signcerts/cert.pem"
ADMIN_KEY_PATH="infrastructure/jedo/ea/alps/admin.alps.ea.jedo.cc/msp/keystore/*_sk"

# Encode credentials to Base64
ADMIN_CERT=$(cat $ADMIN_CERT_PATH | base64 -w 0)
ADMIN_KEY=$(cat $ADMIN_KEY_PATH | base64 -w 0)

echo "==================================="
echo "JEDO Wallet Gateway - API Tests"
echo "==================================="
echo ""

# 1. Health Check (no auth required)
echo "1. Health Check"
curl -s -X GET "${GATEWAY_URL}/health" | jq .
echo ""

# 2. Readiness Check
echo "2. Readiness Check"
curl -s -X GET "${GATEWAY_URL}/ready" | jq .
echo ""

# 3. Liveness Check
echo "3. Liveness Check"
curl -s -X GET "${GATEWAY_URL}/live" | jq .
echo ""

# 4. Create Wallet (requires admin identity)
echo "4. Create Wallet - wallet-worb-001"
curl -s -X POST "${GATEWAY_URL}/api/v1/wallets" \
  -H "Content-Type: application/json" \
  -H "X-Fabric-Cert: ${ADMIN_CERT}" \
  -H "X-Fabric-Key: ${ADMIN_KEY}" \
  -d '{
    "walletId": "wallet-worb-001",
    "ownerId": "worb",
    "initialBalance": 1000
  }' | jq .
echo ""

# 5. Create Second Wallet
echo "5. Create Wallet - wallet-user-alice"
curl -s -X POST "${GATEWAY_URL}/api/v1/wallets" \
  -H "Content-Type: application/json" \
  -H "X-Fabric-Cert: ${ADMIN_CERT}" \
  -H "X-Fabric-Key: ${ADMIN_KEY}" \
  -d '{
    "walletId": "wallet-user-alice",
    "ownerId": "alice",
    "initialBalance": 500
  }' | jq .
echo ""

# 6. Get Wallet Balance
echo "6. Get Balance - wallet-worb-001"
curl -s -X GET "${GATEWAY_URL}/api/v1/wallets/wallet-worb-001/balance" \
  -H "X-Fabric-Cert: ${ADMIN_CERT}" \
  -H "X-Fabric-Key: ${ADMIN_KEY}" | jq .
echo ""

# 7. Get Wallet Details
echo "7. Get Wallet Details - wallet-worb-001"
curl -s -X GET "${GATEWAY_URL}/api/v1/wallets/wallet-worb-001" \
  -H "X-Fabric-Cert: ${ADMIN_CERT}" \
  -H "X-Fabric-Key: ${ADMIN_KEY}" | jq .
echo ""

# 8. Transfer Funds
echo "8. Transfer 50 from wallet-worb-001 to wallet-user-alice"
curl -s -X POST "${GATEWAY_URL}/api/v1/wallets/transfer" \
  -H "Content-Type: application/json" \
  -H "X-Fabric-Cert: ${ADMIN_CERT}" \
  -H "X-Fabric-Key: ${ADMIN_KEY}" \
  -d '{
    "fromWallet": "wallet-worb-001",
    "toWallet": "wallet-user-alice",
    "amount": 50
  }' | jq .
echo ""

# 9. Get Wallet History
echo "9. Get Transaction History - wallet-worb-001"
curl -s -X GET "${GATEWAY_URL}/api/v1/wallets/wallet-worb-001/history" \
  -H "X-Fabric-Cert: ${ADMIN_CERT}" \
  -H "X-Fabric-Key: ${ADMIN_KEY}" | jq .
echo ""

# 10. Low-Level Proxy - Direct Chaincode Submit
echo "10. Proxy Submit - RegisterGens (admin-only function)"
curl -s -X POST "${GATEWAY_URL}/api/v1/proxy/submit" \
  -H "Content-Type: application/json" \
  -H "X-Fabric-Cert: ${ADMIN_CERT}" \
  -H "X-Fabric-Key: ${ADMIN_KEY}" \
  -d '{
    "channelName": "ea",
    "chaincodeName": "jedo-wallet",
    "functionName": "RegisterGens",
    "args": ["worb", "WORB Business"]
  }' | jq .
echo ""

# 11. Low-Level Proxy - Direct Chaincode Evaluate
echo "11. Proxy Evaluate - GetBalance via direct call"
curl -s -X POST "${GATEWAY_URL}/api/v1/proxy/evaluate" \
  -H "Content-Type: application/json" \
  -H "X-Fabric-Cert: ${ADMIN_CERT}" \
  -H "X-Fabric-Key: ${ADMIN_KEY}" \
  -d '{
    "channelName": "ea",
    "chaincodeName": "jedo-wallet",
    "functionName": "GetBalance",
    "args": ["wallet-worb-001"]
  }' | jq .
echo ""

echo "==================================="
echo "All tests completed"
echo "==================================="
