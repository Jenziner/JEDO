# Ager Installation

This package provides the infrastructure for an Ager.

## Contents

This package has been prepared by Orbis/JEDO for your Regnum CA.

- `README.md`  
  This installation guide.
- `config/ager.yaml`  
  Configuration (name, IP, ports, secrets).
<!-- - `scripts/regnum-generate-csr.sh`  
  Generates key and CSR files for the respective CA (TLS or MSP).
- `scripts/regnum-install-cert.sh`  
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
2. Copy `cp config/ager.yaml config/<myAgerName>.yaml`.
2. Adjust IPs/ports in `config/<myAgerName>.yaml` to match your environment.
3. to generate crypto material, send `config/<myAgerName>.yaml` to your Regnum within an encrypted tar.
4. Install your MSP-CA.
5. Install your Orderers.
6. Install your Peers.
7. Install your Servicecs.
8. Install your Gateway.
9. Join the channels.

Your Ager is now ready to participate.

---

