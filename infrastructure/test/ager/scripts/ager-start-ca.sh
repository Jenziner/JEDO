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
export FABRIC_CA_SERVER_LOGLEVEL="info"       # critical, fatal, warning, info, debug
export FABRIC_CA_CLIENT_LOGLEVEL="info"       # critical, fatal, warning, info, debug
export FABRIC_LOGGING_SPEC="INFO"             # FATAL, PANIC, ERROR, WARNING, INFO, DEBUG
export CORE_CHAINCODE_LOGGING_LEVEL="INFO"    # CRITICAL, ERROR, WARNING, NOTICE, INFO, DEBUG

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
      FABRIC_CA_SERVER_LOGLEVEL="debug"
      FABRIC_CA_CLIENT_LOGLEVEL="debug"
      FABRIC_LOGGING_SPEC="DEBUG"
      CORE_CHAINCODE_LOGGING_LEVEL="DEBUG"
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
AGER_CA_CSR="C=XX,ST=$ORBIS_ENV,L=$REGNUM_NAME,O=$AGER_NAME"

AFFILIATION=$ORBIS_NAME.$REGNUM_NAME.$AGER_NAME

LOCAL_CAROOTS_DIR="${SCRIPTDIR}/../../infrastructure/tls-ca-roots"
HOST_CAROOTS_DIR="/etc/hyperledger/tls-ca-roots"

LOCAL_SRV_DIR="${SCRIPTDIR}/../../infrastructure/servers/${AGER_CA_NAME}"
HOST_SRV_DIR="/etc/hyperledger/fabric-ca-server"


###############################################################
# Debug Logging
###############################################################
log_debug "Docker Network:" "${DOCKER_NETWORK} (${DOCKER_SUBNET})"
log_debug "Orbis Info:" "$ORBIS_NAME - $ORBIS_ENV - $ORBIS_TLD"
log_debug "Regnum Info:" "$REGNUM_TLS_NAME:$REGNUM_TLS_PORT / $REGNUM_MSP_NAME:$REGNUM_MSP_PORT"
log_debug "CA Info:" "$AGER_CA_NAME:$AGER_CA_SECRET@$AGER_CA_IP:$AGER_CA_PORT"
log_debug "CA CSR:" "$AGER_CA_CSR"
log_debug "Local Server Dir:" "$LOCAL_SRV_DIR"
log_debug "Host Server Dir:" "$HOST_SRV_DIR"


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
mkdir -p "${LOCAL_SRV_DIR}/tls-root"
cp ${SCRIPTDIR}/../config/tls-ca-cert.pem $LOCAL_SRV_DIR/tls-root/tls-ca-cert.pem
log_debug "tls-root cert copied"

# Enroll Ager-MSP
log_info "Ager-CA enrolling for server certificate..."

# Enroll @ Regnum TLS-CA
docker run --rm \
  --network "${DOCKER_NETWORK}" \
  -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
  -v "${LOCAL_SRV_DIR}:${HOST_SRV_DIR}" \
  -e FABRIC_MSP_CLIENT_HOME="${HOST_SRV_DIR}" \
  -e FABRIC_CA_CLIENT_LOGLEVEL=${FABRIC_CA_CLIENT_LOGLEVEL} \
  hyperledger/fabric-ca:latest \
  fabric-ca-client enroll \
      -u https://$AGER_CA_NAME:$AGER_CA_SECRET@$REGNUM_TLS_NAME:$REGNUM_TLS_PORT \
      --tls.certfiles ${HOST_CAROOTS_DIR}/${REGNUM_TLS_NAME}.pem \
      --mspdir ${HOST_SRV_DIR}/tls \
      --enrollment.profile tls \
      --csr.hosts ${AGER_CA_NAME},${AGER_CA_IP} \
      --csr.cn $AGER_CA_NAME --csr.names "$AGER_CA_CSR"
log_debug "TLS-CA enrolled"

