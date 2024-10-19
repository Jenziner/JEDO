###############################################################
#!/bin/bash
#
# Register and enroll all identities needed for the JEDO-Token-Test network.
#
#
# Folder-Structure:
# keys/
# ├── JenzinerOrg/
#     ├── admin/             # Admin-certificates and keys
#     ├── ca/                # CA-certificates and keys
#     ├── orderer/           # Orderer-certificates and keys
#     ├── peer0/             # Peer 0 certificates and keys
#     └── peer1/             # Peer 1 certificates and keys
# ├── LiebewilerOrg/
#     ├── admin/             # Admin-certificates and keys
#     ├── ca/                # CA-certificates and keys
#     ├── orderer/           # Orderer-certificates and keys
#     └── peer0/             # Peer 1 certificates and keys
# └── tlscerts_collections
#     ├── tls_ca_certs       # one certificate file per CA
#     ├── tls_ca_combined    # one certificate with all CA certificates combined (tls_ca_combined.pem)
#     ├── tls_node_certs     # one certificate file per Node (peer and orderer of all organizations)
#     └── tls_node_combined  # one certificate with all Node certificates combined (peer and orderer of all organizations) (tls_node_combined.pem)
# Make sure to mount the right collection folder / file for each Node (e.g. $PWD/keys/tlscerts_collections/tls_ca_combined/combined_tls_ca.pem:/etc/hyperledger/fabric/ca/combined_tls_ca.pem)
#
###############################################################
source ./utils/utils.sh
source ./utils/help.sh
check_script

echo_ok "Register and Enroll identities - see Documentation here: https://hyperledger-fabric.readthedocs.io"


###############################################################
# Params - from ./config/network-config.yaml
###############################################################
CONFIG_FILE="./config/infrastructure-dev.yaml"
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $CONFIG_FILE)
CHANNELS=$(yq e ".FabricNetwork.Channels[].Name" $CONFIG_FILE)

