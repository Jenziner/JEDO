# Regnum CA Bootstrap

This package provides the CA infrastructure for a Regnum.

## Contents

This package has been prepared by Orbis/JEDO for your Regnum CA.

- `README.md`  
  This installation guide.
- `config/regnum.yaml`  
  Configuration (name, IP, ports, passwords).
- `scripts/regnum-generate-csr.sh`  
  Generates key and CSR files for the respective CA (TLS or MSP).
- `scripts/regnum-install-cert.sh`  
  Installs the certificates signed by Orbis and the CA config file.
- `scripts/regnum-enroll-msp.sh`  
  Enrolls the TLS certificate for the MSP CA.
- `scripts/regnum-start-ca.sh`  
  Starts the respective Regnum CA in Docker.
- `scripts/regnum-register-ager.sh`  
  Register all Identities of an Ager according provided agger.yaml.
- `scripts/utils.sh`  
  Helper functions for script control.
- `scripts/prereq.sh`  
  Script that checks the local prerequisites.

## Prerequisites

- Docker installed.

## Steps

1. Extract the archive.
2. Adjust IPs/ports in `config/regnum.yaml` to match your environment.
3. Generate crypto material:
   1. For TLS: `./scripts/regnum-generate-csr.sh tls new` (optionally with `--debug`).
   2. For MSP: `./scripts/regnum-generate-csr.sh msp new` (optionally with `--debug`).
4. According to the script output, send the encrypted tar file and the password to Orbis.
5. Orbis signs the CSR and sends back an encrypted tar file containing `cert` and `chain` (same password).
6. Start the TLS CA:
   1. `./scripts/regnum-install-cert.sh tls myTLSPassword` (optionally with `--debug`).
   2. `./scripts/regnum-start-ca.sh tls myTLSPassword` (optionally with `--debug`, starts the CA with DEBUG flag).
   3. `docker logs <regnum-tls-name>`.
   4. `curl -k https://<regnum-tls-ip>:<regnum-tls-port>/cainfo`.
7. Enroll TLS certificates for the MSP CA:
   1. `./scripts/regnum-enroll-msp.sh myTLSPassword myMSPPassword` (optionally with `--debug`).
8. Start the MSP CA:
   1. `./scripts/regnum-install-cert.sh msp myMSPPassword` (optionally with `--debug`).
   2. `./scripts/regnum-start-ca.sh msp myMSPPassword` (optionally with `--debug`, starts the CA with DEBUG flag).
   3. `docker logs <regnum-msp-name>`.
   4. `curl -k https://<regnum-msp-ip>:<regnum-msp-port>/cainfo`.

Your Regnum is now ready to register and enroll Ager CAs, admins, and nodes.

To register the Identities of an Ager:
`./scripts/regnum-install-cert.sh myTLSPassword myMSPPassword ager-yaml-filename` (optionally with `--debug`).

To list all Identities:
`./scripts/regnum-install-cert.sh myTLSPassword myMSPPassword ager-yaml-filename --listonly` (optionally with `--debug`).

---

# Regnum CA Operations

## Stopping the CA and restarting with an updated Regnum config

If you need to change `config/regnum.yaml` or the CA config, you must stop the CA cleanly and then restart it with the new settings.

- **Stop the CA**

  ```
  docker stop <type>.<regnum>.jedo.<tld>
  docker rm <type>.<regnum>.jedo.<tld>
  ```

  This removes only the container; the configuration and certificates in the mounted volume remain untouched.

- **Adjust the config**

  - Update `config/regnum.yaml` as needed (IP, ports, log level, etc.).

- **Start the CA with the updated config**

  ```
  cd scripts
  ./regnum-start-ca.sh <type> myPassword
  ```

  The script reads the updated YAML file and starts a new container using the existing certificates and keys.

## Certificate renewal (CA rollover)

At some point the Regnum CA certificate will expire, or you may want to perform a rollover for security reasons. Since the Regnum CA is an intermediate under the offline Orbis CA, the process should be controlled and scheduled within a maintenance window.

**1. Preparation: generate a new CSR**

- Stop the CA:

  ```
  docker stop <type>.<regnum>.jedo.<tld>
  docker rm <type>.<regnum>.jedo.<tld>
  ```

- Based on the existing key you can either:
  - reuse the existing key (new certificate only):  
    `./scripts/regnum-generate-csr.sh <type> renew`
  - or generate a new key pair (recommended for a real rollover):  
    `./scripts/regnum-generate-csr.sh <type> new`

  This script creates a new CSR in `ca/<type>/`, which must be sent to the offline Orbis CA.

**2. Install the signed certificate + new chain from Orbis**

- After Orbis has signed the CSR, you will receive:
  - `*.cert.pem` (new intermediate CA certificate)  
  - `*.chain.pem` (current chain).

**3. Restart the CA**

1. `./scripts/regnum-install-cert.sh <type> myPassword` (optionally with `--debug`)
2. `./scripts/regnum-start-ca.sh <type> myPassword` (optionally with `--debug`, starts the CA with DEBUG flag)
3. `docker logs <regnum-name>`
4. `curl -k https://<regnum-ip>:<regnum-port>/cainfo`

The CA should now run with the new CA certificate; existing client certificates remain valid as long as they can be validated against the new chain.

**4. Communication to downstream participants**

To ensure that peers, orderers and other CAs in the Regnum hierarchy trust the new chain, the Regnum operator should:

- distribute the updated MSP chain to the `cacerts`/`intermediatecerts` directories of all relevant org MSPs,  
- update genesis/channel configurations in a maintenance window if the visible „root of trust“ changes in the consortium.


# Notes
## Regnum TLS-CA
ca:
  name: tls.ea.jedo.cc
  keyfile: /etc/hyperledger/fabric-ca-server/ca/tls-ea-ca.key
  certfile: /etc/hyperledger/fabric-ca-server/ca/cert.pem
  chainfile: /etc/hyperledger/fabric-ca-server/ca/chain.cert

tls:
  enabled: true  # Client-Auth
  clientauth:
    type: RequireAndVerifyClientCert
    certfiles:
      - /etc/hyperledger/tls-ca-roots/tls.ea.jedo.cc.pem

## Regnum MSP-CA
ca:
  name: msp.ea.jedo.cc
  keyfile: /etc/hyperledger/fabric-ca-server/ca/msp-ea-ca.key
  certfile: /etc/hyperledger/fabric-ca-server/ca/cert.pem
  chainfile: /etc/hyperledger/fabric-ca-server/ca/chain.cert

tls:
  enabled: true
  certfile: /etc/hyperledger/fabric-ca-server/tls/signcerts/cert.pem
  keyfile: /etc/hyperledger/fabric-ca-server/tls/keystore/key.pem

**Client Auth for MSP-CA**
clientauth:
  type: RequireAndVerifyClientCert
  certfiles:
    - /etc/hyperledger/fabric-ca-server/tls-ca-roots/tls.ea.jedo.cc.pem

**Use of Client Auth**
fabric-ca-client enroll \
  -u https://user:pw@msp.ea.jedo.cc:7055 \
  --tls.certfiles /path/to/tls-ca-root.pem \
  --tls.client.certfile /path/to/client-tls-cert.pem \  # Neu!
  --tls.client.keyfile /path/to/client-tls-key.pem      # Neu!

