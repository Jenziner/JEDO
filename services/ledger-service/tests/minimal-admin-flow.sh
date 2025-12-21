# Test-Flow
########################
# Params
########################
GATEWAY_ADR="192.168.0.13:53911"
ADMIN_CERT=$(cat infrastructure/jedo/ea/alps/admin.alps.ea.jedo.cc/msp/signcerts/cert.pem | base64 -w 0)
ADMIN_KEY=$(cat infrastructure/jedo/ea/alps/admin.alps.ea.jedo.cc/msp/keystore/*_sk | base64 -w 0)
TEST_ID=$(uuidgen)
TEST_NAME="jedo:$TEST_ID"

########################
# Execute
########################
echo "==================================="
echo "1. Gateway test"
echo "==================================="
curl http://$GATEWAY_ADR/health | jq '.'
echo ""

echo "==================================="
echo "2. Identity list"
echo "==================================="
ls -la infrastructure/jedo/ea/alps/
echo ""

echo "==================================="
echo "3. Admin Cert test"
echo "==================================="
echo "Cert length: ${#ADMIN_CERT}"
echo "Key length: ${#ADMIN_KEY}"
echo ""

echo "==================================="
echo "4. RegisterGens $TEST_NAME"
echo "==================================="
curl -X POST http://$GATEWAY_ADR/api/v1/proxy/submit \
  -H "Content-Type: application/json" \
  -H "X-Fabric-Cert: $ADMIN_CERT" \
  -H "X-Fabric-Key: $ADMIN_KEY" \
  -d '{
    "channelName": "ea",
    "chaincodeName": "jedo-wallet",
    "functionName": "RegisterGens",
    "args": ["'$TEST_ID'", "'$TEST_NAME'"]
  }' | jq '.'
echo ""

echo "==================================="
echo "5. ListGens"
echo "==================================="
curl -X POST http://$GATEWAY_ADR/api/v1/proxy/evaluate \
  -H "Content-Type: application/json" \
  -H "X-Fabric-Cert: $ADMIN_CERT" \
  -H "X-Fabric-Key: $ADMIN_KEY" \
  -d '{
    "channelName": "ea",
    "chaincodeName": "jedo-wallet",
    "functionName": "ListGens",
    "args": []
  }' | jq '.'
echo ""

echo "==================================="
echo "6. GetWallet $TEST_NAME"
echo "==================================="
curl -X POST http://$GATEWAY_ADR/api/v1/proxy/evaluate \
  -H "Content-Type: application/json" \
  -H "X-Fabric-Cert: $ADMIN_CERT" \
  -H "X-Fabric-Key: $ADMIN_KEY" \
  -d '{
    "channelName": "ea",
    "chaincodeName": "jedo-wallet",
    "functionName": "GetWallet",
    "args": ["'$TEST_ID'"]
  }' | jq '.'
echo ""

echo "==================================="
echo "7. Docker logs"
echo "==================================="
read -r -p "Show docker logs of gateway? [y/N] " answer
answer=${answer:-N}
case "$answer" in
  [JjYy])  echo "via.alps.ea.jedo.cc...";;
  [Nn])    echo "End."; exit 1;;
  *)       echo "Y or n."; exit 1;;
esac
docker logs via.alps.ea.jedo.cc -f
echo ""




