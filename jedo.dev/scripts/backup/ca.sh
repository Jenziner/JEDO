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

# TEMP - needs to be changed, if certs are available in git, copy then from git when needed
cp -r ./RootCA/ROOT/. ./infrastructure/


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
echo_warn "CA starting... (Defaults: https://hyperledger-fabric-ca.readthedocs.io/en/latest/serverconfig.html)"


###############################################################
# Orbis-TLS-CA
###############################################################
ORBIS=$(yq eval ".Orbis.Name" "$CONFIG_FILE")
ORBIS_TLS_NAME=$(yq eval ".Orbis.TLS.Name" "$CONFIG_FILE")
ORBIS_TLS_PASS=$(yq eval ".Orbis.TLS.Pass" "$CONFIG_FILE")
ORBIS_TLS_IP=$(yq eval ".Orbis.TLS.IP" "$CONFIG_FILE")
ORBIS_TLS_PORT=$(yq eval ".Orbis.TLS.Port" "$CONFIG_FILE")
ORBIS_TLS_OPPORT=$(yq eval ".Orbis.TLS.OpPort" "$CONFIG_FILE")


# LOCAL_INFRA_DIR=${PWD}/infrastructure
LOCAL_SRV_DIR=${PWD}/infrastructure/$ORBIS/$ORBIS_TLS_NAME
HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server
mkdir -p $LOCAL_SRV_DIR


# Write Orbis-TLS-CA SERVER config
cat <<EOF > $LOCAL_SRV_DIR/fabric-ca-server-config.yaml
---
version: 0.0.1
port: $ORBIS_TLS_PORT
debug: true
tls:
    enabled: true
    clientauth:
      type: noclientcert
      certfiles:
ca:
    name: $ORBIS_TLS_NAME
crl:
registry:
    maxenrollments: -1
    identities:
        - name: $ORBIS_TLS_NAME
          pass: $ORBIS_TLS_PASS
          type: client
          affiliation: "jedo.root"
          attrs:
              hf.Registrar.Roles: "*"
              hf.Registrar.DelegateRoles: "*"
              hf.Revoker: true
              hf.IntermediateCA: true
              hf.GenCRL: true
              hf.Registrar.Attributes: "*"
              hf.AffiliationMgr: true
affiliations:
    jedo:
        - root
        - ea
        - as
        - af
        - na
        - sa
signing:
    default:
        usage:
            - digital signature
        expiry: 8760h
    profiles:
        tls:
            usage:
                - cert sign
                - crl sign
                - signing
                - key encipherment
                - server auth
                - client auth
                - key agreement
            expiry: 8760h
csr:
    cn: $ORBIS_TLS_NAME
    keyrequest:
        algo: ecdsa
        size: 384
    names:
        - C: JD
          ST: Dev
          L:
          O: JEDO
          OU: Root
    hosts:
        - $ORBIS_TLS_NAME
        - $ORBIS_TLS_IP
    ca:
        expiry: 131400h
        pathlength: 1
idemix:
    curve: gurvy.Bn254
operations:
    listenAddress: $ORBIS_TLS_IP:$ORBIS_TLS_OPPORT
    tls:
        enabled: false
#        cert:
#            file:
#        key:
#            file:
#        clientAuthRequired: false
#        clientRootCAs:
#            files: []
EOF


# Start Orbis-TLS-CA Containter
echo ""
echo_info "Docker Container $ORBIS_TLS_NAME starting..."
docker run -d \
    --name $ORBIS_TLS_NAME \
    --network $DOCKER_NETWORK_NAME \
    --ip $ORBIS_TLS_IP \
    $hosts_args \
    --restart=on-failure:1 \
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/src/fabric_ca_logo.png" \
    -p $ORBIS_TLS_PORT:$ORBIS_TLS_PORT \
    -p $ORBIS_TLS_OPPORT:$ORBIS_TLS_OPPORT \
    -v $LOCAL_SRV_DIR:$HOST_SRV_DIR \
    hyperledger/fabric-ca:latest \
    sh -c "fabric-ca-server start -b $ORBIS_TLS_NAME:$ORBIS_TLS_PASS \
    --home $HOST_SRV_DIR"


# Waiting Orbis-TLS-CA Host startup
CheckContainer "$ORBIS_TLS_NAME" "$DOCKER_CONTAINER_WAIT"
CheckContainerLog "$ORBIS_TLS_NAME" "Listening on https://0.0.0.0:$ORBIS_TLS_PORT" "$DOCKER_CONTAINER_WAIT"


