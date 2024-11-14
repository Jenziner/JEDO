###############################################################
#!/bin/bash
#
# This script starts Root-CA and generates certificates for Intermediate-CA
# 
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/ca_utils.sh"
check_script

# TEMP - needs to be changed, if certs are available in git, copy then from git when needed
cp -r ./RootCA/* ./infrastructure/


###############################################################
# Params
###############################################################
CONFIG_FILE="$SCRIPT_DIR/infrastructure-dev.yaml"
DOCKER_UNRAID=$(yq eval '.Docker.Unraid' $CONFIG_FILE)
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $CONFIG_FILE)

get_hosts

echo ""
echo_warn "Orbis-CA starting... (Defaults: https://hyperledger-fabric-ca.readthedocs.io/en/latest/serverconfig.html)"


###############################################################
# Orbis-TLS-CA
###############################################################
ORBISS=$(yq eval '.Organizations[] | select(.Administration.Position == "orbis") | .Name' "$CONFIG_FILE")
ORBIS_COUNT=$(echo "$ORBISS" | wc -l)

# only 1 orbis is allowed
if [ "$ORBIS_COUNT" -ne 1 ]; then
    echo_error "Illegal number of orbis-organizations ($ORBIS_COUNT)."
    exit 1
fi


for ORBIS in $ORBISS; do
    # Params for orbis
    ORBIS_TOOLS_NAME=$(yq eval ".Organizations[] | select(.Name == \"$ORBIS\") | .Tools.Name" "$CONFIG_FILE")
    ORBIS_TOOLS_CACLI_DIR=/etc/hyperledger/fabric-ca-client

    ORBIS_TLS_NAME=$(yq eval ".Organizations[] | select(.Name == \"$ORBIS\") | .TLS.Name" "$CONFIG_FILE")
    ORBIS_TLS_PASS=$(yq eval ".Organizations[] | select(.Name == \"$ORBIS\") | .TLS.Pass" "$CONFIG_FILE")
    ORBIS_TLS_IP=$(yq eval ".Organizations[] | select(.Name == \"$ORBIS\") | .TLS.IP" "$CONFIG_FILE")
    ORBIS_TLS_PORT=$(yq eval ".Organizations[] | select(.Name == \"$ORBIS\") | .TLS.Port" "$CONFIG_FILE")
    ORBIS_TLS_OPPORT=$(yq eval ".Organizations[] | select(.Name == \"$ORBIS\") | .TLS.OpPort" "$CONFIG_FILE")
    
    LOCAL_INFRA_DIR=${PWD}/infrastructure
    LOCAL_SRV_DIR=${PWD}/infrastructure/$ORBIS/$ORBIS_TLS_NAME

    HOST_INFRA_DIR=/etc/infrastructure
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
        -v $LOCAL_INFRA_DIR:$HOST_INFRA_DIR \
        hyperledger/fabric-ca:latest \
        sh -c "fabric-ca-server start -b $ORBIS_TLS_NAME:$ORBIS_TLS_PASS \
        --home $HOST_SRV_DIR"


    # Waiting Orbis-TLS-CA Host startup
    CheckContainer "$ORBIS_TLS_NAME" "$DOCKER_CONTAINER_WAIT"
    CheckContainerLog "$ORBIS_TLS_NAME" "Listening on https://0.0.0.0:$ORBIS_TLS_PORT" "$DOCKER_CONTAINER_WAIT"


    # copy ca-cert.pem to TLS-key directory
    cp $LOCAL_SRV_DIR/ca-cert.pem $LOCAL_INFRA_DIR/$ORBIS/$ORBIS_TLS_NAME/tls-ca-cert.pem


    # Enroll Orbis-TLS-CA TLS certs
    echo ""
    echo_info "Orbis-TLS-CA enrolling..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$ORBIS_TLS_NAME:$ORBIS_TLS_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile tls \
        --mspdir $HOST_INFRA_DIR/$ORBIS/$ORBIS_TLS_NAME/tls \
   

    ###############################################################
    # Register and entroll Orbis-CA TLS certs
    ###############################################################
    ORBIS_CA_NAME=$(yq eval ".Organizations[] | select(.Name == \"$ORBIS\") | .CA.Name" "$CONFIG_FILE")
    ORBIS_CA_PASS=$(yq eval ".Organizations[] | select(.Name == \"$ORBIS\") | .CA.Pass" "$CONFIG_FILE")
    ORBIS_CA_IP=$(yq eval ".Organizations[] | select(.Name == \"$ORBIS\") | .CA.IP" "$CONFIG_FILE")

    # Register Orbis-CA identity
    echo ""
    echo_info "Orbis-CA $ORBIS_CA_NAME registering and enrolling..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$ORBIS_TLS_NAME:$ORBIS_TLS_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $HOST_INFRA_DIR/$ORBIS/$ORBIS_TLS_NAME/tls \
        --id.name $ORBIS_CA_NAME --id.secret $ORBIS_CA_PASS --id.type client --id.affiliation jedo.root
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$ORBIS_CA_NAME:$ORBIS_CA_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile tls \
        --mspdir $HOST_INFRA_DIR/$ORBIS/$ORBIS_CA_NAME/tls \
        --csr.hosts ${ORBIS_CA_NAME},${ORBIS_CA_IP},${ORBIS_TLS_NAME},${ORBIS_TLS_IP},*.jedo.dev
done


###############################################################
# Register and entroll Regnums-CA TLS certs
###############################################################
REGNUMS=$(yq eval '.Organizations[] | select(.Administration.Position == "regnum") | .Name' "$CONFIG_FILE")
REGNUM_COUNT=$(echo "$REGNUMS" | wc -l)

# exit when no regnum is defined
if [ "$REGNUM_COUNT" -eq 0 ]; then
    echo_error "No regnum defined."
    exit 1
fi


for REGNUM in $REGNUMS; do
    # Params for regnum
    REGNUM_CA_NAME=$(yq eval ".Organizations[] | select(.Name == \"$REGNUM\") | .CA.Name" "$CONFIG_FILE")
    REGNUM_CA_PASS=$(yq eval ".Organizations[] | select(.Name == \"$REGNUM\") | .CA.Pass" "$CONFIG_FILE")
    REGNUM_CA_IP=$(yq eval ".Organizations[] | select(.Name == \"$REGNUM\") | .CA.IP" "$CONFIG_FILE")

    # Register Regnum-CA identity
    echo ""
    echo_info "Regnum-CA $REGNUM_CA_NAME registering and enrolling..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$ORBIS_TLS_NAME:$ORBIS_TLS_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $HOST_INFRA_DIR/$ORBIS/$ORBIS_TLS_NAME/tls \
        --id.name $REGNUM_CA_NAME --id.secret $REGNUM_CA_PASS --id.type client --id.affiliation jedo.root
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$REGNUM_CA_NAME:$REGNUM_CA_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile tls \
        --mspdir $HOST_INFRA_DIR/$REGNUM/$REGNUM_CA_NAME/tls \
        --csr.hosts ${REGNUM_CA_NAME},${REGNUM_CA_IP},${ORBIS_CA_NAME},${ORBIS_CA_IP},${ORBIS_TLS_NAME},${ORBIS_TLS_IP},*.jedo.dev
done


###############################################################
# Register and entroll Ager-CA TLS certs
###############################################################
AGERS=$(yq eval '.Organizations[] | select(.Administration.Position == "ager") | .Name' "$CONFIG_FILE")
AGER_COUNT=$(echo "$AGERS" | wc -l)

# exit when no regnum is defined
if [ "$AGER_COUNT" -eq 0 ]; then
    echo_error "No regnum defined."
    exit 1
fi


for AGER in $AGERS; do
    # Params for ager
    AGER_CA_NAME=$(yq eval ".Organizations[] | select(.Name == \"$AGER\") | .CA.Name" "$CONFIG_FILE")
    AGER_CA_PASS=$(yq eval ".Organizations[] | select(.Name == \"$AGER\") | .CA.Pass" "$CONFIG_FILE")
    AGER_CA_IP=$(yq eval ".Organizations[] | select(.Name == \"$AGER\") | .CA.IP" "$CONFIG_FILE")

    # Register Ager-CA identity
    echo ""
    echo_info "Organization-CA $AGER_CA_NAME registering and enrolling..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$ORBIS_TLS_NAME:$ORBIS_TLS_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $HOST_INFRA_DIR/$ORBIS/$ORBIS_TLS_NAME/tls \
        --id.name $AGER_CA_NAME --id.secret $AGER_CA_PASS --id.type client --id.affiliation jedo.root
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$AGER_CA_NAME:$AGER_CA_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile tls \
        --mspdir $HOST_INFRA_DIR/$AGER/$AGER_CA_NAME/tls \
        --csr.hosts ${AGER_CA_NAME},${AGER_CA_IP},${ORBIS_CA_NAME},${ORBIS_CA_IP},${ORBIS_TLS_NAME},${ORBIS_TLS_IP},*.jedo.dev
done


###############################################################
# ORBIS-CA
###############################################################
ORBISS=$(yq eval '.Organizations[] | select(.Administration.Position == "orbis") | .Name' "$CONFIG_FILE")
ORBIS_COUNT=$(echo "$ORBISS" | wc -l)

# only 1 orbis is allowed
if [ "$ORBIS_COUNT" -ne 1 ]; then
    echo_error "Illegal number of orbis-organizations ($ORBIS_COUNT)."
    exit 1
fi


for ORBIS in $ORBISS; do
    # Params for orbis
    ORBIS_CA_NAME=$(yq eval ".Organizations[] | select(.Name == \"$ORBIS\") | .CA.Name" "$CONFIG_FILE")
    ORBIS_CA_PASS=$(yq eval ".Organizations[] | select(.Name == \"$ORBIS\") | .CA.Pass" "$CONFIG_FILE")
    ORBIS_CA_IP=$(yq eval ".Organizations[] | select(.Name == \"$ORBIS\") | .CA.IP" "$CONFIG_FILE")
    ORBIS_CA_PORT=$(yq eval ".Organizations[] | select(.Name == \"$ORBIS\") | .CA.Port" "$CONFIG_FILE")
    ORBIS_CA_OPPORT=$(yq eval ".Organizations[] | select(.Name == \"$ORBIS\") | .CA.OpPort" "$CONFIG_FILE")
    
    LOCAL_INFRA_DIR=${PWD}/infrastructure
    LOCAL_SRV_DIR=${PWD}/infrastructure/$ORBIS/$ORBIS_CA_NAME

    HOST_INFRA_DIR=/etc/infrastructure
    HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server

    mkdir -p $LOCAL_SRV_DIR


    # Start Orbis-CA
    ca_writeCfg "$ORBIS_CA_NAME" "$CONFIG_FILE"
    ca_start "$ORBIS_CA_NAME" "$CONFIG_FILE"


    # Enroll Orbis-CA ID certs
    echo ""
    echo_info "Orbis-ORG-CA enrolling..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$ORBIS_CA_NAME:$ORBIS_CA_PASS@$ORBIS_CA_NAME:$ORBIS_CA_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile ca \
        --mspdir $HOST_INFRA_DIR/$ORBIS/$ORBIS_CA_NAME/msp
done    


###############################################################
# Regnums-CA
###############################################################
REGNUMS=$(yq eval '.Organizations[] | select(.Administration.Position == "regnum") | .Name' "$CONFIG_FILE")
REGNUM_COUNT=$(echo "$REGNUMS" | wc -l)

# exit when no regnum is defined
if [ "$REGNUM_COUNT" -eq 0 ]; then
    echo_error "No regnum defined."
    exit 1
fi


for REGNUM in $REGNUMS; do
    # Params for regnum
    REGNUM_CA_NAME=$(yq eval ".Organizations[] | select(.Name == \"$REGNUM\") | .CA.Name" "$CONFIG_FILE")
    REGNUM_CA_PASS=$(yq eval ".Organizations[] | select(.Name == \"$REGNUM\") | .CA.Pass" "$CONFIG_FILE")
    REGNUM_CA_IP=$(yq eval ".Organizations[] | select(.Name == \"$REGNUM\") | .CA.IP" "$CONFIG_FILE")
    REGNUM_CA_PORT=$(yq eval ".Organizations[] | select(.Name == \"$REGNUM\") | .CA.Port" "$CONFIG_FILE")
    REGNUM_CA_OPPORT=$(yq eval ".Organizations[] | select(.Name == \"$REGNUM\") | .CA.OpPort" "$CONFIG_FILE")
    REGNUM_CA_PARENT=$(yq eval ".Organizations[] | select(.Name == \"$REGNUM\") | .CA.Parent" "$CONFIG_FILE")

    REGNUM_CA_NAME_FORMATTED="${REGNUM_CA_NAME//./-}"

    PARENT_ORG=$(yq eval ".Organizations[] | select(.CA.Name == \"$REGNUM_CA_PARENT\") | .Name" "$CONFIG_FILE")
    PARENT_NAME=$(yq eval ".Organizations[] | select(.CA.Name == \"$REGNUM_CA_PARENT\") | .CA.Name" "$CONFIG_FILE")
    PARENT_PASS=$(yq eval ".Organizations[] | select(.CA.Name == \"$REGNUM_CA_PARENT\") | .CA.Pass" "$CONFIG_FILE")
    PARENT_PORT=$(yq eval ".Organizations[] | select(.CA.Name == \"$REGNUM_CA_PARENT\") | .CA.Port" "$CONFIG_FILE")

    LOCAL_INFRA_DIR=${PWD}/infrastructure
    LOCAL_SRV_DIR=${PWD}/infrastructure/$REGNUM/$REGNUM_CA_NAME/

    HOST_INFRA_DIR=/etc/infrastructure
    HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server

    mkdir -p $LOCAL_SRV_DIR


    # Register Regnum-CA ID identity
    echo ""
    echo_info "Regnum-CA ID $REGNUM_CA_NAME registering and enrolling..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$PARENT_NAME:$PARENT_PASS@$PARENT_NAME:$PARENT_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $HOST_INFRA_DIR/$PARENT_ORG/$PARENT_NAME/msp \
        --id.name $REGNUM_CA_NAME --id.secret $REGNUM_CA_PASS --id.type client --id.affiliation jedo.root \
        --id.attrs '"hf.Registrar.Roles=user,admin","hf.Revoker=true","hf.IntermediateCA=true"'
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$REGNUM_CA_NAME:$REGNUM_CA_PASS@$PARENT_NAME:$PARENT_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile ca \
        --mspdir $HOST_INFRA_DIR/$REGNUM/$REGNUM_CA_NAME/msp \
        --csr.hosts ${PARENT_NAME},${PARENT_IP},*.jedo.dev


    # Start Regnum-CA
    ca_writeCfg "$REGNUM_CA_NAME" "$CONFIG_FILE"
    ca_start "$REGNUM_CA_NAME" "$CONFIG_FILE"


    # Enroll Regnum-CA ID certs
    echo ""
    echo_info "Regnum-CA enrolling..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$REGNUM_CA_NAME:$REGNUM_CA_PASS@$REGNUM_CA_NAME:$REGNUM_CA_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile ca \
        --mspdir $HOST_INFRA_DIR/$REGNUM/$REGNUM_CA_NAME/msp
done


###############################################################
# Ager-CA
###############################################################
AGERS=$(yq eval '.Organizations[] | select(.Administration.Position == "ager") | .Name' "$CONFIG_FILE")
for AGER in $AGERS; do
    # Params for ager
    AGER_CA_NAME=$(yq eval ".Organizations[] | select(.Name == \"$AGER\") | .CA.Name" "$CONFIG_FILE")
    AGER_CA_PASS=$(yq eval ".Organizations[] | select(.Name == \"$AGER\") | .CA.Pass" "$CONFIG_FILE")
    AGER_CA_IP=$(yq eval ".Organizations[] | select(.Name == \"$AGER\") | .CA.IP" "$CONFIG_FILE")
    AGER_CA_PORT=$(yq eval ".Organizations[] | select(.Name == \"$AGER\") | .CA.Port" "$CONFIG_FILE")
    AGER_CA_OPPORT=$(yq eval ".Organizations[] | select(.Name == \"$AGER\") | .CA.OpPort" "$CONFIG_FILE")
    AGER_CA_PARENT=$(yq eval ".Organizations[] | select(.Name == \"$AGER\") | .CA.Parent" "$CONFIG_FILE")

    REGNUM_CA_NAME_FORMATTED="${AGER_CA_NAME//./-}"

    PARENT_ORG=$(yq eval ".Organizations[] | select(.CA.Name == \"$AGER_CA_PARENT\") | .Name" "$CONFIG_FILE")
    PARENT_NAME=$(yq eval ".Organizations[] | select(.CA.Name == \"$AGER_CA_PARENT\") | .CA.Name" "$CONFIG_FILE")
    PARENT_PASS=$(yq eval ".Organizations[] | select(.CA.Name == \"$AGER_CA_PARENT\") | .CA.Pass" "$CONFIG_FILE")
    PARENT_PORT=$(yq eval ".Organizations[] | select(.CA.Name == \"$AGER_CA_PARENT\") | .CA.Port" "$CONFIG_FILE")

    LOCAL_INFRA_DIR=${PWD}/infrastructure
    LOCAL_SRV_DIR=${PWD}/infrastructure/$AGER/$AGER_CA_NAME/

    HOST_INFRA_DIR=/etc/infrastructure
    HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server

    mkdir -p $LOCAL_SRV_DIR


    # Register Ager-CA ID identity
    echo ""
    echo_info "Ager-CA ID $AGER_CA_NAME registering and enrolling..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$PARENT_NAME:$PARENT_PASS@$PARENT_NAME:$PARENT_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $HOST_INFRA_DIR/$PARENT_ORG/$PARENT_NAME/msp \
        --id.name $AGER_CA_NAME --id.secret $AGER_CA_PASS --id.type client --id.affiliation jedo.root \
        --id.attrs '"hf.Registrar.Roles=user,admin","hf.Revoker=true","hf.IntermediateCA=true"'
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$AGER_CA_NAME:$AGER_CA_PASS@$PARENT_NAME:$PARENT_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile ca \
        --mspdir $HOST_INFRA_DIR/$AGER/$AGER_CA_NAME/msp \
        --csr.hosts ${PARENT_NAME},${PARENT_IP},*.jedo.dev


    # Start Ager-CA
    ca_writeCfg "$AGER_CA_NAME" "$CONFIG_FILE"
    ca_start "$AGER_CA_NAME" "$CONFIG_FILE"


    # Enroll Ager-CA ID certs
    echo ""
    echo_info "Ager-CA enrolling..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$AGER_CA_NAME:$AGER_CA_PASS@$AGER_CA_NAME:$AGER_CA_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile ca \
        --mspdir $HOST_INFRA_DIR/$AGER/$AGER_CA_NAME/msp
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



