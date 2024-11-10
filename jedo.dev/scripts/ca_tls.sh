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

ROOT_TOOLS_NAME=$(yq eval '.Root.Tools.Name' $CONFIG_FILE)
ROOT_TOOLS_CACLI_DIR=/etc/hyperledger/fabric-ca-client

get_hosts

echo ""
echo_warn "Root-CA starting... (Defaults: https://hyperledger-fabric-ca.readthedocs.io/en/latest/serverconfig.html)"


###############################################################
# Root-TLS-CA
###############################################################
ROOT_TLS_NAME=$(yq eval ".Root.TLS.Name" "$CONFIG_FILE")
ROOT_TLS_PASS=$(yq eval ".Root.TLS.Pass" "$CONFIG_FILE")
ROOT_TLS_IP=$(yq eval ".Root.TLS.IP" "$CONFIG_FILE")
ROOT_TLS_PORT=$(yq eval ".Root.TLS.Port" "$CONFIG_FILE")
ROOT_TLS_OPPORT=$(yq eval ".Root.TLS.OpPort" "$CONFIG_FILE")
    
LOCAL_INFRA_DIR=${PWD}/infrastructure
LOCAL_SRV_DIR=${PWD}/infrastructure/_root/$ROOT_TLS_NAME/server

HOST_INFRA_DIR=/etc/infrastructure
HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server

mkdir -p $LOCAL_SRV_DIR


# Write Root-TLS-CA SERVER config
cat <<EOF > $LOCAL_SRV_DIR/fabric-ca-server-config.yaml
---
version: 0.0.1
port: $ROOT_TLS_PORT
debug: true
tls:
    enabled: true
    clientauth:
      type: noclientcert
      certfiles:
ca:
    name: $ROOT_TLS_NAME
crl:
registry:
    maxenrollments: -1
    identities:
        - name: $ROOT_TLS_NAME
          pass: $ROOT_TLS_PASS
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
    cn: $ROOT_TLS_NAME
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
        - $ROOT_TLS_NAME
        - $ROOT_TLS_IP
    ca:
        expiry: 131400h
        pathlength: 1
idemix:
    curve: gurvy.Bn254
operations:
    listenAddress: $ROOT_TLS_IP:$ROOT_TLS_OPPORT
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


# Start Root-TLS-CA Containter
echo ""
echo_info "Docker Container $ROOT_TLS_NAME starting..."
docker run -d \
    --name $ROOT_TLS_NAME \
    --network $DOCKER_NETWORK_NAME \
    --ip $ROOT_TLS_IP \
    $hosts_args \
    --restart=on-failure:1 \
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/src/fabric_ca_logo.png" \
    -p $ROOT_TLS_PORT:$ROOT_TLS_PORT \
    -p $ROOT_TLS_OPPORT:$ROOT_TLS_OPPORT \
    -v $LOCAL_SRV_DIR:$HOST_SRV_DIR \
    -v $LOCAL_INFRA_DIR:$HOST_INFRA_DIR \
    hyperledger/fabric-ca:latest \
    sh -c "fabric-ca-server start -b $ROOT_TLS_NAME:$ROOT_TLS_PASS \
    --home $HOST_SRV_DIR"


# Waiting Root-TLS-CA Host startup
CheckContainer "$ROOT_TLS_NAME" "$DOCKER_CONTAINER_WAIT"
CheckContainerLog "$ROOT_TLS_NAME" "Listening on https://0.0.0.0:$ROOT_TLS_PORT" "$DOCKER_CONTAINER_WAIT"


# copy ca-cert.pem to TLS-key directory
cp $LOCAL_SRV_DIR/ca-cert.pem $LOCAL_INFRA_DIR/_root/$ROOT_TLS_NAME/tls-ca-cert.pem


# Enroll Root-TLS-CA TLS certs
echo ""
echo_info "Root-TLS-CA enrolling..."
docker exec -it $ROOT_TOOLS_NAME fabric-ca-client enroll -u https://$ROOT_TLS_NAME:$ROOT_TLS_PASS@$ROOT_TLS_NAME:$ROOT_TLS_PORT \
    --home $ROOT_TOOLS_CACLI_DIR \
    --tls.certfiles tls-root-cert/tls-ca-cert.pem \
    --enrollment.profile tls \
    --mspdir $HOST_INFRA_DIR/_root/$ROOT_TLS_NAME/keys/tls \
   

