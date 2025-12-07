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
