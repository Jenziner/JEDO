###############################################################
#!/bin/bash
#
# This script starts LDAP Services
# 
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
check_script


###############################################################
# Params
###############################################################
CONFIG_FILE="$SCRIPT_DIR/infrastructure-cc.yaml"
DOCKER_UNRAID=$(yq eval '.Docker.Unraid' $CONFIG_FILE)
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $CONFIG_FILE)

get_hosts

echo ""
echo_warn "LDAP starting..."


###############################################################
# LDAP Provider
###############################################################
ORBISS=$(yq eval '.Organizations[] | select(.Administration.Position == "orbis") | .Name' "$CONFIG_FILE")
ORBIS_COUNT=$(echo "$ORBISS" | wc -l)

# only 1 orbis is allowed
if [ "$ORBIS_COUNT" -ne 1 ]; then
    echo_error "Illegal number of orbis-organizations ($ORBIS_COUNT)."
    exit 1
fi


for ORBIS in $ORBISS; do
    # Params for orbis
    ORBIS_LDAP_NAME=$(yq eval ".Organizations[] | select(.Name == \"$ORBIS\") | .LDAP.Name" "$CONFIG_FILE")
    ORBIS_LDAP_PASS=$(yq eval ".Organizations[] | select(.Name == \"$ORBIS\") | .LDAP.Pass" "$CONFIG_FILE")
    ORBIS_LDAP_IP=$(yq eval ".Organizations[] | select(.Name == \"$ORBIS\") | .LDAP.IP" "$CONFIG_FILE")
    ORBIS_LDAP_PORT=$(yq eval ".Organizations[] | select(.Name == \"$ORBIS\") | .LDAP.Port" "$CONFIG_FILE")
    ORBIS_LDAP_PORTSSL=$(yq eval ".Organizations[] | select(.Name == \"$ORBIS\") | .LDAP.PortSSL" "$CONFIG_FILE")
    ORBIS_LDAP_DOMAIN=$(yq eval ".Organizations[] | select(.Name == \"$ORBIS\") | .LDAP.Domain" "$CONFIG_FILE")

    ORBIS_LDAP_ADMIN_NAME=$(yq eval ".Organizations[] | select(.Name == \"$ORBIS\") | .LDAP-Admin.Name" "$CONFIG_FILE")
    ORBIS_LDAP_ADMIN_IP=$(yq eval ".Organizations[] | select(.Name == \"$ORBIS\") | .LDAP-Admin.IP" "$CONFIG_FILE")
    ORBIS_LDAP_ADMIN_PORT=$(yq eval ".Organizations[] | select(.Name == \"$ORBIS\") | .LDAP-Admin.Port" "$CONFIG_FILE")

    LOCAL_SRV_DIR=${PWD}/infrastructure/$ORBIS/$ORBIS_LDAP_NAME/db
    LOCAL_CFG_DIR=${PWD}/infrastructure/$ORBIS/$ORBIS_LDAP_NAME/config
    LOCAL_JOB_DIR=${PWD}/infrastructure/$ORBIS/$ORBIS_LDAP_NAME/jobs

    HOST_SRV_DIR=/var/lib/ldap
    HOST_CFG_DIR=/etc/ldap/slapd.d
    HOST_JOB_DIR=/jobs

    mkdir -p $LOCAL_SRV_DIR $LOCAL_CFG_DIR $LOCAL_JOB_DIR


    # Start Orbis-LDAP Containter
    echo ""
    echo_info "Docker Container $ORBIS_LDAP_NAME starting..."
    docker run -d \
        --name $ORBIS_LDAP_NAME \
        --network $DOCKER_NETWORK_NAME \
        --ip $ORBIS_LDAP_IP \
        $hosts_args \
        --restart=on-failure:1 \
        --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/src/fabric_ca_logo.png" \
        -p $ORBIS_LDAP_PORT:389 \
        -p $ORBIS_LDAP_PORTSSL:636 \
        -v $LOCAL_SRV_DIR:$HOST_SRV_DIR \
        -v $LOCAL_CFG_DIR:$HOST_CFG_DIR \
        -v $LOCAL_JOB_DIR:$HOST_JOB_DIR \
        -e LDAP_ORGANISATION=$ORBIS \
        -e LDAP_DOMAIN=$ORBIS_LDAP_DOMAIN \
        -e LDAP_ADMIN_PASSWORD=$ORBIS_LDAP_PASS \
        osixia/openldap


    # Waiting Orbis-LDAP startup
    CheckContainer "$ORBIS_LDAP_NAME" "$DOCKER_CONTAINER_WAIT"
    CheckContainerLog "$ORBIS_LDAP_NAME" "slapd starting" "$DOCKER_CONTAINER_WAIT"


    # Start Orbis-LDAP-Admin Containter
    echo ""
    echo_info "Docker Container $ORBIS_LDAP_ADMIN_NAME starting..."
    docker run -d \
        --name $ORBIS_LDAP_ADMIN_NAME \
        --network $DOCKER_NETWORK_NAME \
        --ip $ORBIS_LDAP_ADMIN_IP \
        -p $ORBIS_LDAP_ADMIN_PORT:80 \
        $hosts_args \
        --restart=on-failure:1 \
        --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/src/fabric_ca_logo.png" \
        -e PHPLDAPADMIN_LDAP_HOSTS=$ORBIS_LDAP_NAME \
        -e PHPLDAPADMIN_HTTPS=false \
        osixia/phpldapadmin

    # Waiting Orbis-LDAP startup
    CheckContainer "$ORBIS_LDAP_ADMIN_NAME" "$DOCKER_CONTAINER_WAIT"
    CheckContainerLog "$ORBIS_LDAP_ADMIN_NAME" "ready to handle connections" "$DOCKER_CONTAINER_WAIT"


    # Write config in syncprov-module.ldif
    cat <<EOF > $LOCAL_JOB_DIR/syncprov-module.ldif
