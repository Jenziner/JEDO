#!/bin/bash

# Pfad zur network-config.yaml
NETWORK_CONFIG_FILE="network-config.yaml"

# Pfad zur zu generierenden configtx.yaml
OUTPUT_CONFIGTX_FILE="configtx.yaml"

# Start der configtx.yaml
cat <<EOF > $OUTPUT_CONFIGTX_FILE
---
Organizations:
EOF

# Iteriere durch jede Organisation in der network-config.yaml
ORG_COUNT=$(yq e '.Network.Organizations | length' $NETWORK_CONFIG_FILE)

for i in $(seq 0 $(($ORG_COUNT - 1))); do
    ORG_NAME=$(yq e ".Network.Organizations[$i].Name" $NETWORK_CONFIG_FILE)
    MSP_DIR=$(yq e ".Network.Organizations[$i].MSPDir" $NETWORK_CONFIG_FILE)
    
    cat <<EOF >> $OUTPUT_CONFIGTX_FILE
  - &${ORG_NAME}
    Name: ${ORG_NAME}
    ID: ${ORG_NAME}MSP
    MSPDir: ${MSP_DIR}
EOF

    # Iteriere durch die Orderer der aktuellen Organisation
    ORDERER_COUNT=$(yq e ".Network.Organizations[$i].Orderers | length" $NETWORK_CONFIG_FILE)
    for j in $(seq 0 $(($ORDERER_COUNT - 1))); do
        ORDERER_NAME=$(yq e ".Network.Organizations[$i].Orderers[$j].Name" $NETWORK_CONFIG_FILE)
        ORDERER_ADDRESS=$(yq e ".Network.Organizations[$i].Orderers[$j].Address" $NETWORK_CONFIG_FILE)
        ORDERER_HOST=$(yq e ".Network.Organizations[$i].Orderers[$j].Host" $NETWORK_CONFIG_FILE)
        ORDERER_PORT=$(yq e ".Network.Organizations[$i].Orderers[$j].Port" $NETWORK_CONFIG_FILE)

        echo "ScriptInfo: Adding Orderer $ORDERER_NAME"

        cat <<EOF >> $OUTPUT_CONFIGTX_FILE
      - Host: ${ORDERER_HOST}
        Port: ${ORDERER_PORT}
        ClientTLSCert: /path/to/tls/cert/${ORDERER_NAME}
        ServerTLSCert: /path/to/tls/cert/${ORDERER_NAME}
EOF
    done

    # Iteriere durch die Peers der aktuellen Organisation
    PEER_COUNT=$(yq e ".Network.Organizations[$i].Peers | length" $NETWORK_CONFIG_FILE)
    for k in $(seq 0 $(($PEER_COUNT - 1))); do
        PEER_NAME=$(yq e ".Network.Organizations[$i].Peers[$k].Name" $NETWORK_CONFIG_FILE)
        PEER_ADDRESS=$(yq e ".Network.Organizations[$i].Peers[$k].Address" $NETWORK_CONFIG_FILE)
        PEER_HOST=$(yq e ".Network.Organizations[$i].Peers[$k].Host" $NETWORK_CONFIG_FILE)
        PEER_PORT=$(yq e ".Network.Organizations[$i].Peers[$k].Port" $NETWORK_CONFIG_FILE)

        echo "ScriptInfo: Adding Peer $PEER_NAME"
        # Füge die Peers zur configtx.yaml hinzu, falls erforderlich
        # Oder führe andere Aktionen durch
    done
done

echo "ScriptInfo: configtx.yaml wurde erfolgreich generiert!"




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



