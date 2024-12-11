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


###############################################################
# Params for Orbis-TLS
###############################################################
ORBIS=$(yq eval ".Orbis.Name" "$CONFIG_FILE")
ORBIS_TLS_NAME=$(yq eval ".Orbis.TLS.Name" "$CONFIG_FILE")
ORBIS_TLS_PASS=$(yq eval ".Orbis.TLS.Pass" "$CONFIG_FILE")
ORBIS_TLS_IP=$(yq eval ".Orbis.TLS.IP" "$CONFIG_FILE")
ORBIS_TLS_PORT=$(yq eval ".Orbis.TLS.Port" "$CONFIG_FILE")
ORBIS_TLS_OPPORT=$(yq eval ".Orbis.TLS.OpPort" "$CONFIG_FILE")


###############################################################
# Start Orbis-TLS
###############################################################
echo ""
echo_warn "TLS-CA $ORBIS_TLS_NAME starting... (Defaults: https://hyperledger-fabric-ca.readthedocs.io/en/latest/serverconfig.html)"


# LOCAL_INFRA_DIR=${PWD}/infrastructure
LOCAL_SRV_DIR=${PWD}/infrastructure/$ORBIS/$ORBIS_TLS_NAME
HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server
mkdir -p $LOCAL_SRV_DIR


# Write Orbis-TLS SERVER config
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


# Start Orbis-TLS Containter
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


# Waiting Orbis-TLS Container startup
CheckContainer "$ORBIS_TLS_NAME" "$DOCKER_CONTAINER_WAIT"
CheckContainerLog "$ORBIS_TLS_NAME" "Listening on https://0.0.0.0:$ORBIS_TLS_PORT" "$DOCKER_CONTAINER_WAIT"


# copy ca-cert.pem to TLS-key directory and ca-client directory
cp -r $LOCAL_SRV_DIR/ca-cert.pem $LOCAL_SRV_DIR/tls-ca-cert.pem
mkdir ${PWD}/infrastructure/$ORBIS/$ORBIS_TOOLS_NAME/ca-client/tls-root-cert
cp -r $LOCAL_SRV_DIR/ca-cert.pem ${PWD}/infrastructure/$ORBIS/$ORBIS_TOOLS_NAME/ca-client/tls-root-cert/tls-ca-cert.pem


# Enroll TLS certs for Orbis-TLS
echo ""
echo_info "Certificate for $ORBIS_TLS_NAME enrolling..."
docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$ORBIS_TLS_NAME:$ORBIS_TLS_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
    --home $ORBIS_TOOLS_CACLI_DIR \
    --tls.certfiles tls-root-cert/tls-ca-cert.pem \
    --enrollment.profile tls \
    --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$ORBIS_TLS_NAME/tls \


###############################################################
# Last Tasks
###############################################################
chmod -R 777 infrastructure
echo ""
echo_ok "TLS-CA $ORBIS_TLS_NAME started."



