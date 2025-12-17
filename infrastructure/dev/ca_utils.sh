###############################################################
#!/bin/bash
#
# This file provides general settings and general functions.
#
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/params.sh"


###############################################################
# Function to start a Fabric-MSP Docker-Container
###############################################################
function ca_start() {
    local cn="$1"
    local cfg="$2"
    local dir="$3"

    #Init
    DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' "$cfg")
    DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' "$cfg")

    CONTAINER_ORG=$(yq eval-all ".. | select(.MSP? and .MSP.Name == \"$cn\") | .Name" "$cfg")
    CONTAINER_NAME=$(yq eval-all ".. | select(.MSP? and .MSP.Name == \"$cn\") | .MSP.Name" "$cfg")
    CONTAINER_PASS=$(yq eval-all ".. | select(.MSP? and .MSP.Name == \"$cn\") | .MSP.Pass" "$cfg")
    CONTAINER_IP=$(yq eval-all ".. | select(.MSP? and .MSP.Name == \"$cn\") | .MSP.IP" "$cfg")
    CONTAINER_PORT=$(yq eval-all ".. | select(.MSP? and .MSP.Name == \"$cn\") | .MSP.Port" "$cfg")
    CONTAINER_OPPORT=$(yq eval-all ".. | select(.MSP? and .MSP.Name == \"$cn\") | .MSP.OpPort" "$cfg")

    LOCAL_INFRA_DIR=${PWD}/infrastructure
    LOCAL_SRV_DIR=$dir
    HOST_INFRA_DIR=/etc/hyperledger/infrastructure
    HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server

    mkdir -p $LOCAL_SRV_DIR

    get_hosts


    # Start Containter
    echo ""
    if [[ $DEBUG == true ]]; then
        echo_debug "Executing with the following:"
        echo_value_debug "- Docker Container" "$CONTAINER_NAME"
        echo_value_debug "- Infra Dir:" "$LOCAL_INFRA_DIR"
        echo_value_debug "- Local Dir:" "$LOCAL_SRV_DIR"
    fi
    echo_info "Docker Container $CONTAINER_NAME starting..."
    docker run -d \
        --user $(id -u):$(id -g) \
        --name $CONTAINER_NAME \
        --network $DOCKER_NETWORK_NAME \
        --ip $CONTAINER_IP \
        $hosts_args \
        --restart=on-failure:1 \
        --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/src/fabric_ca_logo.png" \
        -p $CONTAINER_PORT:$CONTAINER_PORT \
        -p $CONTAINER_OPPORT:$CONTAINER_OPPORT \
        -v $LOCAL_SRV_DIR:$HOST_SRV_DIR \
        -v $LOCAL_INFRA_DIR:$HOST_INFRA_DIR \
        -e FABRIC_CA_SERVER_LOGLEVEL=$FABRIC_CA_SERVER_LOGLEVEL \
        hyperledger/fabric-ca:latest \
        sh -c "fabric-ca-server start -b $CONTAINER_NAME:$CONTAINER_PASS \
        --home $HOST_SRV_DIR"


    # Waiting Container startup
    CheckContainer "$CONTAINER_NAME" "$DOCKER_CONTAINER_WAIT"
    CheckContainerLog "$CONTAINER_NAME" "Listening on https://0.0.0.0:$CONTAINER_PORT" "$DOCKER_CONTAINER_WAIT"
}


