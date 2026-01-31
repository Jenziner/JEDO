# JEDO-Ecosystem - Infrastructure Setup

Willkommen im JEDO-Ecosystem! Diese Anleitung hilft dir, deine Organisation als AGER in das JEDO-Ecosystem Netzwerk zu integrieren.

## 📋 Voraussetzungen

### Software
- **Docker**: Version 24.0+ ([Installation](https://docs.docker.com/engine/install/))
- **Docker Compose**: Version 2.20+ (meist in Docker enthalten)
- **Git**: Für Repository-Verwaltung (optional)
- **Bash**: Für Helper-Scripts (Linux/macOS Standard, Windows: WSL2)

### Systemanforderungen
- **RAM**: Minimum 4 GB, empfohlen 8 GB
- **CPU**: 2+ Cores
- **Disk**: 20 GB freier Speicher
- **Netzwerk**: Offene Ports für Services (siehe unten)

### Von REGNUM erhalten
- ✅ **Harbor Registry Credentials** (Username + Password)
- ✅ **Crypto-Material** (TLS-Zertifikate)
- ✅ **Netzwerk-Konfiguration** (IPs, Ports, MSP-ID)
- ✅ **Dieses Repository** (oder .tar.gz Package)

## 🚀 Quick Start (5 Minuten)

```bash
# 1. Repository klonen oder Package entpacken
tar -xzf jedo-infrastructure-package.tar.gz
cd jedo-infrastructure

# 2. Root-Konfiguration erstellen
cp .env.template .env
nano .env  # Harbor Credentials eintragen

# 3. Harbor Login testen
./harbor-login.sh

# 4. Gateway konfigurieren
cp gateway/.env.template gateway/.env
nano gateway/.env  # Deine Org-Daten eintragen

# 5. Crypto-Material bereitstellen (von JEDO erhalten)
# Zertifikate nach ./infrastructure/<orbis>/<regnum>/<ager>/<gateway>/tls/ kopieren

# 6. Services starten
docker compose pull
docker compose up -d

# 7. Status prüfen
docker compose ps
docker compose logs -f gateway
```

## 📁 Verzeichnisstruktur

```
jedo-infrastructure/
├── docker-compose.yml          # Orchestrierung aller Services
├── .env                        # Root-Konfiguration (Harbor, Netzwerk)
├── .env.template               # Template für .env
├── harbor-login.sh             # Helper für Harbor Registry Login
├── README.md                   # Diese Datei
│
├── gateway/                    # API Gateway Service
│   ├── .env                    # Gateway-Konfiguration
│   ├── .env.template           # Template
│   └── README.md               # Gateway-spezifische Doku
│
├── ca-service/                 # CA Service (später)
│   ├── .env
│   ├── .env.template
│   └── README.md
│
└── infrastructure/             # Crypto-Material (Zertifikate)
    └── <orbis>/                # z.B. "dev", "prod"
        └── <regnum>/           # z.B. "ea" (Europa)
            └── <ager>/         # z.B. "alps" (deine Org)
                └── <service>/  # z.B. "via.alps.ea.jedo.dev"
                    └── tls/
                        ├── signcerts/  # Server-Zertifikat
                        ├── keystore/   # Private Key
                        └── tlscacerts/ # CA-Zertifikat
```

## ⚙️ Konfiguration

### Schritt 1: Root .env konfigurieren

```bash
cp .env.template .env
nano .env
```

**Pflichtfelder (von JEDO erhalten):**

```bash
# Harbor Credentials
HARBOR_USER=your-org-user          # Von JEDO erhalten
HARBOR_PASS=your-secure-password   # Von JEDO erhalten

# User/Group (Linux)
UID=1000  # Führe aus: id -u
GID=1000  # Führe aus: id -g
```

**Optional anpassen:**

```bash
# Ports (nur bei Konflikten ändern)
GATEWAY_PORT=53901
CA_SERVICE_PORT=53911

# Image-Versionen (Standard: :latest)
GATEWAY_IMAGE=${HARBOR_REGISTRY}/${HARBOR_PROJECT}/jedo-gateway:1.2.3
```

### Schritt 2: Harbor Login testen

```bash
./harbor-login.sh
```

**Erwartete Ausgabe:**
```
🔐 Logging in to Harbor Registry: harbor.jedo.me
✅ Harbor login successful
```

**Bei Fehler:**
- Credentials in `.env` prüfen
- Netzwerkverbindung zu `harbor.jedo.me` testen
- JEDO-Admin kontaktieren

### Schritt 3: Service-Konfiguration

Jeder Service hat sein eigenes `.env`. Siehe Service-spezifische README:
- **Gateway**: `gateway/README.md`
- **CA-Service**: `ca-service/README.md` (später)

### Schritt 4: Crypto-Material bereitstellen

**Struktur (von JEDO erhalten):**

```bash
infrastructure/
└── dev/                        # Orbis (dev/test/prod)
    └── ea/                     # Regnum (Europa)
        └── alps/               # Deine Organisation
            └── via.alps.ea.jedo.dev/  # Gateway-Service
                └── tls/
                    ├── signcerts/
                    │   └── cert.pem
                    ├── keystore/
                    │   └── key_sk
                    └── tlscacerts/
                        └── ca.pem
```

**Dateien kopieren (Beispiel):**

```bash
# Zertifikate von JEDO erhalten als .zip
unzip alps-crypto-material.zip -d ./infrastructure/
```

**Permissions prüfen:**

```bash
chmod -R 750 infrastructure/
chown -R $(id -u):$(id -g) infrastructure/
```

## 🐳 Docker Compose Befehle

### Services starten

```bash
# Alle Services
docker compose up -d

# Nur Gateway
docker compose up -d gateway

# Mit Live-Logs (zum Debuggen)
docker compose up gateway
```

### Status & Logs

```bash
# Status aller Services
docker compose ps

# Logs anzeigen
docker compose logs gateway                # Letzte Logs
docker compose logs -f gateway             # Live-Logs
docker compose logs --tail=100 gateway     # Letzte 100 Zeilen
docker compose logs --since 10m gateway    # Letzte 10 Minuten
```

### Services verwalten

```bash
# Restart (nach Config-Änderung)
docker compose restart gateway

# Stoppen
docker compose stop gateway

# Stoppen + Entfernen
docker compose down

# Stoppen + Volumes löschen
docker compose down -v
```

### Updates

```bash
# Neues Image von Harbor holen
docker compose pull gateway

# Image pullen + Service neu starten
docker compose up -d --pull always gateway

# Alle Services updaten
docker compose pull
docker compose up -d
```

## 🔧 Troubleshooting

### Problem: Harbor Login schlägt fehl

```bash
❌ Error response from daemon: Get "https://harbor.jedo.me/v2/": unauthorized
```

**Lösung:**
1. Credentials in `.env` prüfen
2. `./harbor-login.sh` erneut ausführen
3. JEDO-Admin kontaktieren (Credentials abgelaufen?)

### Problem: Service startet nicht (Healthcheck failing)

```bash
docker compose ps
# Status: unhealthy
```

**Lösung:**

```bash
# Logs prüfen
docker compose logs gateway

# Häufige Ursachen:
# - Falscher TLS_CERT_PATH in gateway/.env
# - Zertifikat-Dateien nicht gefunden
# - Port bereits belegt
# - Falscher FABRIC_MSP_ID
```

### Problem: Container kann nicht auf andere Services zugreifen

```bash
Error: getaddrinfo ENOTFOUND ca.via.alps.ea.jedo.dev
```

**Lösung:**
1. `extra_hosts` in `docker-compose.yml` prüfen
2. Netzwerk-Konfiguration checken: `docker network inspect jedo-fabric-net`
3. Andere Services laufen: `docker compose ps`

### Problem: Permission Denied auf Zertifikaten

```bash
Error: EACCES: permission denied, open '/app/infrastructure/.../cert.pem'
```

**Lösung:**

```bash
# Permissions korrigieren
chmod -R 750 infrastructure/
chown -R $(id -u):$(id -g) infrastructure/

# UID/GID in .env prüfen
echo "UID=$(id -u), GID=$(id -g)"
```

### Problem: Port bereits belegt

```bash
Error: Bind for 0.0.0.0:53901 failed: port is already allocated
```

**Lösung:**

```bash
# Port prüfen
sudo lsof -i :53901

# Alternative: Port in .env ändern
GATEWAY_PORT=53902
docker compose up -d gateway
```

## 🔐 Sicherheit

### Credentials nicht in Git commiten

```bash
# .gitignore sollte enthalten:
.env
gateway/.env
ca-service/.env
infrastructure/**/keystore/*
infrastructure/**/signcerts/*
```

### TLS-Zertifikate schützen

```bash
# Read-only Mounts in docker-compose.yml
volumes:
  - ./infrastructure:/app/infrastructure:ro
```

### Regelmäßige Updates

```bash
# Wöchentlich Images aktualisieren
docker compose pull
docker compose up -d
```

## 📞 Support

### JEDO-Team kontaktieren

- **Email**: support@jedo.me
- **Issue Tracker**: https://github.com/jedo/infrastructure/issues
- **Slack**: #jedo-support (Invite von Admin erhalten)

### Logs für Support bereitstellen

```bash
# Logs in Datei speichern
docker compose logs gateway > gateway-logs.txt
docker compose logs ca-service > ca-service-logs.txt

# Zusammen mit Config (ohne Secrets!) an Support senden
```

## 📚 Weiterführende Dokumentation

- **Gateway Service**: `gateway/README.md`
- **CA Service**: `ca-service/README.md`
- **Hyperledger Fabric**: https://hyperledger-fabric.readthedocs.io/
- **Docker Compose**: https://docs.docker.com/compose/

## 📝 Changelog

### Version 1.0 (Januar 2026)
- Initial Release
- Gateway Service Support
- CA Service Support
- Harbor Registry Integration

---

**Willkommen im JEDO-Ecosystem! Bei Fragen: support@jedo.me** 🚀


