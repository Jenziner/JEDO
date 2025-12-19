JEDO/
├── docker-compose.yml                # Master-File mit include
├── .env                              # Globale Umgebungsvariablen
├── docs/                             # Dokumentation
├── apps/
│   ├── jedo-gateway-consolel/        # Demo-Website
│   └── legacy/                       # Alte Apps (Web und Mobile)
├── services/
│   ├── ca/
│   │   ├── compose.ca.yml            # CA-Service modular
│   │   └── Dockerfile
│   ├── orderer/
│   │   ├── compose.orderer.yml
│   │   └── config/
│   ├── peer/
│   │   ├── compose.peer.yml
│   │   └── config/
│   ├── gateway/
│   │   ├── compose.gateway.yml
│   │   └── src/
│   ├── ca-service/
│   │   ├── compose.ca-service.yml
│   │   ├── Dockerfile
│   │   └── src/
│   └── ledger-service/
│       ├── compose.ledger-service.yml
│       ├── Dockerfile
│       └── src/
├── chaincode/
│   └── jedo-wallet/
│       ├── compose.chaincode.yml
│       ├── Dockerfile
│       └── src/
├── infrastructure/
│   ├── infrastructure.yaml           # Deine Config (angepasst)
│   ├── templates/                    # Muster für andere Agers
│   └── secrets/                      # Verschlüsselte Secrets (SOPS)
├── scripts/
│   ├── deploy.sh                     # Neuer modularer Deployment-Manager
│   ├── build-images.sh               # Build & Push zu Harbor
│   └── utils.sh                      # Deine bestehenden Utils
└── .github/
    └── workflows/
        ├── build-chaincode.yml       # CI für Chaincode
        └── build-services.yml        # CI für Services
