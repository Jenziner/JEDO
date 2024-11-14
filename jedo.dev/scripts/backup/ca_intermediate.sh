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

ROOT_CA_NAME=$(yq eval ".Root.Name" "$CONFIG_FILE")
ROOT_TLSCA_NAME=$(yq eval ".Root.TLS-CA.Name" "$CONFIG_FILE")
ROOT_TLSCA_PASS=$(yq eval ".Root.TLS-CA.Pass" "$CONFIG_FILE")
ROOT_TLSCA_PORT=$(yq eval ".Root.TLS-CA.Port" "$CONFIG_FILE")
ROOT_ORGCA_NAME=$(yq eval ".Root.ORG-CA.Name" "$CONFIG_FILE")
ROOT_ORGCA_PASS=$(yq eval ".Root.ORG-CA.Pass" "$CONFIG_FILE")
ROOT_ORGCA_PORT=$(yq eval ".Root.ORG-CA.Port" "$CONFIG_FILE")

HOST_INFRA_DIR=/etc/infrastructure
HOST_TLS_KEYS_DIR=/etc/hyperledger/$ROOT_TLSCA_NAME
HOST_ORG_KEYS_DIR=/etc/hyperledger/$ROOT_ORGCA_NAME
HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server
HOST_CLI_DIR=/etc/hyperledger/fabric-ca-client

get_hosts

echo ""
echo_warn "Intermediate-CAs starting... (Defaults: https://hyperledger-fabric-ca.readthedocs.io/en/latest/serverconfig.html)"


INTERMEDIATS=$(yq e ".Intermediates[].Name" $CONFIG_FILE)
for INTERMEDIATE in $INTERMEDIATS; do
    ###############################################################
    # Params
    ###############################################################
    CA_NAME=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .Name" "$CONFIG_FILE")
    CA_ORG=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .Organization" "$CONFIG_FILE")
    CA_IP=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .IP" "$CONFIG_FILE")
    CA_OPENSSL=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .OpenSSL" "$CONFIG_FILE")

    TLSCA_NAME=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .TLS-CA.Name" "$CONFIG_FILE")
    TLSCA_PASS=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .TLS-CA.Pass" "$CONFIG_FILE")
    TLSCA_PORT=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .TLS-CA.Port" "$CONFIG_FILE")
    TLSCA_OPPORT=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .TLS-CA.OpPort" "$CONFIG_FILE")

    ORGCA_NAME=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .ORG-CA.Name" "$CONFIG_FILE")
    ORGCA_PASS=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .ORG-CA.Pass" "$CONFIG_FILE")
    ORGCA_PORT=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .ORG-CA.Port" "$CONFIG_FILE")
    ORGCA_OPPORT=$(yq eval ".Intermediates[] | select(.Name == \"$INTERMEDIATE\") | .ORG-CA.OpPort" "$CONFIG_FILE")

    LOCAL_INFRA_DIR=${PWD}/infrastructure
    LOCAL_TLS_KEYS_DIR=${PWD}/infrastructure/$CA_ORG/$TLSCA_NAME/keys
    LOCAL_ORG_KEYS_DIR=${PWD}/infrastructure/$CA_ORG/$ORGCA_NAME/keys
    LOCAL_SRV_DIR=${PWD}/infrastructure/$CA_ORG/$CA_NAME/server
    LOCAL_CLI_DIR=${PWD}/infrastructure/$CA_ORG/$CA_NAME/client


    ###############################################################
    # Generate certificates
    ###############################################################
    # Enroll Intermediate-TLS
    echo ""
    echo_info "Intermediate-TLS $TLSCA_NAME registering and enrolling..."
    docker exec -it $ROOT_CA_NAME fabric-ca-client register -u https://$ROOT_TLSCA_NAME:$ROOT_TLSCA_PASS@$ROOT_TLSCA_NAME:$ROOT_TLSCA_PORT \
        --tls.certfiles $HOST_TLS_KEYS_DIR/tls/tls-cert.pem \
        --caname $ROOT_TLSCA_NAME --home $HOST_CLI_DIR --mspdir $HOST_TLS_KEYS_DIR/msp \
        --csr.cn $TLSCA_NAME --csr.hosts ${TLSCA_NAME},${CA_IP},localhost,0.0.0.0 \
        --id.name $TLSCA_NAME --id.secret $TLSCA_PASS --id.type client --id.affiliation jedo.root \
        --id.attrs 'hf.IntermediateCA=true'
    docker exec -it $ROOT_CA_NAME fabric-ca-client enroll -u https://$TLSCA_NAME:$TLSCA_PASS@$ROOT_TLSCA_NAME:$ROOT_TLSCA_PORT \
        --tls.certfiles $HOST_TLS_KEYS_DIR/tls/tls-cert.pem \
        --caname $ROOT_TLSCA_NAME --home $HOST_CLI_DIR --mspdir $HOST_INFRA_DIR/$CA_ORG/$TLSCA_NAME/keys/msp \
        --csr.hosts "$TLSCA_NAME,$CA_IP,localhost,0.0.0.0,$ROOT_TLSCA_NAME" \
        --enrollment.attrs "hf.IntermediateCA" \
        --enrollment.profile tls

    echo ""
    echo_info "Intermediate-ORG $ORGCA_NAME registering and enrolling..."
    docker exec -it $ROOT_CA_NAME fabric-ca-client register -u https://$ROOT_ORGCA_NAME:$ROOT_ORGCA_PASS@$ROOT_ORGCA_NAME:$ROOT_ORGCA_PORT \
        --tls.certfiles $HOST_ORG_KEYS_DIR/tls/tls-cert.pem \
        --caname $ROOT_ORGCA_NAME --home $HOST_CLI_DIR --mspdir $HOST_ORG_KEYS_DIR/msp \
        --csr.cn $ORGCA_NAME --csr.hosts ${ORGCA_NAME},${CA_IP},localhost,0.0.0.0 \
        --id.name $ORGCA_NAME --id.secret $ORGCA_PASS --id.type client --id.affiliation jedo.root \
        --id.attrs 'hf.IntermediateCA=true'
    docker exec -it $ROOT_CA_NAME fabric-ca-client enroll -u https://$ORGCA_NAME:$ORGCA_PASS@$ROOT_ORGCA_NAME:$ROOT_ORGCA_PORT \
        --tls.certfiles $HOST_ORG_KEYS_DIR/tls/tls-cert.pem \
        --caname $ROOT_ORGCA_NAME --home $HOST_CLI_DIR --mspdir $HOST_INFRA_DIR/$CA_ORG/$ORGCA_NAME/keys/msp \
        --csr.hosts "$ORGCA_NAME,$CA_IP,localhost,0.0.0.0,$ROOT_ORGCA_NAME" \
        --enrollment.attrs "hf.IntermediateCA" \
        --enrollment.profile ca


