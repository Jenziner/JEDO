# OpenSSL root CA configuration file
How to use:
## Preparation
1. mkdir temp
2. cp ca.cnf ./temp/ca.cnf
3. cd temp
4. touch index.txt serial
5. echo 1000 > serial
6. echo 1000 > crlnumber

## Root-CA
1. openssl ecparam -name prime256v1 -genkey -noout -out rca.key
2. openssl req -config ca.cnf -new -x509 -sha256 -extensions v3_ca  \
    -key rca.key \
    -out rca.cert \
    -days 3650 \
    -subj "/C=jd/ST=prod/L=/O=/CN=rca.jedo.me"

## Vault
1. openssl ecparam -name prime256v1 -genkey -noout -out vault.jedo.me.key
2. openssl req -new -sha256 \
    -key vault.jedo.me.key \
    -out vault.jedo.me.csr \
    -config vault-server.cnf
3. openssl ca -batch -config vault-server.cnf \
    -extensions v3_server \
    -days 365 -notext -md sha256 \
    -in vault.jedo.me.csr \
    -out vault.jedo.me.cert
4. cat vault.jedo.me.cert rca.cert > vault.jedo.me-chain.cert
  

# Local Master: tws_ai@pop-os:~/Dokumente/JEDO


# TODO/REDO
## Orbis-CA
### msp.jedo.me:
1. openssl ecparam -name prime256v1 -genkey -noout -out msp-jedo-me.key
2. openssl req -new -sha256 -key msp-jedo-me.key -out msp-jedo-me.csr -subj "/C=XX/ST=prod/L=orbis/O=JEDO/CN=msp.jedo.me"
3. openssl ca -batch -config ca.cnf -extensions v3_intermediate_ca -days 365 -notext -md sha256 -in msp-jedo-me.csr -out msp-jedo-me.cert
4. cat msp-jedo-me.cert rca.cert > msp-jedo-me-chain.cert

### msp.jedo.cc:
1. openssl ecparam -name prime256v1 -genkey -noout -out msp-jedo-cc.key
2. openssl req -new -sha256 -key msp-jedo-cc.key -out msp-jedo-cc.csr -subj "/C=XX/ST=demo/L=orbis/O=JEDO/CN=msp.jedo.cc"
3. openssl ca -batch -config ca.cnf -extensions v3_intermediate_ca -days 365 -notext -md sha256 -in msp-jedo-cc.csr -out msp-jedo-cc.cert
4. cat msp-jedo-cc.cert rca.cert > msp-jedo-cc-chain.cert

### msp.jedo.dev:
1. openssl ecparam -name prime256v1 -genkey -noout -out msp-jedo-dev.key
2. openssl req -new -sha256 -key msp-jedo-dev.key -out msp-jedo-dev.csr -subj "/C=XX/ST=dev/L=orbis/O=JEDO/CN=msp.jedo.dev"
3. openssl ca -batch -config ca.cnf -extensions v3_intermediate_ca -days 365 -notext -md sha256 -in msp-jedo-dev.csr -out msp-jedo-dev.cert
4. cat msp-jedo-dev.cert rca.cert > msp-jedo-dev-chain.cert


