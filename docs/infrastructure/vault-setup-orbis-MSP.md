# TLS @ Vault

## Ziel der Umstellung

- Vault wird als **ausstellende TLS‑CA** für die Orbis‑MSP‑CAs genutzt (Dev/Test/Prod).  
- Die Orbis‑MSP‑CAs verwenden weiterhin eigene Sign‑Keys, aber das **TLS‑Zertifikat** für jede MSP‑CA stammt aus Vault.

***

## Voraussetzungen

- Laufender Vault‑Cluster mit HTTPS‑Zugriff (`https://vault.jedo.me:8200`).
- Vault‑Login mit einem Token, das PKI‑Mounts verwalten darf.  
- Vorhandene Orbis‑Intermediate‑CAs (Dev/Test/Prod) mit:
  - CA‑Zertifikat (z.B. `tls.jedo.dev.cert`)
  - zugehörigem Private Key (z.B. `tls.jedo.dev.key`)  

***

## PKI-Ablage auf dem Vault-Server

Die Orbis-PKI-Schlüssel und -Zertifikate werden NICHT im Git-Repository, sondern lokal auf dem Vault-Server unter `/srv/pki` abgelegt. Die Struktur ist:

- `/srv/pki/intermediate/dev|test|prod`  
  Intermediate-CAs wie `tls.jedo.dev.{cert,key}`, `tls.jedo.cc.{cert,key}`, `tls.jedo.me.{cert,key}`  
- `/srv/pki/servers/dev|test|prod/<dienstname>`  
  TLS-Server-Zertifikate und -Keys, z.B. `/srv/pki/servers/prod/msp.jedo.me/tls-{cert,key,ca}.pem`  

Beispiel: Nach der Erstellung der Intermediate-CA werden die Dateien vom Arbeitsverzeichnis auf den Vault-Server kopiert und dort einsortiert:

lokal: Intermediate erzeugen
```bash
openssl ecparam -name prime256v1 -genkey -noout -out tls.jedo.dev.key
openssl req -new -sha256 -key tls.jedo.dev.key -out tls.jedo.dev.csr -config tls-orbis.cnf
openssl ca -batch -config ca.cnf -extensions v3_intermediate_ca -days 365 -notext -md sha256 -in tls.jedo.dev.csr -out tls.jedo.dev.cert
```

auf Vault-Server kopieren und in PKI-Struktur verschieben
```bash
scp tls.jedo.dev.cert tls.jedo.dev.key jedo:/srv/pki/intermediate/dev/
```

**Wichtiger Hinweis:** Private Keys (`*.key`, `tls-*-key.pem`) werden niemals in Git committet, sondern nur in `/srv/pki/...` mit restriktiven Rechten (`chmod 700` Verzeichnisse, `chmod 600` Dateien) gespeichert.

***

## Schritt 1: PKI‑Engines pro Umgebung einrichten

Für jede Umgebung wurde ein eigener PKI‑Mount angelegt:

```bash
# Dev
vault secrets enable -path=pki_orbis_tls_dev pki
vault secrets tune -max-lease-ttl=87600h pki_orbis_tls_dev

# Test
vault secrets enable -path=pki_orbis_tls_test pki
vault secrets tune -max-lease-ttl=87600h pki_orbis_tls_test

# Prod
vault secrets enable -path=pki_orbis_tls_prod pki
vault secrets tune -max-lease-ttl=87600h pki_orbis_tls_prod
```

Grund: Trennung der Trust‑Domains pro Umgebung (eigenes Intermediate pro Stage, unterschiedliche DNS‑Zonen).

***

## Schritt 2: Intermediate‑CA mit RootCA generieren
### 2.1 tls-orbis.cnf anpassen
```bash
[ req ]
default_bits        = 256
distinguished_name  = req_distinguished_name
prompt              = no

[ req_distinguished_name ]
C  = jd
ST = dev
CN = tls.jedo.dev
```
### Zertifikate generieren
1. openssl ecparam -name prime256v1 -genkey -noout -out tls.jedo.dev.key
2. openssl req -new -sha256 \
  -key tls.jedo.dev.key \
  -out tls.jedo.dev.csr \
  -config tls-orbis.cnf
