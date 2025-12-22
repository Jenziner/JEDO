# Vault Setup on a VPS

## Overview

This document describes the installation and configuration of HashiCorp Vault as the central secrets management service for the JEDO ecosystem on a VPS.

**Goal**: Operate Vault at `https://vault.jedo.me:8200` with Raft integrated storage as a highly available, TLS‑secured secrets backend for all locations.

## System Specifications

- **Provider**: Infomaniak VPS  
- **Resources**: 4 GB RAM, 2 vCPU, IPv4  
- **Operating System**: Ubuntu 24.04 LTS  
- **Vault Version**: 1.17.0 (server and CLI)  
- **Docker Version**: 29.1.3  
- **Container Runtime**: Docker with Docker Compose  

## DNS and Networking

- **DNS A record**: `vault.jedo.me` → `83.228.219.30`  
- **Firewall (VPS level)** – Allowed inbound:
  - Port 8200 (HTTPS Vault API & UI)
  - Port 8201 (Vault cluster traffic, typically internal only / restricted)

## Installation & Hardening

1. **System update**

   - Keep the OS up to date:
     - `sudo apt update && sudo apt upgrade -y`  

2. **SSH hardening**

   - Managed by VPS provider; no additional changes applied.  

3. **Firewall configuration**

   - Restrict inbound ports to: 8200, 8201.
   - Optionally restrict 8201 (cluster) to internal networks only.  

4. **Docker and Docker Compose installation**

   - Install Docker engine and Compose plugin as per Docker’s official instructions.  

5. **TLS certificate for `vault.jedo.me`**

   - Create a certificate via JEDO RootCA, see root-certificates.md
   - Place resulting certificate and key into:
     - `/home/ubuntu/vault/config/vault.crt`
     - `/home/ubuntu/vault/config/vault.key`  

6. **Vault configuration (Raft + TLS)**

   - Directory layout:
     - `/home/ubuntu/vault/config` – Vault configuration and TLS certs
     - `/home/ubuntu/vault/data` – Raft storage data
     - `/home/ubuntu/vault/logs` – logs (if needed)  

   - Vault server configuration file: `/home/ubuntu/vault/config/vault.hcl`:

     ```hcl
     ui = true

     api_addr     = "https://vault.jedo.me:8200"
     cluster_addr = "https://vault.jedo.me:8201"

     storage "raft" {
       path    = "/vault/data"
       node_id = "vault-node-1"
     }

     listener "tcp" {
       address       = "0.0.0.0:8200"
       tls_disable   = 0
       tls_cert_file = "/vault/config/vault.crt"
       tls_key_file  = "/vault/config/vault.key"
     }

     log_level = "info"
     ```

   - Ensure `vault.crt` includes `vault.jedo.me` as a valid hostname.

7. **Docker Compose deployment**

   - Compose file: `/home/ubuntu/vault/docker-compose.yml`:

     ```yaml
     services:
       vault:
         image: hashicorp/vault:1.17.0
         container_name: vault
         restart: unless-stopped
         ports:
           - "8200:8200"
         volumes:
           - /home/ubuntu/vault/config:/vault/config
           - /home/ubuntu/vault/data:/vault/data
           - /home/ubuntu/vault/logs:/vault/logs
         cap_add:
           - IPC_LOCK
         entrypoint: ["vault"]
         command: ["server", "-config=/vault/config/vault.hcl"]
     ```

   - Initialize directories and permissions on host:
     - `mkdir -p /home/ubuntu/vault/{config,data,logs}`
     - `chown -R ubuntu:ubuntu /home/ubuntu/vault`
     - Ensure `/home/ubuntu/vault/data` is writable by the Vault container user (pragmatically: `chmod -R 0777 /home/ubuntu/vault/data`).

   - Start Vault:
     - `cd /home/ubuntu/vault`
     - `docker compose up -d`

8. **Vault CLI setup (on the VPS)**

   - Install the Vault CLI binary and place it in `/usr/local/bin/vault`.
   - Verify:
     - `vault --version`  

9. **TLS verification and environment variables**

   - If the certificate is not trusted by the system yet:
     - `export VAULT_SKIP_VERIFY=true`
   - Set Vault address:
     - `export VAULT_ADDR="https://vault.jedo.me:8200"`  

10. **Initialization and unseal**

    - Check status:
      - `vault status`
    - Initialize:
      - `vault operator init`
    - Safely store:
      - All generated **Unseal Keys** (e.g. 5 shares, threshold 3)
      - **Initial Root Token**
      - Store them in a password manager (e.g. 1Password), ideally in separate entries.
    - Unseal Vault:
      - Run `vault operator unseal` multiple times with different Unseal Keys until `Sealed: false`.

