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
    echo ""
    echo_info "Enrollment of Gens and Human for $AGER starting..."

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
        AFFILIATION=$ORBIS.$REGNUM.$AGER

        ###############################################################
        # Enroll gens @ AGER-MSP using msp-bootstrap
        ###############################################################
        echo ""
        if [[ $DEBUG == true ]]; then
            echo_debug "Executing with the following:"
            echo_value_debug "- Regnum:" "$REGNUM"
            echo_value_debug "- Ager:" "$AGER"
            echo_value_debug "- Gens:" "$GENS"
            echo_value_debug "***" "***"
            echo_value_debug "- Orbis TLS Cert:" "$ORBIS_TLS_CERT"
            echo_value_debug "- Ager MSP:" "$AGER_MSP_NAME"
            echo_value_debug "- MSP Affiliation:" "$AFFILIATION"
        fi
        echo_info "$GENS registering and enrolling at Ager-MSP..."
        docker exec -it $AGER_MSP_NAME fabric-ca-client register -u https://$AGER_MSP_NAME:$AGER_MSP_PASS@$AGER_MSP_NAME:$AGER_MSP_PORT \
            --home $AGER_MSP_DIR \
            --tls.certfiles "$ORBIS_TLS_CERT" \
            --mspdir $AGER_MSP_INFRA/$ORBIS/$REGNUM/$AGER/$AGER_MSP_NAME/msp-bootstrap \
            --id.name $GENS_NAME --id.secret $GENS_PASS --id.type client --id.affiliation $AFFILIATION \
            --id.attrs "role=gens:ecert"
        docker exec -it $AGER_MSP_NAME fabric-ca-client enroll -u https://$GENS_NAME:$GENS_PASS@$AGER_MSP_NAME:$AGER_MSP_PORT \
            --home $AGER_MSP_DIR \
            --tls.certfiles "$ORBIS_TLS_CERT" \
            --mspdir $AGER_MSP_INFRA/$ORBIS/$REGNUM/$AGER/$GENS_NAME/$CN/msp \
            --csr.hosts "$AGER_MSP_NAME,$AGER_CAAPI_NAME,$AGER_CAAPI_IP,*.$ORBIS.$ORBIS_ENV" \
            --csr.cn $CN --csr.names "$CSR_NAMES"


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
            AFFILIATION=$ORBIS.$REGNUM.$AGER

            ###############################################################
            # Enroll Humans @ Ager-MSP using msp-bootstrap
            ###############################################################
            echo ""
            if [[ $DEBUG == true ]]; then
                echo_debug "Executing with the following:"
                echo_value_debug "- Regnum:" "$REGNUM"
                echo_value_debug "- Ager:" "$AGER"
                echo_value_debug "- Gens:" "$GENS"
                echo_value_debug "- Human:" "$HUMAN"
                echo_value_debug "***" "***"
                echo_value_debug "- Orbis TLS Cert:" "$ORBIS_TLS_CERT"
                echo_value_debug "- Ager MSP:" "$AGER_MSP_NAME"
                echo_value_debug "- MSP Affiliation:" "$AFFILIATION"
            fi
            echo_info "$HUMAN registering and enrolling at Ager-MSP..."
            docker exec -it $AGER_MSP_NAME fabric-ca-client register -u https://$AGER_MSP_NAME:$AGER_MSP_PASS@$AGER_MSP_NAME:$AGER_MSP_PORT \
                --home $AGER_MSP_DIR \
                --tls.certfiles "$ORBIS_TLS_CERT" \
                --mspdir $AGER_MSP_INFRA/$ORBIS/$REGNUM/$AGER/$AGER_MSP_NAME/msp-bootstrap \
                --id.name $HUMAN_NAME --id.secret $HUMAN_PASS --id.type client --id.affiliation $AFFILIATION \
                --id.attrs "role=human:ecert" \
                --enrollment.type idemix --idemix.curve gurvy.Bn254
            docker exec -it $AGER_MSP_NAME fabric-ca-client enroll -u https://$HUMAN_NAME:$HUMAN_PASS@$AGER_MSP_NAME:$AGER_MSP_PORT \
                --home $AGER_MSP_DIR \
                --tls.certfiles "$ORBIS_TLS_CERT" \
                --mspdir $AGER_MSP_INFRA/$ORBIS/$REGNUM/$AGER/$GENS_NAME/$HUMAN_NAME/msp \
                --csr.hosts "$AGER_MSP_NAME,$AGER_CAAPI_NAME,$AGER_CAAPI_IP,*.$ORBIS.$ORBIS_ENV" \
                --csr.cn $CN --csr.names "$CSR_NAMES" \
                --enrollment.type idemix --idemix.curve gurvy.Bn254
        done
    done
    echo_info "Enrollment of Gens and Human for $AGER completed..."
done

################################################################
# Last Tasks
################################################################
chmod -R 750 ./infrastructure

