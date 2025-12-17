###############################################################
#!/bin/bash
#
# Register and enroll all identities needed for the JEDO-Token network.
# FIXED VERSION: Uses msp-bootstrap for admin operations
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
check_script

###############################################################
# Params
###############################################################
CONFIG_FILE="$SCRIPT_DIR/infrastructure-cc.yaml"
FABRIC_BIN_PATH=$(yq eval '.Fabric.Path' "$CONFIG_FILE")
DOCKER_UNRAID=$(yq eval '.Docker.Unraid' $CONFIG_FILE)
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $CONFIG_FILE)

ORBIS_TOOLS_NAME=$(yq eval ".Orbis.Tools.Name" "$CONFIG_FILE")
ORBIS_TOOLS_CACLI_DIR=/etc/hyperledger/fabric-ca-client
ORBIS=$(yq eval ".Orbis.Name" "$CONFIG_FILE")
ORBIS_CA_NAME=$(yq eval ".Orbis.CA.Name" "$CONFIG_FILE")
ORBIS_CA_PASS=$(yq eval ".Orbis.CA.Pass" "$CONFIG_FILE")
ORBIS_CA_PORT=$(yq eval ".Orbis.CA.Port" "$CONFIG_FILE")

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
    REGNUM=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Administration.Parent" $CONFIG_FILE)
    CA_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.Name" $CONFIG_FILE)
    CA_PASS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.Pass" $CONFIG_FILE)
    CA_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.Port" $CONFIG_FILE)
    CAAPI_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.CAAPI.Name" "$CONFIG_FILE")
    CAAPI_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.CAAPI.IP" "$CONFIG_FILE")
    CAAPI_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.CAAPI.SrvPort" "$CONFIG_FILE")

#     ###############################################################
#     # Enroll Admins @ Orbis-CA (like Orderer/Peer!)
#     ###############################################################
#     ADMINS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Admins[].Name" $CONFIG_FILE)
#     for ADMIN in $ADMINS; do
#         echo ""
#         echo_info "Admins for $AGER enrolling at Orbis-CA..."
#         ADMIN_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Admins[] | select(.Name == \"$ADMIN\") | .Name" $CONFIG_FILE)
#         ADMIN_SUBJECT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Admins[] | select(.Name == \"$ADMIN\") | .Subject" $CONFIG_FILE)
#         ADMIN_PASS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Admins[] | select(.Name == \"$ADMIN\") | .Pass" $CONFIG_FILE)

#         # Extract fields from subject
#         C=$(echo "$ADMIN_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
#         ST=$(echo "$ADMIN_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
#         L=$(echo "$ADMIN_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')
#         O=$(echo "$ADMIN_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^O=/) {sub(/^O=/, "", $i); print $i}}')
#         CN=$(echo "$ADMIN_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^CN=/) {sub(/^CN=/, "", $i); print $i}}')
#         CSR_NAMES="C=$C,ST=$ST,L=$L,O=$O"
#         AFFILIATION=$ORBIS.$REGNUM

#         # ✅ Register Admin at Orbis-CA (using Orbis bootstrap msp)
#         docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register \
#             -u https://$ORBIS_CA_NAME:$ORBIS_CA_PASS@$ORBIS_CA_NAME:$ORBIS_CA_PORT \
#             --home $ORBIS_TOOLS_CACLI_DIR \
#             --tls.certfiles tls-root-cert/tls-ca-cert.pem \
#             --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$ORBIS_CA_NAME/msp \
#             --id.name $ADMIN_NAME \
#             --id.secret $ADMIN_PASS \
#             --id.type admin \
#             --id.affiliation $AFFILIATION \
#             --id.attrs "role=admin:ecert"
        
#         # ✅ Enroll Admin at Orbis-CA
#         docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll \
#             -u https://$ADMIN_NAME:$ADMIN_PASS@$ORBIS_CA_NAME:$ORBIS_CA_PORT \
#             --home $ORBIS_TOOLS_CACLI_DIR \
#             --tls.certfiles tls-root-cert/tls-ca-cert.pem \
#             --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$ADMIN_NAME/msp \
#             --csr.hosts "$CA_NAME,$CAAPI_NAME,$CAAPI_IP,*.jedo.cc" \
#             --csr.cn $CN --csr.names "$CSR_NAMES"
        