3. openssl ca -batch \
  -config ca.cnf \
  -extensions v3_intermediate_ca \
  -days 365 \
  -notext -md sha256 \
  -in tls.jedo.dev.csr \
  -out tls.jedo.dev.cert

## Schritt 3: Intermediate‑CA in Vault importieren (Zertifikat + Key)

### 3.1. Key und Zertifikat auf den Vault‑Host kopieren

Beispiel Dev (analog für Test/Prod):

```bash
scp tls.jedo.dev.cert tls.jedo.dev.key jedo:/srv/pki/intermediate/dev/
```

Damit liegen CA‑Zertifikat und Private Key geschützt auf dem Vault‑Server, nicht auf einem zufälligen Client.

### 3.2. PEM‑Bundle erstellen

Auf dem Vault‑Host:

```bash
cd /srv/pki/intermediate/dev
cat tls.jedo.dev.cert tls.jedo.dev.key > orbis-dev-intermediate-bundle.pem
cp orbis-dev-intermediate-bundle.pem ~/vault/orbis-dev-intermediate-bundle.pem
```

Reihenfolge: zuerst Zertifikat, danach Key; Vault erwartet dieses Format als „Bundle“.

Das Bundle unter `~/vault/` wird anschließend in Vault importiert, die "Master"-Kopie der Intermediate-CA bleibt unter `/srv/pki/intermediate/dev/`.

### 3.3. Bundle in den PKI‑Mount importieren

```bash
vault write pki_orbis_tls_dev/config/ca \
  pem_bundle=@orbis-dev-intermediate-bundle.pem
```

Wirkung:

- Vault speichert das Intermediate‑Zertifikat.  
- Vault speichert den zugehörigen Private Key.  
- Der Issuer im Mount wird mit dem Key verknüpft, sodass Signatur‑Operationen (Issue, CRL) funktionieren.

Für Test/Prod analog mit den jeweiligen Bundles (`tls.jedo.cc`, `tls.jedo.me`) und `pki_orbis_tls_test` bzw. `pki_orbis_tls_prod`.

***

## Schritt 4: Default‑Issuer setzen (falls nötig)

Nach dem Import wurde geprüft, welcher Issuer existiert:

```bash
vault list pki_orbis_tls_dev/issuers
# Ausgabe z.B.:
# Keys
# ----
# 37204e01-c7b1-5548-71e5-d6d57099b62d
```

Diese Issuer‑ID wurde als Default konfiguriert:

```bash
vault write pki_orbis_tls_dev/config/issuers \
  default="37204e01-c7b1-5548-71e5-d6d57099b62d"
```

Grund: Die neuere PKI‑API in Vault arbeitet mit Issuers; einer davon muss als **default** markiert sein, sonst schlagen `issue`‑Aufrufe mit „no default issuer configured“ oder „issuer has no key associated with it“ fehl.

***

## Schritt 5: Rollen für die Orbis‑MSP‑Hosts anlegen

Für jeden MSP‑Host wurde eine PKI‑Role pro Umgebung erstellt. Die Role begrenzt, für welche DNS‑Namen Zertifikate ausgestellt werden dürfen.[1]

### Dev

```bash
vault write pki_orbis_tls_dev/roles/orbis-msp-dev \
  allowed_domains="msp.jedo.dev" \
  allow_subdomains="false" \
  allow_bare_domains="true" \
  max_ttl="720h"
```

### Test

```bash
vault write pki_orbis_tls_test/roles/orbis-msp-test \
  allowed_domains="msp.jedo.cc" \
  allow_subdomains="false" \
  allow_bare_domains="true" \
  max_ttl="720h"
```

### Prod

```bash
vault write pki_orbis_tls_prod/roles/orbis-msp-prod \
  allowed_domains="msp.jedo.me" \
  allow_subdomains="false" \
  allow_bare_domains="true" \
  max_ttl="720h"
```

Erläuterung:

- `allowed_domains` definiert die erlaubten CN/SAN‑Domains.  
- `allow_subdomains=false` verhindert Wildcard‑/Subdomain‑Zertifikate.  
- `max_ttl` begrenzt die maximale Laufzeit eines ausgestellten Zertifikats (hier 30 Tage).[8]

***

### 6 Vault-CLI vorbereiten

