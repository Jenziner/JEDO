###############################################################
#!/bin/bash
#
# This script starts Fabric Tools Container
#   - peer
#   - osnadmin
#   - configtxgen
#   - cryptogen
#   - configtxlator
#   - discorver
#   - ledgerutil
#   - fabric-ca-client
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
echo_warn "Tools starting... (Defaults: https://hyperledger-fabric-ca.readthedocs.io/en/latest/clientconfig.html)"


ORBIS_NAME=$(yq eval ".Orbis.Name" "$CONFIG_FILE")
TOOLS_NAME=$(yq eval ".Orbis.Tools.Name" "$CONFIG_FILE")
TOOLS_PASS=$(yq eval ".Orbis.Tools.Pass" "$CONFIG_FILE")
TOOLS_IP=$(yq eval ".Orbis.Tools.IP" "$CONFIG_FILE")
TOOLS_PORT=$(yq eval ".Orbis.Tools.Port" "$CONFIG_FILE")

[[ "$TOOLS_NAME" == "null" ]] && continue

LOCAL_CACLI_DIR=${PWD}/infrastructure/$ORBIS_NAME/$TOOLS_NAME/ca-client
LOCAL_INFRA_DIR=${PWD}/infrastructure

HOST_CACLI_DIR=/etc/hyperledger/fabric-ca-client
HOST_INFRA_DIR=/etc/hyperledger/fabric-ca-client/infrastructure


###############################################################
# Start Fabric Tools Containter
###############################################################
echo ""
echo_info "Docker Containter $TOOLS_NAME starting..."
docker run -d \
    --name $TOOLS_NAME \
    --network $DOCKER_NETWORK_NAME \
    --ip $TOOLS_IP \
    $hosts_args \
    --restart=on-failure:1 \
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/src/fabric_logo.png" \
    -p $TOOLS_PORT:$TOOLS_PORT \
    -v $LOCAL_CACLI_DIR:$HOST_CACLI_DIR \
    -v $LOCAL_INFRA_DIR:$HOST_INFRA_DIR \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -e GOPATH=/opt/gopath \
    -e FABRIC_LOGGING_SPEC=DEBUG \
    -w /opt/gopath/src/github.com/hyperledger/fabric \
    -it \
    hyperledger/fabric-tools:latest
    

# Waiting Root-CA Host startup
CheckContainer "$TOOLS_NAME" "$DOCKER_CONTAINER_WAIT"


# Install Fabric-CA-Client
echo ""
echo_info "Fabric-CA-Client installing..."
docker exec -it $TOOLS_NAME /bin/bash -c "
    curl -sSL https://github.com/hyperledger/fabric-ca/releases/download/v1.5.13/hyperledger-fabric-ca-linux-amd64-1.5.13.tar.gz -o fabric-ca.tar.gz && \
    tar -xzf fabric-ca.tar.gz && \
    cp bin/fabric-ca-client /usr/local/bin/fabric-ca-client && \
    chmod +x /usr/local/bin/fabric-ca-client && \
    rm fabric-ca.tar.gz \
    rm -rf bin"


# Install Fabric-Token-SDK Tokengen
echo ""
echo_info "Tokengen installing..."
docker exec -it $TOOLS_NAME /bin/bash -c "
    apt-get update && \
    apt-get install -y build-essential && \
    export CGO_ENABLED=1 && \
    export GO_TAGS=pkcs11 && \
    go install github.com/hyperledger-labs/fabric-token-sdk/cmd/tokengen@v0.3.0 && \
    cp \$GOPATH/bin/tokengen /usr/local/bin/tokengen && \
    chmod +x /usr/local/bin/tokengen "


# Waiting Root-CA Host startup
CheckContainer "$TOOLS_NAME" "$DOCKER_CONTAINER_WAIT"


# Write TLS-Root CLIENT config
mkdir -p $LOCAL_CACLI_DIR
cat <<EOF > $LOCAL_CACLI_DIR/fabric-ca-client-config.yaml
---
url:
mspdir: msp
tls:
    certfiles:
    client:
      certfile:
      keyfile:
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
caname:
idemixCurveID: gurvy.Bn254
EOF

