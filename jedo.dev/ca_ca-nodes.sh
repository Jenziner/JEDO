###############################################################
#!/bin/bash
#
# This script starts Root-CA and generates certificates for Intermediate-CA
# FIXED VERSION: Org MSP uses only Orbis-CA cert for nodes enrolled at Orbis
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/ca_utils.sh"
check_script

###############################################################
# Params
###############################################################
CONFIG_FILE="$SCRIPT_DIR/infrastructure-cc.yaml"
DOCKER_UNRAID=$(yq eval '.Docker.Unraid' $CONFIG_FILE)
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $CONFIG_FILE)
ORBIS_TOOLS_NAME=$(yq eval ".Orbis.Tools.Name" "$CONFIG_FILE")
ORBIS_TOOLS_CACLI_DIR=/etc/hyperledger/fabric-ca-client

get_hosts

echo ""
echo_warn "CA nodes starting..."

###############################################################
# ORBIS-CA (Root CA)
###############################################################
ORBIS=$(yq eval ".Orbis.Name" "$CONFIG_FILE")
ORBIS_CA_NAME=$(yq eval ".Orbis.CA.Name" "$CONFIG_FILE")
ORBIS_CA_PASS=$(yq eval ".Orbis.CA.Pass" "$CONFIG_FILE")
ORBIS_CA_IP=$(yq eval ".Orbis.CA.IP" "$CONFIG_FILE")
ORBIS_CA_PORT=$(yq eval ".Orbis.CA.Port" "$CONFIG_FILE")
ORBIS_CA_OPPORT=$(yq eval ".Orbis.CA.OpPort" "$CONFIG_FILE")
HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server
LOCAL_SRV_DIR=${PWD}/infrastructure/$ORBIS/$ORBIS_CA_NAME

mkdir -p $LOCAL_SRV_DIR

# TEMP - needs to be changed, if certs are available in git, copy then from git when needed
cp -r ./RootCA/ROOT/jedo.cc/$ORBIS_CA_NAME/. $LOCAL_SRV_DIR

# Start Orbis-CA
ca_writeCfg "orbis" "$ORBIS_CA_NAME" "$CONFIG_FILE" "$LOCAL_SRV_DIR"
ca_start "$ORBIS_CA_NAME" "$CONFIG_FILE" "$LOCAL_SRV_DIR"

# Enroll Orbis-CA bootstrap identity
echo ""
echo_info "Orbis-CA enrolling bootstrap identity..."
docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll \
    -u https://$ORBIS_CA_NAME:$ORBIS_CA_PASS@$ORBIS_CA_NAME:$ORBIS_CA_PORT \
    --home $ORBIS_TOOLS_CACLI_DIR \
    --tls.certfiles tls-root-cert/tls-ca-cert.pem \
    --enrollment.profile ca \
    --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$ORBIS_CA_NAME/msp