Auf dem Vault-Host (oder der Workstation mit Vault-CLI):

```bash
export VAULT_ADDR="https://vault.jedo.me:8200"
export VAULT_CACERT="$PWD/config/vault-ca.pem"
vault status # Verbindung testen
```

## Schritt 7: TLS‑Zertifikate für die MSP‑Hosts ausstellen

Für jede Umgebung wird ein Zertifikat mit Vault ausgestellt, inkl. Private Key.

### 7.1. Dev (msp.jedo.dev)

```bash
vault write -format=json pki_orbis_tls_dev/issue/orbis-msp-dev \
  common_name="msp.jedo.dev" > msp.jedo.dev-tls.json
```

### 7.2. Test (msp.jedo.cc)

```bash
vault write -format=json pki_orbis_tls_test/issue/orbis-msp-test \
  common_name="msp.jedo.cc" > msp.jedo.cc-tls.json
```

### 7.3. Prod (msp.jedo.me)

```bash
vault write -format=json pki_orbis_tls_prod/issue/orbis-msp-prod \
  common_name="msp.jedo.me" > msp.jedo.me-tls.json
```

Die JSON‑Antwort enthält:

- `certificate` – Server‑Zertifikat  
- `private_key` – TLS‑Private‑Key  
- `issuing_ca` – Intermediate‑CA‑Zertifikat  
- `ca_chain` – vollständige Zertifikatskette (falls genutzt)[9][1]

***

## Schritt 8: PEM‑Dateien aus JSON extrahieren

Auf dem Vault‑Host:

```bash
# Dev
jq -r '.data.certificate' msp.jedo.dev-tls.json > tls-dev-cert.pem
jq -r '.data.private_key' msp.jedo.dev-tls.json > tls-dev-key.pem
jq -r '.data.issuing_ca'  msp.jedo.dev-tls.json > tls-dev-ca.pem

# Test
jq -r '.data.certificate' msp.jedo.cc-tls.json > tls-test-cert.pem
jq -r '.data.private_key' msp.jedo.cc-tls.json > tls-test-key.pem
jq -r '.data.issuing_ca'  msp.jedo.cc-tls.json > tls-test-ca.pem

# Prod
jq -r '.data.certificate' msp.jedo.me-tls.json > tls-prod-cert.pem
jq -r '.data.private_key' msp.jedo.me-tls.json > tls-prod-key.pem
jq -r '.data.issuing_ca'  msp.jedo.me-tls.json > tls-prod-ca.pem
```

Ergebnis pro Umgebung:

- `tls-*-cert.pem`  → Server‑Zertifikat  
- `tls-*-key.pem`   → Private Key  
- `tls-*-ca.pem`    → CA‑Zertifikat (Intermediate)[10]

Nach dem Extrahieren werden die TLS-Dateien zusätzlich in der PKI-Struktur abgelegt:

Beispiel Dev
```bash
mkdir -p /srv/pki/servers/dev/msp.jedo.dev
cp tls-dev-cert.pem /srv/pki/servers/dev/msp.jedo.dev/tls-cert.pem
cp tls-dev-key.pem /srv/pki/servers/dev/msp.jedo.dev/tls-key.pem
cp tls-dev-ca.pem /srv/pki/servers/dev/msp.jedo.dev/tls-ca.pem
```

Die Fabric-CA-Container/Services mounten diese Dateien (oder eine Kopie davon) als `tls/tls-{cert,key,ca}.pem` in das jeweilige MSP-Verzeichnis.

***

## Schritt 9: TLS‑Dateien herunterladen und in Fabric‑CA einbinden

### 9.1. Dateien per `scp` auf die lokale Maschine holen

Auf deiner Workstation:

```bash
# Dev
scp jedo:~/vault/tls-dev-*.pem .

# Test
scp jedo:~/vault/tls-test-*.pem .

# Prod
scp jedo:~/vault/tls-prod-*.pem .
```

Allgemeines Muster:  

```bash
scp user@host:/remote/pfad/datei /lokaler/pfad/
```

### 9.2. In die Orbis‑/Fabric‑CA‑Verzeichnisse kopieren

Beispiel (Dev‑MSP):

