# Gateway test
curl http://192.168.0.13:53911/health | jq '.'

# Welche Identities hast du?
ls -la infrastructure/jedo/ea/alps/

# Identity verwenden (für Test)
ADMIN_CERT=$(cat infrastructure/jedo/ea/alps/admin.alps.ea.jedo.cc/msp/signcerts/cert.pem | base64 -w 0)
ADMIN_KEY=$(cat infrastructure/jedo/ea/alps/admin.alps.ea.jedo.cc/msp/keystore/*_sk | base64 -w 0)

echo "Cert length: ${#ADMIN_CERT}"
echo "Key length: ${#ADMIN_KEY}"

# Test: RegisterGens
curl -X POST http://192.168.0.13:53911/api/v1/proxy/submit \
  -H "Content-Type: application/json" \
  -H "X-Fabric-Cert: $ADMIN_CERT" \
  -H "X-Fabric-Key: $ADMIN_KEY" \
  -d '{
    "channelName": "ea",
    "chaincodeName": "jedo-wallet",
    "functionName": "RegisterGens",
    "args": ["worb", "WORB Business"]
  }' | jq '.'

docker logs via.alps.ea.jedo.cc -f




