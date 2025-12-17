###############################################################
#!/bin/bash
#
# This script starts Root-CA and generates certificates for Intermediate-CA
# FIXED VERSION: Org MSP uses only Orbis-CA cert for nodes enrolled at Orbis
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/params.sh"
source "$SCRIPT_DIR/ca_utils.sh"
check_script

get_hosts


###############################################################
# ORBIS-CA (Root CA)
###############################################################
ORBIS_TLS_NAME=$(yq eval ".Orbis.TLS.Name" "$CONFIG_FILE")
ORBIS_TLS_INFRA=/etc/hyperledger/infrastructure
ORBIS_TLS_CERT=$ORBIS_TLS_INFRA/$ORBIS/$ORBIS_TLS_NAME/ca-cert.pem

ORBIS_MSP_NAME=$(yq eval ".Orbis.MSP.Name" "$CONFIG_FILE")
ORBIS_MSP_PASS=$(yq eval ".Orbis.MSP.Pass" "$CONFIG_FILE")
ORBIS_MSP_IP=$(yq eval ".Orbis.MSP.IP" "$CONFIG_FILE")
ORBIS_MSP_PORT=$(yq eval ".Orbis.MSP.Port" "$CONFIG_FILE")
ORBIS_MSP_OPPORT=$(yq eval ".Orbis.MSP.OpPort" "$CONFIG_FILE")
ORBIS_MSP_DIR=/etc/hyperledger/fabric-ca-server
ORBIS_MSP_INFRA=/etc/hyperledger/infrastructure

LOCAL_INFRA_DIR=${PWD}/infrastructure
LOCAL_SRV_DIR=$LOCAL_INFRA_DIR/$ORBIS/$ORBIS_MSP_NAME

mkdir -p $LOCAL_SRV_DIR


echo ""
echo_info "CA nodes starting..."


cp -r ../prod/RootCA/$ORBIS.$ORBIS_ENV/$ORBIS_MSP_NAME/. $LOCAL_SRV_DIR

# Start Orbis-CA
if [[ $DEBUG == true ]]; then
    echo_debug "Executing with the following:"
    echo_value_debug "- TLS Cert:" "$ORBIS_TLS_CERT"
    echo_value_debug "- MSP Name:" "$ORBIS_MSP_NAME"
    echo_value_debug "- MSP Dir:" "$LOCAL_SRV_DIR"
fi
ca_writeCfg "orbis" "$ORBIS_MSP_NAME" "$CONFIG_FILE" "$LOCAL_SRV_DIR"
ca_start "$ORBIS_MSP_NAME" "$CONFIG_FILE" "$LOCAL_SRV_DIR"


# Enroll Orbis-CA bootstrap identity
echo ""
echo_info "Orbis-CA enrolling bootstrap identity..."
docker exec -it $ORBIS_MSP_NAME fabric-ca-client enroll \
    -u https://$ORBIS_MSP_NAME:$ORBIS_MSP_PASS@$ORBIS_MSP_NAME:$ORBIS_MSP_PORT \
    --home $ORBIS_MSP_DIR \
    --tls.certfiles "$ORBIS_TLS_CERT" \
    --mspdir $ORBIS_MSP_INFRA/$ORBIS/$ORBIS_MSP_NAME/msp \
    --enrollment.profile ca


