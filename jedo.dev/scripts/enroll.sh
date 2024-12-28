###############################################################
#!/bin/bash
#
# Register and enroll all identities needed for the JEDO-Token network.
#
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
check_script


###############################################################
# Params
###############################################################
CONFIG_FILE="$SCRIPT_DIR/infrastructure-dev.yaml"
FABRIC_BIN_PATH=$(yq eval '.Fabric.Path' "$CONFIG_FILE")
DOCKER_UNRAID=$(yq eval '.Docker.Unraid' $CONFIG_FILE)
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $CONFIG_FILE)

ORBIS_TOOLS_NAME=$(yq eval ".Orbis.Tools.Name" "$CONFIG_FILE")
ORBIS_TOOLS_CACLI_DIR=/etc/hyperledger/fabric-ca-client


###############################################################
# Enroll Token Network
###############################################################
AGERS=$(yq eval '.Ager[] | .Name' "$CONFIG_FILE")
for AGER in $AGERS; do
    ###############################################################
    # Params
    ###############################################################
    echo ""
    echo_warn "Enrollment for $AGER starting..."
    ORBIS=$(yq eval ".Orbis.Name" "$CONFIG_FILE")
    REGNUM=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Administration.Parent" $CONFIG_FILE)
    CA_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.Name" $CONFIG_FILE)
    CA_PASS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.Pass" $CONFIG_FILE)
    CA_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.Port" $CONFIG_FILE)
    CAAPI_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.CAAPI.Name" "$CONFIG_FILE")
    CAAPI_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.CAAPI.IP" "$CONFIG_FILE")
    CAAPI_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.CAAPI.SrvPort" "$CONFIG_FILE")


    ###############################################################
    # Enroll Auditors
    ###############################################################
    AUDITORS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Auditors[].Name" $CONFIG_FILE)
    for AUDITOR in $AUDITORS; do
        echo ""
        echo_info "Auditors for $AGER enrolling..."
        AUDITOR_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Auditors[] | select(.Name == \"$AUDITOR\") | .Name" $CONFIG_FILE)
        AUDITOR_SUBJECT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Auditors[] | select(.Name == \"$AUDITOR\") | .Subject" $CONFIG_FILE)
        AUDITOR_PASS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Auditors[] | select(.Name == \"$AUDITOR\") | .Pass" $CONFIG_FILE)

        # Extract fields from subject
        C=$(echo "$AUDITOR_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
        ST=$(echo "$AUDITOR_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
        L=$(echo "$AUDITOR_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')
        CN=$(echo "$AUDITOR_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^CN=/) {sub(/^CN=/, "", $i); print $i}}')
        CSR_NAMES="C=$C,ST=$ST,L=$L"
        AFFILIATION="jedo.root" #ToDo Affiliation


        # Register FSC User
        docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$CA_NAME:$CA_PASS@$CA_NAME:$CA_PORT \
            --home $ORBIS_TOOLS_CACLI_DIR \
            --tls.certfiles tls-root-cert/tls-ca-cert.pem \
            --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$CA_NAME/msp \
            --id.name fsc.$AUDITOR_NAME --id.secret $AUDITOR_PASS --id.type client --id.affiliation $AFFILIATION \
        # Enroll FSC User
        docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://fsc.$AUDITOR_NAME:$AUDITOR_PASS@$CA_NAME:$CA_PORT \
            --home $ORBIS_TOOLS_CACLI_DIR \
            --tls.certfiles tls-root-cert/tls-ca-cert.pem \
            --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$AUDITOR_NAME/fsc/msp \
            --csr.hosts "$CA_NAME,$CAAPI_NAME,$CAAPI_IP,*.jedo.dev" \
            --csr.cn $CN --csr.names "$CSR_NAMES" \
        # Register Wallet User
        docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$CA_NAME:$CA_PASS@$CA_NAME:$CA_PORT \
            --home $ORBIS_TOOLS_CACLI_DIR \
            --tls.certfiles tls-root-cert/tls-ca-cert.pem \
            --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$CA_NAME/msp \
            --id.name $AUDITOR_NAME --id.secret $AUDITOR_PASS --id.type client --id.affiliation $AFFILIATION \
            --id.attrs "jedo.apiPort=$CAAPI_PORT, jedo.role=auditor"
        # Enroll Wallet User
        docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$AUDITOR_NAME:$AUDITOR_PASS@$CA_NAME:$CA_PORT \
            --home $ORBIS_TOOLS_CACLI_DIR \
            --tls.certfiles tls-root-cert/tls-ca-cert.pem \
            --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$AUDITOR_NAME/msp \
            --csr.hosts "$CA_NAME,$CAAPI_NAME,$CAAPI_IP,*.jedo.dev" \
            --csr.cn $CN --csr.names "$CSR_NAMES" \
            --enrollment.attrs "jedo.apiPort, jedo.role"
    done
    echo_ok "Auditors for $AGER enrolled."


    ###############################################################
    # Enroll Issuers
    ###############################################################
    ISSUERS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Issuers[].Name" $CONFIG_FILE)
    for ISSUER in $ISSUERS; do
        echo ""
        echo_info "Issuers for $AGER enrolling..."
        ISSUER_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Issuers[] | select(.Name == \"$ISSUER\") | .Name" $CONFIG_FILE)
        ISSUER_SUBJECT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Issuers[] | select(.Name == \"$ISSUER\") | .Subject" $CONFIG_FILE)
        ISSUER_PASS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Issuers[] | select(.Name == \"$ISSUER\") | .Pass" $CONFIG_FILE)

        # Extract fields from subject
        C=$(echo "$ISSUER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
        ST=$(echo "$ISSUER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
        L=$(echo "$ISSUER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')
        CN=$(echo "$ISSUER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^CN=/) {sub(/^CN=/, "", $i); print $i}}')
        CSR_NAMES="C=$C,ST=$ST,L=$L"
        AFFILIATION="jedo.root" #ToDo Affiliation

        # Register FSC User
        docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$CA_NAME:$CA_PASS@$CA_NAME:$CA_PORT \
            --home $ORBIS_TOOLS_CACLI_DIR \
            --tls.certfiles tls-root-cert/tls-ca-cert.pem \
            --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$CA_NAME/msp \
            --id.name fsc.$ISSUER_NAME --id.secret $ISSUER_PASS --id.type client --id.affiliation $AFFILIATION \
        # Enroll FSC User
        docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://fsc.$ISSUER_NAME:$ISSUER_PASS@$CA_NAME:$CA_PORT \
            --home $ORBIS_TOOLS_CACLI_DIR \
            --tls.certfiles tls-root-cert/tls-ca-cert.pem \
            --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$ISSUER_NAME/fsc/msp \
            --csr.hosts "$CA_NAME,$CAAPI_NAME,$CAAPI_IP,*.jedo.dev" \
            --csr.cn $CN --csr.names "$CSR_NAMES" \
        # Register Wallet User
        docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$CA_NAME:$CA_PASS@$CA_NAME:$CA_PORT \
            --home $ORBIS_TOOLS_CACLI_DIR \
            --tls.certfiles tls-root-cert/tls-ca-cert.pem \
            --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$CA_NAME/msp \
            --id.name $ISSUER_NAME --id.secret $ISSUER_PASS --id.type client --id.affiliation $AFFILIATION \
            --id.attrs "jedo.apiPort=$CAAPI_PORT, jedo.role=issuer"
        # Enroll Wallet User
        docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$ISSUER_NAME:$ISSUER_PASS@$CA_NAME:$CA_PORT \
            --home $ORBIS_TOOLS_CACLI_DIR \
            --tls.certfiles tls-root-cert/tls-ca-cert.pem \
            --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$ISSUER_NAME/msp \
            --csr.hosts "$CA_NAME,$CAAPI_NAME,$CAAPI_IP,*.jedo.dev" \
            --csr.cn $CN --csr.names "$CSR_NAMES" \
            --enrollment.attrs "jedo.apiPort, jedo.role"
    done
    echo_ok "Issuers for $AGER enrolled."


    ###############################################################
    # Enroll Owner
    ###############################################################
    OWNERS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Owners[].Name" $CONFIG_FILE)
    for OWNER in $OWNERS; do
        echo ""
        echo_info "Owners for $AGER enrolling..."
        OWNER_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Owners[] | select(.Name == \"$OWNER\") | .Name" $CONFIG_FILE)
        OWNER_SUBJECT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Owners[] | select(.Name == \"$OWNER\") | .Subject" $CONFIG_FILE)
        OWNER_PASS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Owners[] | select(.Name == \"$OWNER\") | .Pass" $CONFIG_FILE)

        # Extract fields from subject
        C=$(echo "$OWNER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
        ST=$(echo "$OWNER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
        L=$(echo "$OWNER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')
        O=$(echo "$OWNER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^O=/) {sub(/^O=/, "", $i); print $i}}')
        CN=$(echo "$OWNER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^CN=/) {sub(/^CN=/, "", $i); print $i}}')
        CSR_NAMES="C=$C,ST=$ST,L=$L,O=$O"
        AFFILIATION="jedo.root" #ToDo Affiliation

        # Register FSC User
        docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$CA_NAME:$CA_PASS@$CA_NAME:$CA_PORT \
            --home $ORBIS_TOOLS_CACLI_DIR \
            --tls.certfiles tls-root-cert/tls-ca-cert.pem \
            --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$CA_NAME/msp \
            --id.name fsc.$OWNER_NAME --id.secret $OWNER_PASS --id.type client --id.affiliation $AFFILIATION \
        # Enroll FSC User
        docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://fsc.$OWNER_NAME:$OWNER_PASS@$CA_NAME:$CA_PORT \
            --home $ORBIS_TOOLS_CACLI_DIR \
            --tls.certfiles tls-root-cert/tls-ca-cert.pem \
            --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$OWNER_NAME/$CN/fsc/msp \
            --csr.hosts "$CA_NAME,$CAAPI_NAME,$CAAPI_IP,*.jedo.dev" \
            --csr.cn $CN --csr.names "$CSR_NAMES" \
        # Register Wallet User
        docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$CA_NAME:$CA_PASS@$CA_NAME:$CA_PORT \
            --home $ORBIS_TOOLS_CACLI_DIR \
            --tls.certfiles tls-root-cert/tls-ca-cert.pem \
            --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$CA_NAME/msp \
            --id.name $OWNER_NAME --id.secret $OWNER_PASS --id.type client --id.affiliation $AFFILIATION \
            --id.attrs "jedo.apiPort=$CAAPI_PORT, jedo.role=owner" \
            --enrollment.type idemix --idemix.curve gurvy.Bn254
        # Enroll Wallet User
        docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$OWNER_NAME:$OWNER_PASS@$CA_NAME:$CA_PORT \
            --home $ORBIS_TOOLS_CACLI_DIR \
            --tls.certfiles tls-root-cert/tls-ca-cert.pem \
            --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$OWNER_NAME/$CN/msp \
            --csr.hosts "$CA_NAME,$CAAPI_NAME,$CAAPI_IP,*.jedo.dev" \
            --csr.cn $CN --csr.names "$CSR_NAMES" \
            --enrollment.attrs "jedo.apiPort, jedo.role"


        ###############################################################
        # Enroll Wallet User
        ###############################################################
        USERS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Owners[] | select(.Name == \"$OWNER\") | .Users[].Name" $CONFIG_FILE)
        for USER in $USERS; do
            echo ""
            echo_info "Users for $AGER enrolling..."

            USER_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Owners[] | select(.Name == \"$OWNER\") | .Users[] | select(.Name == \"$USER\") | .Name" $CONFIG_FILE)
            USER_SUBJECT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Owners[] | select(.Name == \"$OWNER\") | .Users[] | select(.Name == \"$USER\") | .Subject" $CONFIG_FILE)
            USER_PASS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Owners[] | select(.Name == \"$OWNER\") | .Users[] | select(.Name == \"$USER\") | .Pass" $CONFIG_FILE)

            # Extract fields from subject
            C=$(echo "$USER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
            ST=$(echo "$USER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
            L=$(echo "$USER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')
            O=$(echo "$USER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^O=/) {sub(/^O=/, "", $i); print $i}}')
            CN=$(echo "$USER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^CN=/) {sub(/^CN=/, "", $i); print $i}}')
            CSR_NAMES="C=$C,ST=$ST,L=$L,O=$O"
            AFFILIATION="jedo.root" #ToDo Affiliation

            # Register Wallet User
            docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$CA_NAME:$CA_PASS@$CA_NAME:$CA_PORT \
                --home $ORBIS_TOOLS_CACLI_DIR \
                --tls.certfiles tls-root-cert/tls-ca-cert.pem \
                --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$CA_NAME/msp \
                --id.name $USER_NAME --id.secret $USER_PASS --id.type client --id.affiliation $AFFILIATION \
                --enrollment.type idemix --idemix.curve gurvy.Bn254
            # Enroll Wallet User
            docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$USER_NAME:$USER_PASS@$CA_NAME:$CA_PORT \
                --home $ORBIS_TOOLS_CACLI_DIR \
                --tls.certfiles tls-root-cert/tls-ca-cert.pem \
                --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$OWNER_NAME/$USER_NAME/msp \
                --csr.hosts "$CA_NAME,$CAAPI_NAME,$CAAPI_IP,*.jedo.dev" \
                --csr.cn $CN --csr.names "$CSR_NAMES"
        done
    done
    echo_ok "Owners and Users for $AGER enrolled."
done


################################################################
# Last Tasks
################################################################
echo_info "ScriptInfo: set permissions for keys-folder"
chmod -R 777 ./infrastructure
echo_ok "Enrollment completed."

