###############################################################
#!/bin/bash
#
# This script starts Root-CA and generates certificates for Intermediate-CA
# 
#
###############################################################
# 
# Test certificate chain:
# openssl verify -CAfile cacert.pem -untrusted intermediatecert.pem cert.pem
# 
# Display certificate:
# openssl x509 -in cert.pem -text -noout
#
# Display certificate content:
# openssl x509 -in cert.pem -text -noout | grep -A 1 "Authority Key Identifier"
# openssl x509 -in cert.pem -text -noout | grep -A 1 "Subject Key Identifier"
# 
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/ca_utils.sh"
check_script


###############################################################
# Params
###############################################################
CONFIG_FILE="$SCRIPT_DIR/infrastructure-dev.yaml"
DOCKER_UNRAID=$(yq eval '.Docker.Unraid' $CONFIG_FILE)
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $CONFIG_FILE)

ORBIS_TOOLS_NAME=$(yq eval ".Orbis.Tools.Name" "$CONFIG_FILE")
ORBIS_TOOLS_CACLI_DIR=/etc/hyperledger/fabric-ca-client

echo ""
echo_warn "TLS certs enrolling... (Defaults: https://hyperledger-fabric-ca.readthedocs.io/en/latest/serverconfig.html)"


###############################################################
# Params for Orbis-TLS
###############################################################
ORBIS=$(yq eval ".Orbis.Name" "$CONFIG_FILE")
ORBIS_TLS_NAME=$(yq eval ".Orbis.TLS.Name" "$CONFIG_FILE")
ORBIS_TLS_PASS=$(yq eval ".Orbis.TLS.Pass" "$CONFIG_FILE")
ORBIS_TLS_PORT=$(yq eval ".Orbis.TLS.Port" "$CONFIG_FILE")


###############################################################
# Register and entroll TLS certs for Orbis-CA
###############################################################
ORBIS_CA_NAME=$(yq eval ".Orbis.CA.Name" "$CONFIG_FILE")
ORBIS_CA_PASS=$(yq eval ".Orbis.CA.Pass" "$CONFIG_FILE")
ORBIS_CA_IP=$(yq eval ".Orbis.CA.IP" "$CONFIG_FILE")

echo ""
echo_info "Orbis-CA $ORBIS_CA_NAME TLS registering and enrolling..."
docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$ORBIS_TLS_NAME:$ORBIS_TLS_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
    --home $ORBIS_TOOLS_CACLI_DIR \
    --tls.certfiles tls-root-cert/tls-ca-cert.pem \
    --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$ORBIS_TLS_NAME/tls \
    --id.name $ORBIS_CA_NAME --id.secret $ORBIS_CA_PASS --id.type client --id.affiliation jedo.root
docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$ORBIS_CA_NAME:$ORBIS_CA_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
    --home $ORBIS_TOOLS_CACLI_DIR \
    --tls.certfiles tls-root-cert/tls-ca-cert.pem \
    --enrollment.profile tls \
    --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$ORBIS_CA_NAME/tls \
    --csr.hosts ${ORBIS_CA_NAME},*.jedo.dev


