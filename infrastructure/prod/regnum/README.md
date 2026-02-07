# Steps to run infrastructure for a new REGNUM
This package provides the CA infrastructure for a REGNUM.


## Check prerequisites
```bash
./scripts/prereq.sh
```


## IMPORTANT
**Replace the placeholder in the .env file (Step 2 below) to match your environment!!**


## Filesystem and crypto material preparation
1. Copy files from `https://github.com/Jenziner/JEDO/tree/main/infrastructure/prod/regnum` to your server (e.g. `~/jedo/<regnum>.jedo.me`)
2. Rename .env `mv .env.template .env` and adjust the placeholder according your infrastructure.
3. Generate crypto material:
   1. For TLS: `./scripts/regnum-generate-csr.sh tls new` (optionally with `--debug`).
   2. For MSP: `./scripts/regnum-generate-csr.sh msp new` (optionally with `--debug`).
4. According to the script output, send the encrypted tar file and the password to Orbis.
5. Orbis signs the CSR and sends back an encrypted tar file containing `cert` and `chain` (same password).


## CA installation
```bash
./scripts/init-ca.sh tls      # copy crypto material and generates fabric-ca-server-config.yaml for TLS-CA
docker-compose up -d ca-tls
./scripts/enroll-tls.sh       # TLS CA enrollment
./scripts/init-ca.sh msp      # copy crypto material and generates fabric-ca-server-config.yaml for MSP-CA
docker-compose up -d ca-msp
./scripts/register-msp.sh     # MSP-CA registration @ TLS-CA
./scripts/enroll-msp.sh       # MSP-CA enrollment
```

## CA daily routines
### start CAs (e.g. after reboot)
`docker-compose up -d`

### stop CAs
`docker-compose down`

### view logs
`docker-compose logs -f`

### get status
`docker-compose ps`

