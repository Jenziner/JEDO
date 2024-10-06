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
# Function to echo in colors
###############################################################
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
function echo_info() {
    echo -e "${YELLOW}$1${NC}"
}
function echo_error() {
    echo -e "${RED}$1${NC}"
}


###############################################################
# Params - from ./config/network-config.yaml
###############################################################
NETWORK_CONFIG_FILE="./config/network-config.yaml"
FABRIC_PATH=$(yq eval '.Fabric.Path' $NETWORK_CONFIG_FILE)
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $NETWORK_CONFIG_FILE)
DOCKER_NETWORK_SUBNET=$(yq eval '.Docker.Network.Subnet' $NETWORK_CONFIG_FILE)
DOCKER_CONTAINER_FABRICTOOLS=$(yq eval '.Docker.Container.FabricTools' $NETWORK_CONFIG_FILE)
export PATH=$PATH:$FABRIC_PATH/bin:$FABRIC_PATH/config
export FABRIC_CFG_PATH=./config


###############################################################
# Checks
###############################################################
echo_info "ScriptInfo: Checking prerequisites"
docker version
git --version
go version
orderer version
peer version
configtxgen --version
configtxlator version
cryptogen version

# Shutdown previous installation
./scripts/down.sh

###############################################################
# Generate identities for the nodes, issuer, auditor and owner
###############################################################
# Check docker network and create
if ! docker network ls --format '{{.Name}}' | grep -wq "$DOCKER_NETWORK_NAME"; then
    docker network create --subnet=$DOCKER_NETWORK_SUBNET "$DOCKER_NETWORK_NAME"
fi
docker network inspect "$DOCKER_NETWORK_NAME"


echo_error "ScriptInfo: Make sure, all Servers are reachable via DNS or hosts-File - starting $DOCKER_NETWORK_NAME"
# start all CA
./scripts/ca.sh

# enroll all certificates
./scripts/enroll.sh

# generate configuration (genesis block and channel configuration)
./scripts/config.sh

# start all nodes
./scripts/node.sh

echo_error "Temporary END of Script"
exit 1














echo "ScriptInfo: run tokengen"
if [ ! "$(docker ps -q -f name=$DOCKER_CONTAINER_FABRICTOOLS)" ]; then
    if [ "$(docker ps -aq -f status=exited -f name=$DOCKER_CONTAINER_FABRICTOOLS)" ]; then
        docker rm -f $DOCKER_CONTAINER_FABRICTOOLS
    fi
    docker run -v /mnt/user/appdata/jedo-network:/root \
      -itd --name $DOCKER_CONTAINER_FABRICTOOLS hyperledger/fabric-tools:latest
fi

echo "ScriptInfo: run fabric tools"
docker exec $DOCKER_CONTAINER_FABRICTOOLS bash -c 'PATH=$PATH:/usr/local/go/bin && /root/go/bin/tokengen gen dlog \
  --base 300 \
  --exponent 5 \
  --issuers /root/keys/issuer/iss/msp \
  --idemix /root/keys/owner1/wallet/alice \
  --auditors /root/keys/auditor/aud/msp \
  --output /root/tokengen'

echo "ScriptInfo: run nodes (peers and orderers)"
./scripts/node.sh

echo "Temporary END of Script"
exit 1


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