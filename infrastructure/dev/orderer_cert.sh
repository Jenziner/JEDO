###############################################################
#!/bin/bash
#
# This script starts Hyperledger Fabric Orderer
#
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/params.sh"
check_script


get_hosts


###############################################################
# Get Orbis TLS-CA
###############################################################
ORBIS_TLS_NAME=$(yq eval ".Orbis.TLS.Name" "$CONFIG_FILE")
ORBIS_TLS_PASS=$(yq eval ".Orbis.TLS.Pass" "$CONFIG_FILE")
ORBIS_TLS_PORT=$(yq eval ".Orbis.TLS.Port" "$CONFIG_FILE")
ORBIS_TLS_DIR=/etc/hyperledger/fabric-ca-server
ORBIS_TLS_INFRA=/etc/hyperledger/infrastructure
ORBIS_TLS_CERT=$ORBIS_TLS_INFRA/$ORBIS/$ORBIS_TLS_NAME/ca-cert.pem

ORBIS_MSP_NAME=$(yq eval ".Orbis.MSP.Name" "$CONFIG_FILE")
ORBIS_MSP_PASS=$(yq eval ".Orbis.MSP.Pass" "$CONFIG_FILE")
ORBIS_MSP_IP=$(yq eval ".Orbis.MSP.IP" "$CONFIG_FILE")
ORBIS_MSP_PORT=$(yq eval ".Orbis.MSP.Port" "$CONFIG_FILE")
ORBIS_MSP_DIR=/etc/hyperledger/fabric-ca-server
ORBIS_MSP_INFRA=/etc/hyperledger/infrastructure


###############################################################
# Params for ager
###############################################################
for AGER in $AGERS; do

    REGNUM=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Administration.Parent" $CONFIG_FILE)

    ORDERERS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[].Name" $CONFIG_FILE)
    for ORDERER in $ORDERERS; do
        ###############################################################
        # Params for orderer
        ###############################################################
        ORDERER_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Name" $CONFIG_FILE)
        ORDERER_SUBJECT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Subject" $CONFIG_FILE)
        ORDERER_PASS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Pass" $CONFIG_FILE)
        ORDERER_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .IP" $CONFIG_FILE)
        ORDERER_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Port" $CONFIG_FILE)
        ORDERER_CLPORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .ClusterPort" $CONFIG_FILE)
        ORDERER_OPPORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .OpPort" $CONFIG_FILE)
        ORDERER_ADMPORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .AdminPort" $CONFIG_FILE)

        LOCAL_INFRA_DIR=${PWD}/infrastructure
        LOCAL_SRV_DIR=$LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$ORDERER/

        # Extract fields from subject
        C=$(echo "$ORDERER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
        ST=$(echo "$ORDERER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
        L=$(echo "$ORDERER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')
        CN=$(echo "$ORDERER_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^CN=/) {sub(/^CN=/, "", $i); print $i}}')
        CSR_NAMES=$(echo "$ORDERER_SUBJECT" | sed 's/,CN=[^,]*//')
        AFFILIATION=$ORBIS.$REGNUM

        ###############################################################
        # Enroll orderer @ orbis
        ###############################################################
        echo ""
        echo_info "Orderer $ORDERER starting..."
        echo ""
        if [[ $DEBUG == true ]]; then
            echo_debug "Executing with the following:"
            echo_value_debug "- TLS Cert:" "$ORBIS_TLS_CERT"
            echo_value_debug "- Orbis MSP Name:" "$ORBIS_MSP_NAME"
            echo_value_debug "***" "***"
            echo_value_debug "- Orderer Name:" "$ORDERER_NAME"
            echo_value_debug "- MSP Affiliation:" "$AFFILIATION"
        fi
        echo_info "$ORDERER_NAME registering and enrolling at Orbis-MSP..."
        
        # Register and enroll MSP-ID
        docker exec -it $ORBIS_MSP_NAME fabric-ca-client register -u https://$ORBIS_MSP_NAME:$ORBIS_MSP_PASS@$ORBIS_MSP_NAME:$ORBIS_MSP_PORT \
            --home $ORBIS_MSP_DIR \
            --tls.certfiles "$ORBIS_TLS_CERT" \
            --mspdir $ORBIS_MSP_INFRA/$ORBIS/$ORBIS_MSP_NAME/msp \
            --id.name $ORDERER_NAME --id.secret $ORDERER_PASS --id.type orderer --id.affiliation $AFFILIATION
        docker exec -it $ORBIS_MSP_NAME fabric-ca-client enroll -u https://$ORDERER_NAME:$ORDERER_PASS@$ORBIS_MSP_NAME:$ORBIS_MSP_PORT \
            --home $ORBIS_MSP_DIR \
            --tls.certfiles "$ORBIS_TLS_CERT" \
            --mspdir $ORBIS_MSP_INFRA/$ORBIS/$REGNUM/$AGER/$ORDERER_NAME/msp \
            --csr.hosts ${ORDERER_NAME},${ORDERER_IP},*.$ORBIS.$ORBIS_ENV \
            --csr.cn $CN --csr.names "$CSR_NAMES"

        # Register and enroll TLS-ID
        docker exec -it $ORBIS_TLS_NAME fabric-ca-client register -u https://$ORBIS_TLS_NAME:$ORBIS_TLS_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
            --home $ORBIS_TLS_DIR \
            --tls.certfiles "$ORBIS_TLS_CERT" \
            --mspdir $ORBIS_TLS_INFRA/$ORBIS/$ORBIS_TLS_NAME/tls \
            --id.name $ORDERER_NAME --id.secret $ORDERER_PASS --id.type client --id.affiliation $AFFILIATION
        docker exec -it $ORBIS_TLS_NAME fabric-ca-client enroll -u https://$ORDERER_NAME:$ORDERER_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
            --home $ORBIS_TLS_DIR \
            --tls.certfiles "$ORBIS_TLS_CERT" \
            --mspdir $ORBIS_TLS_INFRA/$ORBIS/$REGNUM/$AGER/$ORDERER_NAME/tls \
            --csr.hosts ${ORDERER_NAME},${ORDERER_IP},*.$ORBIS.$ORBIS_ENV \
            --csr.cn $CN --csr.names "$CSR_NAMES" \
            --enrollment.profile tls 


        # Generating NodeOUs-File
        echo ""
        echo_info "NodeOUs-File writing..."
        CA_CERT_FILE=$(ls $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$ORDERER_NAME/msp/intermediatecerts/*.pem)
        cat <<EOF > $LOCAL_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$ORDERER_NAME/msp/config.yaml
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

        chmod -R 750 infrastructure


        echo ""
        echo_info "$ORDERER_NAME registered and enrolled."
    done
done
###############################################################
# Last Tasks
###############################################################


