# JEDO CA-Service

## Test-Pyramide
                    ┌──────────┐
                    │   E2E    │  ← 5% (End-to-End, langsam)
                    └──────────┘
                  ┌──────────────┐
                  │ Integration  │  ← 20% (Service + Fabric)
                  └──────────────┘
              ┌────────────────────┐
              │    Unit Tests      │  ← 75% (schnell, isoliert)
              └────────────────────┘


## Test Structure
services/
├── ca-service/
│   ├── src/
│   └── tests/
│       ├── unit/
│       │   ├── services/
│       │   │   └── certificate.service.test.js
│       │   ├── controllers/
│       │   │   └── certificate.controller.test.js
│       │   └── validators/
│       │       └── certificate.validator.test.js
│       ├── integration/
│       │   ├── ca-client.test.js
│       │   ├── enrollment.test.js
│       │   └── api.test.js
│       ├── e2e/
│       │   └── registration-flow.test.js
│       ├── fixtures/
│       │   ├── test-certificates.js
│       │   └── mock-responses.js
│       └── setup.js
│
└── ledger-service/
    ├── src/
    └── tests/
        ├── unit/
        ├── integration/
        ├── e2e/
        └── setup.js


## Test-Kategorien nach Service
### CA-Service Tests:
| Kategorie   | Was wird getestet?         | Anzahl | Tool          |
| ----------- | -------------------------- | ------ | ------------- |
| Unit        | Certificate Service Logic  | ~15    | Jest          |
| Unit        | Validation & Authorization | ~10    | Jest          |
| Integration | Fabric CA Enrollment       | ~5     | Jest + Docker |
| Integration | Certificate Revocation     | ~3     | Jest + Docker |
| E2E         | Full Registration Flow     | ~2     | Supertest     |


### Ledger-Service Tests:
| Kategorie   | Was wird getestet?        | Anzahl | Tool          |
| ----------- | ------------------------- | ------ | ------------- |
| Unit        | Transaction Service Logic | ~15    | Jest          |
| Unit        | Request Validation        | ~10    | Jest          |
| Integration | Fabric Gateway Connection | ~5     | Jest + Docker |
| Integration | Submit/Query Chaincode    | ~8     | Jest + Docker |
| E2E         | Full Transaction Flow     | ~2     | Supertest     |


### Gateway Tests:
| Kategorie   | Was wird getestet? | Anzahl | Tool          |
| ----------- | ------------------ | ------ | ------------- |
| Unit        | Proxy Router Logic | ~10    | Jest          |
| Unit        | Rate Limiting      | ~5     | Jest          |
| Integration | Service Proxying   | ~8     | Jest + Docker |
| E2E         | Multi-Service Flow | ~3     | Supertest     |


## Test-Setup Requirements
### 1. Test Dependencies:
{
  "devDependencies": {
    "@types/jest": "^29.5.0",
    "@types/supertest": "^6.0.0",
    "jest": "^29.7.0",
    "supertest": "^7.0.0",
    "testcontainers": "^10.0.0",
    "ts-jest": "^29.2.0"
  }
}


### 2. Jest Config:
// jest.config.js
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['**/tests/**/*.test.ts'],
  collectCoverageFrom: [
    'src/**/*.{ts,js}',
    '!src/**/*.d.ts'
  ],
  coverageThreshold: {
    global: {
      branches: 70,
      functions: 75,
      lines: 80,
      statements: 80
    }
  }
};


## Environment
orbis (jedo.dev)
  └── regnum (ea)
       └── ager (alps)
            └── gens (worb)
                 └── human (do;ra;...)

CAs (3-Tier Architecture!)
1. Orbis-CA:  msp.jedo.dev          (172.16.1.4:51041)
2. Regnum-CA: msp.ea.jedo.dev       (172.16.2.4:52041)
3. Ager-CA:   msp.alps.ea.jedo.dev  (172.16.3.4:53041)


## Test-Szenario:
┌─────────────┐         ┌──────────────┐         ┌─────────────────┐
│  Test Script│  HTTP   │  CA-Service  │  gRPC   │ Fabric CA       │
│  (curl)     │────────>│  (Docker)    │────────>│ msp.alps.ea...  │
└─────────────┘         └──────────────┘         └─────────────────┘
                             ↓
                        - Real Registration
                        - Real Enrollment
                        - Real Certificate


## Kritische Funktionen:
1. Register User - Neue User registrieren (mit Rolle)
2. Enroll User - Certificate ausstellen
3. Authorization - Nur höhere Rollen dürfen niedrigere registrieren
4. Revoke Certificate - Bei Kompromittierung
5. Re-Enroll - Certificate erneuern


## Install Test Dependencies
cd ~/Entwicklung/JEDO/services/ca-service
npm install --save-dev \
  jest \
  supertest \
  @types/jest \
  @types/supertest

## Run test
### Unit Test
cd ~/Entwicklung/JEDO/services/ca-service
npm test tests/unit/services/certificate.service.test.js

### Integration Test
cd ~/Entwicklung/JEDO/services/ca-service
chmod +x tests/integration/test-ca-service.sh
./tests/integration/test-ca-service.sh


### Certificate Flow
┌─────────────────────────────────────────────────────────────┐
│ AGER (Startup)                                              │
│ ├─ Hat bereits: ager_cert.pem + ager_key.pem                │
│ │   (Bootstrap von Admin)                                   │
│ └─ Kann registrieren: GENS                                  │
└─────────────────────────────────────────────────────────────┘
                      ↓ scannt QR
┌─────────────────────────────────────────────────────────────┐
│ GENS (Registration)                                         │
│ 1. Erstellt: UID + Password (lokal)                         │
│ 2. Zeigt: QR-Code                                           │
│ 3. Ager scannt → POST /register (mit ager_cert)             │
│ 4. Gens: POST /enroll (mit UID + Password)                  │
│ 5. Erhält: gens_cert.pem + gens_key.pem                     │
│ └─ Kann jetzt registrieren: HUMAN                           │
└─────────────────────────────────────────────────────────────┘
                      ↓ scannt QR
┌─────────────────────────────────────────────────────────────┐
│ HUMAN (Registration)                                        │
│ 1. Erstellt: UID + Password (lokal)                         │
│ 2. Zeigt: QR-Code                                           │
│ 3. Gens scannt → POST /register (mit gens_cert)             │
│ 4. Human: POST /enroll (mit UID + Password)                 │
│ 5. Erhält: human_cert.pem + human_key.pem (Idemix)          │
│ └─ Kann jetzt: Ledger Transactions                          │
└─────────────────────────────────────────────────────────────┘
