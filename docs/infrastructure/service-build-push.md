# Service als Docker-Image bauen & pushen

## Übersicht

Dieser Guide zeigt, wie ein Service (z.B. ca-service) als Docker-Image gebaut und zu Harbor gepusht wird. Kann sinngemäss für apps, chaincode, infrastructure angewendet werden.

## Voraussetzungen

- Docker installiert
- Zugriff auf Harbor (`harbor.jedo.me`)
- Robot-Account Credentials (robot$services+ci für Push)

## Schritt-für-Schritt

### 1. Image bauen

docker build
-t harbor.jedo.me/services/<SERVICE>:<VERSION>
-f services/<SERVICE>/Dockerfile
services/<SERVICE>

### 2. Zu Harbor pushen

docker login harbor.jedo.me
docker push harbor.jedo.me/services/<SERVICE>:<VERSION>

### 3. In Harbor verifizieren

- UI: Projects → services → Repositories → <SERVICE>
- Trivy-Scan automatisch nach 1-2 Minuten

### 4. Image deployen

**docker-compose:**
services:
my-service:
image: harbor.jedo.me/services/<SERVICE>:<VERSION>

**docker run:**
docker run -d harbor.jedo.me/services/<SERVICE>:<VERSION>

## Tag-Strategie

- `:X.Y.Z` → Production (immutable)
- `:X.Y.Z-dev` → Development (mutable)
- `:X.Y.Z-test` → Testing (mutable)
- `:latest-dev` → Latest dev build (floating)

## Troubleshooting

**Build schlägt fehl:**
- Check `.dockerignore` (ist `node_modules` ausgeschlossen?)
- Check `package.json` (existiert `build` script?)

**Push schlägt fehl:**
- Check Login: `docker login harbor.jedo.me`
- Check Robot-Account Permissions (Push-Rechte auf Projekt?)

**Image zu groß (>500 MB):**
- Nutze alpine base image
- Multi-stage build (siehe Dockerfile)
- Check `.dockerignore` (werden alle unnötigen Files ausgeschlossen?)

**Service startet nicht:**
- Check Logs: `docker logs <container>`
- Check Port-Mapping (exposed port = service port?)
- Check Environment Variables (alle gesetzt?)