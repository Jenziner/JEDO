# Harbor-Struktur & Zugriffsverwaltung

## Projekte

| Projekt         | Inhalt                                    | Retention | Immutability        |
|-----------------|-------------------------------------------|-----------|---------------------|
| chaincode       | Chaincodes (jedo-wallet, ...)             | 50        | :X.Y.Z              |
| services        | Backend Services (ca, gateway, ledger, …) | 10        | :X.Y.Z              |
| apps            | Frontend (jedo-gateway-console)           | 10        | :X.Y.Z              |
| infrastructure  | Fabric Base (orderer, peer, tools)        | 10        | :X.Y.Z              |

## Robot-Accounts

| Account              | Typ     | Projekte    | Rechte     | Verwendung              |
|----------------------|---------|-------------|------------|-------------------------|
| robot$ci             | System  | Alle        | Push+Pull  | GitHub Actions CI/CD    |
| robot$cd             | System  | Alle        | Pull       | Orbis/Regnum/Ager Pull  |
| robot$replication-*  | Project | Per Regnum  | Push+Pull  | Orbis→Regnum Replication|

## Tag-Strategie

- **Dev:** `:X.Y.Z-dev` (mutable, latest commit on dev branch)
- **Test:** `:X.Y.Z-test` (mutable, nach Tests promoted)
- **Prod:** `:X.Y.Z` (immutable, semantic versioning)

## Replication-Topologie

harbor.jedo.me (Orbis)
└─> Push: harbor.ea.jedo.me (Regnum) --> nur Demo, muss noch angepasst werden
└─> Push: weitere noch offen
- **Trigger:** Event-based (automatisch bei Push zu Orbis)
- **Scope:** Alle Projekte, alle Tags

## Trivy-Scanning

- ✅ Automatisch bei jedem Push
- ✅ Block deployment bei Critical CVEs (konfigurierbar)
- Report: Projects → Repository → Vulnerabilities Tab