#     ###############################################################
#     # Write TLS SERVER config
#     ###############################################################
#     echo ""
#     echo_info "fabric-ca-server-config.yaml for $TLSCA_NAME generating..."

#     mkdir -p $LOCAL_SRV_DIR

#     cat <<EOF > $LOCAL_SRV_DIR/fabric-ca-server-config.yaml
# ---
# version: 0.0.1

# port: $TLSCA_PORT

# debug: true

# tls:
#   enabled: true
#   clientauth:
#     type: noclientcert
#     certfiles:

# ca:
#   name: $TLSCA_NAME
#   keyfile: $HOST_TLS_KEYS_DIR/msp/keystore/$(basename $(ls $LOCAL_TLS_KEYS_DIR/msp/keystore/*_sk | head -n 1))
#   certfile: $HOST_TLS_KEYS_DIR/msp/signcerts/cert.pem

# crl:
# registry:
#   maxenrollments: 1

# affiliations:
#    jedo:
#       - root
#       - ea
#       - as
#       - af
#       - na
#       - sa

# signing:
#     default:
#       usage:
#         - digital signature
#       expiry: 8760h
#     profiles:
#       tls:
#         usage:
#           - cert sign
#           - crl sign
#           - signing
#           - key encipherment
#           - server auth
#           - client auth
#           - key agreement
#         expiry: 8760h

# csr:
#    keyrequest:
#      algo: ecdsa
#      size: 384
#    names:
#       - C: JD
#         ST: "Dev"
#         L:
#         O: JEDO
#         OU: Root
#    hosts:
#      - $TLSCA_NAME
#      - $CA_IP
#      - localhost
#      - 0.0.0.0
#    ca:
#       expiry: 131400h
#       pathlength: 2

# idemix:
#   curve: gurvy.Bn254

# operations:
#     listenAddress: $CA_IP:$TLSCA_OPPORT
#     tls:
# #        enabled: true
# #        cert:
# #            file:
# #        key:
# #            file:
# #        clientAuthRequired: false
# #        clientRootCAs:
# #            files: []
# EOF


    ###############################################################
    # Write ORG SERVER config
    ###############################################################
    echo ""
    echo_info "fabric-org-ca-server-config.yaml for $ORGCA_NAME generating..."

    mkdir -p $LOCAL_SRV_DIR/$ORGCA_NAME

    cat <<EOF > $LOCAL_SRV_DIR/fabric-ca-server-config.yaml
