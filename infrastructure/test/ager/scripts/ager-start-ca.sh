###############################################################
#!/bin/bash
#
# This script starts regnum ca docker container.
#
###############################################################
set -euo pipefail

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTDIR/utils.sh"

log_section "JEDO-Ecosystem - new Ager - CA starting..."


###############################################################
# Usage / Argument-Handling
###############################################################
export LOGLEVEL="INFO"
export DEBUG=false
export FABRIC_CA_SERVER_LOGLEVEL="info"

AGER_CERTS_CONFIG=""
AGER_INFRA_CONFIG=""

usage() {
  log_error "Usage: $0 <config-certs-filename> <config-infra-filename> [--debug]" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)
      DEBUG=true
      LOGLEVEL="DEBUG"
      FABRIC_CA_SERVER_LOGLEVEL="DEBUG"
      shift
      ;;
    -*)
      log_error "Unkown Option: $1" >&2
      usage
      ;;
    *)
      # first non-Option-Argument = CA_TYPE
      if [[ -z "$AGER_CERTS_CONFIG" ]]; then
        AGER_CERTS_CONFIG="$1"
      elif [[ -z "$AGER_INFRA_CONFIG" ]]; then
        AGER_INFRA_CONFIG="$1"
      else
        log_error "To many arguments: '$1'" >&2
        usage
      fi
      shift
      ;;
  esac
done

if [[ -z "$AGER_CERTS_CONFIG" ]] || [[ -z "$AGER_INFRA_CONFIG" ]]; then
  usage
fi


###############################################################
# Config
###############################################################
CERTS_CONFIGFILE="${SCRIPTDIR}/../config/$AGER_CERTS_CONFIG"
INFRA_CONFIGFILE="${SCRIPTDIR}/../config/$AGER_INFRA_CONFIG"

DOCKER_NETWORK=$(yq eval '.Docker.Network' "${INFRA_CONFIGFILE}")
DOCKER_SUBNET=$(yq eval '.Docker.Subnet' "${INFRA_CONFIGFILE}")
DOCKER_GATEWAY=$(yq eval '.Docker.Gateway' "${INFRA_CONFIGFILE}")
DOCKER_WAIT=$(yq eval '.Docker.Wait' "${INFRA_CONFIGFILE}")

ORBIS_NAME=$(yq eval '.Orbis.Name' "${INFRA_CONFIGFILE}")
ORBIS_ENV=$(yq eval '.Orbis.Env' "${INFRA_CONFIGFILE}")
ORBIS_TLD=$(yq eval '.Orbis.Tld' "${INFRA_CONFIGFILE}")

REGNUM_NAME=$(yq eval '.Regnum.Name' "${INFRA_CONFIGFILE}")
REGNUM_TLS_NAME=$(yq eval '.Regnum.tls.Name' "${INFRA_CONFIGFILE}")
REGNUM_TLS_NAME=$REGNUM_TLS_NAME.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD
REGNUM_TLS_PORT=$(yq eval '.Regnum.tls.Port' "${INFRA_CONFIGFILE}")
REGNUM_MSP_NAME=$(yq eval '.Regnum.msp.Name' "${INFRA_CONFIGFILE}")
REGNUM_MSP_NAME=$REGNUM_MSP_NAME.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD
REGNUM_MSP_PORT=$(yq eval '.Regnum.msp.Port' "${INFRA_CONFIGFILE}")

AGER_NAME=$(yq eval '.Ager.Name' "${INFRA_CONFIGFILE}")
AGER_CA_NAME=$(yq eval '.Ager.msp.Name' "${INFRA_CONFIGFILE}")
AGER_CA_NAME=$AGER_CA_NAME.$AGER_NAME.$REGNUM_NAME.$ORBIS_NAME.$ORBIS_TLD
AGER_CA_NAME_FORMATTED="${AGER_CA_NAME//./-}"

AGER_CA_IP=$(yq eval '.Ager.msp.IP' "${INFRA_CONFIGFILE}")
AGER_CA_PORT=$(yq eval '.Ager.msp.Port' "${INFRA_CONFIGFILE}")
AGER_CA_OPPORT=$(yq eval '.Ager.msp.OpPort' "${INFRA_CONFIGFILE}")
AGER_CA_SECRET=$(yq eval '.Ager.msp.Secret' "${CERTS_CONFIGFILE}")