# copy ca-cert.pem to TLS-key directory and ca-client directory
cp -r $LOCAL_SRV_DIR/ca-cert.pem $LOCAL_SRV_DIR/tls-ca-cert.pem
mkdir ${PWD}/infrastructure/$ORBIS/$ORBIS_TOOLS_NAME/ca-client/tls-root-cert
cp -r $LOCAL_SRV_DIR/ca-cert.pem ${PWD}/infrastructure/$ORBIS/$ORBIS_TOOLS_NAME/ca-client/tls-root-cert/tls-ca-cert.pem


# Enroll Orbis-TLS-CA TLS certs
echo ""
echo_info "Orbis-TLS-CA enrolling..."
docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$ORBIS_TLS_NAME:$ORBIS_TLS_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
    --home $ORBIS_TOOLS_CACLI_DIR \
    --tls.certfiles tls-root-cert/tls-ca-cert.pem \
    --enrollment.profile tls \
    --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$ORBIS_TLS_NAME/tls \


###############################################################
# Register and entroll TLS certs for Orbis-CA
###############################################################
ORBIS_CA_NAME=$(yq eval ".Orbis.CA.Name" "$CONFIG_FILE")
ORBIS_CA_PASS=$(yq eval ".Orbis.CA.Pass" "$CONFIG_FILE")
ORBIS_CA_IP=$(yq eval ".Orbis.CA.IP" "$CONFIG_FILE")

# Register Orbis-CA identity
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
    --csr.hosts ${ORBIS_CA_NAME},${ORBIS_CA_IP},${ORBIS_TLS_NAME},${ORBIS_TLS_IP},*.jedo.dev


###############################################################
# Register and entroll TLS certs for Regnums-CA
###############################################################
REGNUMS=$(yq eval '.Regnum[] | .Name' "$CONFIG_FILE")
REGNUM_COUNT=$(echo "$REGNUMS" | wc -l)

# exit when no regnum is defined
if [ "$REGNUM_COUNT" -eq 0 ]; then
    echo_error "No regnum defined."
    exit 1
