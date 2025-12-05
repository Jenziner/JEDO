# JEDO Gateway Server

Gateway-Server für die JEDO Mobile-App mit Hyperledger Fabric 3.0 Integration für das Blockchain-Netzwerk "OrbisRegnumAger".

## Features

- ✅ TypeScript mit Strict Mode
- ✅ Express.js REST API
- ✅ Pino High-Performance Logging
- ✅ ESLint + Prettier für Code-Qualität
- ✅ Graceful Shutdown
- ✅ Rate Limiting & Security (Helmet)
- ✅ Health Check Endpoints
- ✅ Strukturierte Error Handling
- 🔄 Hyperledger Fabric Gateway Integration (geplant)

## Technologie-Stack

- **Runtime**: Node.js 20+ / TypeScript 5.6
- **Framework**: Express.js 4.19
- **Logging**: Pino 9.5 (5-10x schneller als Winston)
- **Security**: Helmet, CORS, Rate Limiting
- **Code Quality**: ESLint, Prettier
- **Dev Tools**: tsx (schneller als ts-node)

## Voraussetzungen

- Node.js >= 20.0.0
- npm >= 10.0.0
- Docker (für Fabric-Integration)

## Getting Started

### 1. Installation

npm install


### 2. Umgebungsvariablen konfigurieren

Kopiere `.env.example` zu `.env` und passe die Werte an:
cp .env.example .env


Wichtige Konfigurationen:
- `PORT`: Server-Port (default: 3000)
- `LOG_LEVEL`: Logging-Level (debug, info, warn, error)
- `FABRIC_*`: Hyperledger Fabric Verbindungsparameter

### 3. Development starten

npm run dev


Der Server startet auf `http://localhost:3000` mit Hot-Reload.

### 4. Production Build

npm run build
npm start


## Verfügbare Scripts

| Script | Beschreibung |
|--------|--------------|
| `npm run dev` | Development-Server mit Hot-Reload (tsx watch) |
| `npm run build` | TypeScript zu JavaScript kompilieren |
| `npm start` | Production-Server starten (dist/server.js) |
| `npm run lint` | ESLint Fehler prüfen |
| `npm run lint:fix` | ESLint Fehler automatisch fixen |
| `npm run format` | Code mit Prettier formatieren |
| `npm run format:check` | Prettier-Formatierung prüfen |
| `npm run typecheck` | TypeScript Type-Checking ohne Build |
| `npm run clean` | dist-Ordner löschen |

## API Endpoints

### Health Checks

Basic Health Check
GET /health

Kubernetes Readiness Probe
GET /ready

Kubernetes Liveness Probe
GET /live


**Response Beispiel:**

{
"success": true,
"data": {
"status": "OK",
"timestamp": "2025-12-05T07:10:00.000Z",
"uptime": 42.5,
"environment": "development",
"version": "1.0.0"
}
}



## Projektstruktur

jedo-gateway/
├── src/
│ ├── config/ # Konfiguration (env, logger)
│ ├── middlewares/ # Express Middlewares
│ ├── routes/ # API Routes
│ ├── types/ # TypeScript Type Definitions
│ ├── utils/ # Utility Functions
│ ├── app.ts # Express App Setup
│ └── server.ts # Server Entry Point
├── dist/ # Kompilierte JS-Dateien
├── tests/ # Unit/Integration Tests
├── .env.example # Umgebungsvariablen Template
├── package.json
└── tsconfig.json



## Code Quality Standards

### TypeScript

- Strict Mode aktiviert
- Alle `any` Types verboten
- Explizite Return Types empfohlen

### ESLint Regeln

- Unused Variables → Error
- No console.log → Warning (nutze Logger)
- Import Order → Automatisch sortiert
- Floating Promises → Error

### Prettier

- Single Quotes
- Semicolons aktiviert
- 100 Zeichen Print Width
- 2 Spaces Indentation

## Logging

Pino wird verwendet wegen:
- 5-10x schneller als Winston [web:6]
- Asynchrones Logging
- Strukturierte JSON-Logs
- Perfekt für High-Throughput APIs

### Log Levels

logger.debug('Debug information');
logger.info('General information');
logger.warn('Warning message');
logger.error({ err }, 'Error occurred');


### Pretty Logs (Development)

In Development werden Logs formatiert ausgegeben. In Production: JSON.

## Security Features

- **Helmet**: Setzt Security HTTP Headers
- **CORS**: Konfigurierbare Cross-Origin Policies
- **Rate Limiting**: 100 Requests/15min pro IP (konfigurierbar)
- **Body Size Limit**: 10MB Maximum

## Graceful Shutdown

Der Server behandelt SIGTERM/SIGINT Signals:

1. Stoppt neue Requests
2. Wartet auf laufende Requests (max 30s)
3. Schließt Fabric Gateway Connections
4. Exit mit Code 0 (success) oder 1 (error)

## Nächste Schritte (Task 2+)

- [ ] Hyperledger Fabric Gateway SDK Integration
- [ ] JWT-Authentifizierung
- [ ] Wallet-API Endpoints (create, transfer, balance)
- [ ] OpenAPI 3.0 Spezifikation
- [ ] Docker Container Setup
- [ ] Load Testing (Artillery)
- [ ] Integration Tests

## Entwicklung & Contribution

### Code Style

Vor jedem Commit
npm run lint:fix
npm run format
npm run typecheck


### Best Practices

1. Verwende den Logger, nicht `console.log`
2. Alle Async-Funktionen müssen Error Handling haben
3. Explicit Return Types für Funktionen
4. Environment Variables über `config/environment.ts`
5. Keine `any` Types verwenden

## Troubleshooting

### Port bereits belegt

Port-Nutzung prüfen
lsof -i :3000

Prozess beenden
kill -9 <PID>


### TypeScript Compilation Errors

npm run clean
npm run build


### ESLint Cache löschen

rm -rf node_modules/.cache
npm run lint


## Lizenz

MIT

## Support

Bei Fragen oder Problemen: Erstelle ein Issue im Repository.
