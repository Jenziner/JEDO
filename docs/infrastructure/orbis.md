# ORBIS

## Crypto Hierarchy (MSP & TLS)
Offline-Root in Vault
rca.jedo.me
├─ Regnum ea
│  ├─ msp.ea.jedo.me      (Regnum-MSP-CA, Intermediate von rca.jedo.me)
│  └─ tls.ea.jedo.me      (Regnum-TLS-CA, Intermediate von rca.jedo.me)
├─ Regnum as
│  ├─ msp.as.jedo.me
│  └─ tls.as.jedo.me
├─ Regnum af
│  ├─ msp.af.jedo.me
│  └─ tls.af.jedo.me
├─ Regnum na
│  ├─ msp.na.jedo.me
│  └─ tls.na.jedo.me
└─ Regnum sa
   ├─ msp.sa.jedo.me
   └─ tls.sa.jedo.me

## Crypto Store (in Vault)
/home/ubuntu/pki/
  root/
    rca.jedo.me.key             # Original-Key
    rca.jedo.me.cert            # Original-Root-Cert
    rca.bundle.pem              # Key + Cert for Vault import
  csr/                          # CSRs from Intermediate-PKI-Mounts (`intermediate/generate/internal`)
    msp.ea.jedo.dev.csr.pem
    msp.ea.jedo.cc.csr.pem
    msp.ea.jedo.me.csr.pem
    ...
  certs/                        # signed Intermediate-Certs
    msp.ea.jedo.dev.cert.pem
    msp.ea.jedo.cc.cert.pem
    ...
  chains/                       # complete chains (Intermediate + Root) for Fabric (Regnum)
    msp.ea.jedo.dev.chain.pem
    tls.ea.jedo.dev.chain.pem
    ...


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

## NEW REGNUM: Create intermediate CAs for Regnum
New Regnum ordered:
1. TLS-CA: `tls.<regnum>.jedo.<tld>`
2. MSP-CA: `msp.<regnum>.jedo.<tld>`

What you need to adjust in the following:
- <type>: (tls|msp): tls
- <regnum>: ea
- <env> (dev|test|prod): dev
- <tld> (dev|cc|me): dev

What to do:
1. Login - Step 1
2. TLS: Step 2 with <type>=tls
3. MSP: Repeat Step 2 with <type>=msp
4. Deliver to Regnum with step 3

### 1. Login into Docker-Container
```bash
# Startup Vault-Container
cd /home/ubuntu/vault
docker compose up -d

# Use Vault-Container
docker exec -it vault sh

# Check Status
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

### 2. Create an intermediate PKI mount

```bash
# Add a mount path
vault secrets enable -path=pki-<type>-<regnum>-<env> pki

# 1 year validity
vault secrets tune -max-lease-ttl=8760h pki-<type>-<regnum>-<env>

# Check Path
vault secrets list

# Generate intermediate CSR
vault write -format=json pki-<type>-<regnum>-<env>/intermediate/generate/internal \
  common_name="<type>.<regnum>.jedo.<tld>" \
  country="jd" \
  province="<env>" \
  locality="<regnum>" \
  organization="" \
  ttl=8760h \
  key_type="ec" \
  key_bits="256" \
  format="pem" \
  > /vault/pki/csr/<type>.<regnum>.jedo.<tld>.csr.json

# Vault returns a CSR (`csr` field). Save it as `<type>.<regnum>.jedo.<tld>.csr.pem`.
cat /vault/pki/csr/<type>.<regnum>.jedo.<tld>.csr.json \
  | jq -r '.data.csr' \
  > /vault/pki/csr/<type>.<regnum>.jedo.<tld>.csr.pem


# Sign intermediate with root
vault write -format=json pki-root/root/sign-intermediate \
  csr=@/vault/pki/csr/<type>.<regnum>.jedo.<tld>.csr.pem \
  format="pem_bundle" \
  ttl=8760h \
  use_csr_values=true \
  > /vault/pki/certs/<type>.<regnum>.jedo.<tld>.cert.json

# Extract cert only
cat /vault/pki/certs/<type>.<regnum>.jedo.<tld>.cert.json \
  | jq -r .data.certificate \
  > /vault/pki/certs/<type>.<regnum>.jedo.<tld>.cert.pem

# Check format: should start with -----BEGIN CERTIFICATE-----
head -n 5 /vault/pki/certs/<type>.<regnum>.jedo.<tld>.cert.pem

# The `pem_bundle` contains the intermediate cert plus the root chain.

# Import signed intermediate back into its PKI
vault write pki-<type>-<regnum>-<env>/intermediate/set-signed \
  certificate=@/vault/pki/certs/<type>.<regnum>.jedo.<tld>.cert.pem

# Check output
vault read -field=certificate pki-<type>-<regnum>-<env>/cert/ca | head

# Generate Chain
cat /vault/pki/certs/<type>.<regnum>.jedo.<tld>.cert.pem \
    /vault/pki/root/rca.cert \
  > /vault/pki/chains/<type>.<regnum>.jedo.<tld>.chain.pem
```

From this point, `pki-<type>-<regnum>-<env>` is a fully functional intermediate CA for TLS/MSP identities.

These files are what you hand over to the Regnum operators to bootstrap their MSP/TLS trust and to compute on‑chain fingerprints.

***

### 3. Delivery to new Regnum

```bash
# Save it locally 
scp jedo:/home/ubuntu/pki/chains/tls.<regnum>.jedo.<tld>.chain.pem ./ 
scp jedo:/home/ubuntu/pki/chains/msp.<regnum>.jedo.<tld>.chain.pem ./ 

# Compress and encrypt ist
tar cz tls.<regnum>.jedo.<tld>.chain.pem msp.<regnum>.jedo.<tld>.chain.pem \
  -f regnum-<regnum>-<env>-certs.tar.gz

# Deliver it to the new regnum

# Regnum can decompress
tar xz -f regnum-<regnum>-<env>-certs.tar.gz
```

***

## Renewal of Regnum CAs

When a Regnum CA is about to expire:

1. Use the same intermediate PKI mount (`pki-<type>-<regnum>-<env>`).  
2. Generate a new **self CSR** (or reuse `intermediate/generate/internal` if you also rotate the key).  
3. Sign it again with `pki-root/root/sign-intermediate`.  
4. Call `intermediate/set-signed` with the new certificate.  
5. Export updated CA/chain and update:
   - Orbis on‑chain registry (fingerprints) 
   - Fabric MSP/TLS config that trusts these CAs.