dn: cn=module{0},cn=config
changetype: modify
add: olcModuleLoad
olcModuleLoad: syncprov
EOF
    docker exec -it $ORBIS_LDAP_NAME ldapadd -Y EXTERNAL -H ldapi:/// -f $HOST_JOB_DIR/syncprov-module.ldif

# See Issue #118 (Project 3)
#     # Write config in syncprov.ldif
#     cat <<EOF > $LOCAL_JOB_DIR/syncprov.ldif
# dn: olcOverlay=syncprov,olcDatabase={1}mdb,cn=config
# changetype: add
# objectClass: olcOverlayConfig
# olcOverlay: syncprov
# objectClass: olcSyncProvConfig
# olcSyncProvSessionlog: 100
# olcSyncProvCheckpoint: 100 10
# EOF
#     docker exec -it $ORBIS_LDAP_NAME ldapadd -Y EXTERNAL -H ldapi:/// -f $HOST_JOB_DIR/syncprov.ldif
done


###############################################################
# LDAP Consumer
###############################################################
REGNUMS=$(yq eval '.Organizations[] | select(.Administration.Position == "regnum") | .Name' "$CONFIG_FILE")
REGNUM_COUNT=$(echo "$REGNUMS" | wc -l)

# exit when no regnum is defined
if [ "$REGNUM_COUNT" -eq 0 ]; then
    echo_error "No regnum defined."
    exit 1
fi


