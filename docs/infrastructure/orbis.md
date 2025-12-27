# ORBIS

## Crypto Hierarchy (MSP & TLS)
```
rca.jedo.me (Vault – Offline Root)
├── msp.ea.jedo.me / tls.ea.jedo.me
├── msp.as.jedo.me  / tls.as.jedo.me
├── msp.af.jedo.me  / tls.af.jedo.me
├── msp.na.jedo.me  / tls.na.jedo.me
└── msp.sa.jedo.me  / tls.sa.jedo.me
```

## Crypto Store (in Vault)
```
/home/ubuntu/pki/
  root/
    rca.jedo.me.key             # Original-Key
    rca.jedo.me.cert            # Original-Root-Cert
    rca.bundle.pem              # Key + Cert for Vault import
  csr/                          # CSRs from Intermediate-PKI-Mounts (`intermediate/generate/internal`)
```


## Using Vault as Offline Root CA for `rca.jedo.me`

This document describes how to operate the **global root CA** `rca.jedo.me` and how to create and renew the **Regnum CA certificates**:

Use Vault’s PKI secrets engine as **offline root CA** for `rca.jedo.me`.  

Issue **intermediate CA certificates** for:
  - MSP CAs: `msp.<regnum>.jedo.dev|cc|me`
  - TLS CAs: `tls.<regnum>.jedo.dev|cc|me`

Keep Vault **not exposed to the internet**, accessible only via SSH on the host (e.g. `127.0.0.1:8200`).  

Use **Raft storage** to make key recovery easier for your team.

Environment suffix:
- `*.dev` = development  
- `*.cc`  = test  
- `*.me`  = production  

---

## Vault server (offline mode) configuration

### 1. Vault configuration (`vault.hcl`):

```hcl
disable_mlock = true

listener "tcp" {
  address     = "127.0.0.1:8200"
  tls_disable = 1
}

storage "file" {
  path        = "/vault/data"
}

api_addr      = "http://127.0.0.1:8200"
cluster_addr  = "http://127.0.0.1:8201"

ui            = false
log_level     = "info"
```

### 2. Docker configuration (`docker-compose.yml`):

```yml
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
      - /home/ubuntu/pki:/vault/pki
    cap_add:
      - IPC_LOCK
    entrypoint: ["vault"]
    command: ["server", "-config=/vault/config/vault.hcl"]
```

### 3. Login into Docker-Container
```bash
# Startup Vault-Container
cd /home/ubuntu/vault
docker compose up -d

# Use Vault-Container - any further commands (init, unseal, PKI) are executed within the container
docker exec -it vault sh

# Install jq for file manipulation later - unsafe and must be repeated if container is rebuilt
apk update && apk add jq

# Check Status
export VAULT_ADDR=http://127.0.0.1:8200
vault status
```

Expected result:
```
Key                Value
---                -----
Seal Type          shamir
Initialized        true
Sealed             true
Total Shares       5
Threshold          3
Unseal Progress    0/3
Unseal Nonce       n/a
Version            1.17.0
Build Date         2024-06-10T10:11:34Z
Storage Type       file
HA Enabled         false
```

***

### 4. Unseal Vault
```bash
export VAULT_ADDR=http://127.0.0.1:8200
vault operator unseal
# Key 1 from your private safe (e.g. 1Password)
vault operator unseal
# Key 2
vault operator unseal
# Key 3
```

Expected result:
```
Key                     Value
---                     -----
Seal Type               shamir
Initialized             true
Sealed                  false
Total Shares            5
Threshold               3
Version                 1.17.0
Build Date              2024-06-10T10:11:34Z
Storage Type            file
Cluster Name            vault-cluster-8b088b6a
Cluster ID              bc293bb6-1251-ebb8-2ab4-0450c7e8c6db
HA Enabled              false
```

***

### 5. Enable PKI for `rca.jedo.me`

#### 5.1 Enable a root PKI engine

Mount a PKI engine to act as the global root:

```bash
vault secrets enable -path=pki-root pki
vault secrets tune -max-lease-ttl=87600h pki-root   # 10 years
```

#### 5.2 Import the root CA
1. Stack key and cert from local OpenSSL with `cat rca.key rca.cert > rca.bundle.pem`
2. SCP to Vault into `/home/ubuntu/pki/root`
3. `vault login` with Root Token
4. Write: `vault write pki-root/config/ca pem_bundle=@/vault/pki/root/rca.bundle.pem`
5. Check: `vault read -field=certificate pki-root/cert/ca | head`

This lets Vault manage the key from now on.

---

## Creating a new Regnum (External Intermediate)

