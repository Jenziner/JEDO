###############################################################
#!/bin/bash
#
# This script starts Root-CA and generates certificates for Intermediate-CA
# 
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
check_script


###############################################################
# Params
###############################################################
CONFIG_FILE="$SCRIPT_DIR/infrastructure-dev.yaml"
DOCKER_UNRAID=$(yq eval '.Docker.Unraid' $CONFIG_FILE)
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $CONFIG_FILE)

TLS_NAME=$(yq eval ".TLS.Name" "$CONFIG_FILE")
TLS_PASS=$(yq eval ".TLS.Pass" "$CONFIG_FILE")

get_hosts

echo ""
echo_warn "TLS-CA starting... (Defaults: https://hyperledger-fabric-ca.readthedocs.io/en/latest/serverconfig.html)"


TLSS=$(yq eval ".TLS.Hosts[].Name" $CONFIG_FILE)
for TLS in $TLSS; do
    ###############################################################
    # Params
    ###############################################################
    TLS_HOST_NAME=$(yq eval ".TLS.Hosts[] | select(.Name == \"$TLS\") | .Name" "$CONFIG_FILE")
    TLS_HOST_IP=$(yq eval ".TLS.Hosts[] | select(.Name == \"$TLS\") | .IP" "$CONFIG_FILE")
    TLS_HOST_PORT=$(yq eval ".TLS.Hosts[] | select(.Name == \"$TLS\") | .Port" "$CONFIG_FILE")
    TLS_HOST_OPPORT=$(yq eval ".TLS.Hosts[] | select(.Name == \"$TLS\") | .OpPort" "$CONFIG_FILE")
    TLS_HOST_OPENSSL=$(yq eval ".TLS.Hosts[] | select(.Name == \"$TLS\") | .OpenSSL" "$CONFIG_FILE")

    LOCAL_INFRA_DIR=${PWD}/infrastructure
    LOCAL_KEYS_DIR=${PWD}/infrastructure/_root/$TLS_HOST_NAME/keys
    LOCAL_SRV_DIR=${PWD}/infrastructure/_root/$TLS_HOST_NAME/server
    LOCAL_CLI_DIR=${PWD}/infrastructure/_root/$TLS_HOST_NAME/client

    HOST_INFRA_DIR=/etc/infrastructure
    HOST_KEYS_DIR=/etc/hyperledger/keys
    HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server
    HOST_CLI_DIR=/etc/hyperledger/fabric-ca-client

    mkdir -p $LOCAL_KEYS_DIR/tls $LOCAL_SRV_DIR $LOCAL_CLI_DIR


  ###############################################################
  # Write TLS-CA SERVER config
  ###############################################################
  echo ""
  echo_info "fabric-ca-server-config.yaml for $TLS_NAME generating..."

  cat <<EOF > $LOCAL_SRV_DIR/fabric-ca-server-config.yaml
---
version: 0.0.1
port: $TLS_HOST_PORT
debug: true
tls:
    enabled: true
    clientauth:
        type: noclientcert
        certfiles:
ca:
    name: $TLS_HOST_NAME
crl:
registry:
    maxenrollments: 1
    identities:
        - name: $TLS_NAME
          pass: $TLS_PASS
          type: client
          affiliation: "jedo.root"
          attrs:
            hf.Registrar.Roles: "*"
            hf.Registrar.DelegateRoles: "*"
            hf.Revoker: true
            hf.IntermediateCA: true
            hf.GenCRL: true
            hf.Registrar.Attributes: "*"
            hf.AffiliationMgr: true
affiliations:
    jedo:
        - root
        - ea
        - as
        - af
        - na
        - sa
signing:
    default:
        usage:
          - digital signature
        expiry: 8760h
    profiles:
        tls:
            usage:
              - signing
              - key encipherment
              - server auth
              - client auth
              - key agreement
            expiry: 8760h
csr:
    cn: $TLS_NAME
    keyrequest:
        algo: ecdsa
        size: 384
    names:
        - C: JD
          ST: "Dev"
          L:
          O: JEDO
          OU: Root
    hosts:
        - $TLS_NAME
        - $TLS_HOST_NAME
        - $TLS_HOST_IP
    ca:
        expiry: 131400h
        pathlength: 1