for CHANNEL in $CHANNELS; do
    ROOTCA_NAME=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .RootCA.Name" "$CONFIG_FILE")
    ROOTCA_PASS=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .RootCA.Pass" "$CONFIG_FILE")
    ROOTCA_PORT=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .RootCA.Port" "$CONFIG_FILE")
    ORGANIZATIONS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[].Name" $CONFIG_FILE)
    REGIONS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Regions[].Name" $CONFIG_FILE)

    CA_DIR=/etc/hyperledger/fabric-ca
    CA_SRV_DIR=/etc/hyperledger/fabric-ca-server
    CA_CLI_DIR=/etc/hyperledger/fabric-ca-client
    KEYS_DIR=/etc/hyperledger/keys


    ###############################################################
    # Enroll Fabric Network
    ###############################################################
    for ORGANIZATION in $ORGANIZATIONS; do
        echo ""
        echo_warn "Enrollment for $ORGANIZATION starting..."

        CA_EXT=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Ext" $CONFIG_FILE)
        if [[ -n "$CA_EXT" ]]; then
            CA_NAME=$(yq eval ".. | select(has(\"CA\")) | .CA | select(.Name == \"$CA_EXT\") | .Name" "$CONFIG_FILE")
            CA_SUBJECT=$(yq eval ".. | select(has(\"CA\")) | .CA | select(.Name == \"$CA_EXT\") | .Subject" "$CONFIG_FILE")
            CA_PASS=$(yq eval ".. | select(has(\"CA\")) | .CA | select(.Name == \"$CA_EXT\") | .Pass" "$CONFIG_FILE")
            CA_PORT=$(yq eval ".. | select(has(\"CA\")) | .CA | select(.Name == \"$CA_EXT\") | .Port" "$CONFIG_FILE")
        else
            CA_NAME=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Name" $CONFIG_FILE)
            CA_SUBJECT=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Subject" $CONFIG_FILE)
            CA_PASS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Pass" $CONFIG_FILE)
            CA_PORT=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Port" $CONFIG_FILE)
        fi

        # Enroll orderers 
        echo ""
        echo_info "Orderers for $ORGANIZATION enrolling"
        ORDERERS_NAME=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Name" $CONFIG_FILE)
        ORDERERS_PASS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Pass" $CONFIG_FILE)
        ORDERERS_SUBJECT=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Subject" $CONFIG_FILE)

        for index in $(seq 0 $(($(echo "$ORDERERS_NAME" | wc -l) - 1))); do
            ORDERER_NAME=$(echo "$ORDERERS_NAME" | sed -n "$((index+1))p")
            ORDERER_PASS=$(echo "$ORDERERS_PASS" | sed -n "$((index+1))p")
            ORDERER_SUBJECT=$(echo "$ORDERERS_SUBJECT" | sed -n "$((index+1))p")

            # Extract fields from subject
            C=$(echo "$ORDERER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
            ST=$(echo "$ORDERER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
            L=$(echo "$ORDERER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')
            O=$(echo "$ORDERER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^O=/) {sub(/^O=/, "", $i); print $i}}')
            CN=$(echo "$ORDERER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^CN=/) {sub(/^CN=/, "", $i); print $i}}')
            CSR_NAMES=$(echo "$ORDERER_SUBJECT" | sed 's/,CN=[^,]*//')
            AFFILIATION="$C.$ST.$L.$O"

            # Register User
            echo_info "User $ORDERER_NAME registering..."
            docker exec -it $CA_NAME fabric-ca-client register -u https://$CA_NAME:$CA_PASS@$CA_NAME:$CA_PORT --mspdir $CA_CLI_DIR/msp \
                --id.name $ORDERER_NAME --id.secret $ORDERER_PASS --id.type orderer --id.affiliation $AFFILIATION

            # Enroll User
            echo ""
            echo_info "User $ORDERER_NAME enrolling..."
            docker exec -it $CA_NAME fabric-ca-client enroll -u https://$ORDERER_NAME:$ORDERER_PASS@$CA_NAME:$CA_PORT --mspdir $KEYS_DIR/$ORDERER_NAME/msp \
                --csr.cn $CN --csr.names "$CSR_NAMES"
            # Enroll User TLS
            echo ""
            echo_info "User $ORDERER_NAME TLS enrolling..."
            docker exec -it $CA_NAME fabric-ca-client enroll -u https://$ORDERER_NAME:$ORDERER_PASS@$CA_NAME:$CA_PORT --mspdir $KEYS_DIR/$ORDERER_NAME/tls \
                --enrollment.profile tls --csr.cn $CN --csr.names "$CSR_NAMES"

            # Generating NodeOUs-File
            echo ""
            echo_info "NodeOUs-File writing..."
            CA_CERT_FILE=$(ls ${PWD}/keys/$ORDERER_NAME/msp/cacerts/*.pem)
            cat <<EOF > ${PWD}/keys/$ORDERER_NAME/msp/config.yaml
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: orderer
EOF
        done
        echo_ok "Orderers for $ORGANIZATION enrolled."

        # Enroll peers 
        echo ""
        echo_info "Peers for $ORGANIZATION enrolling"
        PEERS_NAME=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[].Name" $CONFIG_FILE)
        PEERS_PASS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[].Pass" $CONFIG_FILE)
        PEERS_SUBJECT=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Peers[].Subject" $CONFIG_FILE)

        for index in $(seq 0 $(($(echo "$PEERS_NAME" | wc -l) - 1))); do
            PEER_NAME=$(echo "$PEERS_NAME" | sed -n "$((index+1))p")
            PEER_PASS=$(echo "$PEERS_PASS" | sed -n "$((index+1))p")
            PEER_SUBJECT=$(echo "$PEERS_SUBJECT" | sed -n "$((index+1))p")

            # Extract fields from subject
            C=$(echo "$PEER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
            ST=$(echo "$PEER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
            L=$(echo "$PEER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')
            O=$(echo "$PEER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^O=/) {sub(/^O=/, "", $i); print $i}}')
            CN=$(echo "$PEER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^CN=/) {sub(/^CN=/, "", $i); print $i}}')
            CSR_NAMES=$(echo "$PEER_SUBJECT" | sed 's/,CN=[^,]*//')
            AFFILIATION="$C.$ST.$L.$O"

            # Register User
            echo_info "User $PEER_NAME registering..."
            docker exec -it $CA_NAME fabric-ca-client register -u https://$CA_NAME:$CA_PASS@$CA_NAME:$CA_PORT --mspdir $CA_CLI_DIR/msp \
                --id.name $PEER_NAME --id.secret $PEER_PASS --id.type orderer --id.affiliation $AFFILIATION

            # Enroll User
            echo ""
            echo_info "User $PEER_NAME enrolling..."
            docker exec -it $CA_NAME fabric-ca-client enroll -u https://$PEER_NAME:$PEER_PASS@$CA_NAME:$CA_PORT --mspdir $KEYS_DIR/$PEER_NAME/msp \
                --csr.cn $CN --csr.names "$CSR_NAMES"

            # Enroll User TLS
            echo ""
            echo_info "User $PEER_NAME TLS enrolling..."
            docker exec -it $CA_NAME fabric-ca-client enroll -u https://$PEER_NAME:$PEER_PASS@$CA_NAME:$CA_PORT --mspdir $KEYS_DIR/$PEER_NAME/tls \
                --enrollment.profile tls --csr.cn $CN --csr.names "$CSR_NAMES"

            # Generating NodeOUs-File
            echo ""
            echo_info "NodeOUs-File writing..."
            CA_CERT_FILE=$(ls ${PWD}/keys/$PEER_NAME/msp/cacerts/*.pem)
            cat <<EOF > ${PWD}/keys/$PEER_NAME/msp/config.yaml
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: orderer
EOF
        done
        echo_ok "Peers for $ORGANIZATION enrolled."
    done


    ###############################################################
    # Enroll Token Network
    ###############################################################
    for REGION in $REGIONS; do
        echo ""
        echo_warn "Enrollment for $REGION starting..."

        ###############################################################
        # Enroll Auditors
        ###############################################################
        AUDITORS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Regions[] | select(.Name == \"$REGION\") | .Auditors[].Name" $CONFIG_FILE)
        for AUDITOR in $AUDITORS; do
            echo ""
            echo_info "Auditors for $REGION enrolling..."

            CA_REF=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Regions[] | select(.Name == \"$REGION\") | .Auditors[] | select(.Name == \"$AUDITOR\") | .CA" $CONFIG_FILE)
            CA_NAME=$(yq eval ".. | select(has(\"CA\")) | .CA | select(.Name == \"$CA_REF\") | .Name" "$CONFIG_FILE")
            CA_PASS=$(yq eval ".. | select(has(\"CA\")) | .CA | select(.Name == \"$CA_REF\") | .Pass" "$CONFIG_FILE")
            CA_PORT=$(yq eval ".. | select(has(\"CA\")) | .CA | select(.Name == \"$CA_REF\") | .Port" "$CONFIG_FILE")

            AUDITOR_NAME=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Regions[] | select(.Name == \"$REGION\") | .Auditors[] | select(.Name == \"$AUDITOR\") | .Name" $CONFIG_FILE)
            AUDITOR_PASS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Regions[] | select(.Name == \"$REGION\") | .Auditors[] | select(.Name == \"$AUDITOR\") | .Pass" $CONFIG_FILE)
            AUDITOR_SUBJECT=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Regions[] | select(.Name == \"$REGION\") | .Auditors[] | select(.Name == \"$AUDITOR\") | .Subject" $CONFIG_FILE)

            # Extract fields from subject
            C=$(echo "$AUDITOR_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
            ST=$(echo "$AUDITOR_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
            L=$(echo "$AUDITOR_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')
            O=$(echo "$AUDITOR_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^O=/) {sub(/^O=/, "", $i); print $i}}')
            CN=$(echo "$AUDITOR_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^CN=/) {sub(/^CN=/, "", $i); print $i}}')
            CSR_NAMES=$(echo "$AUDITOR_SUBJECT" | sed 's/,CN=[^,]*//')
            AFFILIATION="$C.$ST.$L.$O"

            # Register FSC User
            docker exec -it $CA_NAME fabric-ca-client register -u https://$CA_NAME:$CA_PASS@$CA_NAME:$CA_PORT --mspdir $CA_CLI_DIR/msp \
              --id.name fsc.$AUDITOR_NAME --id.secret $AUDITOR_PASS --id.type client --id.affiliation $AFFILIATION

            # Enroll FSC User
            docker exec -it $CA_NAME fabric-ca-client enroll -u https://fsc.$AUDITOR_NAME:$AUDITOR_PASS@$CA_NAME:$CA_PORT --mspdir $KEYS_DIR/$CHANNEL/$REGION/$AUDITOR_NAME/fsc/msp \
                --csr.cn $CN --csr.names "$CSR_NAMES"
            # make private key name predictable
            # mv "$FABRIC_CA_CLIENT_HOME/$TOKEN_NETWORK_NAME/$FSC_OWNER/fsc/msp/keystore/"* "$FABRIC_CA_CLIENT_HOME/$TOKEN_NETWORK_NAME/$FSC_OWNER/fsc/msp/keystore/priv_sk"

            # Register Wallet User
            docker exec -it $CA_NAME fabric-ca-client register -u https://$CA_NAME:$CA_PASS@$CA_NAME:$CA_PORT --mspdir $CA_CLI_DIR/msp \
              --id.name $AUDITOR_NAME --id.secret $AUDITOR_PASS --id.type client --id.affiliation $AFFILIATION

            # Enroll Wallet User
            docker exec -it $CA_NAME fabric-ca-client enroll -u https://$AUDITOR_NAME:$AUDITOR_PASS@$CA_NAME:$CA_PORT --mspdir $KEYS_DIR/$CHANNEL/$REGION/$AUDITOR_NAME/msp \
                --csr.cn $CN --csr.names "$CSR_NAMES"
        done
        echo_ok "Auditors for $REGION enrolled."

        ###############################################################
        # Enroll Issuers
        ###############################################################
        ISSUERS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Regions[] | select(.Name == \"$REGION\") | .Issuers[].Name" $CONFIG_FILE)
        for ISSUER in $ISSUERS; do
            echo ""
            echo_info "Issuers for $REGION enrolling..."

            CA_REF=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Regions[] | select(.Name == \"$REGION\") | .Issuers[] | select(.Name == \"$ISSUER\") | .CA" $CONFIG_FILE)
            CA_NAME=$(yq eval ".. | select(has(\"CA\")) | .CA | select(.Name == \"$CA_REF\") | .Name" "$CONFIG_FILE")
            CA_PASS=$(yq eval ".. | select(has(\"CA\")) | .CA | select(.Name == \"$CA_REF\") | .Pass" "$CONFIG_FILE")
            CA_PORT=$(yq eval ".. | select(has(\"CA\")) | .CA | select(.Name == \"$CA_REF\") | .Port" "$CONFIG_FILE")

            ISSUER_NAME=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Regions[] | select(.Name == \"$REGION\") | .Issuers[] | select(.Name == \"$ISSUER\") | .Name" $CONFIG_FILE)
            ISSUER_PASS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Regions[] | select(.Name == \"$REGION\") | .Issuers[] | select(.Name == \"$ISSUER\") | .Pass" $CONFIG_FILE)
            ISSUER_SUBJECT=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Regions[] | select(.Name == \"$REGION\") | .Issuers[] | select(.Name == \"$ISSUER\") | .Subject" $CONFIG_FILE)

            # Extract fields from subject
            C=$(echo "$ISSUER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
            ST=$(echo "$ISSUER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
            L=$(echo "$ISSUER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')
            O=$(echo "$ISSUER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^O=/) {sub(/^O=/, "", $i); print $i}}')
            CN=$(echo "$ISSUER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^CN=/) {sub(/^CN=/, "", $i); print $i}}')
            CSR_NAMES=$(echo "$ISSUER_SUBJECT" | sed 's/,CN=[^,]*//')
            AFFILIATION="$C.$ST.$L.$O"

            # Register FSC User
            docker exec -it $CA_NAME fabric-ca-client register -u https://$CA_NAME:$CA_PASS@$CA_NAME:$CA_PORT --mspdir $CA_CLI_DIR/msp \
              --id.name fsc.$ISSUER_NAME --id.secret $ISSUER_PASS --id.type client --id.affiliation $AFFILIATION

            # Enroll FSC User
            docker exec -it $CA_NAME fabric-ca-client enroll -u https://fsc.$ISSUER_NAME:$ISSUER_PASS@$CA_NAME:$CA_PORT --mspdir $KEYS_DIR/$CHANNEL/$REGION/$ISSUER_NAME/fsc/msp \
                --csr.cn $CN --csr.names "$CSR_NAMES"
            # make private key name predictable
            # mv "$FABRIC_CA_CLIENT_HOME/$TOKEN_NETWORK_NAME/$FSC_OWNER/fsc/msp/keystore/"* "$FABRIC_CA_CLIENT_HOME/$TOKEN_NETWORK_NAME/$FSC_OWNER/fsc/msp/keystore/priv_sk"

            # Register Wallet User
            docker exec -it $CA_NAME fabric-ca-client register -u https://$CA_NAME:$CA_PASS@$CA_NAME:$CA_PORT --mspdir $CA_CLI_DIR/msp \
              --id.name $ISSUER_NAME --id.secret $ISSUER_PASS --id.type client --id.affiliation $AFFILIATION

            # Enroll Wallet User
            docker exec -it $CA_NAME fabric-ca-client enroll -u https://$ISSUER_NAME:$ISSUER_PASS@$CA_NAME:$CA_PORT --mspdir $KEYS_DIR/$CHANNEL/$REGION/$ISSUER_NAME/msp \
                --csr.cn $CN --csr.names "$CSR_NAMES"
        done
        echo_ok "Issuers for $REGION enrolled."

        ###############################################################
        # Enroll Owner
        ###############################################################
        OWNERS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Regions[] | select(.Name == \"$REGION\") | .Owners[].Name" $CONFIG_FILE)
        for OWNER in $OWNERS; do
            echo ""
            echo_info "Owners for $REGION enrolling..."

            CA_REF=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Regions[] | select(.Name == \"$REGION\") | .Owners[] | select(.Name == \"$OWNER\") | .CA" $CONFIG_FILE)
            CA_NAME=$(yq eval ".. | select(has(\"CA\")) | .CA | select(.Name == \"$CA_REF\") | .Name" "$CONFIG_FILE")
            CA_PASS=$(yq eval ".. | select(has(\"CA\")) | .CA | select(.Name == \"$CA_REF\") | .Pass" "$CONFIG_FILE")
            CA_PORT=$(yq eval ".. | select(has(\"CA\")) | .CA | select(.Name == \"$CA_REF\") | .Port" "$CONFIG_FILE")

            OWNER_NAME=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Regions[] | select(.Name == \"$REGION\") | .Owners[] | select(.Name == \"$OWNER\") | .Name" $CONFIG_FILE)
            OWNER_PASS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Regions[] | select(.Name == \"$REGION\") | .Owners[] | select(.Name == \"$OWNER\") | .Pass" $CONFIG_FILE)
            OWNER_SUBJECT=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Regions[] | select(.Name == \"$REGION\") | .Owners[] | select(.Name == \"$OWNER\") | .Subject" $CONFIG_FILE)

            # Extract fields from subject
            C=$(echo "$OWNER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
            ST=$(echo "$OWNER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
            L=$(echo "$OWNER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')
            O=$(echo "$OWNER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^O=/) {sub(/^O=/, "", $i); print $i}}')
            OU=$(echo "$OWNER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^OU=/) {sub(/^OU=/, "", $i); print $i}}')
            CN=$(echo "$OWNER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^CN=/) {sub(/^CN=/, "", $i); print $i}}')
            CSR_NAMES=$(echo "$OWNER_SUBJECT" | sed 's/,CN=[^,]*//')
            AFFILIATION="$C.$ST.$L.$O.$OU"

            # Register FSC User
            docker exec -it $CA_NAME fabric-ca-client register -u https://$CA_NAME:$CA_PASS@$CA_NAME:$CA_PORT --mspdir $CA_CLI_DIR/msp \
              --id.name fsc.$OWNER_NAME --id.secret $OWNER_PASS --id.type client --id.affiliation $AFFILIATION

            # Enroll FSC User
            docker exec -it $CA_NAME fabric-ca-client enroll -u https://fsc.$OWNER_NAME:$OWNER_PASS@$CA_NAME:$CA_PORT --mspdir $KEYS_DIR/$CHANNEL/$REGION/$OWNER_NAME/owner/fsc/msp \
                --csr.cn $CN --csr.names "$CSR_NAMES"
            # make private key name predictable
            # mv "$FABRIC_CA_CLIENT_HOME/$TOKEN_NETWORK_NAME/$FSC_OWNER/fsc/msp/keystore/"* "$FABRIC_CA_CLIENT_HOME/$TOKEN_NETWORK_NAME/$FSC_OWNER/fsc/msp/keystore/priv_sk"

            # Register Wallet User
            docker exec -it $CA_NAME fabric-ca-client register -u https://$CA_NAME:$CA_PASS@$CA_NAME:$CA_PORT --mspdir $CA_CLI_DIR/msp \
              --id.name $OWNER_NAME --id.secret $OWNER_PASS --id.type client --id.affiliation $AFFILIATION --enrollment.type idemix --idemix.curve gurvy.Bn254

            # Enroll Wallet User
            docker exec -it $CA_NAME fabric-ca-client enroll -u https://$OWNER_NAME:$OWNER_PASS@$CA_NAME:$CA_PORT --mspdir $KEYS_DIR/$CHANNEL/$REGION/$OWNER_NAME/owner/msp \
                --csr.cn $CN --csr.names "$CSR_NAMES"

            ###############################################################
            # Enroll Wallet User
            ###############################################################
            USERS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Regions[] | select(.Name == \"$REGION\") | .Owners[] | select(.Name == \"$OWNER\") | .Users[].Name" $CONFIG_FILE)
            for USER in $USERS; do
                echo ""
                echo_info "Users for $REGION enrolling..."

                USER_NAME=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Regions[] | select(.Name == \"$REGION\") | .Owners[] | select(.Name == \"$OWNER\") | .Users[] | select(.Name == \"$USER\") | .Name" $CONFIG_FILE)
                USER_PASS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Regions[] | select(.Name == \"$REGION\") | .Owners[] | select(.Name == \"$OWNER\") | .Users[] | select(.Name == \"$USER\") | .Pass" $CONFIG_FILE)
                USER_SUBJECT=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Regions[] | select(.Name == \"$REGION\") | .Owners[] | select(.Name == \"$OWNER\") | .Users[] | select(.Name == \"$USER\") | .Subject" $CONFIG_FILE)

                # Extract fields from subject
                C=$(echo "$USER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
                ST=$(echo "$USER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
                L=$(echo "$USER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')
                O=$(echo "$USER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^O=/) {sub(/^O=/, "", $i); print $i}}')
                OU=$(echo "$USER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^OU=/) {sub(/^OU=/, "", $i); print $i}}')
                CN=$(echo "$USER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^CN=/) {sub(/^CN=/, "", $i); print $i}}')
                CSR_NAMES=$(echo "$USER_SUBJECT" | sed 's/,CN=[^,]*//')
                AFFILIATION="$C.$ST.$L.$O.$OU"

                # Register Wallet User
                docker exec -it $CA_NAME fabric-ca-client register -u https://$CA_NAME:$CA_PASS@$CA_NAME:$CA_PORT --mspdir $CA_CLI_DIR/msp \
                  --id.name $USER_NAME --id.secret $USER_PASS --id.type client --id.affiliation $AFFILIATION --enrollment.type idemix --idemix.curve gurvy.Bn254

                # Enroll Wallet User
                docker exec -it $CA_NAME fabric-ca-client enroll -u https://$USER_NAME:$USER_PASS@$CA_NAME:$CA_PORT --mspdir $KEYS_DIR/$CHANNEL/$REGION/$OWNER_NAME/users/$USER_NAME/msp \
                    --csr.cn $CN --csr.names "$CSR_NAMES"
            done
            echo_ok "Users for $REGION enrolled."
        done
        echo_ok "Owners for $REGION enrolled."
    done
done


# ###############################################################
# # set permissions
# ###############################################################
echo_info "ScriptInfo: set permissions for keys-folder"
chmod -R 777 ./keys

echo_ok "Users enrolled..."

