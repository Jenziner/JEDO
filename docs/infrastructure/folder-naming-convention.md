# CA
/opt/fabric-ca/
│
├── servers/                                    # CA-Server Homes
│   │
│   ├── tls.ea.jedo.cc/                        # Regnum TLS-CA
│   │   ├── fabric-ca-server-config.yaml
│   │   ├── fabric-ca-server.db
│   │   ├── ca/                                 # Von Vault
│   │   │   ├── tls-ea-ca.key                  # Dein .key-File
│   │   │   ├── cert.pem                       # Von Vault: CA-Cert
│   │   │   └── chain.cert                     # Von Vault: Chain
│   │   └── msp/
│   │       └── config.yaml                     # NodeOUs Config
│   │
│   ├── msp.ea.jedo.cc/                        # Regnum MSP-CA
│   │   ├── fabric-ca-server-config.yaml
│   │   ├── fabric-ca-server.db
│   │   ├── ca/                                 # Von Vault
│   │   │   ├── msp-ea-ca.key
│   │   │   ├── cert.pem
│   │   │   └── chain.cert
│   │   ├── tls/                                # Server-TLS-Identity
│   │   │   ├── signcerts/
│   │   │   │   └── cert.pem                   # Von tls.ea.jedo.cc enrolled
│   │   │   └── keystore/
│   │   │       └── key.pem
│   │   └── msp/
│   │       └── config.yaml                     # NodeOUs Config
│   │
│   └── msp.alps.ea.jedo.cc/                   # Ager MSP-CA (Intermediate)
│       ├── fabric-ca-server-config.yaml
│       ├── fabric-ca-server.db
│       ├── ca/                                 # Von msp.ea.jedo.cc enrolled
│       │   ├── cert.pem                       # Intermediate CA-Cert
│       │   ├── chain.cert                     # Chain zu Orbis
│       │   └── key.pem                        # Bei Enrollment generiert
│       ├── tls/                                # Server-TLS-Identity
│       │   ├── signcerts/
│       │   │   └── cert.pem                   # Von tls.ea.jedo.cc enrolled
│       │   └── keystore/
│       │       └── key.pem
│       └── msp/
│           └── config.yaml                     # NodeOUs Config
│
├── clients/                                    # CA-Client Identities
│   │
│   ├── bootstrap.tls.ea.jedo.cc/              # Bootstrap der TLS-CA
│   │   ├── fabric-ca-client-config.yaml
│   │   └── msp/
│   │       ├── signcerts/
│   │       │   └── cert.pem
│   │       ├── keystore/
│   │       │   └── key.pem
│   │       └── cacerts/
│   │           └── tls-ea-jedo-cc.pem
│   │
│   ├── bootstrap.msp.ea.jedo.cc/              # Bootstrap der MSP-CA
│   │   └── msp/
│   │
│   ├── server.msp.ea.jedo.cc/                 # TLS-Identity für MSP-CA-Server
│   │   └── tls/                                # → Mounten nach servers/msp.ea.jedo.cc/tls/
│   │       ├── signcerts/
│   │       └── keystore/
│   │
│   ├── server.msp.alps.ea.jedo.cc/            # TLS-Identity für Ager-MSP-CA-Server
│   │   └── tls/                                # → Mounten nach servers/msp.alps.ea.jedo.cc/tls/
│   │
│   ├── admin.ea.jedo.cc/                      # Regnum Org-Admin
│   │   └── msp/
│   │
│   └── admin.alps.ea.jedo.cc/                 # Ager Org-Admin
│       └── msp/
│
└── tls-ca-roots/                               # Öffentliche TLS-Root-Certs
    ├── tls.ea.jedo.cc.pem                     # Für --tls.certfiles
    └── orbis-tls-root.pem                     # Falls nötig