- `tls-dev-cert.pem`  → `infrastructure/.../msp.jedo.dev/tls/tls-cert.pem`  
- `tls-dev-key.pem`   → `infrastructure/.../msp.jedo.dev/tls/tls-key.pem`  
- `tls-dev-ca.pem`    → `infrastructure/.../msp.jedo.dev/tls/tls-ca.pem`

In der `fabric-ca-server-config.yaml` der jeweiligen MSP‑CA:

- `tls.certfile` → Pfad zu `tls-cert.pem`  
- `tls.keyfile`  → Pfad zu `tls-key.pem`  
- `csr.ca.certfile` oder entsprechendes CA‑Feld → `tls-ca.pem`.

Damit verwendet jede Orbis‑MSP‑CA künftig ein TLS‑Zertifikat, das von der jeweiligen Vault‑PKI‑Intermediate‑CA ausgestellt wurde.

***

## Schritt 10. Einbindung in Fabric‑CA
In jeder fabric-ca-server-config.yaml der Orbis‑MSP‑CAs werden die TLS‑Dateien aus Vault referenziert:

```bash
tls:
  enabled: true
  certfile: tls/tls-cert.pem
  keyfile: tls/tls-key.pem
  certfiles:
    - tls/tls-ca.pem
```

Die Pfade sind relativ zum Verzeichnis der jeweiligen CA‑Config.
​

Begründung:
- Fabric‑CA benötigt TLS‑Zertifikat und Key für den gRPC/HTTPS‑Endpunkt.
- Das CA‑Zertifikat (tls-ca.pem) bildet die Vertrauenskette zu Vaults Intermediate‑CA.

***

## Schritt 11. Betrieb & Rotation (Hinweise)
- Zertifikatslaufzeit ist durch max_ttl in der Rolle begrenzt (aktuell 720h ≈ 30 Tage).
- Rotation kann automatisiert werden, indem die vault write .../issue/...‑Schritte in ein Script gepackt und die PEM‑Dateien anschließend aktualisiert werden.
​- Die Intermediate‑CAs (in config/ca importiert) sollten seltener rotiert werden; das ist eine CA‑Lifecycle‑Entscheidung.
​

## Schritt 12: Aufräumen auf Vault-Host
Nach erfolgreichem Import in Vault und Übernahme der TLS-Dateien in die Fabric-CAs werden nur folgende Dateien dauerhaft benötigt:

- Vault-Konfiguration und TLS für Vault selbst unter `~/vault/config`
- Vault-Daten unter `~/vault/data`
- PKI-Material (CAs, Intermediates, Server-TLS) unter `/srv/pki/...`

Temporäre Arbeitsdateien können gelöscht werden:
```bash
cd ~/vault
```

JSON-Antworten der letzten Zertifikatsausstellung
```bash
rm -f msp.jedo.*-tls.json
```

temporäre TLS-PEMs (wenn sie bereits unter /srv/pki/servers/... abgelegt sind)
```bash
rm -f tls-dev-.pem tls-test-.pem tls-prod-*.pem
```

Intermediate-Bundles im Arbeitsverzeichnis,
sofern Master-Kopie unter /srv/pki/intermediate/... liegt
```bash
rm -f orbis-dev-intermediate-bundle.pem
rm -f orbis-test-intermediate-bundle.pem
rm -f orbis-prod-intermediate-bundle.pem
```


**Wichtig:** Die Master-Kopien aller CA- und TLS-Dateien liegen unter `/srv/pki/...` und werden dort mit restriktiven Rechten gesichert. Private Keys (`*.key`, `tls-*-key.pem`) werden niemals im Git-Repository abgelegt.

## Wichtige Entscheidungen und Gründe

- **Key‑Import in Vault**: Damit Vault Zertifikate signieren kann, muss der Private Key der Intermediate‑CA im PKI‑Mount liegen; nur das Zertifikat reicht nicht (Fehler „issuer has no key associated with it“).
- **Rollenkonzepte pro Umgebung**: Rollen mit engen `allowed_domains` stellen sicher, dass nur erwartete CN/SANs ausgestellt werden können; das begrenzt Fehlkonfigurationen und Missbrauch.
- **Getrennte Mounts Dev/Test/Prod**: Ermöglicht sauberes Trennen der Trust‑Ketten und unabhängige Rotation/Policy‑Konfiguration pro Stage.
