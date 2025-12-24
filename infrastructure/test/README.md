# How to install JEDO-Ecosystem on an Unraid-Docker-System

## Regnum-Structure
- regnum/
    - config/
        - regnum.yaml
        - orbis-tls-chain.pem (from Offline-Orbis)
​        - orbis-msp-chain.pem (from Offline-Orbis)
    - ca/
        - msp/ (from orbis signed regnum-certs)
        - tls/ (from orbis signed regnum-certs)
    - scripts/
        - regnum-generate-csr.sh
        - regnum-install-cert.sh
        - regnum-start-ca.sh
    - README.md


## 1. Regnum vorbereiten

### 1.1 Regnum-Paket initial anlegen

Für eine neue Regnum (Ersetze <regnum> z.B. mit `ea`):

1. **Verzeichnis anlegen und Basis-Config kopieren**

   ```bash
   mkdir -p regnum-<regnum>/{config,ca/msp,ca/tls,scripts}
   cp templates/regnum.yaml regnum-<regnum>/config/regnum-.yaml
   ```

   In `regnum.yaml` trägst du Orbis- und Regnum-Werte ein (Name, IP, Ports, Passwörter).

2. **Orbis-Chain-Files bereitstellen**

`orbis-tls-chain.pem` und `orbis-msp-chain.pem` aus Vault exportieren (Root-/Orbis-CA-Zertifikat-Chain) und nach `regnum-<regnum>/config/` legen.  

3. **Scripts in das Paket kopieren**

   - `regnum-generate-csr.sh`  
   - `regnum-install-cert.sh`  
   - `regnum-start-ca.sh`  

   Diese bleiben bei dir; im ausgelieferten Paket kannst du die ersten beiden drin lassen, aber in der README klar als „von Orbis bereits ausgeführt“ markieren.

### 1.2 CSR für Regnum erzeugen

Auf deinem Orbis-Admin-Host (nicht in Vault):

```bash
cd regnum-<regnum>/scripts
./regnum-generate-csr.sh
```

- Ergebnis:  
  - privater Key: `regnum-<regnum>/ca/msp/regnum-msp-ca.key`  
  - CSR: `regnum-<regnum>/ca/msp/regnum-msp-ca.csr`  

Diese CSR brauchst du gleich in Vault zur Signierung.

### 1.3 Signiertes Zertifikat & Chain von Vault einspielen

Nachdem Vault die CSR signiert hat (siehe Abschnitt 2), kopierst du:

- `regnum-msp-ca.cert.pem`  
- `regnum-msp-ca-chain.pem`  

nach `regnum-ea/ca/msp/` und führst aus:

```bash
cd regnum-ea/scripts
./regnum-install-cert.sh
```

Das Script legt:

- `ca/msp/signcerts/cert.pem`  
- `ca/msp/intermediatecerts/chain.cert`  
- `ca/msp/cacerts/orbis-msp-chain.pem`  

an, auf die deine `fabric-ca-server-config.yaml` bzw. dein Start-Script verweist.

### 1.4 Regnum-Paket bündeln und ausliefern

Wenn alles sitzt:

```bash
cd regnum-ea
tar czf regnum-ea-package.tar.gz .
```

Dieses Tarball plus README geht an den Regnum-Betreiber; er muss nur noch `regnum-ea.yaml` anpassen und `regnum-start-ca.sh` ausführen.

***

## 2. CSR in Vault signieren (PKI-Engine)

Hier ein generischer, aber sehr gut etablierter Workflow mit HashiCorp Vault PKI-Engine.

### 2.1 Voraussetzungen in Vault

- Vault ist initialisiert & unsealed.  
- Du hast eine PKI-Engine für Orbis-MSP (z.B. gemountet unter `pki_orbis/`) mit einem Root- oder bereits existierenden Orbis-CA-Zertifikat.

Beispiel-Mount:

```bash
vault secrets enable -path=pki_orbis pki
vault secrets tune -max-lease-ttl=87600h pki_orbis
```

