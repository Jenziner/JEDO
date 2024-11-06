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

ROOT_CA_NAME=$(yq eval ".Root.Name" "$CONFIG_FILE")
ROOT_CA_IP=$(yq eval ".Root.IP" "$CONFIG_FILE")
ROOT_CA_OPPORT=$(yq eval ".Root.OpPort" "$CONFIG_FILE")
ROOT_CA_OPENSSL=$(yq eval ".Root.OpenSSL" "$CONFIG_FILE")

ROOT_TLSCA_NAME=$(yq eval ".Root.TLS-CA.Name" "$CONFIG_FILE")
ROOT_TLSCA_PASS=$(yq eval ".Root.TLS-CA.Pass" "$CONFIG_FILE")
ROOT_TLSCA_PORT=$(yq eval ".Root.TLS-CA.Port" "$CONFIG_FILE")
ROOT_TLSCA_OPPORT=$(yq eval ".Root.TLS-CA.OpPort" "$CONFIG_FILE")

ROOT_ORGCA_NAME=$(yq eval ".Root.ORG-CA.Name" "$CONFIG_FILE")
ROOT_ORGCA_PASS=$(yq eval ".Root.ORG-CA.Pass" "$CONFIG_FILE")
ROOT_ORGCA_PORT=$(yq eval ".Root.ORG-CA.Port" "$CONFIG_FILE")
ROOT_ORGCA_OPPORT=$(yq eval ".Root.ORG-CA.OpPort" "$CONFIG_FILE")

LOCAL_TLS_KEYS_DIR=${PWD}/infrastructure/_root/$ROOT_TLSCA_NAME/keys
LOCAL_ORG_KEYS_DIR=${PWD}/infrastructure/_root/$ROOT_ORGCA_NAME/keys
LOCAL_SRV_DIR=${PWD}/infrastructure/_root/$ROOT_CA_NAME/server
LOCAL_CLI_DIR=${PWD}/infrastructure/_root/$ROOT_CA_NAME/client

HOST_TLS_KEYS_DIR=/etc/hyperledger/$ROOT_TLSCA_NAME
HOST_ORG_KEYS_DIR=/etc/hyperledger/$ROOT_ORGCA_NAME
HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server
HOST_CLI_DIR=/etc/hyperledger/fabric-ca-client

get_hosts

echo ""
echo_warn "Root-CA starting... (Defaults: https://hyperledger-fabric-ca.readthedocs.io/en/latest/serverconfig.html)"


###############################################################
# Write TLS SERVER config
###############################################################
echo ""
echo_info "fabric-ca-server-config.yaml for $ROOT_TLSCA_NAME generating..."

mkdir -p $LOCAL_SRV_DIR

cat <<EOF > $LOCAL_SRV_DIR/fabric-ca-server-config.yaml
---
version: 0.0.1

port: $ROOT_TLSCA_PORT

debug: true

tls:
  enabled: true
  clientauth:
    type: noclientcert
    certfiles:

ca:
  name: $ROOT_TLSCA_NAME

crl:
registry:
  maxenrollments: 1
  identities:
     - name: $ROOT_TLSCA_NAME
       pass: $ROOT_TLSCA_PASS
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
            - signing
            - key encipherment
            - server auth
            - client auth
            - key agreement
         expiry: 8760h

csr:
   cn: $ROOT_TLSCA_NAME
   keyrequest:
     algo: ecdsa
     size: 384
   names:
      - C: JD
        ST: "Dev"
        L:
        O: JEDO
        OU: Root
   hosts:
     - $ROOT_CA_NAME
     - $ROOT_CA_IP
     - localhost
     - 0.0.0.0
   ca:
      expiry: 131400h
      pathlength: 2

idemix:
  curve: gurvy.Bn254

operations:
    listenAddress: $ROOT_CA_IP:$ROOT_TLSCA_OPPORT
    tls:
#        enabled: true
#        cert:
#            file:
#        key:
#            file:
#        clientAuthRequired: false
#        clientRootCAs:
#            files: []
EOF


###############################################################
# Write ORG SERVER config
###############################################################
echo ""
echo_info "fabric-org-ca-server-config.yaml for $ROOT_ORGCA_NAME generating..."

mkdir -p $LOCAL_SRV_DIR/$ROOT_ORGCA_NAME

cat <<EOF > $LOCAL_SRV_DIR/$ROOT_ORGCA_NAME/fabric-ca-server-config.yaml
---
version: 0.0.1

port: $ROOT_ORGCA_PORT

debug: true

tls:
  enabled: true
  clientauth:
    type: noclientcert
    certfiles:

ca:
  name: $ROOT_ORGCA_NAME

crl:
registry:
  maxenrollments: 1
  identities:
     - name: $ROOT_ORGCA_NAME
       pass: $ROOT_ORGCA_PASS
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
         expiry: 43800h
         caconstraint:
           isca: true
           maxpathlen: 2

csr:
   cn: $ROOT_ORGCA_NAME
   keyrequest:
     algo: ecdsa
     size: 384
   names:
      - C: JD
        ST: "Dev"
        L:
        O: JEDO
        OU: Root
   hosts:
     - $ROOT_CA_NAME
     - $ROOT_CA_IP
     - localhost
     - 0.0.0.0
   ca:
      expiry: 131400h
      pathlength: 2

idemix:
  curve: gurvy.Bn254

operations:
    listenAddress: $ROOT_CA_IP:$ROOT_ORGCA_OPPORT
    tls:
#        enabled: true
#        cert:
#            file:
#        key:
#            file:
#        clientAuthRequired: false
#        clientRootCAs:
#            files: []
EOF


