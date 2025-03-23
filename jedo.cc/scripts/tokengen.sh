###############################################################
#!/bin/bash
#
# Tokengen 
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
FABRIC_BIN_PATH=$(yq eval '.Fabric.Path' "$CONFIG_FILE")
DOCKER_UNRAID=$(yq eval '.Docker.Unraid' $CONFIG_FILE)
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $CONFIG_FILE)

ORBIS_TOOLS_NAME=$(yq eval ".Orbis.Tools.Name" "$CONFIG_FILE")
ORBIS_TOOLS_CACLI_DIR=/etc/hyperledger/fabric-ca-client


###############################################################
# Generate public parameter for tokenchaincode
###############################################################
HOST_INFRA_DIR=/etc/hyperledger/fabric-ca-client/infrastructure



# tokengen gen dlog --base 300 --exponent 5 \
#   --issuers keys/issuer/iss/msp \
#   --idemix keys/owner1/wallet/alice \
#   --auditors keys/auditor/aud/msp \
#   --output tokenchaincode




echo ""
echo_info "Generate public parameter for tokenchaincode"
docker exec $ORBIS_TOOLS_NAME bash -c 'PATH=$PATH:/usr/local/go/bin && /root/go/bin/tokengen gen dlog --base 300 --exponent 5 \
    --issuers $HOST_INFRA_DIR/jedo/ea/alps/iss.alps.ea.jedo.cc/msp \
    --idemix $HOST_INFRA_DIR/jedo/ea/alps/WORB/do \
    --auditors $HOST_INFRA_DIR/jedo/ea/alps/aud.alps.ea.jedo.cc/msp \
    --output $HOST_INFRA_DIR/jedo/ea/configuration/tokengen'