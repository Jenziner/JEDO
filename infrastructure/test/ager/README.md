# Ager Installation

This package provides the infrastructure for an Ager.

## Contents

This package has been prepared by Orbis/JEDO for your Regnum CA.

- `README.md`  
  This installation guide.
- `config/ager-certs.yaml`  
  Configuration for certificates (name, secrets).
- `config/ager-infra.yaml`  
  Configuration for infrastructure (name, IP, ports).
- `scripts/ager-start-ca.sh`  
  Enrolls Server-Certs and starts Ager-MSP-CA.
- `scripts/ager-start-orderer.sh`  
  Enrolls Server-Certs and starts all Ager-Orderer.
<!-- - `scripts/regnum-install-cert.sh`  
  Installs the certificates signed by Orbis and the CA config file.
- `scripts/regnum-enroll-msp.sh`  
  Enrolls the TLS certificate for the MSP CA.
- `scripts/regnum-start-ca.sh`  
  Starts the respective Regnum CA in Docker.
- `scripts/utils.sh`  
  Helper functions for script control.
- `scripts/prereq.sh`  
  Script that checks the local prerequisites. -->

## Prerequisites

- Docker installed.

## Steps

1. Extract the archive.
2. Register Ager identities:
  1. Copy `cp config/ager-certs.yaml config/<myAgerName>-certs.yaml`.
  2. Adjust names/secrets in `config/<myAgerName>-certs.yaml` to match your environment.
  3. Copy `tls-ca-cert.pem`to your config directory (you get this from regnum: ./ca/cert.pem).
  4. to generate crypto material, send `config/<myAgerName>.yaml` to your Regnum within an encrypted tar.
2. Prepare your Infrastructure
  1. Copy `cp config/ager-infra.yaml config/<myAgerName>-infra.yaml`.
3. Install your MSP-CA.
  1. Run `./scripts/ager-start-ca.sh <myAgerName>-certs.yaml <myAgerName>-infra.yaml` (optionally with `--debug`).
4. Install your Orderers.
  1. Run `./scripts/ager-start-orderer.sh <myAgerName>-certs.yaml <myAgerName>-infra.yaml` (optionally with `--debug`).
5. Install your Peers.
6. Install your Servicecs.
7. Install your Gateway.
8. Join the channels.

Your Ager is now ready to participate.

---

# Notes
ca:
  name: msp.alps.ea.jedo.cc

**Intermediate Configuration**
intermediate:
  parentserver:
    url: https://bootstrap.msp.ea.jedo.cc:password@msp.ea.jedo.cc:7055
    caname: msp.ea.jedo.cc
  enrollment:
    profile: ca
    hosts: 'msp.alps.ea.jedo.cc,localhost'
  tls:
    certfiles:
      - /etc/hyperledger/fabric-ca-server/tls-ca-roots/tls.ea.jedo.cc.pem

tls:
  enabled: true
  certfile: /etc/hyperledger/fabric-ca-server/tls/signcerts/cert.pem
  keyfile: /etc/hyperledger/fabric-ca-server/tls/keystore/key.pem

**Client Auth**
clientauth:
  type: RequireAndVerifyClientCert
  certfiles:
    - /etc/hyperledger/fabric-ca-server/tls-ca-roots/tls.ea.jedo.cc.pem

**Use of Client Auth**
fabric-ca-client enroll \
  -u https://user:pw@msp.ea.jedo.cc:7055 \
  --tls.certfiles /path/to/tls-ca-root.pem \
  --tls.client.certfile /path/to/client-tls-cert.pem \
  --tls.client.keyfile /path/to/client-tls-key.pem