idemix:
    curve: gurvy.Bn254
operations:
    listenAddress: $TLS_HOST_IP:$TLS_HOST_OPPORT
    tls:
#        enabled: true
#        cert:
#            file:
#        key:
#            file:
#        clientAuthRequired: false
#        clientRootCAs:
#            files: []
EOF


    ###############################################################
    # Start TLS-CA Host
    ###############################################################
    echo ""
    echo_info "TLS-CA $TLS_HOST_NAME starting..."
    docker run -d \
        --name $TLS_HOST_NAME \
        --network $DOCKER_NETWORK_NAME \
        --ip $TLS_HOST_IP \
        $hosts_args \
        --restart=on-failure:1 \
        --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/src/fabric_ca_logo.png" \
        -p $TLS_HOST_PORT:$TLS_HOST_PORT \
        -p $TLS_HOST_OPPORT:$TLS_HOST_OPPORT \
        -v $LOCAL_SRV_DIR:$HOST_SRV_DIR \
        -v $LOCAL_CLI_DIR:$HOST_CLI_DIR \
        -v $LOCAL_KEYS_DIR:$HOST_KEYS_DIR \
        -v $LOCAL_INFRA_DIR:$HOST_INFRA_DIR \
        hyperledger/fabric-ca:latest \
        sh -c "fabric-ca-server start -b $TLS_NAME:$TLS_PASS \
        --home $HOST_SRV_DIR" 

    # Waiting TLS-CA Host startup
    CheckContainer "$TLS_HOST_NAME" "$DOCKER_CONTAINER_WAIT"
    CheckContainerLog "$TLS_HOST_NAME" "Listening on https://0.0.0.0:$TLS_HOST_PORT" "$DOCKER_CONTAINER_WAIT"

    # copy tls-cert.pem to key directory
    cp $LOCAL_SRV_DIR/tls-cert.pem $LOCAL_KEYS_DIR/tls/tls-cert.pem

    # Installing OpenSSL
    if [[ $TLS_HOST_OPENSSL = true ]]; then
        echo_info "OpenSSL installing..."
        docker exec $TLS_HOST_NAME sh -c 'command -v apk && apk update && apk add --no-cache openssl || (apt-get update && apt-get install -y openssl)'
        CheckOpenSSL "$TLS_HOST_NAME" "$DOCKER_CONTAINER_WAIT"
    fi


    ###############################################################
    # Write CLIENT config
    ###############################################################
    echo ""
    echo_info "fabric-ca-client-config.yaml generating... (Defaults: https://hyperledger-fabric-ca.readthedocs.io/en/latest/serverconfig.html)"

    mkdir -p $LOCAL_CLI_DIR
    cat <<EOF > $LOCAL_CLI_DIR/fabric-ca-client-config.yaml
---
url: https://$TLS_HOST_NAME:$TLS_HOST_PORT
mspdir: msp
tls:
    certfiles: $HOST_KEYS_DIR/tls/tls-cert.pem
    client:
      certfile:
      keyfile:
csr:
    cn: $TLS_NAME
    keyrequest:
        algo: ecdsa
        size: 384
    names:
        - C: JD
          ST: "Dev"
          L:
          O: JEDO
          OU: Root
    hosts:
        - $TLS_NAME
        - $TLS_HOST_NAME
        - $TLS_HOST_IP
enrollment:
    profile: tls
caname: $TLS_HOST_NAME
idemixCurveID: gurvy.Bn254
EOF


    ###############################################################
    # Enroll TLS-CA
    ###############################################################
    echo ""
    echo_info "TLS enrolling..."
    docker exec -it $TLS_HOST_NAME fabric-ca-client enroll -u https://$TLS_NAME:$TLS_PASS@$TLS_HOST_NAME:$TLS_HOST_PORT \
        --home $HOST_CLI_DIR --mspdir $HOST_KEYS_DIR/msp

done


###############################################################
# Last Tasks
###############################################################
chmod -R 777 infrastructure
echo_ok "TLS-CA started."