(Bei dir vermutlich schon geschehen; wichtig ist der Mount-Pfad, z.B. `pki_orbis`.)

### 2.2 Regnum-CSR in Vault signieren (Root/Orbis signiert Intermediate)

Angenommen, `regnum-msp-ca.csr` liegt lokal neben deinem Vault-Client.

**a) CSR lesen und als Payload vorbereiten**

```bash
CSR_FILE="regnum-ea/ca/msp/regnum-msp-ca.csr"

cat > payload-regnum.json <<EOF
{
  "csr": "$(sed ':a;N;$!ba;s/\n/\\n/g' ${CSR_FILE})",
  "format": "pem_bundle",
  "ttl": "43800h"  // ca. 5 Jahre, nach Bedarf anpassen
}
EOF
```

**b) Signierung via Root-/Orbis-CA**

Variante mit API (gut skriptbar):

```bash
VAULT_ADDR="https://vault.example.com:8200"
VAULT_TOKEN="<dein_token>"

curl \
  --header "X-Vault-Token: ${VAULT_TOKEN}" \
  --request POST \
  --data @payload-regnum.json \
  ${VAULT_ADDR}/v1/pki_orbis/root/sign-intermediate \
  > regnum-msp-signed.json
```

Aus dem Response extrahierst du Zertifikat + Chain:

```bash
jq -r '.data.certificate' regnum-msp-signed.json > regnum-msp-ca.cert.pem
jq -r '.data.issuing_ca' regnum-msp-signed.json > regnum-msp-ca-chain.pem
```

Je nach Konfiguration enthält `certificate` bereits die komplette Chain; in dem Fall kannst du sie auch als einziges `chainfile` verwenden.

**Alternativ: CLI-Shortcut**

Wenn du lieber die CLI nutzt (Format `pem_bundle`):

```bash
vault write -format=json pki_orbis/root/sign-intermediate \
  csr=@regnum-ea/ca/msp/regnum-msp-ca.csr \
  format=pem_bundle \
  ttl=43800h \
  > regnum-msp-signed.json

jq -r '.data.certificate' regnum-msp-signed.json > regnum-msp-ca.cert.pem
jq -r '.data.issuing_ca' regnum-msp-signed.json > regnum-msp-ca-chain.pem
```

Diese beiden Files verschiebst du dann nach `regnum-ea/ca/msp/` und rufst `regnum-install-cert.sh` auf (siehe 1.3).

### 2.3 Orbis-Chain exportieren (für den Regnum)

Damit der Regnum deine Orbis-Chain als Root of Trust hat, musst du sie einmal aus Vault exportieren:

```bash
# Root-/Orbis-CA-Zertifikat
vault read -field=certificate pki_orbis/cert/ca > orbis-msp-chain.pem
```

Wenn du eine eigene TLS-CA in Vault hast (zweiter PKI-Mount z.B. `pki_orbis_tls/`), analog:

```bash
vault read -field=certificate pki_orbis_tls/cert/ca > orbis-tls-chain.pem
```

Diese Dateien legst du im Regnum-Paket nach `config/` und referenzierst sie in `regnum-ea.yaml` sowie in `regnum-install-cert.sh`.

***

## 3. Renewal/Rollover aus Orbis-Sicht

Wenn du später einen Rollover machst (neues Regnum-CA-Zertifikat):

1. **Neue CSR mit deinem Script generieren**

   ```bash
   cd regnum-ea/scripts
   ./regnum-generate-csr.sh
   ```

2. **CSR in Vault wieder über `pki_orbis/root/sign-intermediate` signieren** (wie oben), neue `regnum-msp-ca.cert.pem` und `regnum-msp-ca-chain.pem` erzeugen.

3. **`regnum-install-cert.sh` laufen lassen**, um die neuen Zertifikate einzuspielen.

4. Dem Regnum-Betreiber kurz dokumentieren, dass er seine CA einmal stoppen, dein aktualisiertes Paket/Cert einspielen und wieder starten soll (wie in der README-Erweiterung)

