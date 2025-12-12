# Rollen-Matrix

| Funktion     | Admin        | Gens | Human |
| ------------ | ------------ | ---- | ----- |
| MintTokens   | ✅ (temporär) | ❌    | ❌     |
| RegisterGens | ✅            | ❌    | ❌     |
| ListGens     | ✅            | ❌    | ❌     |
| CreateWallet | ❌            | ✅    | ❌     |
| Transfer     | ❌            | ❌    | ✅     |
| GetBalance   | ❌            | ❌    | ✅     |
| VoteProject  | ❌            | ❌    | ✅     |
| ApproveVote  | ✅ (temporär) | ❌    | ❌     |



# JEDO Identity-Struktur

├── admin.alps.ea.jedo.cc/              # OU=admin
│   └── System-Verwaltung
│
├── WORB/                               # Gens (früher Owner)
│   ├── worb.alps.ea.jedo.cc/           # OU=gens
│   │   └── Registriert Humans
│   │
│   └── humans/                         # Humans (früher User)
│       ├── hans.worb.alps.ea.jedo.cc/  # OU=human
│       └── petra.worb.alps.ea.jedo.cc/ # OU=human
│
└── [Infrastruktur: peer, orderer, ca]

# Funktionen
## Wallet-Funktionen
**CreateWallet(ctx, walletId, ownerId, initialBalance, metadataJson)**
Erstellt ein neues Wallet für einen Human durch ein Gens (Caller-Rolle muss gens sein, Owner muss zu diesem Gens gehören).​
Typischer Aufruf: SubmitTransaction("CreateWallet", "wallet-123", "hans.worb.alps.ea.jedo.cc", "100", "{\"plan\":\"basic\"}").​

**WalletExists(ctx, walletId)**
Prüft, ob ein Wallet im World State vorhanden ist.​
Typischer Aufruf: EvaluateTransaction("WalletExists", "wallet-123").​

**GetWallet(ctx, walletId)**
Liest ein Wallet aus dem World State (interne Helper-Funktion, aber direkt aufrufbar, keine Rollenkontrolle).​
Typischer Aufruf: EvaluateTransaction("GetWallet", "wallet-123").​

**GetBalance(ctx, walletId)**
Gibt den Saldo eines Wallets zurück, nur der Human-Owner darf seine eigenen Wallets abfragen (Caller-Rolle human, Caller-ID muss Owner enthalten).​
Typischer Aufruf: EvaluateTransaction("GetBalance", "wallet-123").​

**UpdateWallet(ctx, walletId, metadataJson)**
Aktualisiert die Metadata eines Wallets; erlaubt für Admin oder Owner (Human).​
Typischer Aufruf: SubmitTransaction("UpdateWallet", "wallet-123", "{\"plan\":\"premium\"}").​

**FreezeWallet(ctx, walletId) / UnfreezeWallet(ctx, walletId)**
Setzt Status auf frozen bzw. wieder active (nur Admin).​
Typischer Aufruf: SubmitTransaction("FreezeWallet", "wallet-123").​

**DeleteWallet(ctx, walletId)**
Markiert ein Wallet als closed, aber nur wenn Balance == 0 (Admin-only; es wird nicht physisch gelöscht).​
Typischer Aufruf: SubmitTransaction("DeleteWallet", "wallet-123").​

##Transaktions-Funktionen
**Transfer(ctx, fromWalletId, toWalletId, amount, description)**
Human-zu-Human Transfer; nur der Human-Owner des fromWalletId darf aufrufen.​
Typischer Aufruf: SubmitTransaction("Transfer", "wallet-from", "wallet-to", "10", "Coffee").​

**Credit(ctx, walletId, amount, description)**
„Minting“: Admin bucht Guthaben auf ein Wallet.​
Typischer Aufruf: SubmitTransaction("Credit", "wallet-123", "50", "Signup bonus").​

**Debit(ctx, walletId, amount, description)**
„Burning“: Admin bucht Guthaben vom Wallet ab.​
Typischer Aufruf: SubmitTransaction("Debit", "wallet-123", "5", "Fee").​

Bei allen drei Funktionen werden Transaktions-Records im World State unter einem Composite Key transaction~walletId~txId gespeichert.​

## Query- und Reporting-Funktionen
**GetWalletHistory(ctx, walletId, limit)**
Liefert eine Liste der Transaction-Einträge für ein Wallet; nur Owner (Human) oder Admin.​
Typischer Aufruf: EvaluateTransaction("GetWalletHistory", "wallet-123", "50") (limit 0 = unlimitiert).​

**GetWalletsByGens(ctx, gensId)**
Liefert alle Wallets, deren ownerId zu einem Gens gehört; aufrufbar von Admin oder dem jeweiligen Gens.​
Typischer Aufruf: EvaluateTransaction("GetWalletsByGens", "worb").​

**GetWalletsByHuman(ctx, humanId)**
Liefert alle Wallets eines Humans; nur Admin oder der Human selbst.​
Typischer Aufruf: EvaluateTransaction("GetWalletsByHuman", "hans.worb.alps.ea.jedo.cc").​

**GetAllWallets(ctx)**
Liefert alle Wallets, Admin-only.​
Typischer Aufruf: EvaluateTransaction("GetAllWallets").​

**GetTotalBalance(ctx)**
Summiert die Balances aller Wallets (Admin-only).​
Typischer Aufruf: EvaluateTransaction("GetTotalBalance").​

## Gens-Management
**ListGens(ctx)**
Gibt alle registrierten Gens-Entitäten zurück, Admin-only.​
Typischer Aufruf: EvaluateTransaction("ListGens").​

**RegisterGens(ctx, gensId, name)**
Legt einen neuen Gens-Eintrag im State an, Admin-only.​
Typischer Aufruf: SubmitTransaction("RegisterGens", "worb", "Worb GmbH").​

## Typische Rollen
human:
- GetBalance, Transfer, GetWalletHistory, GetWalletsByHuman (nur für eigene IDs).​

gens:
- CreateWallet für eigene Humans, GetWalletsByGens für eigene Organisation.​

admin:
- Vollzugriff auf Management/Reporting: Credit, Debit, FreezeWallet, UnfreezeWallet, DeleteWallet, GetAllWallets, GetTotalBalance, ListGens, RegisterGens, plus alle Query-Funktionen.​