###############################################################
# Register and entroll TLS certs for Regnums-CA
###############################################################
REGNUMS=$(yq eval '.Regnum[] | .Name' "$CONFIG_FILE")
for REGNUM in $REGNUMS; do
    # Params for regnum
    REGNUM_CA_NAME=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .CA.Name" "$CONFIG_FILE")
    REGNUM_CA_PASS=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .CA.Pass" "$CONFIG_FILE")
    REGNUM_CA_IP=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .CA.IP" "$CONFIG_FILE")


    # Register Regnum-CA identity
    echo ""
    echo_info "Regnum-CA $REGNUM_CA_NAME TLS registering and enrolling..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$ORBIS_TLS_NAME:$ORBIS_TLS_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$ORBIS_TLS_NAME/tls \
        --id.name $REGNUM_CA_NAME --id.secret $REGNUM_CA_PASS --id.type client --id.affiliation jedo.root
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$REGNUM_CA_NAME:$REGNUM_CA_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile tls \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$REGNUM_CA_NAME/tls \
        --csr.hosts ${REGNUM_CA_NAME},*.jedo.dev


    #Copy files to Organization msp
    echo_info "Organization msp creating (TLS)..."
    mkdir -p ${PWD}/infrastructure/$ORBIS/$REGNUM/msp/tlscacerts
    cp ${PWD}/infrastructure/$ORBIS/$REGNUM/$REGNUM_CA_NAME/tls/tlscacerts/* ${PWD}/infrastructure/$ORBIS/$REGNUM/msp/tlscacerts
    # Not yet in use
    # mkdir -p ${PWD}/infrastructure/$ORBIS/$REGNUM/msp/tlsintermediatecerts
    # cp ${PWD}/infrastructure/$ORBIS/$REGNUM/$REGNUM_CA_NAME/tls/tlsintermediatecerts/* ${PWD}/infrastructure/$ORBIS/$REGNUM/msp/tlsintermediatecerts


    # Params for Regnum-Admin
    REGNUM_ADMIN_NAME=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .Administration.Contact" "$CONFIG_FILE")
    REGNUM_ADMIN_PASS=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .Administration.Pass" "$CONFIG_FILE")
    REGNUM_ADMIN_SUBJECT=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .Administration.Subject" $CONFIG_FILE)
    C=$(echo "$REGNUM_ADMIN_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
    ST=$(echo "$REGNUM_ADMIN_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
    L=$(echo "$REGNUM_ADMIN_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')
    CN=$(echo "$REGNUM_ADMIN_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^CN=/) {sub(/^CN=/, "", $i); print $i}}')
    CSR_NAMES=$(echo "$REGNUM_ADMIN_SUBJECT" | sed 's/,CN=[^,]*//')


    # Register Regnum-Admin identity
    echo ""
    echo_info "Regnum-Admin $REGNUM_ADMIN_NAME TLS registering and enrolling..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$ORBIS_TLS_NAME:$ORBIS_TLS_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$ORBIS_TLS_NAME/tls \
        --id.name $REGNUM_ADMIN_NAME --id.secret $REGNUM_ADMIN_PASS --id.type admin --id.affiliation jedo.root
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$REGNUM_ADMIN_NAME:$REGNUM_ADMIN_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile tls \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/_Admin/$REGNUM_ADMIN_NAME/tls \
        --csr.hosts ${REGNUM_CA_NAME},*.jedo.dev \
        --csr.cn $CN --csr.names "$CSR_NAMES"


    # copy Regnum-Admin-Client tlscacerts
    echo_info "Admin Client tlscacerts copying..."
    mkdir -p ${PWD}/infrastructure/$ORBIS/$REGNUM/_Admin/tls/tlscacerts
    cp ${PWD}/infrastructure/$ORBIS/$REGNUM/_Admin/$REGNUM_ADMIN_NAME/tls/tlscacerts/* ${PWD}/infrastructure/$ORBIS/$REGNUM/_Admin/tls/tlscacerts
done


###############################################################
# Register and entroll Ager-CA TLS certs
###############################################################
AGERS=$(yq eval '.Ager[] | .Name' "$CONFIG_FILE")
for AGER in $AGERS; do
    # Params for ager
    AGER_CA_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.Name" "$CONFIG_FILE")
    AGER_CA_PASS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.Pass" "$CONFIG_FILE")
    AGER_CA_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.IP" "$CONFIG_FILE")
    AGER_PARENT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Administration.Parent" "$CONFIG_FILE")


    # Register Ager-CA identity
    echo ""
    echo_info "Ager-CA $AGER_CA_NAME TLS registering and enrolling..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$ORBIS_TLS_NAME:$ORBIS_TLS_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$ORBIS_TLS_NAME/tls \
        --id.name $AGER_CA_NAME --id.secret $AGER_CA_PASS --id.type client --id.affiliation jedo.root
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$AGER_CA_NAME:$AGER_CA_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile tls \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$AGER_PARENT/$AGER/$AGER_CA_NAME/tls \
        --csr.hosts ${AGER_CA_NAME},*.jedo.dev
done

###############################################################
# Last Tasks
###############################################################
chmod -R 777 infrastructure
echo ""
echo_ok "TLS certs enrolled."
