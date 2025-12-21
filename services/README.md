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