###############################################################
# Function to write a fabric-ca-server-config.yaml File
###############################################################
function ca_writeCfg() {
    local type="$1"
    local cn="$2"
    local cfg="$3"
    local dir="$4"

    #Init
    MSP_ORG=$(yq eval-all ".. | select(.MSP? and .MSP.Name == \"$cn\") | .Name" "$cfg")
    MSP_ORG_PARENT=$(yq eval-all ".. | select(.MSP? and .MSP.Name == \"$cn\") | .Administration.Parent" "$cfg")
    MSP_NAME=$(yq eval-all ".. | select(.MSP? and .MSP.Name == \"$cn\") | .MSP.Name" "$cfg")
    MSP_PASS=$(yq eval-all ".. | select(.MSP? and .MSP.Name == \"$cn\") | .MSP.Pass" "$cfg")
    MSP_IP=$(yq eval-all ".. | select(.MSP? and .MSP.Name == \"$cn\") | .MSP.IP" "$cfg")
    MSP_PORT=$(yq eval-all ".. | select(.MSP? and .MSP.Name == \"$cn\") | .MSP.Port" "$cfg")
    MSP_OPPORT=$(yq eval-all ".. | select(.MSP? and .MSP.Name == \"$cn\") | .MSP.OpPort" "$cfg")

    MSP_NAME_FORMATTED="${MSP_NAME//./-}"
    PARENT_NAME=$(yq eval-all '.. | select(has("Name") and .Name == "'"$MSP_ORG_PARENT"'") | .MSP?.Name // ""' "$cfg" | grep -v "^null$" | xargs echo -n)
    PARENT_PASS=$(yq eval-all '.. | select(has("Name") and .Name == "'"$MSP_ORG_PARENT"'") | .MSP?.Pass // ""' "$cfg" | grep -v "^null$" | xargs echo -n)
    PARENT_IP=$(yq eval-all '.. | select(has("Name") and .Name == "'"$MSP_ORG_PARENT"'") | .MSP?.IP // ""' "$cfg" | grep -v "^null$" | xargs echo -n)
    PARENT_PORT=$(yq eval-all '.. | select(has("Name") and .Name == "'"$MSP_ORG_PARENT"'") | .MSP?.Port // ""' "$cfg" | grep -v "^null$" | xargs echo -n)

    if [ "$MSP_ORG_PARENT" = "root" ]; then
        PARENT_URL=""
    else
        PARENT_URL="https://$PARENT_NAME:$PARENT_PASS@$PARENT_NAME:$PARENT_PORT"
    fi

    LOCAL_SRV_DIR=$dir
    HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server

    mkdir -p $LOCAL_SRV_DIR

    # Write SERVER config
    echo ""
    if [[ $DEBUG == true ]]; then
        echo_debug "Executing with the following:"
        echo_value_debug "- MSP:" "$MSP_ORG"
        echo_value_debug "- CA:" "$MSP_NAME"
        echo_value_debug "- Parent (optional):" "$PARENT_NAME"
    fi
    echo_info "Server-Config for $MSP_NAME writing..."
cat <<EOF > $LOCAL_SRV_DIR/fabric-ca-server-config.yaml
---
version: 0.0.1
port: $MSP_PORT
tls:
    enabled: true
    certfile: $HOST_SRV_DIR/tls/signcerts/cert.pem
    keyfile: $HOST_SRV_DIR/tls/keystore/$(basename $(ls $LOCAL_SRV_DIR/tls/keystore/*_sk | head -n 1))
    clientauth:
      type: noclientcert
      certfiles:
ca:
    name: $MSP_NAME
    certfile: $HOST_SRV_DIR/$MSP_NAME_FORMATTED.cert
    keyfile: $HOST_SRV_DIR/$MSP_NAME_FORMATTED.key
    chainfile: $HOST_SRV_DIR/$MSP_NAME_FORMATTED-chain.cert
crl:
registry:
    maxenrollments: -1
    identities:
        - name: $MSP_NAME
          pass: $MSP_PASS
          type: client
          affiliation: "jedo"
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
        ca:
            usage:
                - cert sign
                - crl sign
            expiry: 8760h
            caconstraint:
                isca: true
EOF

    if [ "$type" = "orbis" ]; then
        echo "                maxpathlen: 2" >> "$LOCAL_SRV_DIR/fabric-ca-server-config.yaml"
    elif [ "$type" = "regnum" ]; then
        echo "                maxpathlen: 1" >> "$LOCAL_SRV_DIR/fabric-ca-server-config.yaml"
    else
        echo "                maxpathlen: 0" >> "$LOCAL_SRV_DIR/fabric-ca-server-config.yaml"
    fi

cat <<EOF >> $LOCAL_SRV_DIR/fabric-ca-server-config.yaml
        tls:
            usage:
                - cert sign
                - crl sign
                - signing
                - key encipherment
                - server auth
                - client auth
                - key agreement
            expiry: 8760h
csr:
    cn: 
    keyrequest:
        algo: ecdsa
        size: 384
    names:
        - C: JD
          ST: CC
          L:
          O: JEDO
          OU: Root
    hosts:
EOF

    if [ -n "$PARENT_NAME" ]; then
        echo "        - $PARENT_NAME" >> "$LOCAL_SRV_DIR/fabric-ca-server-config.yaml"
    fi

    if [ -n "$PARENT_IP" ]; then
        echo "        - $PARENT_IP" >> "$LOCAL_SRV_DIR/fabric-ca-server-config.yaml"
    fi

cat <<EOF >> $LOCAL_SRV_DIR/fabric-ca-server-config.yaml
    ca:
        expiry: 131400h
        pathlength: 1
intermediate:
    parentserver:
        url: $PARENT_URL
        caname: $PARENT_NAME
    enrollment:
        hosts: 
EOF

    if [ -n "$PARENT_NAME" ]; then
        echo "            - $PARENT_NAME" >> "$LOCAL_SRV_DIR/fabric-ca-server-config.yaml"
    fi

    if [ -n "$PARENT_IP" ]; then
        echo "            - $PARENT_IP" >> "$LOCAL_SRV_DIR/fabric-ca-server-config.yaml"
    fi

cat <<EOF >> $LOCAL_SRV_DIR/fabric-ca-server-config.yaml
            - '*.jedo.cc'
        profile: ca
    tls:
        certfiles: $HOST_SRV_DIR/tls/tlscacerts/$(basename $(ls $LOCAL_SRV_DIR/tls/tlscacerts/*.pem | head -n 1))
idemix:
    curve: gurvy.Bn254
operations:
    listenAddress: $MSP_IP:$MSP_OPPORT
    tls:
        enabled: false
#        cert:
#            file:
#        key:
#            file:
#        clientAuthRequired: false
#        clientRootCAs:
#            files: []
EOF
}