#         # NodeOUs config
#         CA_CERT_FILE=$(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$ADMIN_NAME/msp/intermediatecerts/*.pem)
#         cat <<EOF > ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$ADMIN_NAME/msp/config.yaml
# NodeOUs:
#   Enable: true
#   ClientOUIdentifier:
#     Certificate: intermediatecerts/$(basename $CA_CERT_FILE)
#     OrganizationalUnitIdentifier: client
#   PeerOUIdentifier:
#     Certificate: intermediatecerts/$(basename $CA_CERT_FILE)
#     OrganizationalUnitIdentifier: peer
#   AdminOUIdentifier:
#     Certificate: intermediatecerts/$(basename $CA_CERT_FILE)
#     OrganizationalUnitIdentifier: admin
#   OrdererOUIdentifier:
#     Certificate: intermediatecerts/$(basename $CA_CERT_FILE)
#     OrganizationalUnitIdentifier: orderer
# EOF
#     done
#     echo_ok "Admins for $AGER enrolled at Orbis-CA."

    ###############################################################
    # Enroll Gens @ Ager-CA (uses msp-bootstrap!)
    ###############################################################
    GENSS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gens[].Name" $CONFIG_FILE)
    for GENS in $GENSS; do
        echo ""
        echo_info "Gens for $AGER enrolling at Ager-CA..."
        GENS_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gens[] | select(.Name == \"$GENS\") | .Name" $CONFIG_FILE)
        GENS_SUBJECT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gens[] | select(.Name == \"$GENS\") | .Subject" $CONFIG_FILE)
        GENS_PASS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gens[] | select(.Name == \"$GENS\") | .Pass" $CONFIG_FILE)

        # Extract fields from subject
        C=$(echo "$GENS_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
        ST=$(echo "$GENS_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
        L=$(echo "$GENS_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')
        O=$(echo "$GENS_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^O=/) {sub(/^O=/, "", $i); print $i}}')
        CN=$(echo "$GENS_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^CN=/) {sub(/^CN=/, "", $i); print $i}}')
        CSR_NAMES="C=$C,ST=$ST,L=$L,O=$O"
        AFFILIATION=$ORBIS.$REGNUM.$AGER

        # ✅ Register at Ager-CA (using msp-bootstrap!)
        docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register \
            -u https://$CA_NAME:$CA_PASS@$CA_NAME:$CA_PORT \
            --home $ORBIS_TOOLS_CACLI_DIR \
            --tls.certfiles tls-root-cert/tls-ca-cert.pem \
            --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$CA_NAME/msp-bootstrap \
            --id.name $GENS_NAME \
            --id.secret $GENS_PASS \
            --id.type client \
            --id.affiliation $AFFILIATION \
            --id.attrs "role=gens:ecert"
        
        # Enroll at Ager-CA
        docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll \
            -u https://$GENS_NAME:$GENS_PASS@$CA_NAME:$CA_PORT \
            --home $ORBIS_TOOLS_CACLI_DIR \
            --tls.certfiles tls-root-cert/tls-ca-cert.pem \
            --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$GENS_NAME/$CN/msp \
            --csr.hosts "$CA_NAME,$CAAPI_NAME,$CAAPI_IP,*.jedo.cc" \
            --csr.cn $CN --csr.names "$CSR_NAMES"

        ###############################################################
        # Enroll Humans @ Ager-CA (uses msp-bootstrap!)
        ###############################################################
        HUMANS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gens[] | select(.Name == \"$GENS\") | .Humans[].Name" $CONFIG_FILE)
        for HUMAN in $HUMANS; do
            echo ""
            echo_info "Users for $AGER enrolling at Ager-CA..."

            HUMAN_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gens[] | select(.Name == \"$GENS\") | .Humans[] | select(.Name == \"$HUMAN\") | .Name" $CONFIG_FILE)
            HUMAN_SUBJECT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gens[] | select(.Name == \"$GENS\") | .Humans[] | select(.Name == \"$HUMAN\") | .Subject" $CONFIG_FILE)
            HUMAN_PASS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gens[] | select(.Name == \"$GENS\") | .Humans[] | select(.Name == \"$HUMAN\") | .Pass" $CONFIG_FILE)

            # Extract fields from subject
            C=$(echo "$HUMAN_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
            ST=$(echo "$HUMAN_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
            L=$(echo "$HUMAN_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')
            O=$(echo "$HUMAN_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^O=/) {sub(/^O=/, "", $i); print $i}}')
            CN=$(echo "$HUMAN_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^CN=/) {sub(/^CN=/, "", $i); print $i}}')
            CSR_NAMES="C=$C,ST=$ST,L=$L,O=$O"
            AFFILIATION=$ORBIS.$REGNUM.$AGER

            # ✅ Register at Ager-CA (using msp-bootstrap!)
            docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register \
                -u https://$CA_NAME:$CA_PASS@$CA_NAME:$CA_PORT \
                --home $ORBIS_TOOLS_CACLI_DIR \
                --tls.certfiles tls-root-cert/tls-ca-cert.pem \
                --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$CA_NAME/msp-bootstrap \
                --id.name $HUMAN_NAME \
                --id.secret $HUMAN_PASS \
                --id.type client \
                --id.affiliation $AFFILIATION \
                --id.attrs "role=human:ecert" \
                --enrollment.type idemix --idemix.curve gurvy.Bn254
            
            # Enroll at Ager-CA
            docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll \
                -u https://$HUMAN_NAME:$HUMAN_PASS@$CA_NAME:$CA_PORT \
                --home $ORBIS_TOOLS_CACLI_DIR \
                --tls.certfiles tls-root-cert/tls-ca-cert.pem \
                --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$GENS_NAME/$HUMAN_NAME/msp \
                --csr.hosts "$CA_NAME,$CAAPI_NAME,$CAAPI_IP,192.168.0.13,*.jedo.cc" \
                --csr.cn $CN --csr.names "$CSR_NAMES" \
                --enrollment.type idemix --idemix.curve gurvy.Bn254
        done
    done
    echo_ok "Gens and Humans for $AGER enrolled at Ager-CA."
done

################################################################
# Last Tasks
################################################################
echo_info "ScriptInfo: set permissions for keys-folder"
chmod -R 777 ./infrastructure
echo_ok "Enrollment completed."