###############################################################
# Regnum-CA (Intermediate CA Level 1)
###############################################################
REGNUMS=$(yq eval '.Regnum[] | .Name' "$CONFIG_FILE")
for REGNUM in $REGNUMS; do
    # Params for regnum
    REGNUM_CA_NAME=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .CA.Name" "$CONFIG_FILE")
    REGNUM_CA_PASS=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .CA.Pass" "$CONFIG_FILE")
    REGNUM_CA_IP=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .CA.IP" "$CONFIG_FILE")
    REGNUM_CA_PORT=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .CA.Port" "$CONFIG_FILE")
    REGNUM_CA_OPPORT=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .CA.OpPort" "$CONFIG_FILE")
    
    ORBIS=$(yq eval ".Orbis.Name" "$CONFIG_FILE")
    ORBIS_CA_NAME=$(yq eval ".Orbis.CA.Name" "$CONFIG_FILE")
    ORBIS_CA_PASS=$(yq eval ".Orbis.CA.Pass" "$CONFIG_FILE")
    ORBIS_CA_PORT=$(yq eval ".Orbis.CA.Port" "$CONFIG_FILE")
    
    LOCAL_SRV_DIR=${PWD}/infrastructure/$ORBIS/$REGNUM/$REGNUM_CA_NAME/
    HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server
    AFFILIATION=$ORBIS.$REGNUM
    
    mkdir -p $LOCAL_SRV_DIR
    
    # Register Regnum-CA ID identity at Orbis-CA (using Orbis bootstrap msp)
    echo ""
    echo_info "Regnum-CA ID $REGNUM_CA_NAME registering..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register \
        -u https://$ORBIS_CA_NAME:$ORBIS_CA_PASS@$ORBIS_CA_NAME:$ORBIS_CA_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$ORBIS_CA_NAME/msp \
        --id.name $REGNUM_CA_NAME \
        --id.secret $REGNUM_CA_PASS \
        --id.type client \
        --id.affiliation $AFFILIATION \
        --id.attrs '"hf.Registrar.Roles=user,admin","hf.Revoker=true","hf.IntermediateCA=true"'
    
    # Enroll Regnum-CA at Orbis-CA (for server certificate)
    echo ""
    echo_info "Regnum-CA enrolling for server certificate..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll \
        -u https://$REGNUM_CA_NAME:$REGNUM_CA_PASS@$ORBIS_CA_NAME:$ORBIS_CA_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile ca \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$REGNUM_CA_NAME/msp \
        --csr.hosts ${REGNUM_CA_NAME},*.jedo.cc
    
    # Generating NodeOUs-File
    echo ""
    echo_info "NodeOUs-File writing..."
    CA_CERT_FILE=$(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/$REGNUM_CA_NAME/msp/cacerts/*.pem)
    
    cat <<EOF > ${PWD}/infrastructure/$ORBIS/$REGNUM/$REGNUM_CA_NAME/msp/config.yaml
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: intermediatecerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: intermediatecerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: intermediatecerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: intermediatecerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: orderer
EOF
    
    # Start Regnum-CA
    ca_writeCfg "regnum" "$REGNUM_CA_NAME" "$CONFIG_FILE" "$LOCAL_SRV_DIR"
    ca_start "$REGNUM_CA_NAME" "$CONFIG_FILE" "$LOCAL_SRV_DIR"
    
    # Enroll Regnum-CA bootstrap identity (for admin operations)
    echo ""
    echo_info "Enrolling Regnum-CA bootstrap identity for admin operations..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll \
        -u https://$REGNUM_CA_NAME:$REGNUM_CA_PASS@$REGNUM_CA_NAME:$REGNUM_CA_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$REGNUM_CA_NAME/msp-bootstrap
    
    # Copy files to Organization msp (from FIRST enroll only!)
    echo ""
    echo_info "Organization msp creating..."
    rm -rf ${PWD}/infrastructure/$ORBIS/$REGNUM/msp
    mkdir -p ${PWD}/infrastructure/$ORBIS/$REGNUM/msp/cacerts
    mkdir -p ${PWD}/infrastructure/$ORBIS/$REGNUM/msp/intermediatecerts
    
    # Copy root CA
    cp ${PWD}/infrastructure/$ORBIS/$REGNUM/$REGNUM_CA_NAME/msp/cacerts/* \
       ${PWD}/infrastructure/$ORBIS/$REGNUM/msp/cacerts/
    
    # Copy intermediate certs
    cp ${PWD}/infrastructure/$ORBIS/$REGNUM/$REGNUM_CA_NAME/msp/intermediatecerts/* \
       ${PWD}/infrastructure/$ORBIS/$REGNUM/msp/intermediatecerts/
    
    # Copy config
    cp ${PWD}/infrastructure/$ORBIS/$REGNUM/$REGNUM_CA_NAME/msp/config.yaml \
       ${PWD}/infrastructure/$ORBIS/$REGNUM/msp/

done

###############################################################
# Ager-CA (Intermediate CA Level 2)
###############################################################
AGERS=$(yq eval '.Ager[] | .Name' "$CONFIG_FILE")
for AGER in $AGERS; do
    # Params for ager
    AGER_CA_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.Name" "$CONFIG_FILE")
    AGER_CA_PASS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.Pass" "$CONFIG_FILE")
    AGER_CA_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.IP" "$CONFIG_FILE")
    AGER_CA_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.Port" "$CONFIG_FILE")
    AGER_CA_OPPORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.OpPort" "$CONFIG_FILE")
    AGER_CAAPI_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.CAAPI.Name" "$CONFIG_FILE")
    AGER_CAAPI_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.CAAPI.IP" "$CONFIG_FILE")
    AGER_CAAPI_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.CAAPI.SrvPort" "$CONFIG_FILE")
    AGER_REGNUM=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Administration.Parent" "$CONFIG_FILE")
    
    REGNUM=$(yq eval ".Regnum[] | select(.Name == \"$AGER_REGNUM\") | .Name" "$CONFIG_FILE")
    REGNUM_CA_NAME=$(yq eval ".Regnum[] | select(.Name == \"$AGER_REGNUM\") | .CA.Name" "$CONFIG_FILE")
    REGNUM_CA_PASS=$(yq eval ".Regnum[] | select(.Name == \"$AGER_REGNUM\") | .CA.Pass" "$CONFIG_FILE")
    REGNUM_CA_PORT=$(yq eval ".Regnum[] | select(.Name == \"$AGER_REGNUM\") | .CA.Port" "$CONFIG_FILE")
    
    LOCAL_SRV_DIR=${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$AGER_CA_NAME/
    HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server
    AFFILIATION=$ORBIS.$REGNUM.$AGER
    
    mkdir -p $LOCAL_SRV_DIR
    
    # Add affiliation to Regnum-CA (using Regnum-CA bootstrap msp)
    echo ""
    echo_info "Affiliation $AFFILIATION adding to Regnum-CA..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client affiliation add $AFFILIATION \
        -u https://$REGNUM_CA_NAME:$REGNUM_CA_PASS@$REGNUM_CA_NAME:$REGNUM_CA_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$REGNUM_CA_NAME/msp-bootstrap
    
    # Register Ager-CA ID identity at Regnum-CA (using bootstrap msp)
    echo ""
    echo_info "Ager-CA ID $AGER_CA_NAME registering..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register \
        -u https://$REGNUM_CA_NAME:$REGNUM_CA_PASS@$REGNUM_CA_NAME:$REGNUM_CA_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$REGNUM_CA_NAME/msp-bootstrap \
        --id.name $AGER_CA_NAME \
        --id.secret $AGER_CA_PASS \
        --id.type client \
        --id.affiliation $AFFILIATION \
        --id.attrs '"hf.Registrar.Roles=user,admin","hf.Revoker=true","hf.IntermediateCA=true"'
    
    # Enroll Ager-CA at Regnum-CA (for server certificate)
    echo ""
    echo_info "Ager-CA enrolling for server certificate..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll \
        -u https://$AGER_CA_NAME:$AGER_CA_PASS@$REGNUM_CA_NAME:$REGNUM_CA_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile ca \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$AGER_CA_NAME/msp \
        --csr.hosts ${REGNUM_CA_NAME},*.jedo.cc
    
    # Generating NodeOUs-File
    echo ""
    echo_info "NodeOUs-File writing..."
    CA_CERT_FILE=$(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$AGER_CA_NAME/msp/cacerts/*.pem)
    
    cat <<EOF > ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$AGER_CA_NAME/msp/config.yaml
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: intermediatecerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: intermediatecerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: intermediatecerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: intermediatecerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: orderer
EOF
    
    # Start Ager-CA
    ca_writeCfg "ager" "$AGER_CA_NAME" "$CONFIG_FILE" "$LOCAL_SRV_DIR"
    ca_start "$AGER_CA_NAME" "$CONFIG_FILE" "$LOCAL_SRV_DIR"
    
    # Enroll Ager-CA bootstrap identity (for admin operations)
    echo ""
    echo_info "Enrolling Ager-CA bootstrap identity for admin operations..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll \
        -u https://$AGER_CA_NAME:$AGER_CA_PASS@$AGER_CA_NAME:$AGER_CA_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$AGER_CA_NAME/msp-bootstrap
    
    # ✅ Build Organization MSP (for Genesis Block - nodes enrolled at Orbis-CA!)
    echo ""
    echo_info "Organization msp creating (for nodes enrolled at Orbis-CA)..."
    rm -rf ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/msp
    mkdir -p ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/msp/cacerts
    mkdir -p ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/msp/intermediatecerts
    mkdir -p ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/msp/tlscacerts

    # Copy root CA (Orbis Root CA)
    cp ${PWD}/infrastructure/$ORBIS/$ORBIS_CA_NAME/msp/cacerts/* \
       ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/msp/cacerts/
    
    # ✅ Copy ONLY Orbis-CA intermediate cert (NOT complete chain!)
    # Nodes (Orderer/Peer) are enrolled at Orbis-CA, so they have Orbis-CA as issuer
    ORBIS_CA_INTERMEDIATE=$(ls ${PWD}/infrastructure/$ORBIS/$ORBIS_CA_NAME/msp/intermediatecerts/*.pem 2>/dev/null | head -1)
    if [ -n "$ORBIS_CA_INTERMEDIATE" ]; then
        cp $ORBIS_CA_INTERMEDIATE \
           ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/msp/intermediatecerts/
    fi
    
    # ⬅️ NEU: Copy TLS Root CA!
    echo_info "Adding TLS Root CA to Organization MSP..."
    cp ${PWD}/infrastructure/$ORBIS/$REGNUM/_Admin/tls/tlscacerts/*.pem \
      ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/msp/tlscacerts/
   
    # NodeOUs config
    CA_CERT_FILE=$(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/msp/intermediatecerts/*.pem 2>/dev/null | head -1)
    
    if [ -z "$CA_CERT_FILE" ]; then
        # Fallback: use cacerts if no intermediate
        CA_CERT_FILE=$(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/msp/cacerts/*.pem)
        CERT_PATH="cacerts/$(basename $CA_CERT_FILE)"
    else
        CERT_PATH="intermediatecerts/$(basename $CA_CERT_FILE)"
    fi
    
    cat <<EOF > ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/msp/config.yaml
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: $CERT_PATH
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: $CERT_PATH
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: $CERT_PATH
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: $CERT_PATH
    OrganizationalUnitIdentifier: orderer
EOF


    # Add affiliation to Ager-CA (using Ager-CA bootstrap msp)
    echo ""
    echo_info "Affiliation $AFFILIATION adding to Ager-CA..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client affiliation add $AFFILIATION \
        -u https://$AGER_CA_NAME:$AGER_CA_PASS@$AGER_CA_NAME:$AGER_CA_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$AGER_CA_NAME/msp-bootstrap


    ###############################################################
    # Enroll Admins @ Orbis-CA (like Orderer/Peer!)
    ###############################################################
    ADMINS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Admins[].Name" $CONFIG_FILE)
    for ADMIN in $ADMINS; do
        echo ""
        echo_info "Admins for $AGER enrolling at Orbis-CA..."
        ADMIN_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Admins[] | select(.Name == \"$ADMIN\") | .Name" $CONFIG_FILE)
        ADMIN_SUBJECT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Admins[] | select(.Name == \"$ADMIN\") | .Subject" $CONFIG_FILE)
        ADMIN_PASS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Admins[] | select(.Name == \"$ADMIN\") | .Pass" $CONFIG_FILE)

        # Extract fields from subject
        C=$(echo "$ADMIN_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
        ST=$(echo "$ADMIN_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
        L=$(echo "$ADMIN_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')
        O=$(echo "$ADMIN_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^O=/) {sub(/^O=/, "", $i); print $i}}')
        CN=$(echo "$ADMIN_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^CN=/) {sub(/^CN=/, "", $i); print $i}}')
        CSR_NAMES="C=$C,ST=$ST,L=$L,O=$O"
        AFFILIATION=$ORBIS.$REGNUM

        # ✅ Register Admin at Orbis-CA (using Orbis bootstrap msp)
        docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register \
            -u https://$ORBIS_CA_NAME:$ORBIS_CA_PASS@$ORBIS_CA_NAME:$ORBIS_CA_PORT \
            --home $ORBIS_TOOLS_CACLI_DIR \
            --tls.certfiles tls-root-cert/tls-ca-cert.pem \
            --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$ORBIS_CA_NAME/msp \
            --id.name $ADMIN_NAME \
            --id.secret $ADMIN_PASS \
            --id.type admin \
            --id.affiliation $AFFILIATION \
            --id.attrs "role=admin:ecert"
        
        # ✅ Enroll Admin at Orbis-CA
        docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll \
            -u https://$ADMIN_NAME:$ADMIN_PASS@$ORBIS_CA_NAME:$ORBIS_CA_PORT \
            --home $ORBIS_TOOLS_CACLI_DIR \
            --tls.certfiles tls-root-cert/tls-ca-cert.pem \
            --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$ADMIN_NAME/msp \
            --csr.hosts "$CA_NAME,$AGER_CAAPI_NAME,$AGER_CAAPI_IP,*.jedo.cc" \
            --csr.cn $CN --csr.names "$CSR_NAMES"
        
        # NodeOUs config
        CA_CERT_FILE=$(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$ADMIN_NAME/msp/intermediatecerts/*.pem)
        cat <<EOF > ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$ADMIN_NAME/msp/config.yaml
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: intermediatecerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: intermediatecerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: intermediatecerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: intermediatecerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: orderer
EOF
    done
    echo_ok "Admins for $AGER enrolled at Orbis-CA."


done  # ⬅️ Ende der Ager-Loop


###############################################################
# Final Tasks
###############################################################
chmod -R 777 infrastructure

echo ""
echo_ok "CA nodes started successfully!"
echo ""
echo_info "Summary:"
echo_info "  ✅ Root CA: $ORBIS_CA_NAME (with bootstrap msp)"
for REGNUM in $REGNUMS; do
    REGNUM_CA_NAME=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .CA.Name" "$CONFIG_FILE")
    echo_info "  ✅ Regnum CA: $REGNUM_CA_NAME (with msp + msp-bootstrap)"
done
for AGER in $AGERS; do
    AGER_CA_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.Name" "$CONFIG_FILE")
    echo_info "  ✅ Ager CA: $AGER_CA_NAME (with msp + msp-bootstrap)"
    echo_info "      Org MSP: Uses Orbis-CA cert (for nodes enrolled at Orbis)"
done
echo ""
