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
2. Install your MSP-CA.
  1. Copy `cp config/ager-infra.yaml config/<myAgerName>-infra.yaml`.
  2. Run `./scripts/ager-start-ca.sh <myAgerName>-certs.yaml <myAgerName>-infra.yaml` (optionally with `--debug`).
3. Install your Orderers.
4. Install your Peers.
5. Install your Servicecs.
6. Install your Gateway.
7. Join the channels.

Your Ager is now ready to participate.

---

