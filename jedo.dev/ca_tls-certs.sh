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
source "$SCRIPT_DIR/params.sh"
source "$SCRIPT_DIR/ca_utils.sh"
check_script

echo ""
echo_info "TLS certs enrolling... (Defaults: https://hyperledger-fabric-ca.readthedocs.io/en/latest/serverconfig.html)"


###############################################################
# Params for Orbis-TLS
###############################################################
ORBIS_TLS_NAME=$(yq eval ".Orbis.TLS.Name" "$CONFIG_FILE")
ORBIS_TLS_PASS=$(yq eval ".Orbis.TLS.Pass" "$CONFIG_FILE")
ORBIS_TLS_PORT=$(yq eval ".Orbis.TLS.Port" "$CONFIG_FILE")
ORBIS_TLS_DIR=/etc/hyperledger/fabric-ca-server
ORBIS_TLS_INFRA=/etc/hyperledger/infrastructure
ORBIS_TLS_CERT=$ORBIS_TLS_DIR/ca-cert.pem


###############################################################
# Register and entroll TLS certs for Orbis-MSP
###############################################################
ORBIS_MSP_NAME=$(yq eval ".Orbis.MSP.Name" "$CONFIG_FILE")
ORBIS_MSP_PASS=$(yq eval ".Orbis.MSP.Pass" "$CONFIG_FILE")
ORBIS_MSP_IP=$(yq eval ".Orbis.MSP.IP" "$CONFIG_FILE")
AFFILIATION=$ORBIS


echo ""
if [[ $DEBUG == true ]]; then
    echo_debug "Executing with the following:"
    echo_value_debug "- TLS Name:" "$ORBIS_TLS_NAME"
    echo_value_debug "- TLS Dir:" "$ORBIS_TLS_DIR"
    echo_value_debug "- TLS Cert:" "$ORBIS_TLS_CERT"
    echo_value_debug "***" "***"
    echo_value_debug "- MSP Name:" "$ORBIS_MSP_NAME"
    echo_value_debug "- MSP Affiliation:" "$AFFILIATION"
fi
echo_info "Orbis-CA $ORBIS_MSP_NAME TLS registering and enrolling..."
docker exec -it "$ORBIS_TLS_NAME" fabric-ca-client register -u "https://$ORBIS_TLS_NAME:$ORBIS_TLS_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT" \
    --home "$ORBIS_TLS_DIR" \
    --tls.certfiles "$ORBIS_TLS_CERT" \
    --mspdir "$ORBIS_TLS_INFRA/$ORBIS/$ORBIS_TLS_NAME/tls" \
    --id.name "$ORBIS_MSP_NAME" --id.secret "$ORBIS_MSP_PASS" --id.type "client" --id.affiliation "$AFFILIATION"
docker exec -it $ORBIS_TLS_NAME fabric-ca-client enroll -u https://$ORBIS_MSP_NAME:$ORBIS_MSP_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
    --home $ORBIS_TLS_DIR \
    --tls.certfiles "$ORBIS_TLS_CERT" \
    --enrollment.profile tls \
    --mspdir $ORBIS_TLS_INFRA/$ORBIS/$ORBIS_MSP_NAME/tls \
    --csr.hosts ${ORBIS_MSP_NAME},*.$ORBIS.$ORBIS_ENV


