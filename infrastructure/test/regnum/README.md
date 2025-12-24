# Regnum-CA Inbetriebnahme

Dieses Paket stellt die CA-Infrastruktur für eine Regnum bereit.

## Was bereits vorbereitet ist

Dieses Paket wurde von Orbis/JEDO für deine Regnum-CA vorbereitet.

Folgende Schritte wurden **bereits durchgeführt**:

1. **Schlüsselpaar und CSR erzeugt**  
   - Mit dem Script `scripts/regnum-generate-csr.sh` wurde ein privater Schlüssel für deine Regnum-MSP-CA erzeugt und eine Certificate Signing Request (CSR) erstellt.

2. **Signierung durch die Offline-Orbis-CA**  
   - Die CSR wurde offline von der Orbis-CA geprüft und signiert.
   - Du erhältst von Orbis:
     - das signierte Regnum-CA-Zertifikat (`regnum-msp-ca.cert.pem`)
     - die vollständige Zertifikatskette (`regnum-msp-ca-chain.pem`)
     - die Orbis-MSP-Chain (`config/orbis-msp-chain.pem`)
     - optional die Orbis-TLS-Chain (`config/orbis-tls-chain.pem`).

3. **Installation der Zertifikate in die CA-Struktur**  
   - Mit `scripts/regnum-install-cert.sh` wurden Zertifikat und Chain an die richtigen Stellen in `ca/msp/` kopiert und für den Betrieb der Fabric-CA vorbereitet.

4. **Konfigurationsdatei angelegt**  
   - In `config/regnum-ea.yaml` sind Name, IP, Ports und Passwörter deiner Regnum-MSP-CA bereits eingetragen.
   - Diese Werte kannst du bei Bedarf an deine Umgebung anpassen (z.B. andere IP/Ports).

## Inhalte

- `config/regnum.yaml`  
  Konfiguration (Name, IP, Ports, Passwörter).
- `config/orbis-msp-chain.pem`  
  Vertrauenskette der Orbis-MSP-CA.
- `ca/msp/`  
  Installiertes Regnum-MSP-CA-Zertifikat + Key.
- `scripts/regnum-start-ca.sh`  
  Startet die Regnum-MSP-CA in Docker.

## Voraussetzungen

- Docker installiert.

## Schritte



1. Archive entpacken.
2. In `config/regnum.yaml` IP/Ports ggf. an Umgebung anpassen.
3. CA starten:
```bash
cd scripts
./regnum-start-ca.sh
```
4. Prüfen:
```bash
docker logs msp.ea.jedo.test
curl -k https://<IP>:52041/cainfo
```

Die Regnum-MSP-CA ist dann bereit, um Ager-CAs, Admins und Nodes zu registrieren und zu enrolen.


































***

# Regnum-CA Betrieb

## CA stoppen und mit angepasster Config neu starten

Um Anpassungen an `config/regnum-ea.yaml` oder an der CA-Config vorzunehmen, muss die CA sauber gestoppt und danach mit den neuen Einstellungen neu gestartet werden.

- **CA stoppen**

  ```bash
  # Container-Name aus YAML, z.B. msp.<regnum>.jedo.<tld>
  docker stop msp.<regnum>.jedo.<tld>
  docker rm msp.<regnum>.jedo.<tld>
  ```

  Dadurch wird nur der Container entfernt, die Konfiguration und Zertifikate im gemounteten Volume `ca/msp/` bleiben unverändert erhalten.

- **Config anpassen**

  - `config/regnum-ea.yaml` nach Bedarf anpassen (IP, Ports, Log-Level, etc.).  
  - Falls zusätzlich `ca/msp/fabric-ca-server-config.yaml` geändert werden soll, vorher ein Backup machen und nur Felder anpassen, die nicht in die Kryptographie eingreifen (z.B. Log-Level, Operation-Ports).

- **CA mit neuer Config starten**

  ```bash
  cd scripts
  ./regnum-start-ca.sh
  ```

  Das Script liest die aktualisierte YAML und startet einen neuen Container mit den vorhandenen Zertifikaten und Keys im Ordner `ca/msp/`.

## Vorgehen bei Zertifikatserneuerung (CA-Rollover)

Irgendwann läuft das Regnum-CA-Zertifikat aus oder du möchtest aus Sicherheitsgründen einen Rollover durchführen. Da deine Regnum-CA ein Intermediate unter der Offline-Orbis-CA ist, sollte der Ablauf geregelt sein und mit Wartungsfenster erfolgen.

**1. Vorbereitung: neue CSR generieren**

- Regnum stoppt die CA:

  ```bash
  docker stop msp.<regnum>.jedo.<tld>
  docker rm msp.<regnum>.jedo.<tld>
  ```

- Auf Basis des bestehenden Keys kann entweder:
  - der vorhandene Key weiterverwendet werden (nur neues Zertifikat), oder  
  - ein neues Schlüsselpaar erzeugt werden (empfohlen beim echten Rollover).

- Empfohlener Weg (re-use Key, nur neues Zertifikat):

  ```bash
  cd scripts
  ./regnum-generate-csr.sh
  ```

  Dieses Script erzeugt eine neue CSR im Ordner `ca/msp/` (z.B. `regnum-msp-ca.csr`), die zur Offline-Orbis-CA geschickt wird.

**2. Signiertes Zertifikat + neue Chain von Orbis einspielen**

- Nach der Signierung durch Orbis werden zurückgegeben:

  - `regnum-msp-ca.cert.pem` (neues Intermediate-Zertifikat)  
  - `regnum-msp-ca-chain.pem` (aktuelle Chain; ggf. mit neuer Orbis-Root oder Zwischenstufen).

- Diese Dateien im Pfad `ca/msp/` ersetzen und danach:

  ```bash
  cd scripts
  ./regnum-install-cert.sh
  ```

  Das Script kopiert Zertifikat und Chain an die erwarteten Stellen (`signcerts`, `intermediatecerts`, `cacerts`) im CA-Dateisystem.

**3. CA wieder starten**

- Nach erfolgreicher Installation:

  ```bash
  cd scripts
  ./regnum-start-ca.sh
  ```

- Überprüfung:

  ```bash
  docker logs msp.<regnum>.jedo.<tld>
  curl -k https://<IP>:52041/cainfo
  ```

  Die CA sollte mit dem neuen CA-Zertifikat laufen; bestehende Client-Zertifikate bleiben gültig, solange sie in die neue Chain hineinvalidiert werden können.

**4. Kommunikation an nachgelagerte Teilnehmer**

Damit Peers, Orderer und andere CAs der Regnum-Kette die neue Chain akzeptieren, sollte der Regnum-Betreiber:

- die aktualisierte MSP-Chain (`regnum-msp-ca-chain.pem` und ggf. neue Orbis-Chain) in die jeweiligen `cacerts`/`intermediatecerts` der Org-MSPs verteilen,  
- Genesis-/Channel-Configs bei Bedarf in einem Maintenance-Fenster aktualisieren, falls sich die „Root of Trust“ sichtbar im Consortium ändert.