###############################################################
# Start Root-TLS-CA
###############################################################
echo ""
echo_info "Root-CA $ROOT_TLSCA_NAME starting..."

docker run -d \
    --name $ROOT_CA_NAME \
    --network $DOCKER_NETWORK_NAME \
    --ip $ROOT_CA_IP \
    $hosts_args \
    --restart=on-failure:1 \
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/src/fabric_ca_logo.png" \
    -p $ROOT_TLSCA_PORT:$ROOT_TLSCA_PORT \
    -p $ROOT_TLSCA_OPPORT:$ROOT_TLSCA_OPPORT \
    -p $ROOT_ORGCA_PORT:$ROOT_ORGCA_PORT \
    -p $ROOT_ORGCA_OPPORT:$ROOT_ORGCA_OPPORT \
    -v $LOCAL_SRV_DIR:$HOST_SRV_DIR \
    -v $LOCAL_CLI_DIR:$HOST_CLI_DIR \
    -v $LOCAL_TLS_KEYS_DIR:$HOST_TLS_KEYS_DIR \
    -v $LOCAL_ORG_KEYS_DIR:$HOST_ORG_KEYS_DIR \
    hyperledger/fabric-ca:latest \
    sh -c "fabric-ca-server start -b $ROOT_TLSCA_NAME:$ROOT_TLSCA_PASS \
    --cafiles $HOST_SRV_DIR/$ROOT_ORGCA_NAME/fabric-ca-server-config.yaml \
    --home $HOST_SRV_DIR" 

# Waiting Root-CA startup
CheckContainer "$ROOT_CA_NAME" "$DOCKER_CONTAINER_WAIT"
CheckContainerLog "$ROOT_CA_NAME" "Listening on https://0.0.0.0:$ROOT_TLSCA_PORT" "$DOCKER_CONTAINER_WAIT"

# Copy tls-cert.pem
mkdir -p $LOCAL_TLS_KEYS_DIR/tls $LOCAL_ORG_KEYS_DIR/tls
cp $LOCAL_SRV_DIR/tls-cert.pem $LOCAL_TLS_KEYS_DIR/tls/tls-cert.pem
cp $LOCAL_SRV_DIR/tls-cert.pem $LOCAL_ORG_KEYS_DIR/tls/tls-cert.pem


###############################################################
# Start Root-ORG-CA
###############################################################
echo ""
echo_info "Root-CA $ROOT_ORGCA_NAME starting..."

docker exec -d $ROOT_CA_NAME \
    fabric-ca-server start -b $ROOT_ORGCA_NAME:$ROOT_ORGCA_PASS \
    --home $HOST_SRV_DIR/$ROOT_ORGCA_NAME


# Installing OpenSSL
if [[ $ROOT_CA_OPENSSL = true ]]; then
    echo_info "OpenSSL installing..."
    docker exec $ROOT_CA_NAME sh -c 'command -v apk && apk update && apk add --no-cache openssl || (apt-get update && apt-get install -y openssl)'
    CheckOpenSSL "$ROOT_CA_NAME" "$DOCKER_CONTAINER_WAIT"
fi


###############################################################
# Write CLIENT config
###############################################################
echo ""
echo_info "fabric-ca-client-config.yaml generating... (Defaults: https://hyperledger-fabric-ca.readthedocs.io/en/latest/serverconfig.html)"

mkdir -p $LOCAL_CLI_DIR

cat <<EOF > $LOCAL_CLI_DIR/fabric-ca-client-config.yaml
---
url: https://localhost:7054

mspdir: msp

tls:
  certfiles: $HOST_SRV_DIR/tls-cert.pem
  client:
    certfile:
    keyfile:

csr:
   cn: $ROOT_CA_NAME
   keyrequest:
     algo: ecdsa
     size: 384
   names:
      - C: JD
        ST: "Dev"
        L:
        O: JEDO
        OU: Root
   hosts:
     - $ROOT_CA_NAME
     - $ROOT_CA_IP
     - localhost
     - 0.0.0.0

enrollment:
  profile: tls

caname: $ROOT_CA_NAME

idemixCurveID: gurvy.Bn254
EOF


###############################################################
# Enroll Root-TLS-CA
###############################################################
echo ""
echo_info "Root-TLS enrolling..."

docker exec -it $ROOT_CA_NAME fabric-ca-client enroll -u https://$ROOT_TLSCA_NAME:$ROOT_TLSCA_PASS@$ROOT_CA_NAME:$ROOT_TLSCA_PORT \
    --home $HOST_CLI_DIR --mspdir $HOST_TLS_KEYS_DIR/msp \
    --csr.cn $ROOT_TLSCA_NAME --caname $ROOT_TLSCA_NAME


###############################################################
# Enroll Root-ORG-CA
###############################################################
echo ""
echo_info "Root-ORG enrolling..."

docker exec -it $ROOT_CA_NAME fabric-ca-client enroll -u https://$ROOT_ORGCA_NAME:$ROOT_ORGCA_PASS@$ROOT_CA_NAME:$ROOT_ORGCA_PORT \
    --home $HOST_CLI_DIR --mspdir $HOST_ORG_KEYS_DIR/msp \
    --csr.cn $ROOT_ORGCA_NAME --caname $ROOT_ORGCA_NAME \
    --tls.certfiles $HOST_SRV_DIR/$ROOT_ORGCA_NAME/tls-cert.pem \
    --enrollment.profile ca


###############################################################
# Last Tasks
###############################################################
chmod -R 777 infrastructure
echo_ok "Root-CA started."
