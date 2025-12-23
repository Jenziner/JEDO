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
source "$SCRIPT_DIR/params.sh"
source "$SCRIPT_DIR/ca_utils.sh"
check_script

get_hosts


###############################################################
# Params for Orbis-TLS
###############################################################
ORBIS_TLS_NAME=$(yq eval ".Orbis.TLS.Name" "$CONFIG_FILE")
ORBIS_TLS_PASS=$(yq eval ".Orbis.TLS.Pass" "$CONFIG_FILE")
ORBIS_TLS_IP=$(yq eval ".Orbis.TLS.IP" "$CONFIG_FILE")
ORBIS_TLS_PORT=$(yq eval ".Orbis.TLS.Port" "$CONFIG_FILE")
ORBIS_TLS_OPPORT=$(yq eval ".Orbis.TLS.OpPort" "$CONFIG_FILE")
ORBIS_TLS_SRV_DIR=/etc/hyperledger/fabric-ca-server
ORBIS_TLS_INFRA_DIR=/etc/hyperledger/infrastructure
ORBIS_TLS_CERT=$ORBIS_TLS_SRV_DIR/ca-cert.pem
LOCAL_INFRA_DIR=${PWD}/infrastructure
LOCAL_SRV_DIR=$LOCAL_INFRA_DIR/$ORBIS/$ORBIS_TLS_NAME
mkdir -p $LOCAL_SRV_DIR


###############################################################
# Start Orbis-TLS
###############################################################
log_info "TLS-CA $ORBIS_TLS_NAME starting... (Defaults: https://hyperledger-fabric-ca.readthedocs.io/en/latest/serverconfig.html)"
log_debug "Orbis:" "$ORBIS_TLS_NAME"
log_debug "Dir:" "$LOCAL_SRV_DIR"

# Write Orbis-TLS SERVER config
cat <<EOF > $LOCAL_SRV_DIR/fabric-ca-server-config.yaml
---
version: 0.0.1
port: $ORBIS_TLS_PORT
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
          affiliation: "jedo"
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
        - C: jd
          ST: cc
          L:
          O: jedo
          OU: root
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
log_info "Docker Container $ORBIS_TLS_NAME starting..."
docker run -d \
    --user $(id -u):$(id -g) \
    --name $ORBIS_TLS_NAME \
    --network $DOCKER_NETWORK_NAME \
    --ip $ORBIS_TLS_IP \
    $hosts_args \
    --restart=on-failure:1 \
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/src/fabric_ca_logo.png" \
    -p $ORBIS_TLS_PORT:$ORBIS_TLS_PORT \
    -p $ORBIS_TLS_OPPORT:$ORBIS_TLS_OPPORT \
    -v $LOCAL_SRV_DIR:$ORBIS_TLS_SRV_DIR \
    -v $LOCAL_INFRA_DIR:$ORBIS_TLS_INFRA_DIR \
    -e FABRIC_CA_SERVER_LOGLEVEL=$FABRIC_CA_SERVER_LOGLEVEL \
    hyperledger/fabric-ca:latest \
    sh -c "fabric-ca-server start -b $ORBIS_TLS_NAME:$ORBIS_TLS_PASS \
    --home $ORBIS_TLS_SRV_DIR"


# Waiting Orbis-TLS Container startup
CheckContainer "$ORBIS_TLS_NAME" "$DOCKER_CONTAINER_WAIT"
CheckContainerLog "$ORBIS_TLS_NAME" "Listening on https://0.0.0.0:$ORBIS_TLS_PORT" "$DOCKER_CONTAINER_WAIT"


# Enroll TLS certs for Orbis-TLS
log_info "Certificate for $ORBIS_TLS_NAME enrolling..."
docker exec -it $ORBIS_TLS_NAME fabric-ca-client enroll -u https://$ORBIS_TLS_NAME:$ORBIS_TLS_PASS@$ORBIS_TLS_NAME:$ORBIS_TLS_PORT \
    --home "$ORBIS_TLS_SRV_DIR" \
    --tls.certfiles "$ORBIS_TLS_CERT" \
    --mspdir "$ORBIS_TLS_INFRA_DIR/$ORBIS/$ORBIS_TLS_NAME/tls" \
    --enrollment.profile tls \


###############################################################
# Last Tasks
###############################################################
chmod -R 750 infrastructure
echo ""
log_ok "TLS-CA $ORBIS_TLS_NAME started."



