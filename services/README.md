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
cd ~/Entwicklung/JEDO/services/ca-service

**optional:**
npm install
npm test

npm test

docker build -t ca-service:local .

code commit in VSC