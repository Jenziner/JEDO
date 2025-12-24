#!/bin/bash
set -euo pipefail

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASEDIR="${SCRIPTDIR}/.."
CONFIGFILE="${BASEDIR}/config/regnum.yaml"

DOCKER_NETWORK_NAME=$(yq eval '.Fabric.Docker.Network.Name // "jedo"' "${CONFIGFILE}" 2>/dev/null || echo "jedo")

ORBIS_ENV=$(yq eval '.Orbis.Env' "${CONFIGFILE}")

REGNUM_NAME=$(yq eval '.Regnum.Name' "${CONFIGFILE}")
REGNUM_MSP_NAME=$(yq eval '.Regnum.MSP.Name' "${CONFIGFILE}")
REGNUM_MSP_PASS=$(yq eval '.Regnum.MSP.Pass' "${CONFIGFILE}")
REGNUM_MSP_IP=$(yq eval '.Regnum.MSP.IP' "${CONFIGFILE}")
REGNUM_MSP_PORT=$(yq eval '.Regnum.MSP.Port' "${CONFIGFILE}")
REGNUM_MSP_OPPORT=$(yq eval '.Regnum.MSP.OpPort' "${CONFIGFILE}")

CA_DIR="${BASEDIR}/ca/msp"
HOST_CA_DIR="/etc/hyperledger/fabric-ca-server"

mkdir -p "${CA_DIR}"

echo "==> Starte Regnum-MSP-CA Container: ${REGNUM_MSP_NAME}"

# fabric-ca-server-config.yaml schreiben
cat > "${CA_DIR}/fabric-ca-server-config.yaml" <<EOF
---
version: 0.0.1

port: ${REGNUM_MSP_PORT}

tls:
  enabled: true
  certfile: ${HOST_CA_DIR}/tls/signcerts/cert.pem
  keyfile: ${HOST_CA_DIR}/tls/keystore/key.pem

ca:
  name: ${REGNUM_MSP_NAME}
  certfile: ${HOST_CA_DIR}/msp/signcerts/cert.pem
  keyfile: ${HOST_CA_DIR}/msp/keystore/regnum-msp-ca.key
  chainfile: ${HOST_CA_DIR}/msp/intermediatecerts/chain.cert

crl:
  expiry: 8760h

registry:
  maxenrollments: -1
  identities:
    - name: ${REGNUM_MSP_NAME}
      pass: ${REGNUM_MSP_PASS}
      type: client
      affiliation: jedo
      attrs:
        hf.Registrar.Roles: "client,user,admin"
        hf.Registrar.DelegateRoles: "client,user"
        hf.Revoker: true
        hf.GenCRL: true
        hf.IntermediateCA: true
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

csr:
  cn: ${REGNUM_MSP_NAME}
  names:
    - C: jd
      ST: ${ORBIS_ENV}
      L: ${REGNUM_NAME}
      O: 
      OU: 
  hosts:
    - ${REGNUM_MSP_NAME}
    - ${REGNUM_MSP_IP}

operations:
  listenAddress: ${REGNUM_MSP_IP}:${REGNUM_MSP_OPPORT}
  tls:
    enabled: false
EOF

# Docker Container starten
docker run -d \
  --name "${REGNUM_MSP_NAME}" \
  --network "${DOCKER_NETWORK_NAME}" \
  --ip "${REGNUM_MSP_IP}" \
  -p "${REGNUM_MSP_PORT}:${REGNUM_MSP_PORT}" \
  -p "${REGNUM_MSP_OPPORT}:${REGNUM_MSP_OPPORT}" \
  -v "${CA_DIR}:${HOST_CA_DIR}" \
  -e FABRIC_CA_SERVER_LOGLEVEL=info \
  hyperledger/fabric-ca:latest \
  sh -c "fabric-ca-server start -b ${REGNUM_MSP_NAME}:${REGNUM_MSP_PASS} --home ${HOST_CA_DIR}"