11. **Smoke tests**

    - Check status:
      - `vault status`
    - Login with Root Token:
      - `vault login <root-token>`
    - Enable a KV engine:
      - `vault secrets enable -path=kv kv-v2`
    - Write a test secret:
      - `vault kv put kv/test foo=bar`
    - Read it back:
      - `vault kv get kv/test`
    - Access UI:
      - Browser → `https://vault.jedo.me:8200/ui` and login with Root Token.

## Troubleshooting Common Issues

### TLS: Certificate Unknown / Browser Warning

**Problem**: Browser or CLI warns: `x509: certificate signed by unknown authority`.

**Causes & Solutions**:
- Certificate is self‑signed or from a private CA  
  - Import the CA root certificate into system/browser trust store.
- Vault CLI:
  - For initial tests: `export VAULT_SKIP_VERIFY=true`.
- Wrong certificate/key in `vault.hcl`  
  - Verify `tls_cert_file` and `tls_key_file` paths and that files match.

### “address already in use” on port 8200

**Problem**: Logs show `Error initializing listener of type tcp: listen tcp 0.0.0.0:8200: bind: address already in use`.

**Causes & Solutions**:
- Another process or container already listening on 8200  
  - On host: `sudo ss -tulpn | grep 8200`
  - Stop conflicting service or change port mapping in Docker Compose.
- Misconfigured multiple Vault listeners  
  - Ensure only a single `listener "tcp"` block on port 8200 in all configs.
- Stale containers
  - `docker compose down --remove-orphans`
  - `docker ps` to confirm no extra Vault containers.

### Raft “permission denied” on `/vault/data/vault.db`

**Problem**: Logs show `failed to open bolt file ... permission denied`.

**Cause**: Vault process cannot read/write `/vault/data`.

**Solution**:
- On host:
  - `chown -R ubuntu:ubuntu /home/ubuntu/vault/data`
  - `chmod -R 0777 /home/ubuntu/vault/data` (pragmatic single‑node solution)
- Restart Vault:
  - `docker compose down && docker compose up -d`
- Check logs again for Raft initialization.

### Vault already initialized / unknown Unseal Keys

**Problem**: `vault operator init` → `Vault is already initialized` and unseal keys are missing.

**Cause**: Vault was initialized earlier; keys were not recorded.

**Solution**:
- If keys are lost and data is disposable:
  1. Stop Vault: `docker compose down`
  2. Delete Raft data: `rm -rf /home/ubuntu/vault/data/*`
  3. Start Vault: `docker compose up -d`
  4. Re‑run `vault operator init` and **store new Unseal Keys + Root Token** carefully.

### Vault CLI cannot connect (TLS / hostname)

**Problem**: `vault status` fails with TLS errors or connection refused.

**Causes & Solutions**:
- Wrong `VAULT_ADDR`  
  - Ensure: `export VAULT_ADDR="https://vault.jedo.me:8200"`
- TLS hostname mismatch  
  - Certificate must contain `vault.jedo.me` in SAN.
- Port not exposed / container not running  
  - `docker compose ps`
  - `docker logs vault`

## Backup Strategy (to implement)

### Important data for backup

- Vault configuration: `/home/ubuntu/vault/config/vault.hcl`  
- TLS certificates: `/home/ubuntu/vault/config/vault.crt`, `/home/ubuntu/vault/config/vault.key`  
- Raft data: `/home/ubuntu/vault/data/` (contains all Vault data; treat as highly sensitive)  

### Backup procedure

1. **Stop Vault**

   ```bash
   cd /home/ubuntu/vault
   docker compose down
   ```

2. **Create backup archive**

   ```bash
   cd /home/ubuntu
   sudo tar czf vault-backup-$(date +%Y%m%d).tar.gz \
     vault/config/vault.hcl \
     vault/config/vault.crt \
     vault/config/vault.key \
     vault/data
   ```

3. **Start Vault again**

   ```bash
   cd /home/ubuntu/vault
   docker compose up -d
   ```

4. **Store backup**

   - Transfer backup archive to secure, off‑server storage.

## Maintenance & Updates

### Updating Vault container

1. Create a fresh backup (see above).  
2. Update image version in `docker-compose.yml` (e.g. `hashicorp/vault:1.18.x` when released).  
3. Pull new image:
   - `docker compose pull`
4. Restart Vault:
   - `docker compose down && docker compose up -d`
5. Verify:
   - `vault status`
   - Check logs for Raft or TLS issues.

### System updates

- Regularly:
  - `sudo apt update && sudo apt upgrade -y`
- After kernel updates:
  - `sudo reboot`

## References

- Vault Documentation: https://developer.hashicorp.com/vault/docs  
- Integrated Storage (Raft): https://developer.hashicorp.com/vault/docs/configuration/storage/raft  
- TCP Listener Configuration: https://developer.hashicorp.com/vault/docs/configuration/listener/tcp