###############################################################
# Register and entroll TLS certs for Regnums-MSP
###############################################################
for REGNUM in $REGNUMS; do
    # Params for regnum
    REGNUM_MSP_NAME=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .MSP.Name" "$CONFIG_FILE")
    REGNUM_MSP_PASS=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .MSP.Pass" "$CONFIG_FILE")
    REGNUM_MSP_IP=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .MSP.IP" "$CONFIG_FILE")
    AFFILIATION=$ORBIS.$REGNUM


    # Register Regnum-MSP identity
    echo ""
    if [[ $DEBUG == true ]]; then
        echo_debug "Executing with the following:"
        echo_value_debug "- MSP Name:" "$REGNUM_MSP_NAME"
        echo_value_debug "- MSP Affiliation:" "$AFFILIATION"
    fi
    echo_info "Regnum-MSP $REGNUM_MSP_NAME TLS registering and enrolling..."
    docker exec -it $ORBIS_TLS_NAME fabric-ca-client register -u https://$ORBIS_TLS_NAME:$ORBIS_TLS_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TLS_DIR \
        --tls.certfiles "$ORBIS_TLS_CERT" \
        --mspdir "$ORBIS_TLS_INFRA/$ORBIS/$ORBIS_TLS_NAME/tls" \
        --id.name $REGNUM_MSP_NAME --id.secret $REGNUM_MSP_PASS --id.type client --id.affiliation $AFFILIATION
    docker exec -it $ORBIS_TLS_NAME fabric-ca-client enroll -u https://$REGNUM_MSP_NAME:$REGNUM_MSP_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TLS_DIR \
        --tls.certfiles "$ORBIS_TLS_CERT" \
        --enrollment.profile tls \
        --mspdir $ORBIS_TLS_INFRA/$ORBIS/$REGNUM/$REGNUM_MSP_NAME/tls \
        --csr.hosts ${REGNUM_MSP_NAME},*.$ORBIS.$ORBIS_ENV


    #Copy files to Organization msp
    echo_info "Organization msp creating (TLS)..."
    mkdir -p ${PWD}/infrastructure/$ORBIS/$REGNUM/msp/tlscacerts
    cp ${PWD}/infrastructure/$ORBIS/$REGNUM/$REGNUM_MSP_NAME/tls/tlscacerts/* ${PWD}/infrastructure/$ORBIS/$REGNUM/msp/tlscacerts


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
    if [[ $DEBUG == true ]]; then
        echo_debug "Executing with the following:"
        echo_value_debug "- MSP Name:" "$REGNUM_ADMIN_NAME"
        echo_value_debug "- MSP Subject:" "$REGNUM_ADMIN_SUBJECT"
        echo_value_debug "- MSP CSR" "$CSR_NAMES"
    fi
    echo_info "Regnum-Admin $REGNUM_ADMIN_NAME TLS registering and enrolling..."
    docker exec -it $ORBIS_TLS_NAME fabric-ca-client register -u https://$ORBIS_TLS_NAME:$ORBIS_TLS_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TLS_DIR \
        --tls.certfiles "$ORBIS_TLS_CERT" \
        --mspdir "$ORBIS_TLS_INFRA/$ORBIS/$ORBIS_TLS_NAME/tls" \
        --id.name $REGNUM_ADMIN_NAME --id.secret $REGNUM_ADMIN_PASS --id.type admin --id.affiliation $AFFILIATION
    docker exec -it $ORBIS_TLS_NAME fabric-ca-client enroll -u https://$REGNUM_ADMIN_NAME:$REGNUM_ADMIN_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TLS_DIR \
        --tls.certfiles "$ORBIS_TLS_CERT" \
        --enrollment.profile tls \
        --mspdir $ORBIS_TLS_INFRA/$ORBIS/$REGNUM/_Admin/$REGNUM_ADMIN_NAME/tls \
        --csr.hosts ${REGNUM_MSP_NAME},*.$ORBIS.$ORBIS_ENV \
        --csr.cn $CN --csr.names "$CSR_NAMES"


    # copy Regnum-Admin-Client tlscacerts
    echo_info "Admin Client tlscacerts copying..."
    mkdir -p ${PWD}/infrastructure/$ORBIS/$REGNUM/_Admin/tls/tlscacerts
    cp ${PWD}/infrastructure/$ORBIS/$REGNUM/_Admin/$REGNUM_ADMIN_NAME/tls/tlscacerts/* ${PWD}/infrastructure/$ORBIS/$REGNUM/_Admin/tls/tlscacerts
done


###############################################################
# Register and entroll Ager-MSP TLS certs
###############################################################
for AGER in $AGERS; do
    # Params for ager
    AGER_MSP_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .MSP.Name" "$CONFIG_FILE")
    AGER_MSP_PASS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .MSP.Pass" "$CONFIG_FILE")
    AGER_MSP_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .MSP.IP" "$CONFIG_FILE")
    REGNUM=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Administration.Parent" "$CONFIG_FILE")
    AFFILIATION=$ORBIS.$REGNUM.$AGER


    # Add affiliation to TLS-CA
    AFFILIATION=$ORBIS.$REGNUM.$AGER
    echo ""
    echo_info "Affiliation $AFFILIATION adding..."
    docker exec -it $ORBIS_TLS_NAME fabric-ca-client affiliation add $AFFILIATION  -u https://$ORBIS_TLS_NAME:$ORBIS_TLS_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TLS_DIR \
        --tls.certfiles "$ORBIS_TLS_CERT" \
        --mspdir $ORBIS_TLS_INFRA/$ORBIS/$ORBIS_TLS_NAME/tls 


    # Register Ager-MSP identity
    echo ""
    if [[ $DEBUG == true ]]; then
        echo_debug "Executing with the following:"
        echo_value_debug "- MSP Name:" "$AGER_MSP_NAME"
        echo_value_debug "- MSP Affiliation" "$AFFILIATION"
    fi
    echo_info "Ager-MSP $AGER_MSP_NAME TLS registering and enrolling..."
    docker exec -it $ORBIS_TLS_NAME fabric-ca-client register -u https://$ORBIS_TLS_NAME:$ORBIS_TLS_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TLS_DIR \
        --tls.certfiles "$ORBIS_TLS_CERT" \
        --mspdir "$ORBIS_TLS_INFRA/$ORBIS/$ORBIS_TLS_NAME/tls" \
        --id.name $AGER_MSP_NAME --id.secret $AGER_MSP_PASS --id.type client --id.affiliation $AFFILIATION
    docker exec -it $ORBIS_TLS_NAME fabric-ca-client enroll -u https://$AGER_MSP_NAME:$AGER_MSP_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TLS_DIR \
        --tls.certfiles "$ORBIS_TLS_CERT" \
        --enrollment.profile tls \
        --mspdir $ORBIS_TLS_INFRA/$ORBIS/$REGNUM/$AGER/$AGER_MSP_NAME/tls \
        --csr.hosts ${AGER_MSP_NAME},*.$ORBIS.$ORBIS_ENV
done

###############################################################
# Register and entroll Gateway TLS certs
###############################################################
for AGER in $AGERS; do
    # Params for gateway
    AGER_GATEWAY_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.Name" "$CONFIG_FILE")
    AGER_GATEWAY_PASS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.Pass" "$CONFIG_FILE")
    REGNUM=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Administration.Parent" "$CONFIG_FILE")
    AFFILIATION=$ORBIS.$REGNUM.$AGER


    # Register Gateway identity
    log_debug "Gateway Name:" "$AGER_GATEWAY_NAME"
    log_debug "MSP Affiliation" "$AFFILIATION"
    echo_info "Gateway $AGER_GATEWAY_NAME TLS registering and enrolling..."
    docker exec -it $ORBIS_TLS_NAME fabric-ca-client register -u https://$ORBIS_TLS_NAME:$ORBIS_TLS_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TLS_DIR \
        --tls.certfiles "$ORBIS_TLS_CERT" \
        --mspdir "$ORBIS_TLS_INFRA/$ORBIS/$ORBIS_TLS_NAME/tls" \
        --id.name $AGER_GATEWAY_NAME --id.secret $AGER_GATEWAY_PASS --id.type client --id.affiliation $AFFILIATION
    docker exec -it $ORBIS_TLS_NAME fabric-ca-client enroll -u https://$AGER_GATEWAY_NAME:$AGER_GATEWAY_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TLS_DIR \
        --tls.certfiles "$ORBIS_TLS_CERT" \
        --enrollment.profile tls \
        --mspdir $ORBIS_TLS_INFRA/$ORBIS/$REGNUM/$AGER/$AGER_GATEWAY_NAME/tls \
        --csr.hosts ${AGER_GATEWAY_NAME},*.$ORBIS.$ORBIS_ENV


    ###############################################################
    # Register and entroll Service TLS certs
    ###############################################################
    SERVICES=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.Services[].Name" $CONFIG_FILE)
    for SERVICE in $SERVICES; do
        # Params for service
        SERVICE_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.Services[] | select(.Name == \"$SERVICE\") | .Name" $CONFIG_FILE)
        SERVICE_PASS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.Services[] | select(.Name == \"$SERVICE\") | .Pass" $CONFIG_FILE)


        # Register Microservice identity
        log_debug "Gateway Name:" "$SERVICE_NAME"
        log_debug "MSP Affiliation" "$AFFILIATION"
        echo_info "Service $SERVICE_NAME TLS registering and enrolling..."
        docker exec -it $ORBIS_TLS_NAME fabric-ca-client register -u https://$ORBIS_TLS_NAME:$ORBIS_TLS_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
            --home $ORBIS_TLS_DIR \
            --tls.certfiles "$ORBIS_TLS_CERT" \
            --mspdir "$ORBIS_TLS_INFRA/$ORBIS/$ORBIS_TLS_NAME/tls" \
            --id.name $SERVICE_NAME --id.secret $SERVICE_PASS --id.type client --id.affiliation $AFFILIATION
        docker exec -it $ORBIS_TLS_NAME fabric-ca-client enroll -u https://$SERVICE_NAME:$SERVICE_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
            --home $ORBIS_TLS_DIR \
            --tls.certfiles "$ORBIS_TLS_CERT" \
            --enrollment.profile tls \
            --mspdir $ORBIS_TLS_INFRA/$ORBIS/$REGNUM/$AGER/$SERVICE_NAME/tls \
            --csr.hosts ${SERVICE_NAME},*.$ORBIS.$ORBIS_ENV
    done
done

###############################################################
# Last Tasks
###############################################################
chmod -R 750 infrastructure
echo ""
echo_info "TLS certs enrolled."