### 1. Prepare from new Regnum

```bash
# save encrypted tar from regnum locally into:
cd ~/Downloads/pki-regnum

# Un-tar .csr-File
openssl enc -d -aes-256-cbc -salt -pbkdf2 \
  -in <type>.<regnum>.jedo.<tld>-csr.tar.gz.enc \
  -out <type>.<regnum>.jedo.<tld>-csr.tar.gz \
  -pass pass:<password>
tar -xzf <type>.<regnum>.jedo.<tld>-csr.tar.gz

# Save it to Vault
scp ./<type>.<regnum>.jedo.<tld>.csr jedo:/home/ubuntu/pki/<regnum>
```

***

### 2. Log into Vault
```bash
# Startup Vault-Container
cd /home/ubuntu/vault
docker compose up -d

# Use Vault-Container
docker exec -it vault sh

# check jq
jq --version  # optional install it: apk update && apk add jq

# Check Vault status
export VAULT_ADDR=http://127.0.0.1:8200
vault status

# Unseal 3x
vault operator unseal

# Login
vault login

# Check pki-root
vault read -field=certificate pki-root/cert/ca | head

# List current mounts
vault secrets list
```

***

### 3. Sign .csr-File
```bash
REGNUM="<regnum>"   # ea, as, af, na or sa
TYPE="<type>"    # msp or tls
TLD="<tld>"      # cc or me

# Sign intermediate with root
vault write -format=json pki-root/root/sign-intermediate \
  csr=@/vault/pki/${REGNUM}/${TYPE}.${REGNUM}.jedo.${TLD}.csr \
  format="pem" \
  ttl=8760h \
  use_csr_values=true \
  > /vault/pki/${REGNUM}/${TYPE}.${REGNUM}.jedo.${TLD}.cert.json

# Extract cert only
jq -r '.data.certificate' \
  /vault/pki/${REGNUM}/${TYPE}.${REGNUM}.jedo.${TLD}.cert.json \
  > /vault/pki/${REGNUM}/${TYPE}.${REGNUM}.jedo.${TLD}.cert.pem

# Check format: should start with -----BEGIN CERTIFICATE-----
head -n 5 /vault/pki/${REGNUM}/${TYPE}.${REGNUM}.jedo.${TLD}.cert.pem

# Build Chain
cat /vault/pki/${REGNUM}/${TYPE}.${REGNUM}.jedo.${TLD}.cert.pem /vault/pki/root/rca.cert \
  /vault/pki/${REGNUM}/${TYPE}.${REGNUM}.jedo.${TLD}.chain.pem
```

***

### 4. Delivery to new Regnum

```bash
REGNUM="<regnum>"   # ea, as, af, na or sa
TYPE="<type>"    # msp or tls
TLD="<tld>"      # cc or me
PASS="<oldPassword>"

# Save it locally 
scp jedo:/home/ubuntu/pki/${REGNUM}/${TYPE}.${REGNUM}.jedo.${TLD}.cert.pem ./ 
scp jedo:/home/ubuntu/pki/${REGNUM}/${TYPE}.${REGNUM}.jedo.${TLD}.chain.pem ./ 

# Compress cert
tar cz ${TYPE}.${REGNUM}.jedo.${TLD}.cert.pem ${TYPE}.${REGNUM}.jedo.${TLD}.chain.pem /
  -f ${TYPE}.${REGNUM}.jedo.${TLD}-certs.tar.gz

# Encrypt tar with same password
openssl enc -aes-256-cbc -salt -pbkdf2 \
  -in ${TYPE}.${REGNUM}.jedo.${TLD}-certs.tar.gz \
  -out ${TYPE}.${REGNUM}.jedo.${TLD}-certs.tar.gz.enc \
  -pass pass:${PASS}

# Deliver it to the new regnum

# Regnum can decompress
# openssl enc -d -aes-256-cbc -salt -pbkdf2 \
#   -in ${TYPE}.${REGNUM}.jedo.${TLD}-certs.tar.gz.enc \
#   -out ${TYPE}.${REGNUM}.jedo.${TLD}-certs.tar.gz \
#   -pass pass:${PASS}
# tar xz -f ${TYPE}.${REGNUM}.jedo.${TLD}-certs.tar.gz
```

***

### 5. Renewal

When a Regnum’s certificate nears expiration:

1. The Regnum re‑runs `regnum-generate-csr.sh` using the existing or a new key.  
2. Sends the new CSR to Orbis.  
3. Orbis signs it again in Vault following the same procedure.  
4. The new certificate replaces the old one within the Regnum CA without affecting existing identities (as long as the Root remains the same).

***