###############################################################
# Register and entroll Root-CA TLS certs
###############################################################
ROOT_CA_NAME=$(yq eval ".Root.CA.Name" "$CONFIG_FILE")
ROOT_CA_PASS=$(yq eval ".Root.CA.Pass" "$CONFIG_FILE")
ROOT_CA_IP=$(yq eval ".Root.CA.IP" "$CONFIG_FILE")

# Register Root-CA identity
echo ""
echo_info "Root-CA registering..."
docker exec -it $ROOT_TOOLS_NAME fabric-ca-client register -u https://$ROOT_TLS_NAME:$ROOT_TLS_PASS@$ROOT_TLS_NAME:$ROOT_TLS_PORT \
    --home $ROOT_TOOLS_CACLI_DIR \
    --tls.certfiles tls-root-cert/tls-ca-cert.pem \
    --mspdir $HOST_INFRA_DIR/_root/$ROOT_TLS_NAME/keys/tls \
    --id.name $ROOT_CA_NAME --id.secret $ROOT_CA_PASS --id.type client --id.affiliation jedo.root \

# Enroll Root-CA TLS certs
echo ""
echo_info "Root-CA TLS enrolling..."
docker exec -it $ROOT_TOOLS_NAME fabric-ca-client enroll -u https://$ROOT_CA_NAME:$ROOT_CA_PASS@$ROOT_TLS_NAME:$ROOT_TLS_PORT \
    --home $ROOT_TOOLS_CACLI_DIR \
    --tls.certfiles tls-root-cert/tls-ca-cert.pem \
    --enrollment.profile tls \
    --mspdir $HOST_INFRA_DIR/_root/$ROOT_CA_NAME/keys/tls \
    --csr.hosts ${ROOT_CA_NAME},${ROOT_CA_IP},${ROOT_TLS_NAME},${ROOT_TLS_IP},*.jedo.dev


###############################################################
# Register and entroll Realms-CA TLS certs
###############################################################
REALMS=$(yq eval ".Realms[].Name" $CONFIG_FILE)
for REALM in $REALMS; do
    REALM_CA_NAME=$(yq eval ".Realms[] | select(.Name == \"$REALM\") | .ORG-CA.Name" "$CONFIG_FILE")
    REALM_CA_PASS=$(yq eval ".Realms[] | select(.Name == \"$REALM\") | .ORG-CA.Pass" "$CONFIG_FILE")
    REALM_CA_IP=$(yq eval ".Realms[] | select(.Name == \"$REALM\") | .ORG-CA.IP" "$CONFIG_FILE")

    # Register Realm-CA identity
    echo ""
    echo_info "Realm-CA $REALM_CA_NAME registering..."
    docker exec -it $ROOT_TOOLS_NAME fabric-ca-client register -u https://$ROOT_TLS_NAME:$ROOT_TLS_PASS@$ROOT_TLS_NAME:$ROOT_TLS_PORT \
        --home $ROOT_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $HOST_INFRA_DIR/_root/$ROOT_TLS_NAME/keys/tls \
        --id.name $REALM_CA_NAME --id.secret $REALM_CA_PASS --id.type client --id.affiliation jedo.root \

    # Enroll Realm-CA TLS certs
    echo ""
    echo_info "Realm-CA TLS enrolling..."
    docker exec -it $ROOT_TOOLS_NAME fabric-ca-client enroll -u https://$REALM_CA_NAME:$REALM_CA_PASS@$ROOT_TLS_NAME:$ROOT_TLS_PORT \
        --home $ROOT_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile tls \
        --mspdir $HOST_INFRA_DIR/_root/$REALM_CA_NAME/keys/tls \
        --csr.hosts ${REALM_CA_NAME},${REALM_CA_IP},${ROOT_CA_NAME},${ROOT_CA_IP},${ROOT_TLS_NAME},${ROOT_TLS_IP},*.jedo.dev