AFFILIATION=$ORBIS_NAME.$REGNUM_NAME.$AGER_NAME

LOCAL_INFRA_DIR="${SCRIPTDIR}/../../infrastructure"
HOST_INFRA_DIR="/etc/hyperledger/infrastructure"
LOCAL_CA_DIR="${LOCAL_INFRA_DIR}/$AGER_CA_NAME"
HOST_CA_DIR="/etc/hyperledger/fabric-ca-server"
CACLIENT_HOME="/etc/hyperledger/fabric-ca-server/ca-client-admin"
CACLIENT_TLS="${CACLIENT_HOME}/tls-root/tls-ca-cert.pem"


###############################################################
# Debug Logging
###############################################################
log_debug "Docker Network:" "${DOCKER_NETWORK} (${DOCKER_SUBNET})"
log_debug "Orbis Info:" "$ORBIS_NAME - $ORBIS_ENV - $ORBIS_TLD"
log_debug "Regnum Info:" "$REGNUM_TLS_NAME:$REGNUM_TLS_PORT / $REGNUM_MSP_NAME:$REGNUM_MSP_PORT"
log_debug "Ager Info:" "$AGER_CA_NAME:$AGER_CA_SECRET@$AGER_CA_IP:$AGER_CA_PORT"
log_debug "Local CA Dir:" "$LOCAL_CA_DIR"
log_debug "Host CA Dir:" "$HOST_CA_DIR"


###############################################################
# RUN
###############################################################
$SCRIPTDIR/prereq.sh

log_info "$AGER_CA_NAME starting ..."

# Start docker network if not running
if ! docker network ls --format '{{.Name}}' | grep -wq "$DOCKER_NETWORK"; then
    docker network create --subnet=$DOCKER_SUBNET --gateway=$DOCKER_GATEWAY "$DOCKER_NETWORK"
fi
docker network inspect "$DOCKER_NETWORK"

# Prepare MSP-CA local directory
mkdir -p "${LOCAL_CA_DIR}/tls-root"
cp ${SCRIPTDIR}/../config/tls-ca-cert.pem $LOCAL_CA_DIR/tls-root/tls-ca-cert.pem
log_debug "tls-root cert copied"

# Enroll Ager-MSP-CA with temp docker container
log_info "Ager-CA enrolling for server certificate..."
docker run --rm \
  --name "${AGER_CA_NAME}" \
  --network "${DOCKER_NETWORK}" \
  --ip "${AGER_CA_IP}" \
  -p "${AGER_CA_PORT}:${AGER_CA_PORT}" \
  -v "${LOCAL_CA_DIR}:${CACLIENT_HOME}" \
  -e FABRIC_MSP_CLIENT_HOME=${CACLIENT_HOME} \
  -e FABRIC_MSP_SERVER_LOGLEVEL=${LOGLEVEL} \
  hyperledger/fabric-ca:latest \
  fabric-ca-client enroll \
      -u https://$AGER_CA_NAME:$AGER_CA_SECRET@$REGNUM_TLS_NAME:$REGNUM_TLS_PORT \
      --tls.certfiles ${CACLIENT_TLS} \
      --mspdir $CACLIENT_HOME/tls
log_debug "TLS-CA enrolled"
docker run --rm \
  --name "${AGER_CA_NAME}" \
  --network "${DOCKER_NETWORK}" \
  --ip "${AGER_CA_IP}" \
  -p "${AGER_CA_PORT}:${AGER_CA_PORT}" \
  -v $LOCAL_CA_DIR:$CACLIENT_HOME \
  -e FABRIC_CA_CLIENT_HOME=$CACLIENT_HOME \
  -e FABRIC_CA_SERVER_LOGLEVEL=$LOGLEVEL \
  hyperledger/fabric-ca:latest \
  fabric-ca-client enroll \
      -u https://$AGER_CA_NAME:$AGER_CA_SECRET@$REGNUM_MSP_NAME:$REGNUM_MSP_PORT \
      --tls.certfiles ${CACLIENT_TLS} \
      --mspdir $CACLIENT_HOME/msp \
      --csr.hosts ${AGER_CA_NAME},${AGER_CA_IP}