fi


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
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS_NAME/$ORBIS_TLS_NAME/tls \
        --id.name $REGNUM_CA_NAME --id.secret $REGNUM_CA_PASS --id.type client --id.affiliation jedo.root
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$REGNUM_CA_NAME:$REGNUM_CA_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile tls \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS_NAME/$REGNUM/$REGNUM_CA_NAME/tls \
        --csr.hosts ${REGNUM_CA_NAME},${REGNUM_CA_IP},${ORBIS_CA_NAME},${ORBIS_CA_IP},${ORBIS_TLS_NAME},${ORBIS_TLS_IP},*.jedo.dev


    #Copy files to Organization msp
    echo_info "Organization msp creating (TLS)..."
    mkdir -p ${PWD}/infrastructure/$ORBIS_NAME/$REGNUM/_Organization/msp/tlscacerts
    cp ${PWD}/infrastructure/$ORBIS_NAME/$REGNUM/$REGNUM_CA_NAME/tls/tlscacerts/* ${PWD}/infrastructure/$ORBIS_NAME/$REGNUM/_Organization/msp/tlscacerts
    # Not yet in use
    # mkdir -p ${PWD}/infrastructure/$ORBIS_NAME/$REGNUM/Organization/msp/tlsintermediatecerts
    # cp ${PWD}/infrastructure/$ORBIS_NAME/$REGNUM/$REGNUM_CA_NAME/tls/tlsintermediatecerts/* ${PWD}/infrastructure/$ORBIS_NAME/$REGNUM/Organization/msp/tlsintermediatecerts


    # Params for admin
    REGNUM_ADMIN_NAME=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .Administration.Contact" "$CONFIG_FILE")
    REGNUM_ADMIN_PASS=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .Administration.Pass" "$CONFIG_FILE")
    REGNUM_ADMIN_SUBJECT=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .Administration.Subject" $CONFIG_FILE)


    # Extract fields from subject
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
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS_NAME/$ORBIS_TLS_NAME/tls \
        --id.name $REGNUM_ADMIN_NAME --id.secret $REGNUM_ADMIN_PASS --id.type admin --id.affiliation jedo.root
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$REGNUM_ADMIN_NAME:$REGNUM_ADMIN_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile tls \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS_NAME/$REGNUM/_Admin/$REGNUM_ADMIN_NAME/tls \
        --csr.hosts ${REGNUM_CA_NAME},${REGNUM_CA_IP},${ORBIS_CA_NAME},${ORBIS_CA_IP},${ORBIS_TLS_NAME},${ORBIS_TLS_IP},*.jedo.dev \
        --csr.cn $CN --csr.names "$CSR_NAMES"


    # copy admin-client tlscacerts
    echo_info "Admin Client tlscacerts copying..."
    mkdir -p ${PWD}/infrastructure/$ORBIS_NAME/$REGNUM/_Admin/tls/tlscacerts
    cp ${PWD}/infrastructure/$ORBIS_NAME/$REGNUM/_Admin/$REGNUM_ADMIN_NAME/tls/tlscacerts/* ${PWD}/infrastructure/$ORBIS_NAME/$REGNUM/_Admin/tls/tlscacerts
done


###############################################################
# Register and entroll Ager-CA TLS certs
###############################################################
AGERS=$(yq eval '.Ager[] | .Name' "$CONFIG_FILE")
AGER_COUNT=$(echo "$AGERS" | wc -l)

# exit when no regnum is defined
if [ "$AGER_COUNT" -eq 0 ]; then
    echo_error "No regnum defined."
    exit 1
fi


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
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS_NAME/$ORBIS_TLS_NAME/tls \
        --id.name $AGER_CA_NAME --id.secret $AGER_CA_PASS --id.type client --id.affiliation jedo.root
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$AGER_CA_NAME:$AGER_CA_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile tls \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS_NAME/$AGER_PARENT/$AGER/$AGER_CA_NAME/tls \
        --csr.hosts ${AGER_CA_NAME},${AGER_CA_IP},${ORBIS_CA_NAME},${ORBIS_CA_IP},${ORBIS_TLS_NAME},${ORBIS_TLS_IP},*.jedo.dev
done

###############################################################
# ORBIS-CA
###############################################################
ORBIS_CA_NAME=$(yq eval ".Orbis.CA.Name" "$CONFIG_FILE")
ORBIS_CA_PASS=$(yq eval ".Orbis.CA.Pass" "$CONFIG_FILE")
ORBIS_CA_IP=$(yq eval ".Orbis.CA.IP" "$CONFIG_FILE")
ORBIS_CA_PORT=$(yq eval ".Orbis.CA.Port" "$CONFIG_FILE")
ORBIS_CA_OPPORT=$(yq eval ".Orbis.CA.OpPort" "$CONFIG_FILE")

# LOCAL_INFRA_DIR=${PWD}/infrastructure
LOCAL_SRV_DIR=${PWD}/infrastructure/$ORBIS_NAME/$ORBIS_CA_NAME

# HOST_INFRA_DIR=/etc/infrastructure
HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server

mkdir -p $LOCAL_SRV_DIR

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
    --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS_NAME/$ORBIS_CA_NAME/msp 


###############################################################
# Regnums-CA
###############################################################
REGNUMS=$(yq eval '.Regnum[] | .Name' "$CONFIG_FILE")
REGNUM_COUNT=$(echo "$REGNUMS" | wc -l)

# exit when no regnum is defined
if [ "$REGNUM_COUNT" -eq 0 ]; then
    echo_error "No regnum defined."
    exit 1
fi


for REGNUM in $REGNUMS; do
    # Params for regnum
    REGNUM_CA_NAME=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .CA.Name" "$CONFIG_FILE")
    REGNUM_CA_PASS=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .CA.Pass" "$CONFIG_FILE")
    REGNUM_CA_IP=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .CA.IP" "$CONFIG_FILE")
    REGNUM_CA_PORT=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .CA.Port" "$CONFIG_FILE")
    REGNUM_CA_OPPORT=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .CA.OpPort" "$CONFIG_FILE")

    REGNUM_CA_NAME_FORMATTED="${REGNUM_CA_NAME//./-}"

    PARENT_ORG=$(yq eval ".Orbis.Name" "$CONFIG_FILE")
    PARENT_NAME=$(yq eval ".Orbis.CA.Name" "$CONFIG_FILE")
    PARENT_PASS=$(yq eval ".Orbis.CA.Pass" "$CONFIG_FILE")
    PARENT_PORT=$(yq eval ".Orbis.CA.Port" "$CONFIG_FILE")

    LOCAL_SRV_DIR=${PWD}/infrastructure/$ORBIS_NAME/$REGNUM/$REGNUM_CA_NAME/
    HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server

    mkdir -p $LOCAL_SRV_DIR


    # Register Regnum-CA ID identity
    echo ""
    echo_info "Regnum-CA ID $REGNUM_CA_NAME registering and enrolling..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$PARENT_NAME:$PARENT_PASS@$PARENT_NAME:$PARENT_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$PARENT_ORG/$PARENT_NAME/msp \
        --id.name $REGNUM_CA_NAME --id.secret $REGNUM_CA_PASS --id.type client --id.affiliation jedo.root \
        --id.attrs '"hf.Registrar.Roles=user,admin","hf.Revoker=true","hf.IntermediateCA=true"'
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$REGNUM_CA_NAME:$REGNUM_CA_PASS@$PARENT_NAME:$PARENT_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile ca \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS_NAME/$REGNUM/$REGNUM_CA_NAME/msp \
        --csr.hosts ${PARENT_NAME},${PARENT_IP},*.jedo.dev


        # Generating NodeOUs-File
        echo ""
        echo_info "NodeOUs-File writing..."
        CA_CERT_FILE=$(ls ${PWD}/infrastructure/$ORBIS_NAME/$REGNUM/$REGNUM_CA_NAME/msp/cacerts/*.pem)
        cat <<EOF > ${PWD}/infrastructure/$ORBIS_NAME/$REGNUM/$REGNUM_CA_NAME/msp/config.yaml
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
    mkdir -p ${PWD}/infrastructure/$ORBIS_NAME/$REGNUM/_Organization/msp/cacerts
    cp ${PWD}/infrastructure/$ORBIS_NAME/$REGNUM/$REGNUM_CA_NAME/msp/cacerts/* ${PWD}/infrastructure/$ORBIS_NAME/$REGNUM/_Organization/msp/cacerts
    mkdir -p ${PWD}/infrastructure/$ORBIS_NAME/$REGNUM/_Organization/msp/intermediatecerts
    cp ${PWD}/infrastructure/$ORBIS_NAME/$REGNUM/$REGNUM_CA_NAME/msp/intermediatecerts/* ${PWD}/infrastructure/$ORBIS_NAME/$REGNUM/_Organization/msp/intermediatecerts
    cp ${PWD}/infrastructure/$ORBIS_NAME/$REGNUM/$REGNUM_CA_NAME/msp/config.yaml ${PWD}/infrastructure/$ORBIS_NAME/$REGNUM/_Organization/msp


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
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS_NAME/$REGNUM/$REGNUM_CA_NAME/msp
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
    AGER_PARENT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Administration.Parent" "$CONFIG_FILE")

    REGNUM_CA_NAME_FORMATTED="${AGER_CA_NAME//./-}"

    PARENT_ORG=$(yq eval ".Regnum[] | select(.Name == \"$AGER_PARENT\") | .Name" "$CONFIG_FILE")
    PARENT_NAME=$(yq eval ".Regnum[] | select(.Name == \"$AGER_PARENT\") | .CA.Name" "$CONFIG_FILE")
    PARENT_PASS=$(yq eval ".Regnum[] | select(.Name == \"$AGER_PARENT\") | .CA.Pass" "$CONFIG_FILE")
    PARENT_PORT=$(yq eval ".Regnum[] | select(.Name == \"$AGER_PARENT\") | .CA.Port" "$CONFIG_FILE")

    LOCAL_SRV_DIR=${PWD}/infrastructure/$ORBIS_NAME/$PARENT_ORG/$AGER/$AGER_CA_NAME/
    HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server

    mkdir -p $LOCAL_SRV_DIR


    # Register Ager-CA ID identity
    echo ""
    echo_info "Ager-CA ID $AGER_CA_NAME registering and enrolling..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$PARENT_NAME:$PARENT_PASS@$PARENT_NAME:$PARENT_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS_NAME/$PARENT_ORG/$PARENT_NAME/msp \
        --id.name $AGER_CA_NAME --id.secret $AGER_CA_PASS --id.type client --id.affiliation jedo.root \
        --id.attrs '"hf.Registrar.Roles=user,admin","hf.Revoker=true","hf.IntermediateCA=true"'
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$AGER_CA_NAME:$AGER_CA_PASS@$PARENT_NAME:$PARENT_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile ca \
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS_NAME/$PARENT_ORG/$AGER/$AGER_CA_NAME/msp \
        --csr.hosts ${PARENT_NAME},${PARENT_IP},*.jedo.dev


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
        --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS_NAME/$PARENT_ORG/$AGER/$AGER_CA_NAME/msp
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
echo_ok "CA started."



