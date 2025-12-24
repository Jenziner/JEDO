#!/bin/bash
set -euo pipefail

SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGFILE="${SCRIPTDIR}/../config/regnum-ea.yaml"
OUTDIR="${SCRIPTDIR}/../ca/msp"

REGNUM_MSP_NAME=$(yq eval '.Regnum.MSP.Name' "${CONFIGFILE}")

# Erwartete Dateien von Orbis-Offline-CA:
#  - regnum-msp-ca.cert.pem
#  - regnum-msp-ca-chain.pem
# Du legst sie manuell nach ca/msp/ oder kopierst sie in dieses Script.

CERT_IN="${OUTDIR}/regnum-msp-ca.cert.pem"
CHAIN_IN="${OUTDIR}/regnum-msp-ca-chain.pem"

if [[ ! -f "${CERT_IN}" || ! -f "${CHAIN_IN}" ]]; then
  echo "Zertifikat oder Chain fehlt in ${OUTDIR}."
  echo "Erwartet: regnum-msp-ca.cert.pem und regnum-msp-ca-chain.pem"
  exit 1
fi

mkdir -p "${OUTDIR}/signcerts"
mkdir -p "${OUTDIR}/cacerts"
mkdir -p "${OUTDIR}/intermediatecerts"

# Signcerts: unser CA-Zertifikat
cp "${CERT_IN}" "${OUTDIR}/signcerts/cert.pem"

# Chain aufsplitten: Root/Intermediate
# Annahme: CHAIN_IN enthält Root + ggf. Intermediate.
# Du kannst es auch einfach komplett als chainfile nutzen.
cp "${CHAIN_IN}" "${OUTDIR}/intermediatecerts/chain.cert"

echo "==> Regnum-MSP-CA Zertifikat installiert."
echo "   signcerts/cert.pem"
echo "   intermediatecerts/chain.cert"

# Optional: Orbis-MSP-Chain als eigener Trust-Anker
ORBIS_CHAIN="$(yq eval '.Orbis.MSP.ChainFile' "${CONFIGFILE}")"
if [[ -n "${ORBIS_CHAIN}" && -f "${SCRIPTDIR}/../${ORBIS_CHAIN}" ]]; then
  cp "${SCRIPTDIR}/../${ORBIS_CHAIN}" "${OUTDIR}/cacerts/orbis-msp-chain.pem"
  echo "   cacerts/orbis-msp-chain.pem (Orbis-MSP-Chain)"
fi
