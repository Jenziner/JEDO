# JEDO-Ecosystem: Orbis-Kompetenzen & Governance-Framework
## Gesamtzusammenfassung der Konzeptionsdiskussion

**Datum:** 8. Dezember 2025  
**Status:** Abgeschlossen & definiert

***

## Inhaltsverzeichnis

1. [Systemübersicht](#1-systemübersicht)
2. [Strukturelle Hierarchie](#2-strukturelle-hierarchie)
3. [Technische Infrastruktur](#3-technische-infrastruktur)
4. [Wallet-Management & On-Ramp](#4-wallet-management--on-ramp)
5. [Governance & Abstimmungen](#5-governance--abstimmungen)
6. [Wahlen](#6-wahlen)
7. [Stimmrecht](#7-stimmrecht)
8. [Sicherheits-Rat](#8-sicherheits-rat)
9. [Dispute Resolution](#9-dispute-resolution)
10. [Liquidation](#10-liquidation)
11. [Accountability & Nachfolge](#11-accountability--nachfolge)
12. [Weitere Regelungen](#12-weitere-regelungen)
13. [Orbis-Kompetenzen (Übersicht)](#13-orbis-kompetenzen-übersicht)

***

## 1. Systemübersicht

### 1.1 Grundprinzipien
- **Währung:** JEDO (J) – digitales Token für alltägliche Transaktionen
- **Wertbindung:** BigMac-Index (10 JEDO = 1 BigMac weltweit)
- **Limitierung:** Maximale JEDO-Mengen pro Person/Organisation (Spekulationsverhinderung)
- **Technologie:** Hyperledger Fabric 3.0 mit SmartBFT Consensus
- **Governance:** Basisdemokratisch mit Zweikammer-System

### 1.2 Föderale Struktur
- **ORBIS:** Globale Ebene (1 Instanz)
- **REGNUM:** Kontinentale Ebene (5 Instanzen: EA, AS, AF, NA, SA)
- **AGER:** Regionale Ebene (preisähnliche Gebiete, geschätzt 135-180 weltweit)
- **GENS:** Organisationen
- **HUMAN:** Einzelpersonen

***

## 2. Strukturelle Hierarchie

### 2.1 ORBIS
- **Anzahl:** 1 weltweit
- **Funktion:** Technische Infrastruktur-Koordination, minimale operative Kompetenzen
- **Wahl:** Durch alle Humans weltweit (absolutes Mehr >50%)
- **Amtszeit:** 4 Jahre mit Vertrauensabstimmung

### 2.2 REGNUM
- **Anzahl:** 5 (EA: Europa/Naher Osten, AS: Asien/Ozeanien, AF: Afrika, NA: Nordamerika, SA: Südamerika)
- **Funktion:** Intermediate-CA-Betrieb, Channel-Verwaltung, regionale Koordination
- **Wahl:** Durch Humans des jeweiligen Regnum (absolutes Mehr >50%)
- **Amtszeit:** 4 Jahre mit Vertrauensabstimmung
- **Nachfolge-Pool für Orbis:** Bei Orbis-Ausfall wählt Blockchain zufällig einen Regnum als Nachfolger

### 2.3 AGER
- **Anzahl:** Geschätzt 135-180 weltweit (basierend auf BigMac-Index-Homogenität ±15%)
- **Funktion:** Operativer Betrieb (Orderer, Peers, API-Gateway, CA), On-Ramp-Verwaltung
- **Wahl:** Durch Humans des jeweiligen Ager (absolutes Mehr >50%)
- **Amtszeit:** 4 Jahre mit Vertrauensabstimmung
- **Aufteilung:** Bei >10 Mio. USDT in BTC-Wallets wird Aufteilung empfohlen (nicht erzwungen)

### 2.4 Rollentrennung
- **Organisatorisch:** Orbis ≠ Regnum ≠ Ager (keine Doppelrollen)
- **Bootstrap-Phase:** Initial ist Gründer alle Rollen, organische Trennung mit Wachstum
- **Technisch nicht erzwungen:** System erlaubt Doppelrollen, wird aber transparent dokumentiert

***

## 3. Technische Infrastruktur

### 3.1 Certificate Authority (CA) Hierarchie

#### Orbis (zentral)
- **Root-CA (offline, manuell):** rca.jedo.me
  - Erstellt & erneuert nur die 5 Regnum-Zertifikate
  - Veröffentlicht CRLs (Certificate Revocation Lists) bei Kompromittierung
  - **Backup:** Verschlüsselt mit 5-of-5 Shamir Secret Sharing bei allen Regnum
- **TLS-CA (online):** tls.jedo.me
  - Zentral für alle Nodes (keine Intermediate-TLS-CAs)
- **Root-MSP-CA:** ca.jedo.me

#### Regnum (5x dezentral)
- **Intermediate-MSP-CA:** ca.ea.jedo.me, ca.as.jedo.me, etc.
- Stellt Zertifikate für alle Ager des Regnum aus

#### Ager (viele dezentral)
- **Intermediate-MSP-CA** ca.jura.ea.jedo.me etc.
- Enrollen Orderer/Peers bei Regnum-MSP-CA
- Holen TLS-Zertifikate von Orbis-TLS-CA
- Stellt Zertifikate für alle Gens und Human des Ager aus

### 3.2 Genesis-Blocks (Fabric 3.0)
- **Kein System-Channel mehr** (seit Fabric 2.3+)
- **Application-Channel-spezifisch:** Jeder Channel hat eigenen Genesis-Block
- **Orbis-Aufgabe:** Archivierung aller Channel-Genesis-Blocks
- **Verwendung:** Nur beim Channel-Setup, danach archivierbar
- **Zugang:** Nur legitimierte Ager erhalten Genesis-Block (via Governance)
- **Orbis-Channel:** Separater Channel für zentrale Seed-Registry (Infrastruktur- + On-Ramp-Wallets)

### 3.3 DNS-Verwaltung
- **Orbis-Kompetenz:** Hält *.jedo.me Domain

### 3.4 Cross-Regnum-Node-Beteiligung
- **Prinzip:** Jeder Regnum betreibt Nodes in allen anderen Regnum-Channels
- **Umfang:** 4 Ager pro fremdem Regnum → 2 Orderer + 2 Peers
- **Zweck:** Politische Isolation verhindern, Cross-Channel-Transaktionen ermöglichen
- **Status:** **Nicht MVP** (erst mit Erfahrung)

### 3.5 Finanzierung
- Abstimmung definiert Höhe der Entschädigung von Orbis, Regnum und Ager
- Finanzierung durch Steuern von Human/Gens an Ager, an Regnum, an Orbis
- Steuermodell 50% über Anzahl der Unterstruktur, 50% über Anzahl Human aufgeteilt, Ager-Steuer 100% über Human (pro Kopf Steuer, unabhängig von Vermögen, Aktivität, Beitrittsdauer per Stichdatum: 1.1.des Jahres um 00:00 Uhr UTC
- Jede Stufe bestimmt mittels Abstimmung über diese Stufe, ob die Auszahlung erfolgt mittels Auszahlung in BTC ab Infrastruktur-Wallet, Minten von neuen JEDO oder Ausbezahlen von bestehenden Jedo (Steuer)

***

## 4. Wallet-Management & On-Ramp

### 4.1 Wallet-Typen

#### Infrastruktur-Wallets (max. 10.000 USDT)
**Zweck:** Operative Kosten (AWS, Domains, etc.)

**Seed-Management (3-Tier):**
- **Tier 1:** Verschlüsselt mit eigenem Zertifikat (normale Nutzung)
- **Tier 2:** Verschlüsselt mit Parent-Zertifikat (Recovery)
  - Ager → Regnum kann lesen
  - Regnum → Orbis kann lesen
  - Orbis → alle 5 Regnum können gemeinsam lesen (5-of-5)
- **Tier 3:** Shamir 6-of-6 (alle Regnum + Orbis) für Notfall

**Speicherort:**
- Seeds im Orbis-Channel (zentrale Registry)
- Verschlüsselt je nach Tier

#### On-Ramp-Wallets (max. 10 Mio. USDT empfohlen)
**Zweck:** FIAT→JEDO Konversion (Bitcoin als Reserve)

**Seed-Management (2-Tier):**
- **Tier 1:** Verschlüsselt mit Ager-Zertifikat (normale Nutzung)
- **Tier 2:** Shamir 6-of-6 (alle Regnum + Orbis) für Notfall/Nachfolge

**Speicherort:**
- Seeds im Orbis-Channel
- Alle Wallet-Adressen + Transaktionshistorie öffentlich (Community-Überwachung)

**Limitierung:**
- **10 Mio. USDT:** Empfohlenes Maximum pro Ager-Wallet
- Bei Überschreitung: Anreiz zur Ager-Aufteilung (nicht erzwungen, in Verordnung verankert)

### 4.2 FIAT-Einzahlung (On-Ramp)
**Prozess:**
- **Self-Custody:** Jeder Ager verwaltet eigenes Bitcoin-Wallet (Cold-Wallet)
- **Mint-Funktion:** Ager gibt BTC-Betrag in Chaincode ein → mintet JEDO nach BigMac-Index
- **Transparenz:** Mint ist public, jeder kann prüfen ob BTC-Transaktion übereinstimmt
- **Frequenz:** Ager-spezifisch (manuell, automatisiert, je nach Bedarf)
- **Keine externen Provider:** Kein Coinbase, keine Banken (Purismus-Ansatz)

### 4.3 FIAT-Verwendung
**Reserve-Zweck:**
- **Infrastrukturkosten:** AWS, Alibaba, Domains (FIAT-Rechnungen)
- **Liquidations-Reserve:** Bei Systemende für gemeinnützige Zwecke

**Verbrennen vs. Reserve:**
- FIAT wird NICHT verbrannt
- Bitcoin-Reserve wird transparent gehalten
- Bei Liquidation: Stiftung für gemeinnützige Zwecke (kein persönlicher Profit)


**Kein Rücktausch:** JEDO→FIAT ist nicht möglich (Einbahnstraße)

***

## 5. Governance & Abstimmungen

### 5.1 Regelwerk-Hierarchie

| Ebene | Regelwerk | Geltungsbereich | Quorum (1./2./3. Abstimmung) | Kammern |
|---|---|---|---|---|
| **ORBIS** | Manifest (Verfassung) | Global | >80% / >60% / >50% | 2 Kammern |
| **REGNUM** | Gesetz | Regnum-weit | >80% / >60% / >50% | 2 Kammern |
| **REGNUM** | Verordnung | Regnum-weit | >80% / >60% / >50% | 2 Kammern |
| **AGER** | Gesetz | Ager-intern | >80% / >60% / >50% | 1 Kammer |
| **AGER** | Verordnung | Ager-intern | >80% / >60% / >50% | 1 Kammer |

**Hierarchie-Prinzip:**
- Verordnung darf nur regeln, was Gesetz erlaubt
- Gesetz darf nur regeln, was Verfassung erlaubt
- Bei Widerspruch: Höhere Ebene geht vor

### 5.2 Zwei-Kammer-System

#### ORBIS-Abstimmungen (z.B. Manifest-Änderung)

**Prozess:**
1. **Regnum-interne Abstimmung:** Jedes Regnum führt eigenes Zweikammer-Voting durch
2. **Orbis-Ebene:**
   - **Kammer 1 (Regnum):** Anzahl Regnum die intern ≥Quorum erreichten
     - 1. Abstimmung: >80% (= alle 5 Regnum einstimmig)
     - 2. Abstimmung: >60% (= mind. 4 von 5)
     - 3. Abstimmung: >50% (= mind. 3 von 5)
   - **Kammer 2 (Humans):** Alle Humans weltweit (gleiche Quoren)

**Beide Kammern müssen Quorum erreichen.**

#### REGNUM-Abstimmungen (z.B. Steuer-Gesetz)

**Beide Kammern:**
- **Kammer 1 (Ager):** Ager dieses Regnum
- **Kammer 2 (Humans):** Humans dieses Regnum
- Gleiche Quoren wie oben (je nach Gesetz/Verordnung)

#### AGER-Abstimmungen (z.B. Stimmrecht-Parameter)

**Nur 1 Kammer:**
- Humans dieses Ager
- Gleiche Quoren wie oben

### 5.3 Mehrfach-Abstimmungen

**Mechanik:**
- Wird Quorum verfehlt → automatisch 2. Abstimmung (niedrigeres Quorum)
- Maximal 3 Abstimmungen, danach ist Vorlage abgelehnt
- **Cool-Down zwischen Abstimmungen:** Dauer = Abstimmungsdauer selbst
  - Normal: 30 Tage Abstimmung → 30 Tage Cool-Down
  - Kritisch (Sicherheits-Rat): 7 Tage Abstimmung → 7 Tage Cool-Down

**Zweck:** Zeit für Diskussion, Kompromissfindung, Überzeugungsarbeit

### 5.4 Abstimmungsreichweite
- **Manifest:** Alle Humans weltweit (via Zweikammer-System)
- **Regnum-Gesetz/Verordnung:** Nur Ager + Humans dieses Regnum
- **Ager-Gesetz/Verordnung:** Nur Humans dieses Ager

***

## 6. Wahlen

### 6.1 Wahl-Verfahren (für Orbis/Regnum/Ager)

| Wahlgang | Regelung | Gewählt bei |
|---|---|---|
| **1-2** | Alle wählbaren Humans können kandidieren | >50% (absolutes Mehr) |
| **Ab 3** | Keine neuen Kandidaten, Person mit wenigsten Stimmen scheidet aus | >50% (absolutes Mehr) |
| **Endlos** | Weiterwählen bis jemand >50% erreicht | >50% (absolutes Mehr) |

**Bei Patt (z.B. 50:50):**
- Nach 3 aufeinanderfolgenden Wahlgängen ohne absolutes Mehr → Wahl wird vertagt
- 30 Tage Bedenkzeit → Neuwahl mit frischen Kandidaturen

**Cool-Down:**
- Gleiche Regelung wie bei Abstimmungen (30 Tage nach Wahlgang)

### 6.2 Wahlberechtigung
- Gleiche Kriterien wie Stimmrecht (siehe Kapitel 7)

***

## 7. Stimmrecht

### 7.1 Voraussetzungen (kumulative UND-Verknüpfung)
Gilt für den Zeitpunkt der Stimmabgabe (Regelprüfung):
1. **≥10 JEDO Vermögen** (Mindestbetrag)
2. **≥12 Transaktionen in letzten 12 Monaten** (Aktivität)
3. **≥6 Monate Zugehörigkeit zum Ager** (Senioritäts-Schutz gegen Fake-Accounts)

**Alle drei Parameter in Verordnung verankert (Ager-Ebene) → anpassbar**

### 7.2 Prinzipien
- **1 Human = 1 Stimme** (nicht gewichtet nach Vermögen)
- **Binäres Stimmrecht:** Stimmberechtigt oder nicht (keine Abstufungen)
- **Zweck:** Schutz vor Fake-Humans, Sybil-Angriffen, Plutokratie

### 7.3 Sicherheitsmechanismen gegen "51%-Angriffe"
1. **Zertifikat-Pflicht:** Jeder Human braucht Ager-Zertifikat
2. **Vermögen + Aktivität:** 1000 Fake-Humans = 10.000 JEDO + 12.000 Transaktionen/Jahr
3. **JEDO-Limitierung:** Einzelperson kann nicht unbegrenzt akkumulieren
4. **Zweikammer-System:** Selbst bei kompromittierten Humans → Ager-Kammer muss zustimmen
5. **Transparenz:** Plötzlich viele neue Humans = öffentlich sichtbar → Misstrauensvotum

***

## 8. Sicherheits-Rat

### 8.1 Struktur
- **6 Mitglieder:** 1 pro Regnum + Orbis (Vorsitz)
- **Wahl:** Jedes Regnum wählt seinen Vertreter (>50%), Orbis wird separat gewählt
- **Amtszeit:** 2 Jahre (in Manifest/Verfassung fest)
- **Rücktritt:** Jederzeit möglich, 6 Monate Übergangszeit für Nachfolger-Wahl (gilt auch für Orbis, Regnum und Ager)
- **Durchmischung:** Organisch durch vorzeitige Rücktritte (kein künstlicher Versatz)

### 8.2 Kompetenzen

#### Notfall-Updates (kritische Sicherheitslücken)

**Abstimmung im Rat:**
- 1. Abstimmung: einstimmig (6 von 6)
- 2. Abstimmung: >80% (mind. 5 von 6)
- 3. Abstimmung: >60% (mind. 4 von 6)

**Gestaffelter Rollout:**
1. Sicherheits-Rat legt Rollout-Plan fest (Reihenfolge, Zeitplan)
2. Schrittweise Implementierung (z.B. Regnum 1 → Regnum 2 → ...)
3. **Cross-Channel-Transaktionen gesperrt während Rollout**
4. Beobachtungsphase nach jedem Schritt (zB 48h Monitoring)
5. Bei Fehler: Rollback nur für betroffene Regnum
6. Nach vollständigem Rollout: Cross-Channel wieder aktiviert

**Nachträgliche Ratifizierung (innerhalb 30 Tagen):**
- Abstimmung je nach betroffener Regelwerk-Ebene (Manifest/Gesetz)
- Bei Ablehnung: Gestaffelter Rollback + Sicherheits-Rat abgewählt

#### Fast-Track-Vorschläge (zeitkritisch, nicht kritisch)

**Abstimmungsdauer:**
- **Rollback nötig:** 7 Tage
- **Neue Änderung nötig:** 30 Tage

**Sicherheits-Rat muss vorher:**
- Schweregrad einschätzen
- Lösungsweg vorschlagen
- Begründung publizieren

**Normale Quoren gelten** (>80%/>60%/>50%)

### 8.3 Transparenz & Missbrauchsschutz
- **Code-Transparenz:** Alle Chaincode-Versionen auf GitHub/IPFS
- **Code-Diffs:** Bei jedem Update öffentlich
- **Community-Review:** 7 Tage nach Update
- **Automatische Ratifizierung:** Nach 30 Tagen MUSS abgestimmt werden
- **Bei Ablehnung:** Gestaffelter Rollback + Rat wird abgesetzt + Neuwahl (14 Tage)

***

## 9. Dispute Resolution

### 9.1 Szenario A: Kompromittierter Ager

**Sofortmaßnahme:**
- **Regnum sperrt Ager-Zertifikat** (ohne Vorab-Abstimmung)
- Technische Folge: Ager-Nodes (Orderer, Peers, CA, Gateway) ungültig
- System läuft weiter über andere Ager

**Retro-Abstimmung (innerhalb 30 Tagen):**
- Regnum-Abstimmung gemäss Kapitel Abstimmung
- **Bei Bestätigung:** Sperrung bleibt, Neuwahl Ager
- **Bei Ablehnung:** Sperrung aufgehoben, Regnum abgewählt (Missbrauch)

**Auswirkungen:**
- Humans des gesperrten Ager können weiter transaktieren & voten (Ager ist nur Infrastruktur)
- On-Ramp blockiert (müssen anderen Ager nutzen)
- Migration zu anderem Ager jederzeit möglich

### 9.2 Szenario B: Kompromittiertes Regnum

**Delegation an Sicherheits-Rat:**
- Sicherheits-Rat beschließt Sperrung gemäss Kapitel Sicherheits-Rat
- **Konsequenz:** Gesamter Regnum-Channel offline (1/5 des Netzwerks)
- **Akzeptiert:** Besser als kompromittiertes Regnum weiterlaufen lassen
- Kompromitierter Regnum tritt bei persönlicher Betroffenheit in Ausstand

**Retro-Abstimmung (innerhalb 30 Tagen):**
- Orbis-Abstimmung gemäss Kapitel Abstimmung
- **Bei Bestätigung:** Neuwahl Regnum, Re-Bootstrap des Channels
- **Bei Ablehnung:** Sperrung aufgehoben, Sicherheits-Rat abgewählt

**Alternative:** Wenn sanftere Lösung möglich → Sicherheits-Rat kann auch anders als mit Sperrung entscheiden

### 9.3 Szenario C: Kompromittierter Orbis

**Delegation an Sicherheits-Rat:**
- **Orbis tritt in Ausstand** (nur 5 Regnum entscheiden)
- Sicherheits-Rat beschließt Sperrung (Einstimmigkeit: 5 von 5 Regnum)

**Root-CA-Backup:**
- Verschlüsselt mit 5-of-5 Shamir bei allen Regnum
- Bei Orbis-Kompromittierung: Regnum rekonstruieren Root-CA gemeinsam
- Generieren neue Root-CA → stellen neue Regnum-Zertifikate aus
- **Netzwerk-weiter Re-Bootstrap** (alle Ager bekommen neue Zertifikate)

**Retro-Abstimmung (innerhalb 30 Tagen):**
- Orbis-Abstimmung gemäss Kapitel Abstimmung
- **Bei Bestätigung:** Neuwahl Orbis (oder Regnum übernimmt dauerhaft)
- **Bei Ablehnung:** Kein Rollback (geht nur vorwärts), aber Sicherheits-Rat neu gewählt

### 9.4 Regelkonflikte

**Szenario:** Zwei Ager haben widersprüchliche Verordnungen → Cross-Channel-Transaktionen blockiert

**Prozess:**
1. Sicherheits-Rat analysiert Konflikt
2. Gibt **Empfehlung** an betroffene Ager (keine Diktatur)
3. Ager haben 30 Tage Zeit, Regelkonflikt zu lösen
4. **Ultima Ratio:** Bei Nicht-Befolgung kann Sicherheits-Rat Cross-Channel für diesen Ager blockieren (Chaincode-Level)

**Schutz durch Hierarchie-Prinzip:** Sollte selten vorkommen (Verordnung darf nur regeln, was Gesetz erlaubt)

***

## 10. Liquidation

### 10.1 Auslöser
- **Geordnete Liquidation:** Governance-Beschluss (Manifest-Änderung durch Abstimmung)
- **Zwangsliquidation:** Ager, oder Regnum kann Steuern nicht mehr bezahlen (keine JEDO/BTC vorhanden)

### 10.2 Prozess

#### Geordnete Liquidation (mit Vermögen)

**Vorbereitung:**
1. **6 Liquidatoren werden ernannt** (1 pro Regnum + Orbis)
   - Müssen externe Personen sein (keine aktive Rolle im System)
   - Werden vor der Liquidations-Abstimmung gewählt
2. **Wallet-Sammlung:** Liquidatoren sammeln alle Ager-On-Ramp-Wallets auf 1-n Liquidations-Wallets
3. **Abstimmung kann erst enden, wenn Sammlung abgeschlossen**
4. **Während Sammlung:** Keine Ein-/Auszahlungen möglich (JEDO läuft weiter)

**Bei Ablehnung:**
- 100+ Rück-Transaktionen nötig (Wallets zurück an Ager)
- Kostet Geld (Teil der Liquidations-Kosten)
- Akzeptiert

**Bei Annahme:**
- Liquidatoren erhalten Multi-Sig-Zugang zur Krypto-Reserve (6-of-6)
- Gründen Stiftung für gemeinnützige Zwecke oder JEDO-2.0-Projekt
- Kein persönlicher Profit (eliminiert Sabotage-Anreiz)

**Timing-Angriff-Schutz:**
- Böswilliger Ager könnte BTC abziehen bevor Liquidatoren sammeln
- Mitigation: Transparent on-chain nachweisbar → rechtliche Verfolgung + sozialer Ausschluss
- Liquidatoren können Anzeige wegen Diebstahl erstatten (landesspezifisch)

**Timing-Angriff-Schutz:**
- Böswilliger Ager könnte BTC abziehen bevor Liquidatoren sammeln
- Mitigation: Transparent on-chain nachweisbar → rechtliche Verfolgung + sozialer Ausschluss
- Liquidatoren können Anzeige wegen Diebstahl erstatten (landesspezifisch)

#### Zwangsliquidation (ohne Vermögen)

**Szenario:** Ager kann kann Regnum-Steuern nicht zahlen, Regnum kann Orbis nicht zahlen

**Solidaritäts-Mechanismus:**
- Andere Ager können einspringen (freiwillige Überweisung)
- Bei Nicht-Einspringen: Goodwill & Enthusiasmus als letzter Mechanismus
- **Risiko akzeptiert:** Bei Systemversagen ist Zwangsliquidation akzeptabel

**Liquidatoren-Rolle:**
- Können rechtliche Schritte gegen böswillige Ager einleiten (Diebstahl)
- Erfolg unsicher (verschiedene Rechtssysteme)
- Rest: Soziale Konsequenzen

### 10.3 Liquidations-Reserve (Bitcoin)

**Zweck:**
1. **Transparenz:** Extrinsischer vs. intrinsischer Wert im System sichtbar
2. **Vertrauensbildung:** Zeigt reale Wertunterlegung
3. **Notfall-Liquidierung:** Für gemeinnützige Zwecke (kein Profit für Humans)

**Kein Sabotage-Anreiz:** Niemand profitiert persönlich vom Systemkollaps

### 10.4 Diebstahl und andere Vergehen
Diebstahl von BTC und andere Vergehen gemäss lokalem Recht werden über bestehende Mechanismen angezeigt und geahndet, je nach geltendem Rechtsraum

***

## 11. Accountability & Nachfolge

### 11.1 Misstrauensvoten (Bottom-Up)

**Ager-Ebene:**
- **Initiierung:** Jeder Human kann Misstrauensvotum gegen seinen Ager initiieren
- **Abstimmung:** Ager-intern gemäss Kapitel Abstimmung
- **Folge:** Bei Annahme → Neuwahl Ager

**Regnum-Ebene:**
- **Initiierung:** Jeder Ager kann Misstrauensvotum gegen sein Regnum initiieren
- **Abstimmung:** Regnum-intern  gemäss Kapitel Abstimmung
- **Folge:** Bei Annahme → Neuwahl Regnum

**Orbis-Ebene:**
- **Initiierung:** Jedes Regnum kann Misstrauensvotum gegen Orbis initiieren
- **Abstimmung:** Orbis-Ebene gemäss Kapitel Abstimmung
- **Folge:** Bei Annahme → Neuwahl Orbis

### 11.2 Automatische Vertrauensabstimmung
- **Alle 4 Jahre:** Obligatorische Vertrauensabstimmung für Orbis/Regnum/Ager
- **Gleichzeitig mit Amtszeit-Ende:** Kann zu Wiederwahl oder Neuwahl führen
- **Quoren:** Gleiche wie bei Wahlen (>50%)
- Wiederwahl ist nicht beschränkt weil mit technischer Migration verbunden

### 11.3 Nachfolge-Mechanismus

**Orbis-Ausfall (z.B. nicht mehr verfügbar):**
- **Blockchain verlangt monatliche Interaktion** vom Orbis ("Lebenszeichen")
- Bei Ausfall: Blockchain wählt zufällig einen Regnum als Orbis-Nachfolger
- Regnum übernimmt Orbis-Rolle temporär
- Vertrauensabstimmung Orbis  gemäss Kapitel Wahl
- Allenfalls Neuwahl Regnum  gemäss Kapitel Wahl

**Orbis-Instruktionen (Root-CA, etc.):**
- Orbis hinterlegt "Adresse" im Blockchain-Record (z.B. Notar, Tresor)
- Nachfolger kann Instruktionen abholen (physisches Backup)

**Regnum/Ager-Nachfolge:**
- Bei Rücktritt: 6 Monate Übergangszeit für Wahl & Etablierung
- Bei Abwahl: Sofortige Neuwahl gemäss Kapitel Wahl
- Bei Ausfall Regnum: Analog Ausfall Orbis mit Ager
- Bei Ausfall Ager: siehe Kompromitierung
***

## 12. Weitere Regelungen

### 12.1 Steuern & Finanzierung

**Hierarchie:**
- **Human → Ager:** Steuer-Einnahmen für Ager-Infrastruktur
- **Ager → Regnum:** Solidarische Umverteilung für Regnum-Infrastruktur
- **Regnum → Orbis:** Finanzierung von Orbis-Betrieb (DNS, CA-Verwaltung)

**Festlegung:**
- **In Verordnung verankert**
- Via Governance-Abstimmung änderbar
- **Zwangsmechanismus:** Chaincode zieht automatisch Steuern ein (transparent, konsequent)

**Bei Zahlungsunfähigkeit:**
- **Human:** Sofortige Sperrung für Transaktionen und Voting, solidarische Umverteilung auf verbleibende Human
- **Ager:** Solidarische Umverteilung auf verbleibende Ager des Regnum
- **Regnum:** Solidarische Umverteilung auf verbleibende Regnum
- **Kein Verschulden:** Ager/Regnum kann nicht ins Minus (verhindert Schuldengesellschaft)

### 12.2 Inflation & Geldschöpfung

**Gemeinnützigkeits-Prinzip:**
- Human oder Gens stellt Projekt/Arbeit als gemeinnützig zur Abstimmung
- Inkl. Anzahl benötigter JEDO (= Mehrwert für Gemeinschaft)
- Bei Annahme: JEDO werden nach Abstimmung gemintet und nach gewählten Auszahlungsprinzip ausbezahlt
- **Inflations-Kontrolle:** Bei der Gemeinschaft (keine Zentralbank)

**Keine willkürliche Geldschöpfung** für Infrastruktur-Entschädigung → nur via Steuern oder Infrastruktur-Wallet

### 12.3 BigMac-Index-Updates

**Kompetenz:** Ager (nicht Orbis)
- Jeder Ager bestimmt seinen Index selbst (via Verordnung)
- Ager sind preisähnliche Gebiete → kennen lokale Wirtschaftsrealität am besten
- Änderung via Abstimmung (verhindert Willkür)

### 12.4 Massenabwanderung & Ager-Auflösung

**Physische Migration:**
- Ager bleibt funktional
- Humans migrieren organisiert (Umzugsmechanismus im System)
- Kein spezieller Handlungsbedarf

**JEDO-Flucht (Misstrauen):**
- Entspricht faktisch Misstrauensvotum
- Wer flieht, kann nicht an Korrektur mitwirken
- Verbleibende Humans können Ager-Auflösung beschließen

**Abgestellter Ager:**
- Regnum kann als Human Auflösungs-Abstimmung initiieren
- Humans haben immer Wallet-Zugriff + Stimm-/Wahlrecht (unabhängig von technischem Ager-Status)

**Keine Zwangsliquidierung:**
- Ager kann so klein werden wie er will (solange Infrastruktur finanziert)
- Selbst bei 1 Human: Solange funktional, keine Auflösung erzwungen

**Generell:**
- Intra-Regnum Umzug: Einfach, da gleicher Channel, nur Ager-Zertifikat wechselt
- Inter-Regnum Umzug: Aufwändiger, da Cross-Chain, aber als Aufgabe bei Cross-Channel zu berücksichtigen

***

## 13. Orbis-Kompetenzen (Übersicht)

### 13.1 Zentrale Kompetenzen (nicht dezentralisierbar)

| Kompetenz | Beschreibung | Entschädigung |
|---|---|---|
| **Root-CA (offline)** | Generierung & Erneuerung der 5 Regnum-Zertifikate | Via Steuern (Regnum → Orbis) |
| **TLS-CA (online)** | Zentrale TLS-Zertifikate für alle Nodes | Via Steuern |
| **Root-MSP-CA** | Root-Identity-CA für MSP-Hierarchie | Via Steuern |
| **DNS-Verwaltung** | *.jedo.me Domain-Verwaltung | Via Steuern + Chaincode-Entschädigung |
| **Genesis-Block-Archivierung** | Verwahrung aller Channel-Genesis-Blocks | Via Steuern |
| **Sicherheits-Rat-Vorsitz** | Koordination bei Notfall-Governance | Ehrenamt (keine Extra-Entschädigung) |

### 13.2 Dezentralisierte Funktionen (Orbis NICHT zuständig)

| Funktion | Zuständig | Mechanismus |
|---|---|---|
| **Governance-Abstimmungen** | Chaincode (automatisch) | Stimmen werden on-chain ausgezählt |
| **BigMac-Index-Updates** | Ager | Via Verordnung |
| **Steuerfestsetzung** | Ager/Regnum | Via Verordnung |
| **Geldschöpfung** | Community | Gemeinnützigkeits-Abstimmung |
| **Zertifikatssperrung** | Regnum oder Sicherheits-Rat | Retro-Abstimmung erforderlich |

### 13.3 Orbis-Schutzmechanismen gegen Machtmissbrauch

1. **Minimale Kompetenzen:** Nur technische Infrastruktur, keine Governance-Macht
2. **Transparenz:** Alle Aktionen on-chain nachvollziehbar
3. **Accountability:** 4-Jahres-Amtszeit + Misstrauensvoten jederzeit möglich
4. **Root-CA-Backup:** Bei Kompromittierung können Regnum übernehmen (5-of-5 Shamir)
5. **Finanzielle Limitierung:** Nur Infrastruktur-Entschädigung, kein Vermögensaufbau
6. **Nachfolge-Automatik:** Bei Ausfall wählt Blockchain zufälligen Regnum als Nachfolger

***

## Anhang: Geschätzte Ager-Verteilung

| Regnum | Geschätzte Ager | Begründung |
|---|---|---|
| **EA (Europa/Nahost)** | 35-45 | Hohe Fragmentierung (Nord-Süd- und West-Ost-Gefälle) |
| **AS (Asien/Ozeanien)** | 40-55 | China/Indien mit hohen internen Unterschieden, Südostasien fragmentiert |
| **AF (Afrika)** | 10-20 | Eher homogen bezüglich BigMac-Index, dafür kulturell und religiös fragmentiert |
| **NA (Nordamerika)** | 25-35 | USA sehr heterogen (Kalifornien vs. Arkansas ±30%), Kanada moderat |
| **SA (Südamerika)** | 12-18 | Brasilien fragmentiert, Rest homogener |
| **GESAMT** | **135-180** | Basierend auf BigMac-Index-Homogenität ±15% |

***

## Schlussbemerkung

Dieses Dokument fasst alle abgeschlossenen und definierten Punkte der Diskussion vom 8. Dezember 2025 zusammen. Es dient als Grundlage für:

1. **Regelwerk-Ausarbeitung** (Manifest, Gesetze, Verordnungen)
2. **Job-Profile** (Orbis, Regnum, Ager)
3. **Recovery-Tool Epic** (Seed-Management, Shamir-Implementierung)

### Regelwerk-Ausarbeitung

***

# Aufgabe: JEDO-Ecosystem Regelwerk-Ausarbeitung

Du bist ein Experte für dezentrale Governance-Systeme und juristische Dokumentenstruktur. Basierend auf dem beigefügten Konzeptdokument "KonzeptWorkshop-20251208.md" sollst du konkrete Regelwerk-Entwürfe erstellen.

## Kontext
Das JEDO-Ecosystem ist ein dezentrales, digitales Geldsystem mit föderaler Struktur (Orbis → Regnum → Ager → Gens → Human). Es nutzt Hyperledger Fabric 3.0 mit basisdemokratischer Governance.

## Deine Aufgabe
Erstelle drei separate Regelwerk-Dokumente:

### 1. Manifest (Verfassung) – Orbis-Ebene
- **Geltungsbereich:** Global für gesamtes JEDO-Ecosystem
- **Änderungsquorum:** >80% / >60% / >50% (3 Abstimmungsrunden)
- **Inhalt:**
  - Grundprinzipien & Werte
  - Föderale Struktur (Orbis/Regnum/Ager/Gens/Human)
  - Grundrechte & -pflichten
  - Governance-Mechanismen (Zweikammer-System)
  - Sicherheits-Rat
  - Liquidations-Prozedur
  - Nicht-delegierbare Orbis-Kompetenzen

### 2. Gesetz (Muster) – Regnum/Ager-Ebene
- **Geltungsbereich:** Regnum-weit oder Ager-intern
- **Änderungsquorum:** >80% / >60% / >50%
- **Beispiele:**
  - Steuergesetz (Höhe, Erhebung, Verwendung)
  - Wahlgesetz (Verfahren, Fristen, Kandidatur)
  - Zertifikatsgesetz (CA-Hierarchie, Sperrung, Erneuerung)

### 3. Verordnung (Muster) – Regnum/Ager-Ebene
- **Geltungsbereich:** Regnum-weit oder Ager-intern
- **Änderungsquorum:** >80% / >60% / >50%
- **Beispiele:**
  - Stimmrechts-Verordnung (10 JEDO, 12 Transaktionen, 6 Monate)
  - BigMac-Index-Verordnung (Aktualisierungsverfahren)
  - Wallet-Limit-Verordnung (10k USDT Infrastruktur, 10 Mio USDT On-Ramp)

## Anforderungen
- **Sprache:** Deutsch, präzise juristische Formulierungen
- **Struktur:** Artikel-basiert (Art. 1, Art. 2, etc.) mit Absätzen
- **Klarheit:** Verständlich für technische Laien, aber rechtlich eindeutig
- **Hierarchie-Prinzip beachten:** Verordnung darf nur regeln, was Gesetz erlaubt; Gesetz nur was Manifest erlaubt
- **Blockchain-Bezug:** Wo möglich, Chaincode-Mechanismen erwähnen (z.B. "automatische Steuererhebung via Smart Contract")

## Output-Format
Für jedes Dokument:
1. **Präambel** (Zweck & Geltungsbereich)
2. **Artikel-Struktur** mit Nummerierung
3. **Schlussbestimmungen** (Inkrafttreten, Übergangsregelungen)

Beginne mit dem **Manifest (Verfassung)** und strukturiere es in sinnvolle Kapitel (Grundlagen, Struktur, Rechte & Pflichten, Governance, Infrastruktur, Schlussbestimmungen).

***

### Job-Profile

***

# Aufgabe: JEDO-Ecosystem Job-Profile für Orbis, Regnum, Ager

Du bist ein HR-Experte für dezentrale Organisationen und technische Rollen. Basierend auf dem beigefügten Konzeptdokument "KonzeptWorkshop-20251208.md" sollst du detaillierte Job-Profile erstellen.

## Kontext
Das JEDO-Ecosystem ist ein dezentrales Blockchain-Netzwerk (Hyperledger Fabric 3.0) mit föderaler Struktur. Die Rollen Orbis, Regnum und Ager sind keine klassischen "Jobs", sondern **ehrenamtliche Vertrauenspositionen** mit technischer Verantwortung.

## Deine Aufgabe
Erstelle drei Job-Profile:

### 1. Orbis (Globale Koordination)
### 2. Regnum (Kontinentale Koordination)
### 3. Ager (Regionale Infrastruktur)

## Struktur pro Job-Profil

### A) Übersicht
- **Titel & Geltungsbereich**
- **Amtszeit:** 4 Jahre (Wiederwahl möglich)
- **Wahl:** Durch wen, Quorum (>50%)
- **Entschädigung:** Via Steuern (Infrastrukturkosten, kein Gehalt)

### B) Hauptaufgaben
Liste der 5-8 wichtigsten Aufgaben (aus Konzeptdokument ableiten)

### C) Technische Verantwortlichkeiten
- **Infrastruktur:** Was muss betrieben werden? (z.B. Orbis: Root-CA, TLS-CA, DNS)
- **Wallet-Management:** Infrastruktur-Wallet (10k USDT), On-Ramp-Wallet (nur Ager)
- **Seed-Backup:** Tier-System, Shamir Secret Sharing

### D) Governance-Kompetenzen
- **Abstimmungen:** Welche Ebene, welche Quoren
- **Misstrauensvoten:** Wer kann initiieren
- **Sicherheits-Rat:** Mitgliedschaft (ja/nein)

### E) Qualifikationen & Anforderungen

#### Muss-Kriterien:
- Technische Skills (z.B. "Grundverständnis Hyperledger Fabric" für Ager)
- Organisatorische Skills (z.B. "Koordination von 20-40 Ager" für Regnum)
- Verfügbarkeit (z.B. "Monatliche Interaktion für Lebenszeichen" bei Orbis)

#### Wünschenswert:
- Erfahrung mit dezentralen Systemen
- Community-Management
- Kryptografie-Grundlagen (für Seed-Management)

### F) Risiken & Herausforderungen
- **Kompromittierung:** Was passiert? (Zertifikatssperrung, Retro-Abstimmung)
- **Ausfall:** Nachfolge-Mechanismus (z.B. Blockchain wählt zufällig Regnum bei Orbis-Ausfall)
- **Erpressbarkeit:** Wie minimiert? (Transparenz, begrenzte Wallet-Größen)

### G) Nachfolge-Prozess
- **Bei Rücktritt:** 6 Monate Übergangszeit
- **Bei Abwahl:** Sofortige Neuwahl (14 Tage)
- **Bei Ausfall:** Automatische Blockchain-Nachfolge (Orbis/Regnum)

### H) Erfolgs-Metriken
Woran misst sich gute Amtsführung? (z.B. "Uptime >99%", "Keine Zertifikatssperrungen", "Pünktliche Steuerabrechnung")

## Anforderungen
- **Sprache:** Deutsch, klar und motivierend
- **Zielgruppe:** Technisch versierte Enthusiasten (keine Profis nötig, aber Lernbereitschaft)
- **Ton:** Nicht wie klassische Job-Anzeige, sondern **Community-orientiert** ("Du bist Teil einer globalen Bewegung...")
- **Realismus:** Ehrlich über Aufwand (z.B. "ca. 10-20h/Monat für Ager-Betrieb")

## Output-Format
Drei separate Markdown-Dokumente:
- `Orbis_Job-Profil.md`
- `Regnum_Job-Profil.md`
- `Ager_Job-Profil.md`

Beginne mit **Ager** (konkreteste Rolle), dann Regnum, dann Orbis.


***

### Recovery-Tool Epic

***

# Aufgabe: JEDO-Ecosystem Recovery-Tool Epic (Seed-Management)

Du bist ein Product Owner für Blockchain-Tools. Basierend auf dem beigefügten Konzeptdokument "KonzeptWorkshop-20251208.md" sollst du eine detaillierte Epic mit User Stories für das Seed-Recovery-Tool erstellen.

## Kontext
Das JEDO-Ecosystem nutzt ein mehrstufiges Seed-Management-System:
- **Infrastruktur-Wallets:** 3-Tier (Selbst, Parent, Shamir 6-of-6)
- **On-Ramp-Wallets:** 2-Tier (Selbst, Shamir 6-of-6)
- **Shamir Secret Sharing:** 6-of-6 Threshold (alle 5 Regnum + Orbis nötig für Recovery)

## Deine Aufgabe
Erstelle eine **Epic** mit Features und User Stories für das Recovery-Tool.

### Epic-Beschreibung (Template)
Epic ID: JEDO-RECOVERY-001
Titel: Seed-Management & Recovery-System
Ziel: Sichere Speicherung und Wiederherstellung von Bitcoin-Wallet-Seeds für Orbis/Regnum/Ager
Business Value: Verhindert Seed-Verlust (Totalausfall), ermöglicht Nachfolge, schützt vor Erpressung
Stakeholder: Orbis, Regnum (5x), Ager (135-180x)
Technologie: Shamir Secret Sharing (SLIP-39), Hyperledger Fabric Chaincode, Hardware-Wallet-kompatibel

### Features (Vorschlag, ergänze bei Bedarf)

#### Feature 1: Seed-Verschlüsselung & Speicherung im Orbis-Channel
**User Stories:**
- Als **Ager** möchte ich meinen Infrastruktur-Wallet-Seed verschlüsselt im Orbis-Channel speichern, damit mein Nachfolger Zugriff hat.
- Als **Regnum** möchte ich die Seeds meiner Ager einsehen können (Tier 2), um bei Seed-Verlust zu helfen.
- Als **Orbis** möchte ich die Root-CA-Seed mit 5-of-5 Shamir bei Regnum hinterlegen, damit das System bei meiner Kompromittierung weiterlaufen kann.

#### Feature 2: Shamir Secret Sharing (6-of-6 für On-Ramp-Wallets)
**User Stories:**
- Als **Ager** möchte ich meinen On-Ramp-Wallet-Seed in 6 Shares aufteilen (Shamir), damit kein Einzelner ihn rekonstruieren kann.
- Als **Regnum/Orbis** möchte ich meinen Share sicher verwahren (Hardware-Wallet), damit ich bei Recovery mitwirken kann.
- Als **System** möchte ich sicherstellen, dass nur bei Vorlage aller 6 Shares der Seed rekonstruiert wird.

#### Feature 3: Recovery-Prozess (GUI-Tool)
**User Stories:**
- Als **Nachfolger-Ager** möchte ich via GUI-Tool meinen Vorgänger-Seed abrufen können (Tier 1: mit meinem Zertifikat).
- Als **Regnum** möchte ich bei Ager-Seed-Verlust den Recovery-Prozess initiieren können (Tier 2: mit Regnum-Zertifikat).
- Als **Liquidator** möchte ich bei Systemliquidation alle 6 Shares koordinieren können (Tier 3: Shamir 6-of-6), um Wallets einzusammeln.

#### Feature 4: Testing & Simulation
**User Stories:**
- Als **Regnum** möchte ich 1x jährlich einen Test-Recovery durchführen, um sicherzustellen, dass mein Share funktioniert.
- Als **System-Administrator** möchte ich einen Sandbox-Modus haben, um Recovery-Prozesse zu simulieren (ohne echte Seeds).
- Als **Orbis** möchte ich ein Monitoring haben, das mich warnt, wenn ein Share seit >12 Monaten nicht getestet wurde.

#### Feature 5: Dokumentation & Schritt-für-Schritt-Anleitung
**User Stories:**
- Als **neuer Ager** möchte ich eine Schritt-für-Schritt-Anleitung haben, wie ich meinen Seed sicher erstelle und speichere.
- Als **Regnum** möchte ich eine Video-Anleitung für Shamir-Recovery haben, um den Prozess zu verstehen.
- Als **Community-Mitglied** möchte ich FAQs zu häufigen Problemen haben (z.B. "Was wenn ich meinen Hardware-Wallet verliere?").

### Technische Anforderungen
- **Shamir-Implementierung:** SLIP-39 Standard (Trezor-kompatibel)
- **Verschlüsselung:** AES-256 für Tier 1/2, Shamir für Tier 3
- **Speicherort:** Hyperledger Fabric Private Data Collection (im Orbis-Channel)
- **Hardware-Wallet-Support:** Trezor Model T, Ledger Nano X
- **GUI:** Electron-basierte Desktop-App (Linux, macOS, Windows)
- **CLI:** Für fortgeschrittene Nutzer (scriptable)

### Akzeptanzkriterien (Epic-Level)
- [ ] Ager kann Seed in <5 Minuten sicher speichern (Tier 1)
- [ ] Recovery via Tier 2 (Parent) dauert <30 Minuten
- [ ] Shamir 6-of-6 Recovery dauert <2 Stunden (mit Koordination)
- [ ] Jährlicher Test-Recovery läuft fehlerfrei bei >95% der Teilnehmer
- [ ] Dokumentation ist verständlich für Nicht-Krypto-Experten

### Risiken & Abhängigkeiten
- **Risiko 1:** Shamir-Shares gehen verloren (alle 6) → Seed unwiederbringlich
  - *Mitigation:* Jährlicher Test + Monitoring
- **Risiko 2:** GUI-Tool hat Sicherheitslücke → Seed-Diebstahl
  - *Mitigation:* Open Source, Code-Audit, deterministische Builds
- **Abhängigkeit 1:** Orbis-Channel muss existieren (vor Seed-Speicherung)
- **Abhängigkeit 2:** Zertifikats-Infrastruktur muss laufen (für Verschlüsselung)

## Output-Format
Erstelle ein Markdown-Dokument mit:
1. **Epic-Übersicht** (wie oben)
2. **Features** (5+, jeweils mit 3-5 User Stories)
3. **Technische Architektur** (Komponenten-Diagramm als Mermaid oder Text)
4. **Implementierungs-Roadmap** (3 Phasen: MVP, Erweiterung, Optimierung)
5. **Testing-Strategie** (Unit, Integration, jährlicher Live-Test)

Strukturiere die User Stories nach **MoSCoW-Prinzip** (Must-have, Should-have, Could-have, Won't-have).

***

**Status:** Konzeptionell abgeschlossen, bereit für technische Umsetzung.