done


###############################################################
# Register and entroll Organization-CA TLS certs
###############################################################
ORGS=$(yq eval ".Organizations[].Name" $CONFIG_FILE)
for ORG in $ORGS; do
    ORG_CA_NAME=$(yq eval ".Organizations[] | select(.Name == \"$ORG\") | .ORG-CA.Name" "$CONFIG_FILE")
    ORG_CA_PASS=$(yq eval ".Organizations[] | select(.Name == \"$ORG\") | .ORG-CA.Pass" "$CONFIG_FILE")
    ORG_CA_IP=$(yq eval ".Organizations[] | select(.Name == \"$ORG\") | .ORG-CA.IP" "$CONFIG_FILE")

    # Register Organization-CA identity
    echo ""
    echo_info "Organization-CA $ORG_CA_NAME registering..."
    docker exec -it $ROOT_TOOLS_NAME fabric-ca-client register -u https://$ROOT_TLS_NAME:$ROOT_TLS_PASS@$ROOT_TLS_NAME:$ROOT_TLS_PORT \
        --home $ROOT_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $HOST_INFRA_DIR/_root/$ROOT_TLS_NAME/keys/tls \
        --id.name $ORG_CA_NAME --id.secret $ORG_CA_PASS --id.type client --id.affiliation jedo.root \

    # Enroll Organization-CA TLS certs
    echo ""
    echo_info "Organization-CA TLS enrolling..."
    docker exec -it $ROOT_TOOLS_NAME fabric-ca-client enroll -u https://$ORG_CA_NAME:$ORG_CA_PASS@$ROOT_TLS_NAME:$ROOT_TLS_PORT \
        --home $ROOT_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile tls \
        --mspdir $HOST_INFRA_DIR/_root/$ORG_CA_NAME/keys/tls \
        --csr.hosts ${ORG_CA_NAME},${ORG_CA_IP},${ROOT_CA_NAME},${ROOT_CA_IP},${ROOT_TLS_NAME},${ROOT_TLS_IP},*.jedo.dev
done


###############################################################
# Root-CA
###############################################################
ROOT_CA_NAME=$(yq eval ".Root.CA.Name" "$CONFIG_FILE")
ROOT_CA_PASS=$(yq eval ".Root.CA.Pass" "$CONFIG_FILE")
ROOT_CA_IP=$(yq eval ".Root.CA.IP" "$CONFIG_FILE")
ROOT_CA_PORT=$(yq eval ".Root.CA.Port" "$CONFIG_FILE")
ROOT_CA_OPPORT=$(yq eval ".Root.CA.OpPort" "$CONFIG_FILE")
    
LOCAL_INFRA_DIR=${PWD}/infrastructure
LOCAL_SRV_DIR=${PWD}/infrastructure/_root/$ROOT_CA_NAME/server

HOST_INFRA_DIR=/etc/infrastructure
HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server

mkdir -p $LOCAL_SRV_DIR


