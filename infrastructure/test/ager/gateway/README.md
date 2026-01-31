# JEDO Gateway Service

API Gateway für das JEDO Ecosystem. Routet Anfragen zu Backend-Microservices (CA, Ledger, Voting, Recovery).

## 📋 Service-Übersicht

**Funktion:** Zentraler API-Endpunkt für JEDO Mobile App
- Rate Limiting (100 req/min default)
- TLS-verschlüsselte Kommunikation
- Request-Routing zu Microservices
- Audit Logging
- Health Monitoring

**Image:** `harbor.jedo.me/services/jedo-gateway:latest`

**Standard-Port:** `53901`

## ⚙️ Konfiguration

### .env erstellen

```bash
cp .env.template .env
nano .env
```

### Pflichtfelder anpassen

#### 1. Service-Identifikation

```bash
# Dein Gateway-Hostname (von JEDO erhalten)
SERVICE_NAME=via.alps.ea.jedo.dev

# Umgebung (dev/test/prod)
NODE_ENV=dev
```

#### 2. Fabric MSP

```bash
# Deine Organisation MSP-ID (von JEDO erhalten)
# Beispiele: "alps", "rome", "berlin"
FABRIC_MSP_ID=alps
```

#### 3. TLS-Zertifikate

**Wichtig:** Pfade müssen zu deinen tatsächlichen Zertifikat-Dateinamen passen!

```bash
# Prüfe deine Dateinamen:
ls -la ../infrastructure/dev/ea/alps/via.alps.ea.jedo.dev/tls/signcerts/
ls -la ../infrastructure/dev/ea/alps/via.alps.ea.jedo.dev/tls/keystore/
ls -la ../infrastructure/dev/ea/alps/via.alps.ea.jedo.dev/tls/tlscacerts/

# Passe in .env an:
TLS_CERT_PATH=/app/infrastructure/dev/ea/alps/via.alps.ea.jedo.dev/tls/signcerts/<DEIN_CERT>.pem
TLS_KEY_PATH=/app/infrastructure/dev/ea/alps/via.alps.ea.jedo.dev/tls/keystore/<DEIN_KEY>_sk
TLS_CA_PATH=/app/infrastructure/dev/ea/alps/via.alps.ea.jedo.dev/tls/tlscacerts/<DEIN_CA>.pem
```

**Beispiel:**

```bash
# Falls deine Dateien heißen:
# - cert-via-alps.pem
# - 12345abcdef_sk
# - ca-root.pem

TLS_CERT_PATH=/app/infrastructure/dev/ea/alps/via.alps.ea.jedo.dev/tls/signcerts/cert-via-alps.pem
TLS_KEY_PATH=/app/infrastructure/dev/ea/alps/via.alps.ea.jedo.dev/tls/keystore/12345abcdef_sk
TLS_CA_PATH=/app/infrastructure/dev/ea/alps/via.alps.ea.jedo.dev/tls/tlscacerts/ca-root.pem
```

#### 4. Microservice URLs

Backend-Services, zu denen Gateway routet (von JEDO erhalten):

```bash
# CA Service (User Management, Enrollment)
CA_SERVICE_URL=https://172.16.3.91:53911

# Ledger Service (Blockchain Queries)
LEDGER_SERVICE_URL=https://172.16.3.92:53921

# Optional: Weitere Services
# VOTING_SERVICE_URL=https://172.16.3.93:53931
# RECOVERY_SERVICE_URL=https://172.16.3.94:53941
```

**Wichtig:** IPs und Ports müssen zu deiner `infrastructure.yaml` passen!

### Optionale Anpassungen

#### Security

```bash
# Rate Limiting (Anfragen pro Minute)
RATE_LIMIT_MAX_REQUESTS=100  # Erhöhen bei vielen Usern
RATE_LIMIT_WINDOW_MS=60000   # 1 Minute

# CORS (Production: Nur deine App-Domain)
CORS_ORIGIN=*                # Development: Alle erlaubt
# CORS_ORIGIN=https://app.jedo.me  # Production
```

#### Logging

```bash
# Log-Level (error < warn < info < debug)
LOG_LEVEL=info               # Production
# LOG_LEVEL=debug            # Development (mehr Details)

# Pretty Logs (nur Development)
LOG_PRETTY=true              # Formatiert für Terminal
# LOG_PRETTY=false           # Production (JSON für Log-Parser)
```

#### Port

```bash
# Nur ändern bei Konflikten
PORT=53901
```

## 🚀 Service starten

### Einzeln (zum Testen)

```bash
# Von Root-Verzeichnis
docker compose up gateway

# Im Hintergrund
docker compose up -d gateway
```

### Mit Dependencies (empfohlen)

Gateway benötigt CA + Ledger Service:

```bash
# Startet automatisch alle Dependencies
docker compose up -d gateway
```

## 🔍 Monitoring

### Health Check

```bash
# Via Docker
docker compose ps gateway

# Via HTTP (direkt)
curl http://localhost:53901/health

# Via HTTPS (mit TLS)
curl -k https://localhost:53901/health
```

**Erwartete Antwort:**

```json
{
  "status": "healthy",
  "service": "via.alps.ea.jedo.dev",
  "timestamp": "2026-01-27T17:00:00.000Z"
}
```

### Logs anzeigen

```bash
# Live-Logs
docker compose logs -f gateway

# Letzte 100 Zeilen
docker compose logs --tail=100 gateway

# Nach Fehler filtern
docker compose logs gateway | grep ERROR

# Mit Zeitstempel
docker compose logs --timestamps gateway
```

