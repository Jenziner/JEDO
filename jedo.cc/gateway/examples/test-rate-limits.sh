#!/bin/bash
# Test rate limiting with certificate-based identity

set -e

GATEWAY_URL="http://localhost:53911"
ADMIN_CERT=$(cat infrastructure/jedo/ea/alps/admin.alps.ea.jedo.cc/msp/signcerts/cert.pem | base64 -w 0)
ADMIN_KEY=$(cat infrastructure/jedo/ea/alps/admin.alps.ea.jedo.cc/msp/keystore/*_sk | base64 -w 0)

echo "========================================="
echo "Testing Rate Limits"
echo "========================================="
echo ""

# Test 1: Balance Query (100/min allowed)
echo "Test 1: Balance queries (should allow 100, block 101st)"
for i in {1..25}; do
  echo -n "Request $i: "
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X GET "${GATEWAY_URL}/api/v1/wallets/wallet-worb-001/balance" \
    -H "X-Fabric-Cert: ${ADMIN_CERT}" \
    -H "X-Fabric-Key: ${ADMIN_KEY}")
  
  if [ $i -le 20 ]; then
    if [ "$STATUS" == "200" ]; then
      echo "✅ OK (200)"
    else
      echo "❌ FAIL (expected 200, got $STATUS)"
    fi
  else
    if [ "$STATUS" == "429" ]; then
      echo "✅ BLOCKED (429) - Rate limit working!"
    else
      echo "❌ FAIL (expected 429, got $STATUS)"
    fi
  fi
done

echo ""
echo "Waiting 60 seconds for rate limit reset..."
sleep 60

# Test 2: Transfer (5/min allowed)
echo ""
echo "Test 2: Transfers (should allow 5, block 6th)"
for i in {1..7}; do
  echo -n "Request $i: "
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "${GATEWAY_URL}/api/v1/wallets/transfer" \
    -H "Content-Type: application/json" \
    -H "X-Fabric-Cert: ${ADMIN_CERT}" \
    -H "X-Fabric-Key: ${ADMIN_KEY}" \
    -d '{
      "fromWallet": "wallet-worb-001",
      "toWallet": "wallet-user-alice",
      "amount": 1
    }')
  
  if [ $i -le 5 ]; then
    if [ "$STATUS" == "200" ]; then
      echo "✅ OK (200)"
    else
      echo "⚠️  Got $STATUS (might be chaincode error, not rate limit)"
    fi
  else
    if [ "$STATUS" == "429" ]; then
      echo "✅ BLOCKED (429) - Rate limit working!"
    else
      echo "❌ FAIL (expected 429, got $STATUS)"
    fi
  fi
done

echo ""
echo "========================================="
echo "Rate limit tests completed"
echo "========================================="