# Write Root-CA SERVER config
cat <<EOF > $LOCAL_SRV_DIR/fabric-ca-server-config.yaml
---
version: 0.0.1
port: $ROOT_CA_PORT
debug: true
tls:
    enabled: true
    certfile: $HOST_INFRA_DIR/_root/$ROOT_CA_NAME/keys/tls/signcerts/cert.pem
    keyfile: $HOST_INFRA_DIR/_root/$ROOT_CA_NAME/keys/tls/keystore/$(basename $(ls $LOCAL_INFRA_DIR/_root/$ROOT_CA_NAME/keys/tls/keystore/*_sk | head -n 1))
    clientauth:
      type: noclientcert
      certfiles:
ca:
    name: $ROOT_CA_NAME
crl:
registry:
    maxenrollments: -1
    identities:
        - name: $ROOT_CA_NAME
          pass: $ROOT_CA_PASS
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
    cn: $ROOT_CA_NAME
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
        - $ROOT_CA_NAME
        - $ROOT_CA_IP
        - '*.jedo.dev'
    ca:
        expiry: 131400h
        pathlength: 2
idemix:
    curve: gurvy.Bn254
operations:
    listenAddress: $ROOT_CA_IP:$ROOT_CA_OPPORT
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


# Start Root-CA Containter
echo ""
echo_info "Docker Container $ROOT_CA_NAME starting..."
docker run -d \
    --name $ROOT_CA_NAME \
    --network $DOCKER_NETWORK_NAME \
    --ip $ROOT_CA_IP \
    $hosts_args \
    --restart=on-failure:1 \
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/src/fabric_ca_logo.png" \
    -p $ROOT_CA_PORT:$ROOT_CA_PORT \
    -p $ROOT_CA_OPPORT:$ROOT_CA_OPPORT \
    -v $LOCAL_SRV_DIR:$HOST_SRV_DIR \
    -v $LOCAL_INFRA_DIR:$HOST_INFRA_DIR \
    hyperledger/fabric-ca:latest \
    sh -c "fabric-ca-server start -b $ROOT_CA_NAME:$ROOT_CA_PASS \
    --home $HOST_SRV_DIR"


# Waiting Root-CA Host startup
CheckContainer "$ROOT_CA_NAME" "$DOCKER_CONTAINER_WAIT"
CheckContainerLog "$ROOT_CA_NAME" "Listening on https://0.0.0.0:$ROOT_CA_PORT" "$DOCKER_CONTAINER_WAIT"


# Enroll Root-CA ID certs
echo ""
echo_info "Root-ORG-CA enrolling..."
docker exec -it $ROOT_TOOLS_NAME fabric-ca-client enroll -u https://$ROOT_CA_NAME:$ROOT_CA_PASS@$ROOT_CA_NAME:$ROOT_CA_PORT \
    --home $ROOT_TOOLS_CACLI_DIR \
    --tls.certfiles tls-root-cert/tls-ca-cert.pem \
    --enrollment.profile ca \
    --mspdir $HOST_INFRA_DIR/_root/$ROOT_CA_NAME/keys/msp \
    

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
# Realms-ORG-CA
###############################################################
REALMS=$(yq eval ".Realms[].Name" $CONFIG_FILE)
for REALM in $REALMS; do
    REALM_ORG_NAME=$(yq eval ".Realms[] | select(.Name == \"$REALM\") | .ORG-CA.Name" "$CONFIG_FILE")
    REALM_ORG_PASS=$(yq eval ".Realms[] | select(.Name == \"$REALM\") | .ORG-CA.Pass" "$CONFIG_FILE")
    REALM_ORG_IP=$(yq eval ".Realms[] | select(.Name == \"$REALM\") | .ORG-CA.IP" "$CONFIG_FILE")
    REALM_ORG_PORT=$(yq eval ".Realms[] | select(.Name == \"$REALM\") | .ORG-CA.Port" "$CONFIG_FILE")
    REALM_ORG_OPPORT=$(yq eval ".Realms[] | select(.Name == \"$REALM\") | .ORG-CA.OpPort" "$CONFIG_FILE")

    LOCAL_INFRA_DIR=${PWD}/infrastructure
    LOCAL_SRV_DIR=${PWD}/infrastructure/_root/$REALM_ORG_NAME/server

    HOST_INFRA_DIR=/etc/infrastructure
    HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server

    mkdir -p $LOCAL_SRV_DIR


    # Register Realm-ORG-CA ID identity, enrollment later
    echo ""
    echo_info "Realm-ORG-CA ID $REALM_ORG_NAME registering..."
    docker exec -it $ROOT_TOOLS_NAME fabric-ca-client register -u https://$ROOT_CA_NAME:$ROOT_CA_PASS@$ROOT_CA_NAME:$ROOT_CA_PORT \
        --home $ROOT_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --mspdir $HOST_INFRA_DIR/_root/$ROOT_CA_NAME/keys/msp \
        --id.name $REALM_ORG_NAME --id.secret $REALM_ORG_PASS --id.type client --id.affiliation jedo.root \
        --id.attrs '"hf.Registrar.Roles=user,admin","hf.Revoker=true","hf.IntermediateCA=true"'


    # Write Realm-ORG-CA SERVER config
    cat <<EOF > $LOCAL_SRV_DIR/fabric-ca-server-config.yaml
---
version: 0.0.1
port: $REALM_ORG_PORT
debug: true
tls:
    enabled: true
    certfile: $HOST_INFRA_DIR/_root/$REALM_ORG_NAME/keys/tls/signcerts/cert.pem
    keyfile: $HOST_INFRA_DIR/_root/$REALM_ORG_NAME/keys/tls/keystore/$(basename $(ls $LOCAL_INFRA_DIR/_root/$REALM_ORG_NAME/keys/tls/keystore/*_sk | head -n 1))
    clientauth:
      type: noclientcert
      certfiles:
ca:
    name: $REALM_ORG_NAME
    chainfile: $HOST_INFRA_DIR/_root/$REALM_ORG_NAME/keys/msp/intermediatecerts/ca-chain.pem
crl:
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
        - $REALM_ORG_NAME
        - $REALM_ORG_IP
    ca:
        expiry: 131400h
        pathlength: 1
intermediate:
    parentserver:
        url: https://$ROOT_CA_NAME:$ROOT_CA_PASS@$ROOT_CA_NAME:$ROOT_CA_PORT
        caname: $ROOT_CA_NAME
    enrollment:
        hosts: 
            - $ROOT_CA_NAME
            - $ROOT_CA_IP
            - '*.jedo.dev'
        profile: ca
    tls:
        certfiles: $HOST_INFRA_DIR/_root/tls.jedo.dev/tls-ca-cert.pem
idemix:
    curve: gurvy.Bn254
operations:
    listenAddress: $REALM_ORG_IP:$REALM_ORG_OPPORT
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


    # Start Realm-ORG-CA Containter
    echo ""
    echo_info "Docker Container $REALM_ORG_NAME starting..."
    docker run -d \
        --name $REALM_ORG_NAME \
        --network $DOCKER_NETWORK_NAME \
        --ip $REALM_ORG_IP \
        $hosts_args \
        --restart=on-failure:1 \
        --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/src/fabric_ca_logo.png" \
        -p $REALM_ORG_PORT:$REALM_ORG_PORT \
        -p $REALM_ORG_OPPORT:$REALM_ORG_OPPORT \
        -v $LOCAL_SRV_DIR:$HOST_SRV_DIR \
        -v $LOCAL_INFRA_DIR:$HOST_INFRA_DIR \
        hyperledger/fabric-ca:latest \
        sh -c "fabric-ca-server start -b $REALM_ORG_NAME:$REALM_ORG_PASS \
        --home $HOST_SRV_DIR"


    # Waiting Realm-ORG-CA Host startup
    CheckContainer "$REALM_ORG_NAME" "$DOCKER_CONTAINER_WAIT"
    CheckContainerLog "$REALM_ORG_NAME" "Listening on https://0.0.0.0:$REALM_ORG_PORT" "$DOCKER_CONTAINER_WAIT"


    # copy ca-chain.pem to MSP-key directory
    mkdir -p $LOCAL_INFRA_DIR/_root/$REALM_ORG_NAME/keys/msp/intermediatecerts
    cp $LOCAL_SRV_DIR/ca-chain.pem $LOCAL_INFRA_DIR/_root/$REALM_ORG_NAME/keys/msp/intermediatecerts/ca-chain.pem


    # Enroll Realm-ORG-CA certs
    echo ""
    echo_info "Realm-CA ORG enrolling..."
    docker exec -it $ROOT_TOOLS_NAME fabric-ca-client enroll -u https://$REALM_ORG_NAME:$REALM_ORG_PASS@$ROOT_CA_NAME:$ROOT_CA_PORT \
        --home $ROOT_TOOLS_CACLI_DIR \
        --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        --enrollment.profile ca \
        --mspdir $HOST_INFRA_DIR/_root/$REALM_ORG_NAME/keys/msp \
        --csr.hosts ${REALM_ORG_NAME},${REALM_ORG_IP},${ROOT_CA_NAME},${ROOT_CA_IP},${ROOT_TLS_NAME},${ROOT_TLS_IP},*.jedo.dev

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