### Performance Metrics

```bash
# Container-Stats
docker stats via.alps.ea.jedo.dev

# CPU + Memory Usage
docker compose top gateway
```

## 🔧 Troubleshooting

### Problem: Gateway startet nicht (Port belegt)

```bash
Error: Bind for 0.0.0.0:53901 failed: port is already allocated
```

**Lösung:**

```bash
# Prüfe Port
sudo lsof -i :53901

# Option 1: Anderen Service stoppen
docker compose down old-gateway

# Option 2: Port in .env ändern
PORT=53902
docker compose up -d gateway
```

### Problem: TLS-Zertifikat nicht gefunden

```bash
Error: ENOENT: no such file or directory, open '/app/infrastructure/.../cert.pem'
```

**Lösung:**

```bash
# 1. Prüfe Dateiname im Container
docker compose exec gateway ls -la /app/infrastructure/dev/ea/alps/via.alps.ea.jedo.dev/tls/signcerts/

# 2. Passe TLS_CERT_PATH in .env an
# 3. Restart
docker compose restart gateway
```

### Problem: Kann Microservice nicht erreichen

```bash
Error: connect ECONNREFUSED 172.16.3.91:53911
```

**Lösung:**

```bash
# 1. Prüfe ob CA-Service läuft
docker compose ps ca-service

# 2. Starte CA-Service
docker compose up -d ca-service

# 3. Prüfe Netzwerk
docker network inspect jedo-fabric-net | grep -A 5 "ca.via.alps"

# 4. URL in .env prüfen
echo $CA_SERVICE_URL
```

### Problem: Rate Limit zu niedrig

```bash
HTTP 429 Too Many Requests
```

**Lösung:**

```bash
# In .env erhöhen
RATE_LIMIT_MAX_REQUESTS=500

# Restart
docker compose restart gateway
```

### Problem: CORS-Fehler im Browser

```bash
Access to fetch at 'https://via.alps.ea.jedo.dev:53901/api/users' from origin 'https://app.jedo.me' has been blocked by CORS policy
```

**Lösung:**

```bash
# In .env anpassen
CORS_ORIGIN=https://app.jedo.me

# Oder mehrere Origins (komma-getrennt)
CORS_ORIGIN=https://app.jedo.me,https://test.jedo.me

# Development: Alle erlauben
CORS_ORIGIN=*

# Restart
docker compose restart gateway
```

## 🔐 Sicherheit

### TLS Best Practices

```bash
# Zertifikate read-only mounten (in docker-compose.yml bereits gesetzt)
volumes:
  - ./infrastructure:/app/infrastructure:ro

# Permissions prüfen
chmod 600 ../infrastructure/.../keystore/*_sk
chmod 644 ../infrastructure/.../signcerts/*.pem
```

### Credentials schützen

```bash
# .env niemals committen
echo ".env" >> .gitignore

# Audit-Log aktivieren (in .env bereits gesetzt)
AUDIT_LOG_PATH=./logs/audit.log
AUDIT_LOG_LEVEL=info
```

### Production Checklist

- [ ] `NODE_ENV=production` gesetzt
- [ ] `CORS_ORIGIN` auf App-Domain beschränkt
- [ ] `LOG_LEVEL=info` (nicht debug)
- [ ] `LOG_PRETTY=false` (JSON für Parser)
- [ ] Rate Limits angepasst
- [ ] TLS-Zertifikate valid (nicht abgelaufen)
- [ ] Audit-Logs aktiviert

## 📊 API Endpoints

Gateway routet zu folgenden Services:

### CA Service (`/api/ca/*`)

```bash
# User Enrollment
POST /api/ca/enroll
POST /api/ca/register

# Health
GET /api/ca/health
```

### Ledger Service (`/api/ledger/*`)

```bash
# Query Blockchain
GET /api/ledger/query
POST /api/ledger/invoke

# Health
GET /api/ledger/health
```

### Swagger UI (Development)

```bash
# OpenAPI Dokumentation
https://via.alps.ea.jedo.dev:53901/api-docs
```

## 🔄 Updates

### Neue Version deployen

```bash
# 1. Image von Harbor pullen
docker compose pull gateway

# 2. Service neu starten
docker compose up -d gateway

# 3. Alte Container entfernen
docker system prune -f
```

### Rollback

```bash
# 1. Spezifische Version in ../.env setzen
GATEWAY_IMAGE=harbor.jedo.me/services/jedo-gateway:1.2.3

# 2. Pullen + Restart
docker compose pull gateway
docker compose up -d gateway
```

### Config-Änderung ohne Downtime

```bash
# 1. .env anpassen
nano .env

# 2. Restart (< 5 Sekunden Downtime)
docker compose restart gateway

# Bei Load-Balancer: Rolling Update möglich
```

## 📞 Support

### Logs für Support bereitstellen

```bash
# Logs exportieren
docker compose logs --tail=500 gateway > gateway-logs-$(date +%Y%m%d).txt

# Config exportieren (ohne Secrets!)
grep -v "PASS\|KEY\|SECRET" .env > gateway-config-redacted.txt

# An JEDO-Support senden
```

### Debug-Modus aktivieren

```bash
# In .env
LOG_LEVEL=debug
LOG_PRETTY=true

# Restart
docker compose restart gateway

# Live-Logs
docker compose logs -f gateway
```

## 📚 Weitere Infos

- **Root README**: `../README.md`
- **Docker Compose**: `../docker-compose.yml`
- **Infrastructure Config**: `../infrastructure/`

---

**Bei Problemen: support@jedo.me** 🚀
```
