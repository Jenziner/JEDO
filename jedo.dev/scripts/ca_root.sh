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

get_hosts

echo ""
echo_warn "Root-CA starting... (Defaults: https://hyperledger-fabric-ca.readthedocs.io/en/latest/serverconfig.html)"


ROOT_NAME=$(yq eval ".Root.Name" "$CONFIG_FILE")
ROOT_PASS=$(yq eval ".Root.Pass" "$CONFIG_FILE")
ROOT_IP=$(yq eval ".Root.IP" "$CONFIG_FILE")
ROOT_PORT=$(yq eval ".Root.Port" "$CONFIG_FILE")
ROOT_OPPORT=$(yq eval ".Root.OpPort" "$CONFIG_FILE")
    
LOCAL_INFRA_DIR=${PWD}/infrastructure
LOCAL_KEYS_DIR=${PWD}/infrastructure/_root/$ROOT_NAME/keys
LOCAL_SRV_DIR=${PWD}/infrastructure/_root/$ROOT_NAME/server
LOCAL_CLI_DIR=${PWD}/infrastructure/_root/$ROOT_NAME/client

HOST_INFRA_DIR=/etc/infrastructure
HOST_KEYS_DIR=/etc/hyperledger/keys
HOST_SRV_DIR=/etc/hyperledger/fabric-ca-server
HOST_CLI_DIR=/etc/hyperledger/fabric-ca-client

mkdir -p $LOCAL_KEYS_DIR/tls $LOCAL_SRV_DIR $LOCAL_CLI_DIR


# Write Root-CA SERVER config
cat <<EOF > $LOCAL_SRV_DIR/fabric-ca-server-config.yaml
---
version: 0.0.1
port: $ROOT_PORT
debug: true
tls:
    enabled: true
    clientauth:
      type: noclientcert
      certfiles:
ca:
    name: $ROOT_NAME
crl:
registry:
    maxenrollments: -1
    identities:
        - name: $ROOT_NAME
          pass: $ROOT_PASS
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
        idca:
            usage:
                - cert sign
                - crl sign
            expiry: 8760h
            caconstraint:
                isca: true
                maxpathlen: 2
        tlsca:
            usage:
                - cert sign
                - crl sign
            expiry: 8760h
            caconstraint:
                isca: true
                maxpathlen: 1
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
    cn: $ROOT_NAME
    keyrequest:
        algo: ecdsa
        size: 384
    names:
        - C: JD
          ST: Dev
          L:
          O: JEDO
          OU: Root
    hosts:
        - $ROOT_NAME
        - $ROOT_IP
    ca:
        expiry: 131400h
        pathlength: 2
idemix:
    curve: gurvy.Bn254
operations:
    listenAddress: $ROOT_IP:$ROOT_OPPORT
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

echo_info "$hosts_args"


# Start Root-CA Containter
echo ""
echo_info "$ROOT_NAME starting..."
docker run -d \
    --name $ROOT_NAME \
    --network $DOCKER_NETWORK_NAME \
    --ip $ROOT_IP \
    $hosts_args \
    --restart=on-failure:1 \
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/src/fabric_ca_logo.png" \
    -p $ROOT_PORT:$ROOT_PORT \
    -p $ROOT_OPPORT:$ROOT_OPPORT \
    -v $LOCAL_SRV_DIR:$HOST_SRV_DIR \
    -v $LOCAL_CLI_DIR:$HOST_CLI_DIR \
    -v $LOCAL_KEYS_DIR:$HOST_KEYS_DIR \
    -v $LOCAL_INFRA_DIR:$HOST_INFRA_DIR \
    hyperledger/fabric-ca:latest \
    sh -c "fabric-ca-server start -b $ROOT_NAME:$ROOT_PASS \
    --home $HOST_SRV_DIR"


# Waiting Root-CA Host startup
CheckContainer "$ROOT_NAME" "$DOCKER_CONTAINER_WAIT"
CheckContainerLog "$ROOT_NAME" "Listening on https://0.0.0.0:$ROOT_PORT" "$DOCKER_CONTAINER_WAIT"


# copy tls-cert.pem to key directory
cp $LOCAL_SRV_DIR/tls-cert.pem $LOCAL_KEYS_DIR/tls/tls-cert.pem


# Write TLS-Root CLIENT config
mkdir -p $LOCAL_CLI_DIR
cat <<EOF > $LOCAL_CLI_DIR/fabric-ca-client-config.yaml
---
tls:
    certfiles: $HOST_KEYS_DIR/tls/tls-cert.pem
    client:
      certfile:
      keyfile:
csr:
    cn: $ROOT_NAME
    keyrequest:
        algo: ecdsa
        size: 384
    names:
        - C: JD
          ST: Dev
          L:
          O: JEDO
          OU: Root
    hosts:
        - $ROOT_NAME
        - $ROOT_IP
caname: $ROOT_NAME
idemixCurveID: gurvy.Bn254
EOF


# Enroll Root-CA certs
echo ""
echo_info "Root-CA ID enrolling..."
docker exec -it $ROOT_NAME fabric-ca-client enroll -u https://$ROOT_NAME:$ROOT_PASS@$ROOT_NAME:$ROOT_PORT \
    --home $HOST_CLI_DIR --mspdir $HOST_KEYS_DIR/msp \
    --enrollment.profile idca
echo ""
echo_info "Root-CA TLS enrolling..."
docker exec -it $ROOT_NAME fabric-ca-client enroll -u https://$ROOT_NAME:$ROOT_PASS@$ROOT_NAME:$ROOT_PORT \
    --home $HOST_CLI_DIR --mspdir $HOST_KEYS_DIR/tls \
    --enrollment.profile tls


