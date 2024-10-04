###############################################################
#!/bin/bash
#
# This script fully tears down and deletes all artifacts from the sample network that was started with ./scripts/up.sh.
#
# Prerequisits:
# - yq (sudo wget https://github.com/mikefarah/yq/releases/download/v4.6.3/yq_linux_amd64 -O /usr/local/bin/yq)
#
###############################################################
ls scripts/down.sh || { echo "ScriptInfo: run this script from the root directory: ./scripts/down.sh"; exit 1; }


###############################################################
# Params - from ./config/network-config.yaml
###############################################################
CONFIG_FILE="./config/network-config.yaml"
FABRIC_PATH=$(yq eval '.Fabric.Path' "$CONFIG_FILE")
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' "$CONFIG_FILE")
NETWORK_CA_NAME=$(yq eval '.Network.CA.Name' "$CONFIG_FILE")



###############################################################
# Checks
###############################################################
# Check script


###############################################################
# Stopping Docker-Container
###############################################################
echo "ScriptInfo: removing docker container and network"
docker rm -f $NETWORK_CA_NAME
# TODO: Remove all container
#containers=$(docker ps -a --filter "name=.jedo.test" --format "{{.Names}}")

# Überprüfe, ob Container gefunden wurden
#if [ -z "$containers" ]; then
#    echo "Keine Container gefunden, die auf '.jedo.test' enden."
#else
#    echo "Lösche folgende Container:"
#    echo "$containers"
#
#    # Lösche alle gefundenen Container
#    for container in $containers; do
#        docker rm -f $container
#        echo "Container $container gelöscht."
#    done
#fi
echo "ScriptInfo: removing docker network"
docker network rm  $DOCKER_NETWORK_NAME

###############################################################
# Remove Folder
###############################################################
echo "ScriptInfo: removing folders"
rm -rf keys
rm -rf tokengen
rm -rf configtx #TODO: Check if still needed
rm -rf production
#rm -rf data
#rm tokenchaincode/zkatdlog_pp.json