for REGNUM in $REGNUMS; do
    # Params for orbis
    REGNUM_LDAP_NAME=$(yq eval ".Organizations[] | select(.Name == \"$REGNUM\") | .LDAP.Name" "$CONFIG_FILE")
    REGNUM_LDAP_PASS=$(yq eval ".Organizations[] | select(.Name == \"$REGNUM\") | .LDAP.PASS" "$CONFIG_FILE")
    REGNUM_LDAP_IP=$(yq eval ".Organizations[] | select(.Name == \"$REGNUM\") | .LDAP.IP" "$CONFIG_FILE")
    REGNUM_LDAP_PORT=$(yq eval ".Organizations[] | select(.Name == \"$REGNUM\") | .LDAP.Port" "$CONFIG_FILE")
    REGNUM_LDAP_PORTSSL=$(yq eval ".Organizations[] | select(.Name == \"$REGNUM\") | .LDAP.PortSSL" "$CONFIG_FILE")
    REGNUM_LDAP_DOMAIN=$(yq eval ".Organizations[] | select(.Name == \"$REGNUM\") | .LDAP.Domain" "$CONFIG_FILE")

    DN=$(echo "$REGNUM_LDAP_DOMAIN" | cut -d'.' -f1)
    TDN=$(echo "$REGNUM_LDAP_DOMAIN" | cut -d'.' -f2)

    LOCAL_SRV_DIR=${PWD}/infrastructure/$REGNUM/$REGNUM_LDAP_NAME/db
    LOCAL_CFG_DIR=${PWD}/infrastructure/$REGNUM/$REGNUM_LDAP_NAME/config
    LOCAL_JOB_DIR=${PWD}/infrastructure/$REGNUM/$REGNUM_LDAP_NAME/jobs

    HOST_SRV_DIR=/var/lib/ldap
    HOST_CFG_DIR=/etc/ldap/slapd.d
    HOST_JOB_DIR=/jobs

    mkdir -p $LOCAL_SRV_DIR $LOCAL_CFG_DIR $LOCAL_JOB_DIR


    # Start Regnum-LDAP Containter
    echo ""
    echo_info "Docker Container $REGNUM_LDAP_NAME starting..."
    docker run -d \
        --name $REGNUM_LDAP_NAME \
        --network $DOCKER_NETWORK_NAME \
        --ip $REGNUM_LDAP_IP \
        $hosts_args \
        --restart=on-failure:1 \
        --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/src/fabric_ca_logo.png" \
        -p $REGNUM_LDAP_PORT:389 \
        -p $REGNUM_LDAP_PORTSSL:636 \
        -v $LOCAL_SRV_DIR:$HOST_SRV_DIR \
        -v $LOCAL_CFG_DIR:$HOST_CFG_DIR \
        -v $LOCAL_JOB_DIR:$HOST_JOB_DIR \
        -e LDAP_ORGANISATION=$REGNUM \
        -e LDAP_DOMAIN=$REGNUM_LDAP_DOMAIN \
        -e LDAP_ADMIN_PASSWORD=$REGNUM_LDAP_PASS \
        -d osixia/openldap


    # Waiting Regnum-LDAP startup
    CheckContainer "$REGNUM_LDAP_NAME" "$DOCKER_CONTAINER_WAIT"
    CheckContainerLog "$REGNUM_LDAP_NAME" "slapd starting" "$DOCKER_CONTAINER_WAIT"


    # Write config in syncrepl.ldif
    cat <<EOF > $LOCAL_JOB_DIR/syncrepl.ldif
dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcSyncrepl
olcSyncrepl: rid=001
  provider=ldap://$ORBIS_LDAP_IP
  bindmethod=simple
  binddn="cn=admin,dc=$DN,dc=$TDN"
  credentials=$ORBIS_LDAP_PASS
  searchbase="dc=$DN,dc=$TDN"
  type=refreshAndPersist
  retry="60 +"
  interval=00:00:05:00
EOF
    docker exec -it $REGNUM_LDAP_NAME ldapmodify -Y EXTERNAL -H ldapi:/// -f $HOST_JOB_DIR/syncrepl.ldif
done


###############################################################
# LDAP Consumer
###############################################################






###############################################################
# Last Tasks
###############################################################
echo_ok "LDAP started."