# Enroll @ Regnum MSP-CA
docker run --rm \
  --network "${DOCKER_NETWORK}" \
  -v "${LOCAL_CAROOTS_DIR}:${HOST_CAROOTS_DIR}" \
  -v "${LOCAL_SRV_DIR}:${HOST_SRV_DIR}" \
  -e FABRIC_MSP_CLIENT_HOME="${HOST_SRV_DIR}" \
  -e FABRIC_CA_CLIENT_LOGLEVEL=${FABRIC_CA_CLIENT_LOGLEVEL} \
  hyperledger/fabric-ca:latest \
  fabric-ca-client enroll \
      -u https://$AGER_CA_NAME:$AGER_CA_SECRET@$REGNUM_MSP_NAME:$REGNUM_MSP_PORT \
      --tls.certfiles ${HOST_CAROOTS_DIR}/${REGNUM_TLS_NAME}.pem \
      --mspdir ${HOST_SRV_DIR}/msp \
      --csr.hosts ${AGER_CA_NAME},${AGER_CA_IP} \
      --csr.cn $AGER_CA_NAME --csr.names "$AGER_CA_CSR"
log_debug "MSP-CA enrolled"

# Generating NodeOUs-File
log_debug "NodeOUs-File writing..."
CA_CERT_FILE=$(ls $LOCAL_SRV_DIR/msp/cacerts/*.pem)
log_debug "CA Cert-File:" "$CA_CERT_FILE"
cat <<EOF > $LOCAL_SRV_DIR/msp/config.yaml
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

# Write config: fabric-ca-server-config.yaml
log_debug "CA Server Config writing..."
log_debug "CA Name formatted:" "$AGER_CA_NAME_FORMATTED"
cat <<EOF > $LOCAL_SRV_DIR/fabric-ca-server-config.yaml
---
version: 0.0.1

port: $AGER_CA_PORT

tls:
    enabled: true
    certfile: $HOST_SRV_DIR/tls/signcerts/cert.pem
    keyfile: $HOST_SRV_DIR/tls/keystore/$(basename $(ls $LOCAL_SRV_DIR/tls/keystore/*_sk | head -n 1))
    clientauth:
      type: noclientcert
      certfiles:

ca:
    name: $AGER_CA_NAME
    certfile: $HOST_SRV_DIR/$AGER_CA_NAME_FORMATTED.cert
    keyfile: $HOST_SRV_DIR/$AGER_CA_NAME_FORMATTED.key
    chainfile: $HOST_SRV_DIR/$AGER_CA_NAME_FORMATTED-chain.cert

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
log_debug "- Docker Container" "$AGER_CA_NAME"
log_debug "- Local Dir:" "$LOCAL_SRV_DIR"
log_info "Docker Container $AGER_CA_NAME starting..."
docker run -d \
    --user $(id -u):$(id -g) \
    --name $AGER_CA_NAME \
    --network $DOCKER_NETWORK \
    --ip $AGER_CA_IP \
    --restart=on-failure:1 \
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/infrastructure/src/fabric_logo.png" \
    -p $AGER_CA_PORT:$AGER_CA_PORT \
    -p $AGER_CA_OPPORT:$AGER_CA_OPPORT \
    -v $LOCAL_SRV_DIR:$HOST_SRV_DIR \
    -e FABRIC_CA_SERVER_LOGLEVEL=$FABRIC_CA_SERVER_LOGLEVEL \
    hyperledger/fabric-ca:latest \
    sh -c "fabric-ca-server start -b $AGER_CA_NAME:$AGER_CA_SECRET \
    --home $HOST_SRV_DIR"

# Waiting Container startup
CheckContainer "$AGER_CA_NAME" "$DOCKER_WAIT"
CheckContainerLog "$AGER_CA_NAME" "Listening on https://0.0.0.0:$AGER_CA_PORT" "$DOCKER_WAIT"

log_ok "$AGER_CA_NAME started."

chmod -R 750 $SCRIPTDIR/../../infrastructure

# chmod -R 777 /mnt/user/appdata/jedo/demo/infrastructure