---
version: 0.0.1

port: $ORGCA_PORT

debug: true

tls:
  enabled: true
  clientauth:
    type: noclientcert
    certfiles:

ca:
  name: $ORGCA_NAME
  keyfile: $HOST_ORG_KEYS_DIR/msp/keystore/$(basename $(ls $LOCAL_ORG_KEYS_DIR/msp/keystore/*_sk | head -n 1))
  certfile: $HOST_ORG_KEYS_DIR/msp/signcerts/cert.pem

crl:
registry:
  maxenrollments: 1

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
      ca:
        usage:
          - cert sign
          - crl sign
        expiry: 43800h
        caconstraint:
          isca: true
          maxpathlen: 2

csr:
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
     - $ORGCA_NAME
     - $CA_IP
     - localhost
     - 0.0.0.0
   ca:
      expiry: 131400h
      pathlength: 2

idemix:
  curve: gurvy.Bn254

operations:
    listenAddress: $CA_IP:$ORGCA_OPPORT
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
    # Start Intermediate-ORG-CA
    ###############################################################
    echo ""
    echo_info "Intermediate-CA $TLSCA_NAME starting..."

    docker run -d \
        --name $CA_NAME \
        --network $DOCKER_NETWORK_NAME \
        --ip $CA_IP \
        $hosts_args \
        --restart=on-failure:1 \
        --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/src/fabric_ca_logo.png" \
        -p $TLSCA_PORT:$TLSCA_PORT \
        -p $TLSCA_OPPORT:$TLSCA_OPPORT \
        -p $ORGCA_PORT:$ORGCA_PORT \
        -p $ORGCA_OPPORT:$ORGCA_OPPORT \
        -v $LOCAL_SRV_DIR:$HOST_SRV_DIR \
        -v $LOCAL_CLI_DIR:$HOST_CLI_DIR \
        -v $LOCAL_TLS_KEYS_DIR:$HOST_TLS_KEYS_DIR \
        -v $LOCAL_ORG_KEYS_DIR:$HOST_ORG_KEYS_DIR \
        -v $LOCAL_INFRA_DIR:$HOST_INFRA_DIR \
        hyperledger/fabric-ca:latest \
        sh -c "fabric-ca-server start -b $ORGCA_NAME:$ORGCA_PASS \
        --home $HOST_SRV_DIR" 
#        --cafiles $HOST_SRV_DIR/$ORGCA_NAME/fabric-ca-server-config.yaml \

    # Waiting Root-CA startup
    CheckContainer "$CA_NAME" "$DOCKER_CONTAINER_WAIT"
    CheckContainerLog "$CA_NAME" "Listening on https://0.0.0.0:$ORGCA_PORT" "$DOCKER_CONTAINER_WAIT"


    # ###############################################################
    # # Start Root-ORG-CA
    # ###############################################################
    # echo ""
    # echo_info "Intermediate-CA $ORGCA_NAME starting..."

    # docker exec -d $CA_NAME \
    #     fabric-ca-server start -b $ORGCA_NAME:$ORGCA_PASS \
    #     --home $HOST_SRV_DIR/$ORGCA_NAME


    # Installing OpenSSL
    if [[ $CA_OPENSSL = true ]]; then
        echo_info "OpenSSL installing..."
        docker exec $CA_NAME sh -c 'command -v apk && apk update && apk add --no-cache openssl || (apt-get update && apt-get install -y openssl)'
        CheckOpenSSL "$CA_NAME" "$DOCKER_CONTAINER_WAIT"
    fi


    ###############################################################
    # Write CLIENT config
    ###############################################################
    echo ""
    echo_info "fabric-ca-client-config.yaml generating... (Defaults: https://hyperledger-fabric-ca.readthedocs.io/en/latest/serverconfig.html)"

    mkdir -p $LOCAL_CLI_DIR

    cat <<EOF > $LOCAL_CLI_DIR/fabric-ca-client-config.yaml
---
url: https://localhost:7054

mspdir: msp

tls:
  certfiles: $HOST_TLS_KEYS_DIR/tls/tls-cert.pem
  client:
    certfile:
    keyfile:

csr:
   cn: $CA_NAME
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
     - $CA_NAME
     - $CA_IP
     - localhost
     - 0.0.0.0

enrollment:
  profile: tls

caname: $CA_NAME

idemixCurveID: gurvy.Bn254
EOF

done


###############################################################
# Last Tasks
###############################################################
chmod -R 777 infrastructure
echo_ok "Intermediate-CAs started."
