###############################################################
#!/bin/bash
#
# This script generates crypto, starts Fabric, deploys the chaincode and starts the token nodes.
#
# Prerequisits:
#   - yq: 
#       - installation: sudo wget https://github.com/mikefarah/yq/releases/download/v4.6.3/yq_linux_amd64 -O /usr/local/bin/yq
#       - make it executable: chmod +x /usr/local/bin/yq
#
###############################################################
set -Eeuo pipefail
ls scripts/up.sh || { echo "ScriptInfo: run this script from the root directory: ./scripts/up.sh"; exit 1; }


###############################################################
# Params - from ./config/network-config.yaml
###############################################################
CONFIG_FILE="./config/network-config.yaml"
FABRIC_PATH=$(yq eval '.Fabric.Path' "$CONFIG_FILE")
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' "$CONFIG_FILE")
DOCKER_CONTAINER_FABRICTOOLS=$(yq eval '.Docker.Container.FabricTools' "$CONFIG_FILE")


###############################################################
# Checks
###############################################################
export PATH=$PATH:$FABRIC_PATH/bin:$FABRIC_PATH/config
# Check prerequisites
docker version
git --version
go version
orderer version
peer version
configtxgen --version
configtxlator version
cryptogen version
# Check old data
[ ! -d keys ] || { echo "ScriptInfo: remove previous installation (folders) before starting new, use ./scripts/down.sh"; exit 1; }


# --------------------------------------------------------------
#TODO
#tokengen version || { echo "ScriptInfo: install tokengen (see readme)"; exit 1; }
# Check if old data exist
# Check Network
#TODO
TEST_NETWORK_HOME="${TEST_NETWORK_HOME:-$(pwd)/}"
ls "$TEST_NETWORK_HOME/config/configtx.yaml" 1> /dev/null || { echo "ScriptInfo: set the TEST_NETWORK_HOME environment variable to the directory of the jedo-network; e.g.:

export TEST_NETWORK_HOME=\"$TEST_NETWORK_HOME\"
"; exit 1; }
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^



# Check docker network and create
if ! docker network ls --format '{{.Name}}' | grep -wq "$DOCKER_NETWORK_NAME"; then
    docker network create "$DOCKER_NETWORK_NAME"
fi
docker network inspect "$DOCKER_NETWORK_NAME"


###############################################################
# Generate identities for the nodes, issuer, auditor and owner
###############################################################
mkdir -p keys/ca
./scripts/ca.sh
./scripts/enroll.sh
echo "ScriptInfo: run tokengen"
if [ ! "$(docker ps -q -f name=$DOCKER_CONTAINER_FABRICTOOLS)" ]; then
    if [ "$(docker ps -aq -f status=exited -f name=$DOCKER_CONTAINER_FABRICTOOLS)" ]; then
        docker rm -f $DOCKER_CONTAINER_FABRICTOOLS
    fi
    docker run -v /mnt/user/appdata/jedo-network:/root \
      -itd --name $DOCKER_CONTAINER_FABRICTOOLS hyperledger/fabric-tools:latest
fi
echo"ToDo: create certificates for issuer, idemix, auditors"
exit 1

docker exec $DOCKER_CONTAINER_FABRICTOOLS bash -c 'PATH=$PATH:/usr/local/go/bin && /root/go/bin/tokengen gen dlog \
  --base 300 \
  --exponent 5 \
  --issuers /root/keys/issuer/iss/msp \
  --idemix /root/keys/owner1/wallet/alice \
  --auditors /root/keys/auditor/aud/msp \
  --output /root/tokengen'


# Start Fabric network
#bash "$TEST_NETWORK_HOME/network.sh" up createChannel
# copy the keys and certs of the peers, orderer and the client user
#mkdir -p keys/fabric
#cp -r "$TEST_NETWORK_HOME/organizations" keys/fabric/

# Install and start tokenchaincode as a service
#INIT_REQUIRED="--init-required" "$TEST_NETWORK_HOME/network.sh" deployCCAAS  -ccn tokenchaincode -ccp "$(pwd)/tokenchaincode" -cci "init" -ccs 1

# Start token nodes
#mkdir -p data/auditor data/issuer data/owner1 data/owner2
#docker-compose up -d
#echo "
#Ready!

#Visit http://localhost:8080 in your browser to view the API documentation and try some transactions.
#"