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
    LOCAL_SRV_DIR=${PWD}/infrastructure/$ORBIS/$ORBIS_TLS_NAME/server

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
        --mspdir $HOST_INFRA_DIR/$ORBIS/$ORBIS_TLS_NAME/keys/tls \
   

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
        --mspdir $HOST_INFRA_DIR/$ORBIS/$ORBIS_TLS_NAME/keys/tls \
        --id.name $ORBIS_CA_NAME --id.secret $ORBIS_CA_PASS --id.type client --id.affiliation jedo.root
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$ORBIS_CA_NAME:$ORBIS_CA_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile tls \
        --mspdir $HOST_INFRA_DIR/$ORBIS/$ORBIS_CA_NAME/keys/tls \
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
        --mspdir $HOST_INFRA_DIR/$ORBIS/$ORBIS_TLS_NAME/keys/tls \
        --id.name $REGNUM_CA_NAME --id.secret $REGNUM_CA_PASS --id.type client --id.affiliation jedo.root
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$REGNUM_CA_NAME:$REGNUM_CA_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile tls \
        --mspdir $HOST_INFRA_DIR/$REGNUM/$REGNUM_CA_NAME/keys/tls \
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
        --mspdir $HOST_INFRA_DIR/$ORBIS/$ORBIS_TLS_NAME/keys/tls \
        --id.name $AGER_CA_NAME --id.secret $AGER_CA_PASS --id.type client --id.affiliation jedo.root
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$AGER_CA_NAME:$AGER_CA_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile tls \
        --mspdir $HOST_INFRA_DIR/$AGER/$AGER_CA_NAME/keys/tls \
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
    LOCAL_SRV_DIR=${PWD}/infrastructure/$ORBIS/$ORBIS_CA_NAME/server

    HOST_INFRA_DIR=/etc/infrastructure
    HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server

    mkdir -p $LOCAL_SRV_DIR


    # Write Root-CA SERVER config
    cat <<EOF > $LOCAL_SRV_DIR/fabric-ca-server-config.yaml
