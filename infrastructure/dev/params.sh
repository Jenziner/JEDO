###############################################################
# Params
###############################################################
CONFIG_FILE="$SCRIPT_DIR/infrastructure.yaml"
FABRIC_PATH=$(yq eval '.Fabric.Path' $CONFIG_FILE)
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $CONFIG_FILE)
DOCKER_NETWORK_SUBNET=$(yq eval '.Docker.Network.Subnet' $CONFIG_FILE)
DOCKER_NETWORK_GATEWAY=$(yq eval '.Docker.Network.Gateway' $CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $CONFIG_FILE)
DOCKER_CONTAINER_FABRICTOOLS=$(yq eval '.Docker.Container.FabricTools' $CONFIG_FILE)

export PATH=$PATH:$FABRIC_PATH/bin:$FABRIC_PATH/config
export FABRIC_CFG_PATH=${PWD}/../../fabric-samples/config

ROOT_ENV=$(yq eval ".Root.Env" "$CONFIG_FILE")
ORBIS=$(yq eval '.Orbis.Name' "$CONFIG_FILE")
ORBIS_ENV=$(yq eval '.Orbis.Env' "$CONFIG_FILE")
REGNUMS=$(yq eval '.Regnum[] | .Name' "$CONFIG_FILE")
AGERS=$(yq eval '.Ager[] | .Name' "$CONFIG_FILE")
