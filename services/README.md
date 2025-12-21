# Architecture

Mobile App (User)
    ↓ HTTPS (Public Internet)
┌─────────────────────────────────────────────┐
│  via.alps.ea.jedo.dev (Gateway)             │
│  - Reverse Proxy                            │
│  - Public Endpoint                          │
└─────────────────────────────────────────────┘
    ↓                          ↓
    ↓ HTTP (Internal)          ↓ HTTP (Internal)
    ↓                          ↓
┌──────────────────┐    ┌─────────────────────┐
│ ca.via.alps...   │    │ ledger.via.alps...  │
│ (CA-Service)     │    │ (Ledger-Service)    │
└──────────────────┘    └─────────────────────┘
         ↓                       ↓
         ↓ gRPC/TLS              ↓ gRPC/TLS
         ↓                       ↓
┌─────────────────┐    ┌──────────────────────┐
│ msp.alps...     │    │ peer0.alps...        │
│ (Fabric CA)     │    │ (Fabric Peer)        │
└─────────────────┘    └──────────────────────┘


# How-to-Dev
## CA-Service Maint

## Local Dev-Workflow
1. cd ~/Entwicklung/JEDO/services/ca-service

**optional:**
- rm -rf node_modules package-lock.json
- npm install
- npm test

2. docker build -t ca-service:local .
3. docker run --rm -p 3001:3001 --env-file .env ca-service:local

4. code commit in VSC


docker login harbor.jedo.me -u robot$cd
# Password: See 1Password

docker pull harbor.jedo.me/services/ca-service:latest


docker run -d \
  --name ca-service \
  --network jedo-cc \
  -p 3001:3001 \
  -e NODE_ENV=dev \
  -e FABRIC_CA_URL=https://ca.alps.ea.jedo.cc:53041 \
  -e FABRIC_CA_NAME=ca.alps.ea.jedo.cc \
  -e FABRIC_CA_TLS_CERT_PATH=/app/tls/ca-cert.pem \
  -e FABRIC_CA_ADMIN_USER=ca.alps.ea.jedo.cc \
  -e FABRIC_CA_ADMIN_PASS=Test1 \
  -e FABRIC_MSP_ID=alps \
  -e TLS_ENABLED=true \
  -e TLS_KEY_PATH=/app/tls/keystore/309b7a08e78bc2d3e7c1826400b2f26106dfe89ffa76a833240fbf8b2dd5be3d_sk \
  -e TLS_CERT_PATH=/app/tls/signcerts/cert.pem \
  -e TLS_CA_PATH=/app/tls/tlscacerts/tls-tls-jedo-cc-51031.pem \
  -e FABRIC_ORBIS_NAME=jedo \
  -e FABRIC_REGNUM_NAME=ea \
  -e FABRIC_AGER_NAME=alps \
  -e FABRIC_CA_TLS_CERT_PATH=/app/tls/tlscacerts/tls-tls-jedo-cc-51031.pem \
  -e FABRIC_CA_TLS_VERIFY=true \
  -e FABRIC_CA_IDEMIX_CURVE=gurvy.Bn254 \
  -v /mnt/user/appdata/jedo/demo/infrastructure/jedo/tls.jedo.cc/tls:/app/tls:ro \
  -v /mnt/user/appdata/jedo/demo/infrastructure/temp/ca-service/production:/app/production \
  harbor.jedo.me/services/ca-service:latest
  
docker logs ca-service

curl -k https://<unraid-ip>:3001/health