# Enroll Realms-CA certs
REALMS=$(yq eval ".Realms[].Name" $CONFIG_FILE)
for REALM in $REALMS; do
    REALM_TLS_NAME=$(yq eval ".Realms[] | select(.Name == \"$REALM\") | .TLS-CA.Name" "$CONFIG_FILE")
    REALM_TLS_PASS=$(yq eval ".Realms[] | select(.Name == \"$REALM\") | .TLS-CA.Pass" "$CONFIG_FILE")
    REALM_TLS_IP=$(yq eval ".Realms[] | select(.Name == \"$REALM\") | .TLS-CA.IP" "$CONFIG_FILE")
    REALM_ORG_NAME=$(yq eval ".Realms[] | select(.Name == \"$REALM\") | .ORG-CA.Name" "$CONFIG_FILE")
    REALM_ORG_PASS=$(yq eval ".Realms[] | select(.Name == \"$REALM\") | .ORG-CA.Pass" "$CONFIG_FILE")

    echo ""
    echo_info "Realm-TLS-CA ID registerin..."
    docker exec -it $ROOT_NAME fabric-ca-client register -u https://$ROOT_NAME:$ROOT_PASS@$ROOT_NAME:$ROOT_PORT \
        --home $HOST_CLI_DIR --mspdir $HOST_KEYS_DIR/msp \
        --id.name $REALM_TLS_NAME --id.secret $REALM_TLS_PASS --id.type client --id.affiliation jedo.root \
        --id.attrs 'hf.Registrar.Roles=*:ecert' \
        --id.attrs 'hf.Registrar.DelegateRoles=*:ecert' \
        --id.attrs 'hf.Revoker=true:ecert' \
        --id.attrs 'hf.IntermediateCA=true:ecert' \
        --id.attrs 'hf.GenCRL=true:ecert' \
        --id.attrs 'hf.Registrar.Attributes=*:ecert' \
        --id.attrs 'hf.AffiliationMgr=true:ecert'
    echo ""
    echo_info "Realm-TLS-CA ID enrolling..."
    docker exec -it $ROOT_NAME fabric-ca-client enroll -u https://$REALM_TLS_NAME:$REALM_TLS_PASS@$ROOT_NAME:$ROOT_PORT \
        --home $HOST_CLI_DIR --mspdir $HOST_INFRA_DIR/_root/$REALM_TLS_NAME/keys/msp \
        --csr.hosts ${REALM_TLS_NAME},${REALM_TLS_IP},localhost,0.0.0.11 \
        --enrollment.profile tlsca
    echo ""
    echo_info "Realm-TLS-CA TLS enrolling..."
    docker exec -it $ROOT_NAME fabric-ca-client enroll -u https://$REALM_TLS_NAME:$REALM_TLS_PASS@$ROOT_NAME:$ROOT_PORT \
        --home $HOST_CLI_DIR --mspdir $HOST_INFRA_DIR/_root/$REALM_TLS_NAME/keys/tls \
        --csr.cn $REALM_TLS_NAME --csr.hosts ${REALM_TLS_NAME},${REALM_TLS_IP},localhost,0.0.0.11 \
        --enrollment.profile tls
done


# Final tasks
chmod -R 777 infrastructure

#yq eval '.operations.tls.enabled = true' -i "$CONFIG_FILE"

        # --tls.certfiles $HOST_TLS_KEYS_DIR/tls/tls-cert.pem \
        # --caname $ROOT_TLSCA_NAME --home $HOST_CLI_DIR --mspdir $HOST_INFRA_DIR/$CA_ORG/$TLSCA_NAME/keys/msp \
        # --csr.hosts "$TLSCA_NAME,$CA_IP,localhost,0.0.0.0,$ROOT_TLSCA_NAME" \
        # --enrollment.attrs "hf.IntermediateCA" \
        # --enrollment.profile tls



















###############################################################
# TLS-CA DB (mySQL)
###############################################################
DB_NAME=$(yq eval ".TLS.DB.Name" "$CONFIG_FILE")
DB_IP=$(yq eval ".TLS.DB.IP" "$CONFIG_FILE")
DB_PORT=$(yq eval ".TLS.DB.Port" "$CONFIG_FILE")
DB_ROOTPASS=$(yq eval ".TLS.DB.RootPass" "$CONFIG_FILE")
DB_DATABASE="fabric_ca_tls"
DB_USER=$(yq eval ".TLS.DB.Name" "$CONFIG_FILE")
DB_PASSWORD=$(yq eval ".TLS.DB.Pass" "$CONFIG_FILE")

echo ""
echo_info "TLS-CA DB starting..."

docker run -d \
    --name $DB_NAME \
    --network $DOCKER_NETWORK_NAME \
    --ip $DB_IP \
    $hosts_args \
    --restart=on-failure:1 \
    -p $DB_PORT:3306 \
    -v $(pwd)/infrastructure/_root/$DB_NAME/mysql_data:/var/lib/mysql \
    -e MYSQL_ROOT_PASSWORD=$DB_ROOTPASS \
    -e MYSQL_DATABASE=$DB_DATABASE \
    -e MYSQL_USER=$DB_USER \
    -e MYSQL_PASSWORD=$DB_PASSWORD \
    mysql:latest

# Waiting TLS-CA DB startup
CheckContainer "$DB_NAME" "$DOCKER_CONTAINER_WAIT"
CheckContainerLog "$DB_NAME" "port: 3306  MySQL Community Server - GPL" "$DOCKER_CONTAINER_WAIT"
docker exec -it $DB_NAME mysql -u root -p${DB_ROOTPASS} -e "SHOW DATABASES;"

temp_end















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