---
version: 0.0.1
port: $ORBIS_CA_PORT
debug: true
tls:
    enabled: true
    certfile: $HOST_INFRA_DIR/$ORBIS/$ORBIS_CA_NAME/keys/tls/signcerts/cert.pem
    keyfile: $HOST_INFRA_DIR/$ORBIS/$ORBIS_CA_NAME/keys/tls/keystore/$(basename $(ls $LOCAL_INFRA_DIR/$ORBIS/$ORBIS_CA_NAME/keys/tls/keystore/*_sk | head -n 1))
    clientauth:
      type: noclientcert
      certfiles:
ca:
    name: $ORBIS_CA_NAME
crl:
registry:
    maxenrollments: -1
    identities:
        - name: $ORBIS_CA_NAME
          pass: $ORBIS_CA_PASS
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
        ca:
            usage:
                - cert sign
                - crl sign
            expiry: 8760h
            caconstraint:
                isca: true
                maxpathlen: 2
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
    cn: $ORBIS_CA_NAME
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
        - $ORBIS_CA_NAME
        - $ORBIS_CA_IP
        - '*.jedo.dev'
    ca:
        expiry: 131400h
        pathlength: 2
idemix:
    curve: gurvy.Bn254
operations:
    listenAddress: $ORBIS_CA_IP:$ORBIS_CA_OPPORT
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


    # Start Orbis-CA Containter
    echo ""
    echo_info "Docker Container $ORBIS_CA_NAME starting..."
    docker run -d \
        --name $ORBIS_CA_NAME \
        --network $DOCKER_NETWORK_NAME \
        --ip $ORBIS_CA_IP \
        $hosts_args \
        --restart=on-failure:1 \
        --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/src/fabric_ca_logo.png" \
        -p $ORBIS_CA_PORT:$ORBIS_CA_PORT \
        -p $ORBIS_CA_OPPORT:$ORBIS_CA_OPPORT \
        -v $LOCAL_SRV_DIR:$HOST_SRV_DIR \
        -v $LOCAL_INFRA_DIR:$HOST_INFRA_DIR \
        hyperledger/fabric-ca:latest \
        sh -c "fabric-ca-server start -b $ORBIS_CA_NAME:$ORBIS_CA_PASS \
        --home $HOST_SRV_DIR"


    # Waiting Orbis-CA Host startup
    CheckContainer "$ORBIS_CA_NAME" "$DOCKER_CONTAINER_WAIT"
    CheckContainerLog "$ORBIS_CA_NAME" "Listening on https://0.0.0.0:$ORBIS_CA_PORT" "$DOCKER_CONTAINER_WAIT"


    # Enroll Orbis-CA ID certs
    echo ""
    echo_info "Orbis-ORG-CA enrolling..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$ORBIS_CA_NAME:$ORBIS_CA_PASS@$ORBIS_CA_NAME:$ORBIS_CA_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile ca \
        --mspdir $HOST_INFRA_DIR/$ORBIS/$ORBIS_CA_NAME/keys/msp
done    

###############################################################
# Realms-TLS-CA
###############################################################
#
#  DISCLAIMER: 
#  The Realm-TLS-CA can not yet be used to generate TLS-certs,
#  as these are not recognized as intermediate CA!
#
#
###############################################################
# REALMS=$(yq eval ".Realms[].Name" $CONFIG_FILE)
# for REALM in $REALMS; do
#     REALM_TLS_NAME=$(yq eval ".Realms[] | select(.Name == \"$REALM\") | .TLS-CA.Name" "$CONFIG_FILE")
#     REALM_TLS_PASS=$(yq eval ".Realms[] | select(.Name == \"$REALM\") | .TLS-CA.Pass" "$CONFIG_FILE")
#     REALM_TLS_IP=$(yq eval ".Realms[] | select(.Name == \"$REALM\") | .TLS-CA.IP" "$CONFIG_FILE")
#     REALM_TLS_PORT=$(yq eval ".Realms[] | select(.Name == \"$REALM\") | .TLS-CA.Port" "$CONFIG_FILE")
#     REALM_TLS_OPPORT=$(yq eval ".Realms[] | select(.Name == \"$REALM\") | .TLS-CA.OpPort" "$CONFIG_FILE")

#     LOCAL_INFRA_DIR=${PWD}/infrastructure
#     LOCAL_SRV_DIR=${PWD}/infrastructure/_root/$REALM_TLS_NAME/server

#     HOST_INFRA_DIR=/etc/infrastructure
#     HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server

#     mkdir -p $LOCAL_SRV_DIR


#     # Register Realm-TLS-CA identity
#     echo ""
#     echo_info "Realm-TLS-CA registering..."
#     docker exec -it $ROOT_TOOLS_NAME fabric-ca-client register -u https://$ROOT_CA_NAME:$ROOT_CA_PASS@$ROOT_CA_NAME:$ROOT_CA_PORT \
#         --home $ROOT_TOOLS_CACLI_DIR \
#         --tls.certfiles tls-root-cert/tls-ca-cert.pem \
#         --mspdir $HOST_INFRA_DIR/_root/$ROOT_CA_NAME/keys/msp \
#         --id.name $REALM_TLS_NAME --id.secret $REALM_TLS_PASS --id.type client --id.affiliation jedo.root \
#         --id.attrs '"hf.Registrar.Roles=client,admin","hf.Revoker=true","hf.IntermediateCA=true"'

#     # Enroll Realm-TLS-CA TLS certs
#     echo ""
#     echo_info "Realm-TLS-CA TLS enrolling..."
#     docker exec -it $ROOT_TOOLS_NAME fabric-ca-client enroll -u https://$REALM_TLS_NAME:$REALM_TLS_PASS@$ROOT_CA_NAME:$ROOT_CA_PORT \
#         --home $ROOT_TOOLS_CACLI_DIR \
#         --tls.certfiles tls-root-cert/tls-ca-cert.pem \
#         --enrollment.profile tls \
#         --mspdir $HOST_INFRA_DIR/_root/$REALM_TLS_NAME/keys/tls \
#         --csr.hosts ${ROOT_CA_NAME},${ROOT_CA_IP},${REALM_TLS_NAME},${REALM_TLS_IP},*.jedo.dev


#     # Enroll Realm-TLS-CA ID certs
#     echo ""
#     echo_info "Realm-TLS-CA ID enrolling..."
#     docker exec -it $ROOT_TOOLS_NAME fabric-ca-client enroll -u https://$REALM_TLS_NAME:$REALM_TLS_PASS@$ROOT_CA_NAME:$ROOT_CA_PORT \
#         --home $ROOT_TOOLS_CACLI_DIR \
#         --tls.certfiles tls-root-cert/tls-ca-cert.pem \
#         --enrollment.profile ca \
#         --mspdir $HOST_INFRA_DIR/_root/$REALM_TLS_NAME/keys/msp \
#         --csr.hosts ${ROOT_CA_NAME},${ROOT_CA_IP},${REALM_TLS_NAME},${REALM_TLS_IP},*jedo.dev \
#         --enrollment.attrs "hf.IntermediateCA"


#     # Write Realm-TLS-CA SERVER config
#     cat <<EOF > $LOCAL_SRV_DIR/fabric-ca-server-config.yaml
# ---
# version: 0.0.1
# port: $REALM_TLS_PORT
# debug: true
# tls:
#     enabled: true
#     certfile: $HOST_INFRA_DIR/_root/$REALM_TLS_NAME/keys/tls/signcerts/cert.pem
#     keyfile: $HOST_INFRA_DIR/_root/$REALM_TLS_NAME/keys/tls/keystore/$(basename $(ls $LOCAL_INFRA_DIR/_root/$REALM_TLS_NAME/keys/tls/keystore/*_sk | head -n 1))
#     clientauth:
#       type: noclientcert
#       certfiles:
# ca:
#     name: $REALM_TLS_NAME
#     certfile: $HOST_INFRA_DIR/_root/$REALM_TLS_NAME/keys/msp/signcerts/cert.pem
#     keyfile: $HOST_INFRA_DIR/_root/$REALM_TLS_NAME/keys/msp/keystore/$(basename $(ls $LOCAL_INFRA_DIR/_root/$REALM_TLS_NAME/keys/msp/keystore/*_sk | head -n 1))
# crl:
# affiliations:
#     jedo:
#         - root
#         - ea
#         - as
#         - af
#         - na
#         - sa
# signing:
#     default:
#         usage:
#             - digital signature
#         expiry: 8760h
#     profiles:
#         ca:
#             usage:
#                 - cert sign
#                 - crl sign
#             expiry: 8760h
#             caconstraint:
#                 isca: true
#                 maxpathlen: 0
#         tls:
#             usage:
#                 - cert sign
#                 - crl sign
#                 - signing
#                 - key encipherment
#                 - server auth
#                 - client auth
#                 - key agreement
#             expiry: 8760h
# csr:
#     cn:
#     keyrequest:
#         algo: ecdsa
#         size: 384
#     names:
#         - C: JD
#           ST: Dev
#           L:
#           O: JEDO
#           OU: Root
#     hosts:
#         - $ROOT_CA_NAME
#         - $ROOT_CA_IP
#         - $REALM_TLS_NAME
#         - $REALM_TLS_IP
#         - '*.jedo.dev'
#     ca:
#         expiry: 131400h
#         pathlength: 0
# intermediate:
#     parentserver:
#         url: https://$ROOT_CA_NAME:$ROOT_CA_PASS@$ROOT_CA_NAME:$ROOT_CA_PORT
#         caname: $ROOT_CA_NAME
#     enrollment:
#         hosts: 
#             - $ROOT_CA_NAME
#             - $ROOT_CA_IP
#             - $REALM_TLS_NAME
#             - $REALM_TLS_IP
#             - '*.jedo.dev'
#         profile: ca
#     tls:
#         certfiles: $HOST_INFRA_DIR/_root/tls.jedo.dev/ca.jedo.dev.tls-ca-cert.pem
# idemix:
#     curve: gurvy.Bn254
# operations:
#     listenAddress: $REALM_TLS_IP:$REALM_TLS_OPPORT
#     tls:
#         enabled: false
# #        cert:
# #            file:
# #        key:
# #            file:
# #        clientAuthRequired: false
# #        clientRootCAs:
# #            files: []
# EOF


#     # Start Realm-TLS-CA Containter
#     echo ""
#     echo_info "Docker Container $REALM_TLS_NAME starting..."
#     docker run -d \
#         --name $REALM_TLS_NAME \
#         --network $DOCKER_NETWORK_NAME \
#         --ip $REALM_TLS_IP \
#         $hosts_args \
#         --restart=on-failure:1 \
#         --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/src/fabric_ca_logo.png" \
#         -p $REALM_TLS_PORT:$REALM_TLS_PORT \
#         -p $REALM_TLS_OPPORT:$REALM_TLS_OPPORT \
#         -v $LOCAL_SRV_DIR:$HOST_SRV_DIR \
#         -v $LOCAL_INFRA_DIR:$HOST_INFRA_DIR \
#         hyperledger/fabric-ca:latest \
#         sh -c "fabric-ca-server start -b $REALM_TLS_NAME:$REALM_TLS_PASS \
#         --home $HOST_SRV_DIR"


#     # Waiting Root-CA Host startup
#     CheckContainer "$REALM_TLS_NAME" "$DOCKER_CONTAINER_WAIT"
#     CheckContainerLog "$REALM_TLS_NAME" "Listening on https://0.0.0.0:$REALM_TLS_PORT" "$DOCKER_CONTAINER_WAIT"

#     # copy ca-cert.pem to TLS key directory
#     cp $LOCAL_INFRA_DIR/_root/$REALM_TLS_NAME/keys/tls/signcerts/cert.pem $LOCAL_INFRA_DIR/_root/tls.jedo.dev/$REALM_TLS_NAME.tls-ca-cert.pem
# done


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
    # Params for regnum
    REGNUM_CA_NAME=$(yq eval ".Organizations[] | select(.Name == \"$REGNUM\") | .CA.Name" "$CONFIG_FILE")
    REGNUM_CA_PASS=$(yq eval ".Organizations[] | select(.Name == \"$REGNUM\") | .CA.Pass" "$CONFIG_FILE")
    REGNUM_CA_IP=$(yq eval ".Organizations[] | select(.Name == \"$REGNUM\") | .CA.IP" "$CONFIG_FILE")
    REGNUM_CA_PORT=$(yq eval ".Organizations[] | select(.Name == \"$REGNUM\") | .CA.Port" "$CONFIG_FILE")
    REGNUM_CA_OPPORT=$(yq eval ".Organizations[] | select(.Name == \"$REGNUM\") | .CA.OpPort" "$CONFIG_FILE")

    LOCAL_INFRA_DIR=${PWD}/infrastructure
    LOCAL_SRV_DIR=${PWD}/infrastructure/$REGNUM/$REGNUM_CA_NAME/server

    HOST_INFRA_DIR=/etc/infrastructure
    HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server

    mkdir -p $LOCAL_SRV_DIR


    # Register Regnum-CA ID identity, enrollment later
    echo ""
    echo_info "Regnum-CA ID $REGNUM_CA_NAME registering..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$ORBIS_CA_NAME:$ORBIS_CA_PASS@$ORBIS_CA_NAME:$ORBIS_CA_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $HOST_INFRA_DIR/$ORBIS/$ORBIS_CA_NAME/keys/msp \
        --id.name $REGNUM_CA_NAME --id.secret $REGNUM_CA_PASS --id.type client --id.affiliation jedo.root \
        --id.attrs '"hf.Registrar.Roles=user,admin","hf.Revoker=true","hf.IntermediateCA=true"'


    # Write Regnum-CA SERVER config
    cat <<EOF > $LOCAL_SRV_DIR/fabric-ca-server-config.yaml
---
version: 0.0.1
port: $REGNUM_CA_PORT
debug: true
tls:
    enabled: true
    certfile: $HOST_INFRA_DIR/$REGNUM/$REGNUM_CA_NAME/keys/tls/signcerts/cert.pem
    keyfile: $HOST_INFRA_DIR/$REGNUM/$REGNUM_CA_NAME/keys/tls/keystore/$(basename $(ls $LOCAL_INFRA_DIR/$REGNUM/$REGNUM_CA_NAME/keys/tls/keystore/*_sk | head -n 1))
    clientauth:
      type: noclientcert
      certfiles:
ca:
    name: $REGNUM_CA_NAME
#    certfile: $HOST_INFRA_DIR/$REGNUM/$REGNUM_CA_NAME/keys/msp/signcerts/cert.pem
#    keyfile: $HOST_INFRA_DIR/$REGNUM/$REGNUM_CA_NAME/keys/msp/keystore/$(basename $(ls $LOCAL_INFRA_DIR/$REGNUM/$REGNUM_CA_NAME/keys/msp/keystore/*_sk | head -n 1))
#    chainfile: $HOST_INFRA_DIR/$REGNUM/$REGNUM_CA_NAME/keys/msp/intermediatecerts/ca-chain.pem
crl:
registry:
    maxenrollments: -1
    identities:
        - name: $REGNUM_CA_NAME
          pass: $REGNUM_CA_PASS
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
        ca:
            usage:
                - cert sign
                - crl sign
            expiry: 8760h
            caconstraint:
                isca: true
                maxpathlen: 1
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
    cn:
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
        - $REGNUM_CA_NAME
        - $REGNUM_CA_IP
    ca:
        expiry: 131400h
        pathlength: 1
intermediate:
    parentserver:
        url: https://$ORBIS_CA_NAME:$ORBIS_CA_PASS@$ORBIS_CA_NAME:$ORBIS_CA_PORT
        caname: $ORBIS_CA_NAME
    enrollment:
        hosts: 
            - $ORBIS_CA_NAME
            - $ORBIS_CA_IP
            - '*.jedo.dev'
        profile: ca
    tls:
        certfiles: $HOST_INFRA_DIR/$ORBIS/tls.jedo.dev/tls-ca-cert.pem
idemix:
    curve: gurvy.Bn254
operations:
    listenAddress: $REGNUM_CA_IP:$REGNUM_CA_OPPORT
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


    # Start Regnum-CA Containter
    echo ""
    echo_info "Docker Container $REGNUM_CA_NAME starting..."
    docker run -d \
        --name $REGNUM_CA_NAME \
        --network $DOCKER_NETWORK_NAME \
        --ip $REGNUM_CA_IP \
        $hosts_args \
        --restart=on-failure:1 \
        --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/src/fabric_ca_logo.png" \
        -p $REGNUM_CA_PORT:$REGNUM_CA_PORT \
        -p $REGNUM_CA_OPPORT:$REGNUM_CA_OPPORT \
        -v $LOCAL_SRV_DIR:$HOST_SRV_DIR \
        -v $LOCAL_INFRA_DIR:$HOST_INFRA_DIR \
        hyperledger/fabric-ca:latest \
        sh -c "fabric-ca-server start -b $REGNUM_CA_NAME:$REGNUM_CA_PASS \
        --home $HOST_SRV_DIR"


    # Waiting Regnum-CA Host startup
    CheckContainer "$REGNUM_CA_NAME" "$DOCKER_CONTAINER_WAIT"
    CheckContainerLog "$REGNUM_CA_NAME" "Listening on https://0.0.0.0:$REGNUM_CA_PORT" "$DOCKER_CONTAINER_WAIT"


    # copy ca-chain.pem to MSP-key directory
    mkdir -p $LOCAL_INFRA_DIR/$REGNUM/$REGNUM_CA_NAME/keys/msp/intermediatecerts
    cp $LOCAL_SRV_DIR/ca-chain.pem $LOCAL_INFRA_DIR/$REGNUM/$REGNUM_CA_NAME/keys/msp/intermediatecerts/ca-chain.pem


    # Enroll Regnum-ORG-CA certs
    echo ""
    echo_info "Regnum-CA ORG enrolling..."
    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$REGNUM_CA_NAME:$REGNUM_CA_PASS@$ORBIS_CA_NAME:$ORBIS_CA_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile ca \
        --mspdir $HOST_INFRA_DIR/$REGNUM/$REGNUM_CA_NAME/keys/msp \
        --csr.hosts ${REGNUM_CA_NAME},${REGNUM_CA_IP},${ORBIS_CA_NAME},${ORBIS_CA_IP},${ORBIS_TLS_NAME},${ORBIS_TLS_IP},*.jedo.dev



chmod -R 777 infrastructure
echo_error "TEST"
echo_info "RUN:    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$REGNUM_CA_NAME:$REGNUM_CA_PASS@$REGNUM_CA_NAME:$REGNUM_CA_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $HOST_INFRA_DIR/$REGNUM/$REGNUM_CA_NAME/keys/msp \
        --id.name irgendwer --id.secret Test1 --id.type client --id.affiliation jedo.root"

    docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client register -u https://$REGNUM_CA_NAME:$REGNUM_CA_PASS@$REGNUM_CA_NAME:$REGNUM_CA_PORT \
        --home $ORBIS_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $HOST_INFRA_DIR/$REGNUM/$REGNUM_CA_NAME/keys/msp \
        --id.name irgendwer --id.secret Test1 --id.type client --id.affiliation jedo.root
chmod -R 777 infrastructure
temp_end


done


###############################################################
# Organizations-ORG-CA
###############################################################
ORGS=$(yq eval ".Organizations[].Name" $CONFIG_FILE)
for ORG in $ORGS; do
    ORG_ORG_NAME=$(yq eval ".Organizations[] | select(.Name == \"$ORG\") | .ORG-CA.Name" "$CONFIG_FILE")
    ORG_ORG_PASS=$(yq eval ".Organizations[] | select(.Name == \"$ORG\") | .ORG-CA.Pass" "$CONFIG_FILE")
    ORG_ORG_IP=$(yq eval ".Organizations[] | select(.Name == \"$ORG\") | .ORG-CA.IP" "$CONFIG_FILE")
    ORG_ORG_PORT=$(yq eval ".Organizations[] | select(.Name == \"$ORG\") | .ORG-CA.Port" "$CONFIG_FILE")
    ORG_ORG_OPPORT=$(yq eval ".Organizations[] | select(.Name == \"$ORG\") | .ORG-CA.OpPort" "$CONFIG_FILE")
    ORG_ORG_PARENT=$(yq eval ".Organizations[] | select(.Name == \"$ORG\") | .ORG-CA.Parent" "$CONFIG_FILE")

    PARENT_ORG_NAME=$(yq eval ".Realms[] | select(.Name == \"$ORG_ORG_PARENT\") | .ORG-CA.Name" "$CONFIG_FILE")
    PARENT_ORG_PASS=$(yq eval ".Realms[] | select(.Name == \"$ORG_ORG_PARENT\") | .ORG-CA.Pass" "$CONFIG_FILE")
    PARENT_ORG_PORT=$(yq eval ".Realms[] | select(.Name == \"$ORG_ORG_PARENT\") | .ORG-CA.Port" "$CONFIG_FILE")

    LOCAL_INFRA_DIR=${PWD}/infrastructure
    LOCAL_SRV_DIR=${PWD}/infrastructure/_root/$ORG_ORG_NAME/server

    HOST_INFRA_DIR=/etc/infrastructure
    HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server

    mkdir -p $LOCAL_SRV_DIR


    # Register Organization-ORG-CA ID identity, enrollment later
    echo ""
    echo_info "Organization-ORG-CA ID $ORG_ORG_NAME registering..."
echo_error "Run:     docker exec -it $ROOT_TOOLS_NAME fabric-ca-client register -u https://$PARENT_ORG_NAME:$PARENT_ORG_PASS@$PARENT_ORG_NAME:$PARENT_ORG_PORT \
        --home $ROOT_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $HOST_INFRA_DIR/_root/$PARENT_ORG_NAME/keys/msp \
        --id.name $ORG_ORG_NAME --id.secret $ORG_ORG_PASS --id.type client --id.affiliation jedo.root \
        --id.attrs '"hf.Registrar.Roles=user,admin","hf.Revoker=true","hf.IntermediateCA=true"'"

    docker exec -it $ROOT_TOOLS_NAME fabric-ca-client register -u https://$PARENT_ORG_NAME:$PARENT_ORG_PASS@$PARENT_ORG_NAME:$PARENT_ORG_PORT \
        --home $ROOT_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $HOST_INFRA_DIR/_root/$PARENT_ORG_NAME/keys/msp \
        --id.name $ORG_ORG_NAME --id.secret $ORG_ORG_PASS --id.type client --id.affiliation jedo.root \
        --id.attrs '"hf.Registrar.Roles=user,admin","hf.Revoker=true","hf.IntermediateCA=true"'


    # Write Organization-ORG-CA SERVER config
    cat <<EOF > $LOCAL_SRV_DIR/fabric-ca-server-config.yaml
---
version: 0.0.1
port: $ORG_ORG_PORT
debug: true
tls:
    enabled: true
    certfile: $HOST_INFRA_DIR/_root/$ORG_ORG_NAME/keys/tls/signcerts/cert.pem
    keyfile: $HOST_INFRA_DIR/_root/$ORG_ORG_NAME/keys/tls/keystore/$(basename $(ls $LOCAL_INFRA_DIR/_root/$ORG_ORG_NAME/keys/tls/keystore/*_sk | head -n 1))
    clientauth:
      type: noclientcert
      certfiles:
ca:
    name: $ORG_ORG_NAME
crl:
registry:
    maxenrollments: -1
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
        ca:
            usage:
                - cert sign
                - crl sign
            expiry: 8760h
            caconstraint:
                isca: true
                maxpathlen: 0
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
    cn:
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
        - $ORG_ORG_NAME
        - $ORG_ORG_IP
    ca:
        expiry: 131400h
        pathlength: 0
intermediate:
    parentserver:
        url: https://$PARENT_ORG_NAME:$PARENT_ORG_PASS@$PARENT_ORG_NAME:$PARENT_ORG_PORT
        caname: $ORG_CA_NAME
    enrollment:
        hosts: 
            - $ORG_CA_NAME
            - $ORG_CA_IP
            - '*.jedo.dev'
        profile: ca
    tls:
        certfiles: $HOST_INFRA_DIR/_root/tls.jedo.dev/tls-ca-cert.pem
idemix:
    curve: gurvy.Bn254
operations:
    listenAddress: $ORG_ORG_IP:$ORG_ORG_OPPORT
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


    # Start Organization-ORG-CA Containter
    echo ""
    echo_info "Docker Container $ORG_ORG_NAME starting..."
    docker run -d \
        --name $ORG_ORG_NAME \
        --network $DOCKER_NETWORK_NAME \
        --ip $ORG_ORG_IP \
        $hosts_args \
        --restart=on-failure:1 \
        --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/src/fabric_ca_logo.png" \
        -p $ORG_ORG_PORT:$ORG_ORG_PORT \
        -p $ORG_ORG_OPPORT:$ORG_ORG_OPPORT \
        -v $LOCAL_SRV_DIR:$HOST_SRV_DIR \
        -v $LOCAL_INFRA_DIR:$HOST_INFRA_DIR \
        hyperledger/fabric-ca:latest \
        sh -c "fabric-ca-server start -b $ORG_ORG_NAME:$ORG_ORG_PASS \
        --home $HOST_SRV_DIR"


    # Waiting Organization-ORG-CA Host startup
    CheckContainer "$ORG_ORG_NAME" "$DOCKER_CONTAINER_WAIT"
    CheckContainerLog "$ORG_ORG_NAME" "Listening on https://0.0.0.0:$ORG_ORG_PORT" "$DOCKER_CONTAINER_WAIT"


    # Enroll Organization-ORG-CA certs
    echo ""
    echo_info "Organization-CA ORG enrolling..."
    docker exec -it $ROOT_TOOLS_NAME fabric-ca-client enroll -u https://$ORG_ORG_NAME:$ORG_ORG_PASS@$PARENT_ORG_NAME:$PARENT_ORG_PORT \
        --home $ROOT_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile ca \
        --mspdir $HOST_INFRA_DIR/_root/$ORG_ORG_NAME/keys/msp \
        --csr.hosts ${ORG_ORG_NAME},${ORG_ORG_IP},${PARENT_ORG_NAME},${PARENT_ORG_IP},${ROOT_CA_NAME},${ROOT_CA_IP},${ROOT_TLS_NAME},${ROOT_TLS_IP},*.jedo.dev

done


###############################################################
# Last Tasks
###############################################################
chmod -R 777 infrastructure
echo_ok "Root-CA started."


docker exec -it tools.jedo.dev fabric-ca-client getcainfo -u https://ca.ea.jedo.dev:50121 \
    --home /etc/hyperledger/fabric-ca-client \
    --tls.certfiles tls-root-cert/tls-ca-cert.pem \
    --mspdir /etc/infrastructure/_root/ca.ea.jedo.dev/keys/msp



