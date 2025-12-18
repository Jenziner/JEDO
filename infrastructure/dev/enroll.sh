###############################################################
#!/bin/bash
#
# Register and enroll all identities needed for the JEDO-Token network.
# FIXED VERSION: Uses msp-bootstrap for admin operations
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/params.sh"
check_script

###############################################################
# Params
###############################################################
ORBIS_TLS_NAME=$(yq eval ".Orbis.TLS.Name" "$CONFIG_FILE")
ORBIS_TLS_INFRA=/etc/hyperledger/infrastructure
ORBIS_TLS_CERT=$ORBIS_TLS_INFRA/$ORBIS/$ORBIS_TLS_NAME/ca-cert.pem

###############################################################
# Enroll Token Network
###############################################################
AGERS=$(yq eval '.Ager[] | .Name' "$CONFIG_FILE")
for AGER in $AGERS; do
    ###############################################################
    # Params
    ###############################################################
    REGNUM=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Administration.Parent" $CONFIG_FILE)
    AGER_MSP_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .MSP.Name" $CONFIG_FILE)
    AGER_MSP_PASS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .MSP.Pass" $CONFIG_FILE)
    AGER_MSP_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .MSP.Port" $CONFIG_FILE)
    AGER_MSP_DIR=/etc/hyperledger/fabric-ca-server
    AGER_MSP_INFRA=/etc/hyperledger/infrastructure
    AGER_CAAPI_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .MSP.CAAPI.Name" "$CONFIG_FILE")
    AGER_CAAPI_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .MSP.CAAPI.IP" "$CONFIG_FILE")
    AGER_CAAPI_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .MSP.CAAPI.SrvPort" "$CONFIG_FILE")


    ###############################################################
    # Enroll Gens @ Ager-CA (uses msp-bootstrap!)
    ###############################################################
    log_info "Enrollment of Gens and Human for $AGER starting..."

    GENSS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gens[].Name" $CONFIG_FILE)
    for GENS in $GENSS; do
        ###############################################################
        # Params
        ###############################################################
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
        AFFILIATION=$ORBIS.$REGNUM.$AGER.$GENS

        GENS_FQDN=$CN


        ###############################################################
        # Enroll Ager-MSP bootstrap identity (for admin operations)
        ###############################################################
        REGNUM_MSP_NAME=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .MSP.Name" $CONFIG_FILE)
        REGNUM_MSP_DIR=/etc/hyperledger/fabric-ca-server
        log_debug "Enroll Ager-MSP bootstrap identity:"
        log_debug "- TLS Cert:" "$ORBIS_TLS_CERT"
        log_debug "- Regnum MSP Name:" "$REGNUM_MSP_NAME"
        log_debug "- Ager MSP Name:" "$AGER_MSP_NAME"
        log_info "Enrolling Ager-MSP bootstrap identity for admin operations..."
        docker exec -it $REGNUM_MSP_NAME fabric-ca-client enroll \
            -u https://$AGER_MSP_NAME:$AGER_MSP_PASS@$AGER_MSP_NAME:$AGER_MSP_PORT \
            --home $REGNUM_MSP_DIR \
            --tls.certfiles "$ORBIS_TLS_CERT" \
            --mspdir $AGER_MSP_INFRA/$ORBIS/$REGNUM/$AGER/$AGER_MSP_NAME/msp-bootstrap


        ###############################################################
        # Add Gens affiliation to Ager-CA (using Ager-CA bootstrap msp)
        ###############################################################
        log_debug "Add Gens affiliation to Ager-CA:"
        log_debug "- TLS Cert:" "$ORBIS_TLS_CERT"
        log_debug "- Ager MSP Name:" "$AGER_MSP_NAME"
        log_debug "- MSP Affiliation:" "$AFFILIATION"
        log_info "Affiliation $AFFILIATION adding to Ager-MSP..."
        docker exec -it $AGER_MSP_NAME fabric-ca-client affiliation add $AFFILIATION \
            -u https://$AGER_MSP_NAME:$AGER_MSP_PASS@$AGER_MSP_NAME:$AGER_MSP_PORT \
            --home $AGER_MSP_DIR \
            --tls.certfiles "$ORBIS_TLS_CERT" \
            --mspdir $AGER_MSP_INFRA/$ORBIS/$REGNUM/$AGER/$AGER_MSP_NAME/msp-bootstrap


        ###############################################################
        # Register and enroll gens @ AGER-MSP using msp-bootstrap
        ###############################################################
        log_debug "Register and enroll gens:"
        log_debug "- Regnum:" "$REGNUM"
        log_debug "- Ager:" "$AGER"
        log_debug "- Gens:" "$GENS"
        log_debug "***" "***"
        log_debug "- Orbis TLS Cert:" "$ORBIS_TLS_CERT"
        log_debug "- Ager MSP:" "$AGER_MSP_NAME"
        log_debug "- MSP Affiliation:" "$AFFILIATION"
        log_debug "- FQDN-Name:" "$GENS_FQDN"
        log_debug "- CN:" "$CN"
        log_debug "- CSR-Names:" "$CSR_NAMES"

        log_info "Registering and enrolling $GENS at Ager-MSP..."

        log_debug "Registering Gens..."
        docker exec -it $AGER_MSP_NAME fabric-ca-client register -u https://$AGER_MSP_NAME:$AGER_MSP_PASS@$AGER_MSP_NAME:$AGER_MSP_PORT \
            --home $AGER_MSP_DIR \
            --tls.certfiles "$ORBIS_TLS_CERT" \
            --mspdir $AGER_MSP_INFRA/$ORBIS/$REGNUM/$AGER/$AGER_MSP_NAME/msp-bootstrap \
            --id.name $GENS_FQDN --id.secret $GENS_PASS --id.type client --id.affiliation $AFFILIATION \
            --id.attrs '"role=gens:ecert","hf.Registrar.Roles=client","hf.Registrar.Attributes=role","hf.Revoker=true"'

        log_debug "Enrolling Gens..."
        docker exec -it $AGER_MSP_NAME fabric-ca-client enroll -u https://$GENS_FQDN:$GENS_PASS@$AGER_MSP_NAME:$AGER_MSP_PORT \
            --home $AGER_MSP_DIR \
            --tls.certfiles "$ORBIS_TLS_CERT" \
            --mspdir $AGER_MSP_INFRA/$ORBIS/$REGNUM/$AGER/$GENS_NAME/$GENS_FQDN/msp \
            --csr.hosts "$AGER_MSP_NAME,$AGER_CAAPI_NAME,$AGER_CAAPI_IP,*.$ORBIS.$ORBIS_ENV" \
            --csr.cn "$CN" --csr.names "$CSR_NAMES"


        HUMANS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gens[] | select(.Name == \"$GENS\") | .Humans[].Name" $CONFIG_FILE)
        for HUMAN in $HUMANS; do
            ###############################################################
            # Params
            ###############################################################
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
            AFFILIATION=$ORBIS.$REGNUM.$AGER.$GENS

            HUMAN_FQDN=$CN


            ###############################################################
            # Enroll Humans @ Ager-MSP using msp-bootstrap
            ###############################################################
            log_debug "Register and enroll human:"
            log_debug "- Regnum:" "$REGNUM"
            log_debug "- Ager:" "$AGER"
            log_debug "- Gens:" "$GENS"
            log_debug "- Human:" "$HUMAN"
            log_debug "***" "***"
            log_debug "- Orbis TLS Cert:" "$ORBIS_TLS_CERT"
            log_debug "- Ager MSP:" "$AGER_MSP_NAME"
            log_debug "- MSP Affiliation:" "$AFFILIATION"
            log_debug "- CN:" "$CN"
            log_debug "- CSR-Names:" "$CSR_NAMES"

            log_info "Registering and enrolling $HUMAN at Gens-MSP..."

            log_debug "Enrolling Gens for admin operation..."
            docker exec -it $AGER_MSP_NAME fabric-ca-client enroll -u https://$GENS_FQDN:$GENS_PASS@$AGER_MSP_NAME:$AGER_MSP_PORT \
                --home $AGER_MSP_DIR \
                --tls.certfiles "$ORBIS_TLS_CERT" \
                --mspdir $AGER_MSP_INFRA/$ORBIS/$REGNUM/$AGER/$GENS_NAME/$GENS_FQDN/msp-bootstrap

            log_debug "Registering human..."
            docker exec -it $AGER_MSP_NAME fabric-ca-client register -u https://$GENS_FQDN:$GENS_PASS@$AGER_MSP_NAME:$AGER_MSP_PORT \
                --home $AGER_MSP_DIR \
                --tls.certfiles "$ORBIS_TLS_CERT" \
                --mspdir $AGER_MSP_INFRA/$ORBIS/$REGNUM/$AGER/$GENS_NAME/$GENS_FQDN/msp-bootstrap \
                --id.name $HUMAN_FQDN --id.secret $HUMAN_PASS --id.type client --id.affiliation $AFFILIATION \
                --id.attrs "role=human:ecert"

            log_debug "Enrolling human..."
            docker exec -it $AGER_MSP_NAME fabric-ca-client enroll -u https://$HUMAN_FQDN:$HUMAN_PASS@$AGER_MSP_NAME:$AGER_MSP_PORT \
                --home $AGER_MSP_DIR \
                --tls.certfiles "$ORBIS_TLS_CERT" \
                --mspdir $AGER_MSP_INFRA/$ORBIS/$REGNUM/$AGER/$GENS_NAME/$HUMAN_FQDN/msp \
                --csr.hosts "$AGER_MSP_NAME,$AGER_CAAPI_NAME,$AGER_CAAPI_IP,*.$ORBIS.$ORBIS_ENV" \
                --csr.cn "$CN" --csr.names "$CSR_NAMES" \
                --enrollment.type idemix --idemix.curve gurvy.Bn254
        done
    done
    log_info "Enrollment of Gens and Human for $AGER completed..."
done

################################################################
# Last Tasks
################################################################
chmod -R 750 ./infrastructure

