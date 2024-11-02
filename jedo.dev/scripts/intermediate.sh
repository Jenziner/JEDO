###############################################################
#!/bin/bash
#
# This script starts Root-CA and generates certificates for Intermediate-CA
# 
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
check_script


###############################################################
# Params - from ./config/network-config.yaml
###############################################################
CONFIG_FILE="$SCRIPT_DIR/infrastructure-dev.yaml"
DOCKER_UNRAID=$(yq eval '.Docker.Unraid' $CONFIG_FILE)
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $CONFIG_FILE)

CA_SRV_DIR=/etc/hyperledger/fabric-ca-server
CA_CLI_DIR=/etc/hyperledger/fabric-ca-client
INFRA_DIR=/etc/hyperledger/infrastructure

get_hosts


ROOT_NAME=$(yq eval ".Root.Name" "$CONFIG_FILE")
AFFILIATION_ROOT=${ROOT_NAME##*.}.${ROOT_NAME%%.*}

ROOT_TLSCA_NAME=$(yq eval ".Root.TLS-CA.Name" "$CONFIG_FILE")
ROOT_TLSCA_PORT=$(yq eval ".Root.TLS-CA.Port" "$CONFIG_FILE")
ROOT_TLSCA_ADMIN_NAME=$(yq eval ".Root.TLS-CA.Admin" "$CONFIG_FILE")
ROOT_TLSCA_ADMIN_PASS=$(yq eval ".Root.TLS-CA.Pass" "$CONFIG_FILE")

INTERMEDIATS=$(yq e ".Intermediates[].Name" $CONFIG_FILE)
for INTERMEDIATE in $INTERMEDIATS; do
    ###############################################################
    # Start Intermediate-TLS-CA
    ###############################################################
    echo ""
    echo_warn "Intermediate-TLS-CA for $INTERMEDIATE starting... - see Documentation here: https://hyperledger-fabric-ca.readthedocs.io"
    INTERTLSCA_NAME=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .TLS-CA.Name" $CONFIG_FILE)
    INTERTLSCA_IP=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .TLS-CA.IP" $CONFIG_FILE)
    INTERTLSCA_PORT=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .TLS-CA.Port" $CONFIG_FILE)
    INTERTLSCA_OPPORT=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .TLS-CA.OpPort" $CONFIG_FILE)
    INTERTLSCA_OPENSSL=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .TLS-CA.OpenSSL" $CONFIG_FILE)
    INTERTLSCA_ADMIN=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .TLS-CA.Admin" $CONFIG_FILE)
    INTERTLSCA_PASS=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .TLS-CA.Pass" $CONFIG_FILE)

    # Add Affiliation
    echo ""
    echo_info "Affiliation adding..."
    AFFILIATION_INT=$AFFILIATION_ROOT.${INTERMEDIATE,,}
    docker exec -it $ROOT_TLSCA_NAME fabric-ca-client affiliation add $AFFILIATION_INT -u https://$ROOT_TLSCA_ADMIN_NAME:$ROOT_TLSCA_ADMIN_PASS@$ROOT_TLSCA_NAME:$ROOT_TLSCA_PORT
    docker exec -it $ROOT_TLSCA_NAME fabric-ca-client affiliation list

    # Enroll Intermediate-TLS-Admin
    echo ""
    echo_info "Intermediate-TLS-Admin $INTERTLSCA_ADMIN registering and enrolling..."
    docker exec -it $ROOT_TLSCA_NAME fabric-ca-client register -u https://$ROOT_TLSCA_ADMIN_NAME:$ROOT_TLSCA_ADMIN_PASS@0.0.0.0:$ROOT_TLSCA_PORT \
        --id.name $INTERTLSCA_ADMIN --id.secret $INTERTLSCA_PASS --id.type admin --id.affiliation $AFFILIATION_ROOT \
        --id.attrs 'hf.Registrar.Attributes=*,hf.AffiliationMgr=true,hf.Revoker=true,hf.GenCRL=true,hf.IntermediateCA=true'
    docker exec -it $ROOT_TLSCA_NAME fabric-ca-client enroll -u https://$INTERTLSCA_ADMIN:$INTERTLSCA_PASS@$ROOT_TLSCA_NAME:$ROOT_TLSCA_PORT --mspdir $INFRA_DIR/_intermediate/$INTERTLSCA_ADMIN/keys/server/msp \
        --enrollment.attrs "hf.Registrar.Attributes,hf.AffiliationMgr,hf.Revoker,hf.IntermediateCA" --csr.hosts "$INTERTLSCA_NAME,$INTERTLSCA_IP,localhost,$ROOT_TLSCA_NAME"
    docker exec -it $ROOT_TLSCA_NAME fabric-ca-client enroll -u https://$INTERTLSCA_ADMIN:$INTERTLSCA_PASS@$ROOT_TLSCA_NAME:$ROOT_TLSCA_PORT --mspdir $INFRA_DIR/_intermediate/$INTERTLSCA_ADMIN/keys/server/tls \
        --enrollment.attrs "hf.Registrar.Attributes,hf.AffiliationMgr,hf.Revoker,hf.IntermediateCA" --csr.hosts "$INTERTLSCA_NAME,$INTERTLSCA_IP,localhost,$ROOT_TLSCA_NAME" --enrollment.profile tls


    # Initiate Intermediate-TLS-CA
    ROOT_TLS_CA_CERT=$(basename $(ls ${PWD}/infrastructure/_intermediate/$INTERTLSCA_ADMIN/keys/server/tls/tlscacerts/*.pem | head -n 1))
    TLS_CA_KEY=$(basename $(ls ${PWD}/infrastructure/_intermediate/$INTERTLSCA_ADMIN/keys/server/tls/keystore/*_sk | head -n 1))
    echo ""
    echo_info "Intermediate-CA $INTERTLSCA_NAME starting..."

    docker run -d \
        --name $INTERTLSCA_NAME \
        --network $DOCKER_NETWORK_NAME \
        --ip $INTERTLSCA_IP \
        $hosts_args \
        --restart=unless-stopped \
        --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/src/fabric_ca_logo.png" \
        -p $INTERTLSCA_PORT:$INTERTLSCA_PORT \
        -p $INTERTLSCA_OPPORT:$INTERTLSCA_OPPORT \
        -v ${PWD}/infrastructure/_intermediate/$INTERTLSCA_ADMIN/keys/server:$CA_SRV_DIR \
        -v ${PWD}/infrastructure/_intermediate/$INTERTLSCA_ADMIN/keys/client:$CA_CLI_DIR \
        -v ${PWD}/infrastructure/:$INFRA_DIR \
        -e FABRIC_CA_SERVER_LOGLEVEL=debug \
        -e FABRIC_CA_SERVER_CA_NAME=$INTERTLSCA_NAME \
        -e FABRIC_CA_SERVER_PORT=$INTERTLSCA_PORT \
        -e FABRIC_CA_SERVER_HOME=$CA_SRV_DIR \
        -e FABRIC_CA_SERVER_MSPDIR=$CA_SRV_DIR/msp \
        -e FABRIC_CA_SERVER_LISTENADDRESS=$INTERTLSCA_PORT \
        -e FABRIC_CA_SERVER_CSR_HOSTS="$INTERTLSCA_NAME,$INTERTLSCA_IP,localhost,0.0.0.0" \
        -e FABRIC_CA_SERVER_CSR_CA_PATHLENGTH=1 \
        -e FABRIC_CA_SERVER_TLS_ENABLED=true \
        -e FABRIC_CA_SERVER_TLS_CERTFILE=$INFRA_DIR/_intermediate/$INTERTLSCA_ADMIN/keys/server/tls/signcerts/cert.pem \
        -e FABRIC_CA_SERVER_TLS_KEYFILE=$INFRA_DIR/_intermediate/$INTERTLSCA_ADMIN/keys/server/tls/keystore/$TLS_CA_KEY \
        -e FABRIC_CA_SERVER_INTERMEDIATE_PARENTSERVER_URL=https://$ROOT_TLSCA_ADMIN_NAME:$ROOT_TLSCA_ADMIN_PASS@$ROOT_TLSCA_NAME:$ROOT_TLSCA_PORT \
        -e FABRIC_CA_SERVER_INTERMEDIATE_PARENTSERVER_NAME=$ROOT_TLSCA_NAME \
        -e FABRIC_CA_SERVER_INTERMEDIATE_ENROLLMENT_HOST=$INTERTLSCA_NAME \
        -e FABRIC_CA_SERVER_INTERMEDIATE_ENROLLMENT_PROFILE=ca \
        -e FABRIC_CA_SERVER_INTERMEDIATE_TLS_CERTFILES=$INFRA_DIR/_intermediate/$INTERTLSCA_ADMIN/keys/server/tls/tlscacerts/$ROOT_TLS_CA_CERT \
        -e FABRIC_CA_SERVER_CA_CHAINFILE=$INFRA_DIR/_intermediate/$INTERTLSCA_ADMIN/keys/server/tls/cacerts/ca-chain.pem \
        -e FABRIC_CA_SERVER_IDEMIX_CUURVE=gurvy.Bn254 \
        -e FABRIC_CA_SERVER_OPERATIONS_LISTENADDRESS=0.0.0.0:$INTERTLSCA_OPPORT \
        -e FABRIC_CA_SERVER_OPERATIONS_TLS=true \
        -e FABRIC_CA_SERVER_OPERATIONS_TLS_CERTFILE=$INFRA_DIR/_intermediate/$INTERTLSCA_ADMIN/keys/server/tls/signcerts/cert.pem \
        -e FABRIC_CA_SERVER_OPERATIONS_TLS_KEYFILE=$INFRA_DIR/_intermediate/$INTERTLSCA_ADMIN/keys/server/tls/keystore/$TLS_CA_KEY \
        -e FABRIC_CA_SERVER_CFG_AFFILIATIONS_ALLOWREMOVE=true \
        -e FABRIC_CA_CLIENT_HOME=$CA_CLI_DIR \
        -e FABRIC_CA_CLIENT_MSPDIR=$CA_CLI_DIR/msp \
        -e FABRIC_CA_CLIENT_TLS_ENABLED=true \
        -e FABRIC_CA_CLIENT_TLS_CERTFILES=$INFRA_DIR/_intermediate/$INTERTLSCA_ADMIN/keys/server/tls/tlscacerts/$ROOT_TLS_CA_CERT \
        hyperledger/fabric-ca:latest \
        sh -c "fabric-ca-server start -b $INTERTLSCA_ADMIN:$INTERTLSCA_PASS" 

    # Waiting Root-CA startup
    CheckContainer "$INTERTLSCA_NAME" "$DOCKER_CONTAINER_WAIT"
    CheckContainerLog "$INTERTLSCA_NAME" "Listening on https://0.0.0.0:$INTERTLSCA_PORT" "$DOCKER_CONTAINER_WAIT"

    # Installing OpenSSL
    if [[ $INTERTLSCA_OPENSSL = true ]]; then
        echo_info "OpenSSL installing..."
        docker exec $INTERTLSCA_NAME sh -c 'command -v apk && apk update && apk add --no-cache openssl || (apt-get update && apt-get install -y openssl)'
        CheckOpenSSL "$INTERTLSCA_NAME" "$DOCKER_CONTAINER_WAIT"
    fi

    # Enroll Intermediate-TLS-Admin
    echo ""
    echo_info "Intermediate-TLS-Admin enrolling..."
    docker exec -it $INTERTLSCA_NAME fabric-ca-client enroll -u https://$INTERTLSCA_ADMIN:$INTERTLSCA_PASS@$INTERTLSCA_NAME:$INTERTLSCA_PORT

    # Add Affiliation
    echo ""
    echo_info "Affiliation adding..."
    ROOT_NAME=$(yq eval ".Root.Name" "$CONFIG_FILE")
    DN="${ROOT_NAME%%.*}"   # Alles vor dem ersten Punkt
    TLDN="${ROOT_NAME##*.}" 

    AFFILIATION_ROOT=$TLDN
    docker exec -it $INTERTLSCA_NAME fabric-ca-client affiliation add $AFFILIATION_ROOT -u https://$INTERTLSCA_ADMIN:$INTERTLSCA_PASS@$INTERTLSCA_NAME:$INTERTLSCA_PORT
    AFFILIATION_ROOT=$TLDN.$DN
    docker exec -it $INTERTLSCA_NAME fabric-ca-client affiliation add $AFFILIATION_ROOT -u https://$INTERTLSCA_ADMIN:$INTERTLSCA_PASS@$INTERTLSCA_NAME:$INTERTLSCA_PORT
    AFFILIATION_INT=$AFFILIATION_ROOT.${INTERMEDIATE,,}
    docker exec -it $INTERTLSCA_NAME fabric-ca-client affiliation add $AFFILIATION_INT -u https://$INTERTLSCA_ADMIN:$INTERTLSCA_PASS@$INTERTLSCA_NAME:$INTERTLSCA_PORT

    # Remove default affiliation
    echo ""
    echo_info "Default affiliation removing..."
    docker exec -it $INTERTLSCA_NAME fabric-ca-client affiliation remove org1 --force -u https://$INTERTLSCA_ADMIN:$INTERTLSCA_PASS@$INTERTLSCA_NAME:$INTERTLSCA_PORT
    docker exec -it $INTERTLSCA_NAME fabric-ca-client affiliation remove org2 --force -u https://$INTERTLSCA_ADMIN:$INTERTLSCA_PASS@$INTERTLSCA_NAME:$INTERTLSCA_PORT
    docker exec -it $INTERTLSCA_NAME fabric-ca-client affiliation list

    echo_ok "Intermediate-TLS-CA $INTERTLSCA_NAME started..."
done




chmod -R 777 infrastructure
echo_error "TEMP END"
exit 1

###############################################################
# Last Tasks
###############################################################
chmod -R 777 infrastructure
echo_ok "Intermediate-CA certificates generated."












###############################################################
# Start Intermediate CAs
###############################################################
INTERMEDIATS=$(yq e ".Intermediates[].Name" $CONFIG_FILE)
for INTERMEDIATE in $INTERMEDIATS; do

    docker exec $INTERTLSCA_NAME sh -c "fabric-ca-server intermediate createcsr -b $INTERTLSCA_ADMIN:$INTERTLSCA_PASS"



    # docker exec -it tls.tws.jedo.dev fabric-ca-server gencrl --csr.certfile "/etc/hyperledger/fabric-ca-server/ca-cert.pem"









        -e FABRIC_CA_SERVER_MSPDIR=$CA_SRV_DIR/msp \
        -e FABRIC_CA_SERVER_CSR_CN=$INTERTLSCA_NAME \
        -e FABRIC_CA_SERVER_CSR_HOSTS="$INTERTLSCA_NAME,localhost,0.0.0.0" \
        -e FABRIC_CA_SERVER_CSR_CA_PATHLENGTH=1 \
        -e FABRIC_CA_SERVER_INTERMEDIATE_TLS_CERTFILES=$CA_SRV_DIR/tls/tlscacerts/$TLS_CERT_FILE \
        -e FABRIC_CA_SERVER_OPERATIONS_LISTENADDRESS=0.0.0.0:$INTERTLSCA_OPPORT \
        -e FABRIC_CA_SERVER_OPERATIONS_TLS=true \
        -e FABRIC_CA_SERVER_OPERATIONS_TLS_CERTFILE=$CA_SRV_DIR/tls/tls-cert.pem \
        -e FABRIC_CA_SERVER_OPERATIONS_TLS_KEYFILE=$CA_SRV_DIR/tls/tls-key.pem \
        -e FABRIC_CA_SERVER_CFG_AFFILIATIONS_ALLOWREMOVE=true \
        -e FABRIC_CA_CLIENT_HOME=$CA_CLI_DIR \
        -e FABRIC_CA_CLIENT_MSPDIR=$CA_CLI_DIR/msp \
        -e FABRIC_CA_CLIENT_TLS_ENABLED=true \
        -e FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_SRV_DIR/tls-cert.pem \




    # Enroll Intermediate-TLS-Admin
    echo ""
    echo_info "Certificates for $INTERMEDIATE enrolling..."
    docker exec -it $ROOT_TLSCA_NAME fabric-ca-client register -u https://$ROOT_TLSCA_ADMIN_NAME:$ROOT_TLSCA_ADMIN_PASS@$ROOT_TLSCA_NAME:$ROOT_TLSCA_PORT --mspdir $CA_CLI_DIR/msp \
        --id.name $INTERTLSCA_ADMIN --id.secret $INTERTLSCA_PASS --id.type admin --id.affiliation $AFFILIATION_ROOT 
    docker exec -it $ROOT_TLSCA_NAME fabric-ca-client enroll -u https://$INTERTLSCA_ADMIN:$ROOTCA_NODEADMIN_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $INFRA_DIR/_intermediate/$INTERTLSCA_ADMIN/msp









done


###############################################################
# Start OLD
###############################################################
docker run -d \
    --network $DOCKER_NETWORK_NAME \
    --name $ROOTCA_NAME \
    --ip $ROOTCA_IP \
    $hosts_args \
    --restart=unless-stopped \
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/src/fabric_ca_logo.png" \
    -e FABRIC_CA_SERVER_LOGLEVEL=debug \
    -e FABRIC_CA_NAME=$ROOTCA_NAME \
    -e FABRIC_CA_SERVER=$ROOTCA_SRV_DIR \
    -e FABRIC_CA_SERVER_MSPDIR=$ROOTCA_SRV_DIR/msp \
    -e FABRIC_CA_SERVER_LISTENADDRESS=$ROOTCA_IP \
    -e FABRIC_CA_SERVER_PORT=$ROOTCA_PORT \
    -e FABRIC_CA_SERVER_CSR_HOSTS="$ROOTCA_NAME,localhost" \
    -e FABRIC_CA_SERVER_TLS_ENABLED=true \
    -e FABRIC_CA_SERVER_IDEMIX_CUURVE=gurvy.Bn254 \
    -e FABRIC_CA_SERVER_OPERATIONS_LISTENADDRESS=0.0.0.0:$ROOTCA_OPPORT \
    -e FABRIC_CA_SERVER_OPERATIONS_TLS=true \
    -e FABRIC_CA_SERVER_OPERATIONS_TLS_CERTFILE=$ROOTCA_SRV_DIR/tls/tls-cert.pem \
    -e FABRIC_CA_SERVER_OPERATIONS_TLS_KEYFILE=$ROOTCA_SRV_DIR/tls/tls-key.pem \
    -e FABRIC_CA_SERVER_CFG_AFFILIATIONS_ALLOWREMOVE=true \
    -e FABRIC_CA_CLIENT=$ROOTCA_CLI_DIR \
    -e FABRIC_CA_CLIENT_MSPDIR=$ROOTCA_CLI_DIR/msp \
    -e FABRIC_CA_CLIENT_TLS_ENABLED=true \
    -e FABRIC_CA_CLIENT_TLS_CERTFILES=$ROOTCA_SRV_DIR/tls-cert.pem \
    -v ${PWD}/infrastructure/_root/$ROOTCA_NAME/keys:$ROOTCA_SRV_DIR \
    -v ${PWD}/infrastructure/_root/admin.$ROOTCA_NAME/keys:$ROOTCA_CLI_DIR \
    -v ${PWD}/infrastructure/:$INFRA_DIR \
    -p $ROOTCA_PORT:$ROOTCA_PORT \
    -p $ROOTCA_OPPORT:$ROOTCA_OPPORT \
    hyperledger/fabric-ca:latest \
    sh -c "fabric-ca-server start -b $ROOTCA_ORGADMIN_NAME:$ROOTCA_ORGADMIN_PASS" 

# Waiting Root-CA startup
CheckContainer "$ROOTCA_NAME" "$DOCKER_CONTAINER_WAIT"
CheckContainerLog "$ROOTCA_NAME" "Listening on https://0.0.0.0:$ROOTCA_PORT" "$DOCKER_CONTAINER_WAIT"

# Installing OpenSSL
if [[ $ROOTCA_OPENSSL = true ]]; then
    echo_info "OpenSSL installing..."
    docker exec $ROOTCA_NAME sh -c 'command -v apk && apk update && apk add --no-cache openssl || (apt-get update && apt-get install -y openssl)'
    CheckOpenSSL "$ROOTCA_NAME" "$DOCKER_CONTAINER_WAIT"
fi


###############################################################
# Enroll Root Admins and Affiliation
###############################################################
# Enroll Root-OrgAdmin
echo ""
echo_info "Root-OrgAdmin enrolling..."
docker exec -it $ROOTCA_NAME fabric-ca-client enroll -u https://$ROOTCA_ORGADMIN_NAME:$ROOTCA_ORGADMIN_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $ROOTCA_CLI_DIR/msp


# Add Affiliation
echo ""
echo_info "Affiliation adding..."
ROOTCA_ORGADMIN_SUBJECT=$(yq eval ".Root.OrgAdmin.Subject" "$CONFIG_FILE")
ST=$(echo "$ROOTCA_ORGADMIN_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
DN="${ST%%.*}"   # Alles vor dem ersten Punkt
TLDN="${ST##*.}" 

AFFILIATION_ROOT=$TLDN
docker exec -it $ROOTCA_NAME fabric-ca-client affiliation add $AFFILIATION_ROOT -u https://$ROOTCA_ORGADMIN_NAME:$ROOTCA_ORGADMIN_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $ROOTCA_CLI_DIR/msp

AFFILIATION_ROOT=$TLDN.$DN
docker exec -it $ROOTCA_NAME fabric-ca-client affiliation add $AFFILIATION_ROOT -u https://$ROOTCA_ORGADMIN_NAME:$ROOTCA_ORGADMIN_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $ROOTCA_CLI_DIR/msp


# Remove default affiliation
echo ""
echo_info "Default affiliation removing..."
docker exec -it $ROOTCA_NAME fabric-ca-client affiliation remove org1 --force -u https://$ROOTCA_ORGADMIN_NAME:$ROOTCA_ORGADMIN_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $ROOTCA_CLI_DIR/msp
docker exec -it $ROOTCA_NAME fabric-ca-client affiliation remove org2 --force -u https://$ROOTCA_ORGADMIN_NAME:$ROOTCA_ORGADMIN_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $ROOTCA_CLI_DIR/msp
docker exec -it $ROOTCA_NAME fabric-ca-client affiliation list


# Enroll Root-NodeAdmin
echo ""
echo_info "Root-NodeAdmin registering and enrolling..."
ROOTCA_NODEADMIN_NAME=$(yq eval ".Root.NodeAdmin.Name" "$CONFIG_FILE")
ROOTCA_NODEADMIN_PASS=$(yq eval ".Root.NodeAdmin.Pass" "$CONFIG_FILE")
docker exec -it $ROOTCA_NAME fabric-ca-client register -u https://$ROOTCA_ORGADMIN_NAME:$ROOTCA_ORGADMIN_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $ROOTCA_CLI_DIR/msp \
    --id.name $ROOTCA_NODEADMIN_NAME --id.secret $ROOTCA_NODEADMIN_PASS --id.type admin --id.affiliation $AFFILIATION_ROOT 
docker exec -it $ROOTCA_NAME fabric-ca-client enroll -u https://$ROOTCA_NODEADMIN_NAME:$ROOTCA_NODEADMIN_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $INFRA_DIR/_root/$ROOTCA_NODEADMIN_NAME/msp


# Enroll Root-TokenAdmin
echo ""
echo_info "Root-TokenAdmin registering and enrolling..."
ROOTCA_TOKENADMIN_NAME=$(yq eval ".Root.TokenAdmin.Name" "$CONFIG_FILE")
ROOTCA_TOKENADMIN_PASS=$(yq eval ".Root.TokenAdmin.Pass" "$CONFIG_FILE")
docker exec -it $ROOTCA_NAME fabric-ca-client register -u https://$ROOTCA_ORGADMIN_NAME:$ROOTCA_ORGADMIN_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $ROOTCA_CLI_DIR/msp \
    --id.name $ROOTCA_TOKENADMIN_NAME --id.secret $ROOTCA_TOKENADMIN_PASS --id.type admin --id.affiliation $AFFILIATION_ROOT
docker exec -it $ROOTCA_NAME fabric-ca-client enroll -u https://$ROOTCA_TOKENADMIN_NAME:$ROOTCA_TOKENADMIN_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $INFRA_DIR/_root/$ROOTCA_TOKENADMIN_NAME/msp


# Enroll Root-TlsAdmin
echo ""
echo_info "Root-TlsAdmin registering and enrolling..."
ROOTCA_TLSADMIN_NAME=$(yq eval ".Root.TlsAdmin.Name" "$CONFIG_FILE")
ROOTCA_TLSADMIN_PASS=$(yq eval ".Root.TlsAdmin.Pass" "$CONFIG_FILE")
docker exec -it $ROOTCA_NAME fabric-ca-client register -u https://$ROOTCA_ORGADMIN_NAME:$ROOTCA_ORGADMIN_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $ROOTCA_CLI_DIR/msp \
    --id.name $ROOTCA_TLSADMIN_NAME --id.secret $ROOTCA_TLSADMIN_PASS --id.type admin --id.affiliation $AFFILIATION_ROOT
docker exec -it $ROOTCA_NAME fabric-ca-client enroll -u https://$ROOTCA_TLSADMIN_NAME:$ROOTCA_TLSADMIN_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $INFRA_DIR/_root/$ROOTCA_TLSADMIN_NAME/msp


echo_ok "Root-CA $ROOTCA_NAME started."


###############################################################
# Generate Intermediate certificats
###############################################################
echo ""
echo_warn "Intermediate-CA certificates generating..."
ORGANIZATIONS=$(yq e ".Organizations[].Name" $CONFIG_FILE)
for ORGANIZATION in $ORGANIZATIONS; do
    CA_EXT=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Ext" "$CONFIG_FILE")


    # Skip if external CA is defined
    if ! [[ -n "$CA_EXT" ]]; then
        # Add Affiliation
        echo ""
        echo_info "Affiliation adding for $ORGANIZATION..."
        ORGADMIN_SUBJECT=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .OrgAdmin.Subject" $CONFIG_FILE)
        AFFILIATION_ORG=$AFFILIATION_ROOT.${ORGANIZATION,,}
        docker exec -it $ROOTCA_NAME fabric-ca-client affiliation add $AFFILIATION_ORG -u https://$ROOTCA_ORGADMIN_NAME:$ROOTCA_ORGADMIN_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $ROOTCA_CLI_DIR/msp


        # Enroll OrgAdmin
        echo ""
        echo_info "OrgAdmin registering and enrolling..."
        ORGADMIN_NAME=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .OrgAdmin.Name" $CONFIG_FILE)
        ORGADMIN_PASS=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .OrgAdmin.Pass" $CONFIG_FILE)
        C=$(echo "$ORGADMIN_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^C=/) {sub(/^C=/, "", $i); print $i}}')
        ST=$(echo "$ORGADMIN_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^ST=/) {sub(/^ST=/, "", $i); print $i}}')
        L=$(echo "$ORGADMIN_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^L=/) {sub(/^L=/, "", $i); print $i}}')
        CN=$(echo "$ORGADMIN_SUBJECT" | awk -F',' '{for(i=1;i<=NF;i++) if ($i ~ /^CN=/) {sub(/^CN=/, "", $i); print $i}}')
        CSR_NAMES="C=$C,ST=$ST,L=$L"
        CAAPI_NAME=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.CAAPI.Name" $CONFIG_FILE)
        CAAPI_IP=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.CAAPI.IP" $CONFIG_FILE)
        CAAPI_PORT=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.CAAPI.SrvPort" $CONFIG_FILE)

        docker exec -it $ROOTCA_NAME fabric-ca-client register -u https://$ROOTCA_ORGADMIN_NAME:$ROOTCA_ORGADMIN_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $ROOTCA_CLI_DIR/msp \
            --id.name $ORGADMIN_NAME --id.secret $ORGADMIN_PASS --id.type admin --id.affiliation $AFFILIATION_ORG \
            --id.attrs 'jedo.apiPort='"$CAAPI_PORT"',jedo.role=CA,"hf.Registrar.Roles=client,peer,orderer,admin","hf.Registrar.DelegateRoles=client,peer,orderer,admin",hf.Registrar.Attributes=*,hf.AffiliationMgr=true,hf.Revoker=true,hf.GenCRL=true,hf.IntermediateCA=true'
        docker exec -it $ROOTCA_NAME fabric-ca-client enroll -u https://$ORGADMIN_NAME:$ORGADMIN_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $INFRA_DIR/$ORGANIZATION/$ORGADMIN_NAME/msp \
            --enrollment.attrs "hf.Registrar.Roles,hf.Registrar.DelegateRoles,hf.Registrar.Attributes,hf.AffiliationMgr,hf.Revoker,hf.IntermediateCA,hf.GenCRL,jedo.apiPort,jedo.role" --csr.cn $CN --csr.names $CSR_NAMES --csr.hosts "$ROOTCA_NAME,$ORGADMIN_NAME,$CAAPI_NAME,$CAAPI_IP,$DOCKER_UNRAID"
        docker exec -it $ROOTCA_NAME fabric-ca-client enroll -u https://$ORGADMIN_NAME:$ORGADMIN_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $INFRA_DIR/$ORGANIZATION/$ORGADMIN_NAME/tls \
            --enrollment.profile tls --csr.cn $CN --csr.names "$CSR_NAMES" --csr.hosts "$ROOTCA_NAME,$ROOTCA_IP,$DOCKER_UNRAID"  


        # Enroll NodeAdmin
        echo ""
        echo_info "NodeAdmin registering and enrolling..."
        NODEADMIN_NAME=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .NodeAdmin.Name" $CONFIG_FILE)
        NODEADMIN_PASS=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .NodeAdmin.Pass" $CONFIG_FILE)

        docker exec -it $ROOTCA_NAME fabric-ca-client register -u https://$ROOTCA_ORGADMIN_NAME:$ROOTCA_ORGADMIN_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $ROOTCA_CLI_DIR/msp \
            --id.name $NODEADMIN_NAME --id.secret $NODEADMIN_PASS --id.type admin --id.affiliation $AFFILIATION_ORG \
            --id.attrs 'jedo.apiPort='"$CAAPI_PORT"',jedo.role=CA,"hf.Registrar.Roles=client,peer,orderer,admin","hf.Registrar.DelegateRoles=client,peer,orderer,admin",hf.Registrar.Attributes=*,hf.AffiliationMgr=true,hf.Revoker=true,hf.GenCRL=true,hf.IntermediateCA=true'
        docker exec -it $ROOTCA_NAME fabric-ca-client enroll -u https://$NODEADMIN_NAME:$NODEADMIN_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $INFRA_DIR/$ORGANIZATION/$NODEADMIN_NAME/msp \
            --enrollment.attrs "hf.Registrar.Roles,hf.Registrar.DelegateRoles,hf.Registrar.Attributes,hf.AffiliationMgr,hf.Revoker,hf.IntermediateCA,hf.GenCRL,jedo.apiPort,jedo.role" --csr.cn $CN --csr.names $CSR_NAMES --csr.hosts "$ROOTCA_NAME,$ORGADMIN_NAME,$CAAPI_NAME,$CAAPI_IP,$DOCKER_UNRAID"
        docker exec -it $ROOTCA_NAME fabric-ca-client enroll -u https://$NODEADMIN_NAME:$NODEADMIN_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $INFRA_DIR/$ORGANIZATION/$NODEADMIN_NAME/tls \
            --enrollment.profile tls --csr.cn $CN --csr.names "$CSR_NAMES" --csr.hosts "$ROOTCA_NAME,$ROOTCA_IP,$DOCKER_UNRAID"  


        # Enroll TokenAdmin
        echo ""
        echo_info "TokenAdmin registering and enrolling..."
        TOKENADMIN_NAME=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .TokenAdmin.Name" $CONFIG_FILE)
        TOKENADMIN_PASS=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .TokenAdmin.Pass" $CONFIG_FILE)

        docker exec -it $ROOTCA_NAME fabric-ca-client register -u https://$ROOTCA_ORGADMIN_NAME:$ROOTCA_ORGADMIN_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $ROOTCA_CLI_DIR/msp \
            --id.name $TOKENADMIN_NAME --id.secret $TOKENADMIN_PASS --id.type admin --id.affiliation $AFFILIATION_ORG \
            --id.attrs 'jedo.apiPort='"$CAAPI_PORT"',jedo.role=CA,"hf.Registrar.Roles=client,peer,orderer,admin","hf.Registrar.DelegateRoles=client,peer,orderer,admin",hf.Registrar.Attributes=*,hf.AffiliationMgr=true,hf.Revoker=true,hf.GenCRL=true,hf.IntermediateCA=true'
        docker exec -it $ROOTCA_NAME fabric-ca-client enroll -u https://$TOKENADMIN_NAME:$TOKENADMIN_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $INFRA_DIR/$ORGANIZATION/$TOKENADMIN_NAME/msp \
            --enrollment.attrs "hf.Registrar.Roles,hf.Registrar.DelegateRoles,hf.Registrar.Attributes,hf.AffiliationMgr,hf.Revoker,hf.IntermediateCA,hf.GenCRL,jedo.apiPort,jedo.role" --csr.cn $CN --csr.names $CSR_NAMES --csr.hosts "$ROOTCA_NAME,$ORGADMIN_NAME,$CAAPI_NAME,$CAAPI_IP,$DOCKER_UNRAID"
        docker exec -it $ROOTCA_NAME fabric-ca-client enroll -u https://$TOKENADMIN_NAME:$TOKENADMIN_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $INFRA_DIR/$ORGANIZATION/$TOKENADMIN_NAME/tls \
            --enrollment.profile tls --csr.cn $CN --csr.names "$CSR_NAMES" --csr.hosts "$ROOTCA_NAME,$ROOTCA_IP,$DOCKER_UNRAID"  


        # Enroll TlsAdmin
        echo ""
        echo_info "TlsAdmin registering and enrolling..."
        TLSADMIN_NAME=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .TlsAdmin.Name" $CONFIG_FILE)
        TLSADMIN_PASS=$(yq eval ".Organizations[] | select(.Name == \"$ORGANIZATION\") | .TlsAdmin.Pass" $CONFIG_FILE)

        docker exec -it $ROOTCA_NAME fabric-ca-client register -u https://$ROOTCA_ORGADMIN_NAME:$ROOTCA_ORGADMIN_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $ROOTCA_CLI_DIR/msp \
            --id.name $TLSADMIN_NAME --id.secret $TLSADMIN_PASS --id.type admin --id.affiliation $AFFILIATION_ORG \
            --id.attrs 'jedo.apiPort='"$CAAPI_PORT"',jedo.role=CA,"hf.Registrar.Roles=client,peer,orderer,admin","hf.Registrar.DelegateRoles=client,peer,orderer,admin",hf.Registrar.Attributes=*,hf.AffiliationMgr=true,hf.Revoker=true,hf.GenCRL=true,hf.IntermediateCA=true'
        docker exec -it $ROOTCA_NAME fabric-ca-client enroll -u https://$TLSADMIN_NAME:$TLSADMIN_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $INFRA_DIR/$ORGANIZATION/$TLSADMIN_NAME/msp \
            --enrollment.attrs "hf.Registrar.Roles,hf.Registrar.DelegateRoles,hf.Registrar.Attributes,hf.AffiliationMgr,hf.Revoker,hf.IntermediateCA,hf.GenCRL,jedo.apiPort,jedo.role" --csr.cn $CN --csr.names $CSR_NAMES --csr.hosts "$ROOTCA_NAME,$ORGADMIN_NAME,$CAAPI_NAME,$CAAPI_IP,$DOCKER_UNRAID"
        docker exec -it $ROOTCA_NAME fabric-ca-client enroll -u https://$TLSADMIN_NAME:$TLSADMIN_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $INFRA_DIR/$ORGANIZATION/$TLSADMIN_NAME/tls \
            --enrollment.profile tls --csr.cn $CN --csr.names "$CSR_NAMES" --csr.hosts "$ROOTCA_NAME,$ROOTCA_IP,$DOCKER_UNRAID"  
    else
        echo ""
        echo_info "Affiliation adding for $ORGANIZATION..."
        AFFILIATION_ORG=$AFFILIATION_ROOT.${ORGANIZATION,,}
        docker exec -it $ROOTCA_NAME fabric-ca-client affiliation add $AFFILIATION_ORG -u https://$ROOTCA_ORGADMIN_NAME:$ROOTCA_ORGADMIN_PASS@$ROOTCA_NAME:$ROOTCA_PORT --mspdir $ROOTCA_CLI_DIR/msp
    fi
done


chmod -R 777 infrastructure


echo_ok "Intermediate-CA certificates generated."