log_debug "MSP-CA enrolled"

# Generating NodeOUs-File
log_debug "NodeOUs-File writing..."
CA_CERT_FILE=$(ls $LOCAL_CA_DIR/msp/cacerts/*.pem)
log_debug "CA Cert-File:" "$CA_CERT_FILE"
cat <<EOF > $LOCAL_CA_DIR/msp/config.yaml
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
log_debug "NodeOUs-Files saved"

# Generating CA Server Config
log_debug "CA Server Config writing..."
log_debug "CA Name formatted:" "$AGER_CA_NAME_FORMATTED"
cat <<EOF > $LOCAL_CA_DIR/fabric-ca-server-config.yaml
---
version: 0.0.1

port: $AGER_CA_PORT

tls:
    enabled: true
    certfile: $HOST_CA_DIR/tls/signcerts/cert.pem
    keyfile: $HOST_CA_DIR/tls/keystore/$(basename $(ls $LOCAL_CA_DIR/tls/keystore/*_sk | head -n 1))
    clientauth:
      type: noclientcert
      certfiles:

ca:
    name: $AGER_CA_NAME
    certfile: $HOST_CA_DIR/$AGER_CA_NAME_FORMATTED.cert
    keyfile: $HOST_CA_DIR/$AGER_CA_NAME_FORMATTED.key
    chainfile: $HOST_CA_DIR/$AGER_CA_NAME_FORMATTED-chain.cert

crl:

registry:
    maxenrollments: -1
    identities:
        - name: $AGER_CA_NAME
          pass: $AGER_CA_SECRET
          type: client
          affiliation: $AFFILIATION
          attrs:
              hf.Registrar.Roles: "client,user"
              hf.Registrar.DelegateRoles: "client,user"
              hf.Registrar.Attributes: "*"
              hf.Revoker: true
              hf.GenCRL: true
              hf.IntermediateCA: false
              hf.AffiliationMgr: false

affiliations:
    jedo:
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

csr:
  cn: ${AGER_CA_NAME}
  names:
    - C: XX
      ST: ${ORBIS_ENV}
      L: ${REGNUM_NAME}
      O: ${AGER_NAME}
      OU: 
  hosts:
    - ${AGER_CA_NAME}
    - ${AGER_CA_IP}

idemix:
    curve: gurvy.Bn254

operations:
    listenAddress: $AGER_CA_IP:$AGER_CA_OPPORT
    tls:
        enabled: false
EOF

# Start Containter
log_info "CA Server starting..."
log_debug "- Docker Container" "$AGER_CA_NAME"
log_debug "- Infra Dir:" "$LOCAL_INFRA_DIR"
log_debug "- Local Dir:" "$LOCAL_CA_DIR"
log_info "Docker Container $AGER_CA_NAME starting..."
docker run -d \
    --user $(id -u):$(id -g) \
    --name $AGER_CA_NAME \
    --network $DOCKER_NETWORK \
    --ip $AGER_CA_IP \
    --restart=on-failure:1 \
    -p $AGER_CA_PORT:$AGER_CA_PORT \
    -p $AGER_CA_OPPORT:$AGER_CA_OPPORT \
    -v $LOCAL_CA_DIR:$HOST_CA_DIR \
    -v $LOCAL_INFRA_DIR:$HOST_INFRA_DIR \
    -e FABRIC_CA_SERVER_LOGLEVEL=$LOGLEVEL \
    hyperledger/fabric-ca:latest \
    sh -c "fabric-ca-server start -b $AGER_CA_NAME:$AGER_CA_SECRET \
    --home $HOST_CA_DIR"

# Waiting Container startup
CheckContainer "$AGER_CA_NAME" "$DOCKER_WAIT"
CheckContainerLog "$AGER_CA_NAME" "Listening on https://0.0.0.0:$AGER_CA_PORT" "$DOCKER_WAIT"

chmod -R 750 $SCRIPTDIR/../../infrastructure

log_ok "$AGER_CA_NAME started."





chmod -R 777 $SCRIPTDIR/../../infrastructure
exit 1
chmod -R 777 /mnt/user/appdata/jedo/demo/infrastructure