###############################################################
# Regnum-MSP (Intermediate CA Level 1)
###############################################################
REGNUMS=$(yq eval '.Regnum[] | .Name' "$CONFIG_FILE")
for REGNUM in $REGNUMS; do
    # Params for regnum
    REGNUM_MSP_NAME=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .MSP.Name" "$CONFIG_FILE")
    REGNUM_MSP_PASS=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .MSP.Pass" "$CONFIG_FILE")
    REGNUM_MSP_IP=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .MSP.IP" "$CONFIG_FILE")
    REGNUM_MSP_PORT=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .MSP.Port" "$CONFIG_FILE")
    REGNUM_MSP_OPPORT=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .MSP.OpPort" "$CONFIG_FILE")
    
    ORBIS=$(yq eval ".Orbis.Name" "$CONFIG_FILE")
    ORBIS_MSP_NAME=$(yq eval ".Orbis.MSP.Name" "$CONFIG_FILE")
    ORBIS_MSP_PASS=$(yq eval ".Orbis.MSP.Pass" "$CONFIG_FILE")
    ORBIS_MSP_PORT=$(yq eval ".Orbis.MSP.Port" "$CONFIG_FILE")
    
    LOCAL_INFRA_DIR=${PWD}/infrastructure/
    LOCAL_SRV_DIR=$LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$REGNUM_MSP_NAME/
    AFFILIATION=$ORBIS.$REGNUM
    
    mkdir -p $LOCAL_SRV_DIR
    
    # Register Regnum-MSP ID identity at Orbis-CA (using Orbis bootstrap msp)
    echo ""
    if [[ $DEBUG == true ]]; then
        echo_debug "Executing with the following:"
        echo_value_debug "- TLS Cert:" "$ORBIS_TLS_CERT"
        echo_value_debug "- Orbis MSP Name:" "$ORBIS_MSP_NAME"
        echo_value_debug "***" "***"
        echo_value_debug "- MSP Name:" "$REGNUM_MSP_NAME"
        echo_value_debug "- MSP Affiliation:" "$AFFILIATION"
    fi
    echo_info "Regnum-MSP ID $REGNUM_MSP_NAME registering..."
    docker exec -it $ORBIS_MSP_NAME fabric-ca-client register \
        -u https://$ORBIS_MSP_NAME:$ORBIS_MSP_PASS@$ORBIS_MSP_NAME:$ORBIS_MSP_PORT \
        --home $ORBIS_MSP_DIR \
        --tls.certfiles "$ORBIS_TLS_CERT" \
        --mspdir $ORBIS_MSP_INFRA/$ORBIS/$ORBIS_MSP_NAME/msp \
        --id.name $REGNUM_MSP_NAME \
        --id.secret $REGNUM_MSP_PASS \
        --id.type client \
        --id.affiliation $AFFILIATION \
        --id.attrs '"hf.Registrar.Roles=user,admin","hf.Revoker=true","hf.IntermediateCA=true"'
    
    # Enroll Regnum-MSP at Orbis-CA (for server certificate)
    echo ""
    echo_info "Regnum-MSP enrolling for server certificate..."
    docker exec -it $ORBIS_MSP_NAME fabric-ca-client enroll \
        -u https://$REGNUM_MSP_NAME:$REGNUM_MSP_PASS@$ORBIS_MSP_NAME:$ORBIS_MSP_PORT \
        --home $ORBIS_MSP_DIR \
        --tls.certfiles "$ORBIS_TLS_CERT" \
        --enrollment.profile ca \
        --mspdir $ORBIS_MSP_INFRA/$ORBIS/$REGNUM/$REGNUM_MSP_NAME/msp \
        --csr.hosts ${REGNUM_MSP_NAME},*.$ORBIS.$ORBIS_ENV
    
    # Generating NodeOUs-File
    echo ""
    echo_info "NodeOUs-File writing..."
    CA_CERT_FILE=$(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/$REGNUM_MSP_NAME/msp/cacerts/*.pem)
    
    cat <<EOF > ${PWD}/infrastructure/$ORBIS/$REGNUM/$REGNUM_MSP_NAME/msp/config.yaml
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


    # Start Regnum-MSP
    ca_writeCfg "regnum" "$REGNUM_MSP_NAME" "$CONFIG_FILE" "$LOCAL_SRV_DIR"
    ca_start "$REGNUM_MSP_NAME" "$CONFIG_FILE" "$LOCAL_SRV_DIR"


    # Enroll Regnum-MSP bootstrap identity (for admin operations)
    echo ""
    echo_info "Enrolling Regnum-MSP bootstrap identity for admin operations..."
    docker exec -it $ORBIS_MSP_NAME fabric-ca-client enroll \
        -u https://$REGNUM_MSP_NAME:$REGNUM_MSP_PASS@$REGNUM_MSP_NAME:$REGNUM_MSP_PORT \
        --home $ORBIS_MSP_DIR \
        --tls.certfiles "$ORBIS_TLS_CERT" \
        --mspdir $ORBIS_MSP_INFRA/$ORBIS/$REGNUM/$REGNUM_MSP_NAME/msp-bootstrap


    # Copy files to Organization msp (from FIRST enroll only!)
    echo ""
    echo_info "Organization msp creating..."
    rm -rf $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/msp
    mkdir -p $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/msp/cacerts
    mkdir -p $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/msp/intermediatecerts


    # Copy root CA, intermediate certs, config
    cp $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$REGNUM_MSP_NAME/msp/cacerts/* \
       $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/msp/cacerts/
    cp $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$REGNUM_MSP_NAME/msp/intermediatecerts/* \
       $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/msp/intermediatecerts/
    cp $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$REGNUM_MSP_NAME/msp/config.yaml \
       $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/msp/

done


###############################################################
# Ager-CA (Intermediate CA Level 2)
###############################################################
AGERS=$(yq eval '.Ager[] | .Name' "$CONFIG_FILE")
for AGER in $AGERS; do
    # Params for ager
    AGER_MSP_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .MSP.Name" "$CONFIG_FILE")
    AGER_MSP_PASS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .MSP.Pass" "$CONFIG_FILE")
    AGER_MSP_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .MSP.IP" "$CONFIG_FILE")
    AGER_MSP_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .MSP.Port" "$CONFIG_FILE")
    AGER_MSP_OPPORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .MSP.OpPort" "$CONFIG_FILE")
    AGER_CAAPI_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .MSP.CAAPI.Name" "$CONFIG_FILE")
    AGER_CAAPI_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .MSP.CAAPI.IP" "$CONFIG_FILE")
    AGER_CAAPI_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .MSP.CAAPI.SrvPort" "$CONFIG_FILE")
    AGER_REGNUM=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Administration.Parent" "$CONFIG_FILE")
    
    REGNUM=$(yq eval ".Regnum[] | select(.Name == \"$AGER_REGNUM\") | .Name" "$CONFIG_FILE")
    REGNUM_MSP_NAME=$(yq eval ".Regnum[] | select(.Name == \"$AGER_REGNUM\") | .MSP.Name" "$CONFIG_FILE")
    REGNUM_MSP_PASS=$(yq eval ".Regnum[] | select(.Name == \"$AGER_REGNUM\") | .MSP.Pass" "$CONFIG_FILE")
    REGNUM_MSP_PORT=$(yq eval ".Regnum[] | select(.Name == \"$AGER_REGNUM\") | .MSP.Port" "$CONFIG_FILE")
    REGNUM_MSP_DIR=/etc/hyperledger/fabric-ca-server
    REGNUM_MSP_INFRA=/etc/hyperledger/infrastructure
    
    LOCAL_INFRA_DIR=${PWD}/infrastructure/
    LOCAL_SRV_DIR=$LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$AGER_MSP_NAME/
    AFFILIATION=$ORBIS.$REGNUM.$AGER
    
    mkdir -p $LOCAL_SRV_DIR
    
    # Add affiliation to Regnum-CA (using Regnum-CA bootstrap msp)
    echo ""
    if [[ $DEBUG == true ]]; then
        echo_debug "Executing with the following:"
        echo_value_debug "- TLS Cert:" "$ORBIS_TLS_CERT"
        echo_value_debug "- Regnum MSP Name:" "$REGNUM_MSP_NAME"
        echo_value_debug "***" "***"
        echo_value_debug "- MSP Name:" "$AGER_MSP_NAME"
        echo_value_debug "- MSP Affiliation:" "$AFFILIATION"
    fi
    echo_info "Affiliation $AFFILIATION adding to Regnum-MSP..."
    docker exec -it $REGNUM_MSP_NAME fabric-ca-client affiliation add $AFFILIATION \
        -u https://$REGNUM_MSP_NAME:$REGNUM_MSP_PASS@$REGNUM_MSP_NAME:$REGNUM_MSP_PORT \
        --home $REGNUM_MSP_DIR \
        --tls.certfiles "$ORBIS_TLS_CERT" \
        --mspdir $REGNUM_MSP_INFRA/$ORBIS/$REGNUM/$REGNUM_MSP_NAME/msp-bootstrap
    
    # Register Ager-MSP ID identity at Regnum-MSP (using bootstrap msp)
    echo ""
    echo_info "Ager-MSP ID $AGER_MSP_NAME registering..."
    docker exec -it $REGNUM_MSP_NAME fabric-ca-client register \
        -u https://$REGNUM_MSP_NAME:$REGNUM_MSP_PASS@$REGNUM_MSP_NAME:$REGNUM_MSP_PORT \
        --home $REGNUM_MSP_DIR \
        --tls.certfiles "$ORBIS_TLS_CERT" \
        --mspdir $REGNUM_MSP_INFRA/$ORBIS/$REGNUM/$REGNUM_MSP_NAME/msp-bootstrap \
        --id.name $AGER_MSP_NAME \
        --id.secret $AGER_MSP_PASS \
        --id.type client \
        --id.affiliation $AFFILIATION \
        --id.attrs '"hf.Registrar.Roles=user,admin","hf.Revoker=true","hf.IntermediateCA=true"'
    
    # Enroll Ager-CA at Regnum-CA (for server certificate)
    echo ""
    echo_info "Ager-CA enrolling for server certificate..."
    docker exec -it $REGNUM_MSP_NAME fabric-ca-client enroll \
        -u https://$AGER_MSP_NAME:$AGER_MSP_PASS@$REGNUM_MSP_NAME:$REGNUM_MSP_PORT \
        --home $REGNUM_MSP_DIR \
        --tls.certfiles "$ORBIS_TLS_CERT" \
        --enrollment.profile ca \
        --mspdir $REGNUM_MSP_INFRA/$ORBIS/$REGNUM/$AGER/$AGER_MSP_NAME/msp \
        --csr.hosts ${REGNUM_MSP_NAME},*.jedo.cc
    
    # Generating NodeOUs-File
    echo ""
    echo_info "NodeOUs-File writing..."
    CA_CERT_FILE=$(ls $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$AGER_MSP_NAME/msp/cacerts/*.pem)
    
    cat <<EOF > $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$AGER_MSP_NAME/msp/config.yaml
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

    # Start Ager-MSP
    ca_writeCfg "ager" "$AGER_MSP_NAME" "$CONFIG_FILE" "$LOCAL_SRV_DIR"
    ca_start "$AGER_MSP_NAME" "$CONFIG_FILE" "$LOCAL_SRV_DIR"
    
    # Enroll Ager-MSP bootstrap identity (for admin operations)
    echo ""
    echo_info "Enrolling Ager-MSP bootstrap identity for admin operations..."
    docker exec -it $REGNUM_MSP_NAME fabric-ca-client enroll \
        -u https://$AGER_MSP_NAME:$AGER_MSP_PASS@$AGER_MSP_NAME:$AGER_MSP_PORT \
        --home $REGNUM_MSP_DIR \
        --tls.certfiles "$ORBIS_TLS_CERT" \
        --mspdir $REGNUM_MSP_INFRA/$ORBIS/$REGNUM/$AGER/$AGER_MSP_NAME/msp-bootstrap
    
    # Build Organization MSP (for Genesis Block - nodes enrolled at Orbis-MSP!)
    echo ""
    echo_info "Organization msp creating (for nodes enrolled at Orbis-MSP)..."
    rm -rf $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/msp
    mkdir -p $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/msp/cacerts
    mkdir -p $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/msp/intermediatecerts
    mkdir -p $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/msp/tlscacerts

    # Copy root MSP (Orbis Root MSP)
    cp $LOCAL_INFRA_DIR/$ORBIS/$ORBIS_MSP_NAME/msp/cacerts/* \
       $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/msp/cacerts/
    
    # Copy ONLY Orbis-MSP intermediate cert (NOT complete chain!)
    # Nodes (Orderer/Peer) are enrolled at Orbis-MSP, so they have Orbis-MSP as issuer
    ORBIS_MSP_INTERMEDIATE=$(ls $LOCAL_INFRA_DIR/$ORBIS/$ORBIS_MSP_NAME/msp/intermediatecerts/*.pem 2>/dev/null | head -1)
    if [ -n "$ORBIS_MSP_INTERMEDIATE" ]; then
        cp $ORBIS_MSP_INTERMEDIATE \
           $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/msp/intermediatecerts/
    fi
    
    # Copy TLS Root CA!
    echo ""
    echo_info "Adding TLS Root Cert to Organization MSP..."
    cp $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/_Admin/tls/tlscacerts/*.pem \
      $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/msp/tlscacerts/
   
    # NodeOUs config
    CA_CERT_FILE=$(ls $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/msp/intermediatecerts/*.pem 2>/dev/null | head -1)
    
    if [ -z "$CA_CERT_FILE" ]; then
        # Fallback: use cacerts if no intermediate
        CA_CERT_FILE=$(ls $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/msp/cacerts/*.pem)
        CERT_PATH="cacerts/$(basename $CA_CERT_FILE)"
    else
        CERT_PATH="intermediatecerts/$(basename $CA_CERT_FILE)"
    fi
    
    cat <<EOF > $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/msp/config.yaml
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


    # Add affiliation to Ager-MSP (using Ager-MSP bootstrap msp)
    echo ""
    echo_info "Affiliation $AFFILIATION adding to Ager-MSP..."
    docker exec -it $REGNUM_MSP_NAME fabric-ca-client affiliation add $AFFILIATION \
        -u https://$AGER_MSP_NAME:$AGER_MSP_PASS@$AGER_MSP_NAME:$AGER_MSP_PORT \
        --home $REGNUM_MSP_DIR \
        --tls.certfiles "$ORBIS_TLS_CERT" \
        --mspdir $REGNUM_MSP_INFRA/$ORBIS/$REGNUM/$AGER/$AGER_MSP_NAME/msp-bootstrap


    ###############################################################
    # Enroll Admins @ Orbis-MSP (like Orderer/Peer!)
    ###############################################################
    ADMINS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Admins[].Name" $CONFIG_FILE)
    for ADMIN in $ADMINS; do
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

        echo ""
        if [[ $DEBUG == true ]]; then
            echo_debug "Executing with the following:"
            echo_value_debug "- Ager:" "$AGER"
            echo_value_debug "- Admin:" "$ADMIN_NAME"
            echo_value_debug "- Subject:" "$ADMIN_SUBJECT"
            echo_value_debug "- Affiliation:" "$AFFILIATION"
        fi
        echo_info "Admins for $AGER enrolling at Orbis-CA..."


        # Register Admin at Orbis-CA (using Orbis bootstrap msp)
        docker exec -it $ORBIS_MSP_NAME fabric-ca-client register \
            -u https://$ORBIS_MSP_NAME:$ORBIS_MSP_PASS@$ORBIS_MSP_NAME:$ORBIS_MSP_PORT \
            --home $ORBIS_MSP_DIR \
            --tls.certfiles "$ORBIS_TLS_CERT" \
            --mspdir $ORBIS_MSP_INFRA/$ORBIS/$ORBIS_MSP_NAME/msp \
            --id.name $ADMIN_NAME \
            --id.secret $ADMIN_PASS \
            --id.type admin \
            --id.affiliation $AFFILIATION \
            --id.attrs '"role=admin","hf.Registrar.Roles=client,user,admin","hf.Registrar.DelegateRoles=client,user","hf.Registrar.Attributes=*","hf.Revoker=true","hf.GenCRL=true"'
   
        # Enroll Admin at Orbis-CA
        docker exec -it $ORBIS_MSP_NAME fabric-ca-client enroll \
            -u https://$ADMIN_NAME:$ADMIN_PASS@$ORBIS_MSP_NAME:$ORBIS_MSP_PORT \
            --home $ORBIS_MSP_DIR \
            --tls.certfiles "$ORBIS_TLS_CERT" \
            --mspdir $ORBIS_MSP_INFRA/$ORBIS/$REGNUM/$AGER/$ADMIN_NAME/msp \
            --csr.hosts "$AGER_MSP_NAME,$AGER_CAAPI_NAME,$AGER_CAAPI_IP,*.$ORBIS.$ORBIS_ENV" \
            --csr.cn $CN --csr.names "$CSR_NAMES"
        
        # NodeOUs config
        CA_CERT_FILE=$(ls $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$ADMIN_NAME/msp/intermediatecerts/*.pem)
        cat <<EOF > $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$ADMIN_NAME/msp/config.yaml
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
    echo_info "Admins for $AGER enrolled at Orbis-MSP."


done  #


###############################################################
# Final Tasks
###############################################################
chmod -R 750 infrastructure

echo ""
echo_info "MSP-CA nodes started."
