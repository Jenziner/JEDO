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
