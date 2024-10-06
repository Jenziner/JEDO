
curl -k -s https://peer0.jenziner.jedo.test:7069/healthz

openssl x509 -in ./keys/JenzinerOrg/orderer.jenziner.jedo.test/tls/signcerts/cert.pem -text -noout
openssl x509 -in ./keys/LiebiwilerOrg/orderer.liebiwiler.jedo.test/tls/signcerts/cert.pem -text -noout

-e ORDERER_GENERAL_TLS_ROOTCAS=[/etc/hyperledger/orderer/tls/tlscacerts/$TLS_ROOTCERT] \


keys/
└── JenzinerOrg/
    ├── admin/             # Admin-Zertifikate und Schlüssel
    ├── ca/                # CA-Zertifikate und Schlüssel
    ├── orderer/           # Orderer-Zertifikate und Schlüssel
    ├── peer0/             # Peer 0 Zertifikate und Schlüssel
    ├── peer1/             # Peer 1 Zertifikate und Schlüssel
    └── msp/               # Zentralisiertes MSP-Verzeichnis
        ├── admincerts/    # Admin-Zertifikate
        ├── cacerts/       # CA-Zertifikat der Organisation
        ├── keystore/      # Privater Schlüssel der Organisation
        ├── signcerts/     # Signaturzertifikat der Organisation
        ├── tlscacerts/    # TLS-Zertifikate (optional)
        └── config.yaml    # Optional, NodeOUs Konfiguration


PEER Operation:
        -e CORE_OPERATIONS_LISTENADDRESS=0.0.0.0:$PEER_OPPORT \
        -e CORE_OPERATIONS_TLS_ENABLED=true \
        -e CORE_OPERATIONS_TLS_CERTIFICATE=/etc/hyperledger/fabric/tls/signcerts/cert.pem \
        -e CORE_OPERATIONS_TLS_PRIVATEKEY=/etc/hyperledger/fabric/tls/keystore/$TLS_PRIVATE_KEY \

ORDERER Operation:
        -e ORDERER_OPERATIONS_LISTENADDRESS=0.0.0.0:$ORDERER_OPPORT \
        -e ORDERER_OPERATIONS_TLS_ENABLED=true \
        -e ORDERER_OPERATIONS_TLS_CERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem \
        -e ORDERER_OPERATIONS_TLS_PRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/$TLS_PRIVATE_KEY \
