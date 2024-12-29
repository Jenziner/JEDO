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

get_hosts

echo ""
echo_warn "CA nodes starting... (Defaults: https://hyperledger-fabric-ca.readthedocs.io/en/latest/serverconfig.html)"


###############################################################
# ORBIS-CA
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
cp -r ./RootCA/ROOT/jedo.dev/$ORBIS_CA_NAME/. $LOCAL_SRV_DIR

# Start Orbis-CA
ca_writeCfg "orbis" "$ORBIS_CA_NAME" "$CONFIG_FILE" "$LOCAL_SRV_DIR"
ca_start "$ORBIS_CA_NAME" "$CONFIG_FILE" "$LOCAL_SRV_DIR"


# Enroll Orbis-CA ID certs
echo ""
echo_info "Orbis-ORG-CA enrolling..."
docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$ORBIS_CA_NAME:$ORBIS_CA_PASS@$ORBIS_CA_NAME:$ORBIS_CA_PORT \
    --home $ORBIS_TOOLS_CACLI_DIR \
    --tls.certfiles tls-root-cert/tls-ca-cert.pem \
    --enrollment.profile ca \
    --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$ORBIS_CA_NAME/msp 


###############################################################
# Regnums-CA
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


    # Register Regnum-CA ID identity
    echo ""
    echo_info "Regnum-CA ID $REGNUM_CA_NAME registering and enrolling..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$ORBIS_CA_NAME:$ORBIS_CA_PASS@$ORBIS_CA_NAME:$ORBIS_CA_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$ORBIS_CA_NAME/msp \
        --id.name $REGNUM_CA_NAME --id.secret $REGNUM_CA_PASS --id.type client --id.affiliation $AFFILIATION \
        --id.attrs '"hf.Registrar.Roles=user,admin","hf.Revoker=true","hf.IntermediateCA=true"'
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$REGNUM_CA_NAME:$REGNUM_CA_PASS@$ORBIS_CA_NAME:$ORBIS_CA_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile ca \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$REGNUM_CA_NAME/msp \
        --csr.hosts ${PARENT_NAME},*.jedo.dev


        # Generating NodeOUs-File
        echo ""
        echo_info "NodeOUs-File writing..."
        CA_CERT_FILE=$(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/$REGNUM_CA_NAME/msp/cacerts/*.pem)
        cat <<EOF > ${PWD}/infrastructure/$ORBIS/$REGNUM/$REGNUM_CA_NAME/msp/config.yaml
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: orderer
EOF


    #Copy files to Organization msp
    echo_info "Organization msp creating (CA)..."
    mkdir -p ${PWD}/infrastructure/$ORBIS/$REGNUM/msp/cacerts
    cp ${PWD}/infrastructure/$ORBIS/$REGNUM/$REGNUM_CA_NAME/msp/cacerts/* ${PWD}/infrastructure/$ORBIS/$REGNUM/msp/cacerts
    mkdir -p ${PWD}/infrastructure/$ORBIS/$REGNUM/msp/intermediatecerts
    cp ${PWD}/infrastructure/$ORBIS/$REGNUM/$REGNUM_CA_NAME/msp/intermediatecerts/* ${PWD}/infrastructure/$ORBIS/$REGNUM/msp/intermediatecerts
    cp ${PWD}/infrastructure/$ORBIS/$REGNUM/$REGNUM_CA_NAME/msp/config.yaml ${PWD}/infrastructure/$ORBIS/$REGNUM/msp


    # Start Regnum-CA
    ca_writeCfg "regnum" "$REGNUM_CA_NAME" "$CONFIG_FILE" "$LOCAL_SRV_DIR"
    ca_start "$REGNUM_CA_NAME" "$CONFIG_FILE" "$LOCAL_SRV_DIR"


    # Enroll Regnum-CA ID certs
    echo ""
    echo_info "Regnum-CA enrolling..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$REGNUM_CA_NAME:$REGNUM_CA_PASS@$REGNUM_CA_NAME:$REGNUM_CA_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile ca \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$REGNUM_CA_NAME/msp
done


###############################################################
# Ager-CA
###############################################################
AGERS=$(yq eval '.Ager[] | .Name' "$CONFIG_FILE")
for AGER in $AGERS; do
    # Params for ager
    AGER_CA_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.Name" "$CONFIG_FILE")
    AGER_CA_PASS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.Pass" "$CONFIG_FILE")
    AGER_CA_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.IP" "$CONFIG_FILE")
    AGER_CA_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.Port" "$CONFIG_FILE")
    AGER_CA_OPPORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA.OpPort" "$CONFIG_FILE")
    AGER_REGNUM=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Administration.Parent" "$CONFIG_FILE")

    REGNUM=$(yq eval ".Regnum[] | select(.Name == \"$AGER_REGNUM\") | .Name" "$CONFIG_FILE")
    REGNUM_NAME=$(yq eval ".Regnum[] | select(.Name == \"$AGER_REGNUM\") | .CA.Name" "$CONFIG_FILE")
    REGNUM_PASS=$(yq eval ".Regnum[] | select(.Name == \"$AGER_REGNUM\") | .CA.Pass" "$CONFIG_FILE")
    REGNUM_PORT=$(yq eval ".Regnum[] | select(.Name == \"$AGER_REGNUM\") | .CA.Port" "$CONFIG_FILE")

    LOCAL_SRV_DIR=${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$AGER_CA_NAME/
    HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server

    AFFILIATION=$ORBIS.$REGNUM.$AGER

    mkdir -p $LOCAL_SRV_DIR


    # Add affiliation to Regnum-CA
    AFFILIATION=$ORBIS.$REGNUM.$AGER
    echo ""
    echo_info "Affiliation $AFFILIATION adding..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client affiliation add $AFFILIATION  -u https://$REGNUM_NAME:$REGNUM_PASS@$REGNUM_NAME:$REGNUM_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$REGNUM_NAME/msp


    # Register Ager-CA ID identity
    echo ""
    echo_info "Ager-CA ID $AGER_CA_NAME registering and enrolling..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$REGNUM_NAME:$REGNUM_PASS@$REGNUM_NAME:$REGNUM_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$REGNUM_NAME/msp \
        --id.name $AGER_CA_NAME --id.secret $AGER_CA_PASS --id.type client --id.affiliation $AFFILIATION \
        --id.attrs '"hf.Registrar.Roles=user,admin","hf.Revoker=true","hf.IntermediateCA=true"'
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$AGER_CA_NAME:$AGER_CA_PASS@$REGNUM_NAME:$REGNUM_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile ca \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$AGER_CA_NAME/msp \
        --csr.hosts ${REGNUM_NAME},*.jedo.dev


    # Generating NodeOUs-File
    echo ""
    echo_info "NodeOUs-File writing..."
    CA_CERT_FILE=$(ls ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$AGER_CA_NAME/msp/cacerts/*.pem)
    cat <<EOF > ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$AGER_CA_NAME/msp/config.yaml
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/$(basename $CA_CERT_FILE)
    OrganizationalUnitIdentifier: orderer
EOF


    #Copy files to Organization msp
    echo_info "Organization msp creating (CA)..."
    mkdir -p ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/msp/cacerts
    cp ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$AGER_CA_NAME/msp/cacerts/* ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/msp/cacerts
    mkdir -p ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/msp/intermediatecerts
    cp ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$AGER_CA_NAME/msp/intermediatecerts/* ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/msp/intermediatecerts
    cp ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/$AGER_CA_NAME/msp/config.yaml ${PWD}/infrastructure/$ORBIS/$REGNUM/$AGER/msp


    # Start Ager-CA
    ca_writeCfg "ager" "$AGER_CA_NAME" "$CONFIG_FILE" "$LOCAL_SRV_DIR"
    ca_start "$AGER_CA_NAME" "$CONFIG_FILE" "$LOCAL_SRV_DIR"


    # Enroll Ager-CA ID certs
    echo ""
    echo_info "Ager-CA enrolling..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$AGER_CA_NAME:$AGER_CA_PASS@$AGER_CA_NAME:$AGER_CA_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile ca \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$AGER_CA_NAME/msp

    # Add affiliation to Ager-CA
    AFFILIATION=$ORBIS.$REGNUM.$AGER
    echo ""
    echo_info "Affiliation $AFFILIATION adding..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client affiliation add $AFFILIATION  -u https://$AGER_CA_NAME:$AGER_CA_PASS@$AGER_CA_NAME:$AGER_CA_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$AGER_CA_NAME/msp


done

    # echo ""
    # echo_error "TEST Register..."
    # docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$AGER_CA_NAME:$AGER_CA_PASS@$AGER_CA_NAME:$AGER_CA_PORT \
    #     --home $ORBIS_TOOLS_CACLI_DIR \
    #     --tls.certfiles tls-root-cert/tls-ca-cert.pem \
    #     --mspdir $HOST_INFRA_DIR/$AGER/$AGER_CA_NAME/msp \
    #     --id.name irgendwer --id.secret irgendwie --id.type client --id.affiliation jedo.root 
    # docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://irgendwer:irgendwie@$AGER_CA_NAME:$AGER_CA_PORT \
    #     --home $ORBIS_TOOLS_CACLI_DIR \
    #     --tls.certfiles tls-root-cert/tls-ca-cert.pem \
    #     --mspdir $HOST_INFRA_DIR/irgendwer/msp \
    #     --csr.hosts ${AGER_CA_NAME},${AGER_CA_IP},*.jedo.dev


###############################################################
# Last Tasks
###############################################################
chmod -R 777 infrastructure
echo ""
echo_ok "CA nodes started."



