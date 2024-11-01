###############################################################
#!/bin/bash
#
# This script generates a new jedo-network according network-config.yaml
# Documentation: https://hyperledger-fabric.readthedocs.io
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/help.sh"

export JEDO_INITIATED="yes"


###############################################################
# Arguments
###############################################################
if [[ $# -eq 0 ]]; then
    up_help
fi
opt_d=false
opt_a=""
opt_r=""
while getopts ":hpda:r:" opt; do
    case ${opt} in
        h )
            up_help
            exit 0
            ;;
        d )
            opt_d=true
            ;;
        a )
            if [[ "$OPTARG" != "go" && "$OPTARG" != "pause" ]]; then
                echo "invalid argument for -a: $OPTARG" >&2
                echo "use -h for help" >&2
                exit 3
            fi
            opt_a="$OPTARG"
            ;;
        r )
            if [[ "$OPTARG" != "ca" && "$OPTARG" != "enroll" && "$OPTARG" != "channel" && "$OPTARG" != "config" && "$OPTARG" != "net" && "$OPTARG" != "orderer" && "$OPTARG" != "peer" && "$OPTARG" != "prereq" && "$OPTARG" != "root" ]]; then
                echo "invalid argument for -r: $OPTARG" >&2
                echo "use -h for help" >&2
                exit 3
            fi
            opt_r="$OPTARG"
            ;;
        \? )
            echo "invalid option: -$OPTARG" >&2
            exit 2
            ;;
        : )
            echo "option -$OPTARG requires argument." >&2
            exit 2
            ;;
    esac
done


###############################################################
# Params
###############################################################
CONFIG_FILE="$SCRIPT_DIR/infrastructure-dev.yaml"
FABRIC_PATH=$(yq eval '.Fabric.Path' $CONFIG_FILE)
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $CONFIG_FILE)
DOCKER_NETWORK_SUBNET=$(yq eval '.Docker.Network.Subnet' $CONFIG_FILE)
DOCKER_NETWORK_GATEWAY=$(yq eval '.Docker.Network.Gateway' $CONFIG_FILE)
DOCKER_CONTAINER_FABRICTOOLS=$(yq eval '.Docker.Container.FabricTools' $CONFIG_FILE)
export PATH=$PATH:$FABRIC_PATH/bin:$FABRIC_PATH/config
export FABRIC_CFG_PATH=./config


###############################################################
# Checks
###############################################################
if [[ "$opt_r" == "prereq" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    $SCRIPT_DIR/prereq.sh
    if [[ "$opt_a" == "pause" ]]; then
        cool_down "Prerequisites checked."
    fi
fi


###############################################################
# Delete previous installation
###############################################################
if $opt_d || [[ "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    $SCRIPT_DIR/down.sh
    if [[ "$opt_a" == "pause" ]]; then
        cool_down "Previous installation deleted."
    fi
fi


###############################################################
# Create Docker Network
###############################################################
if [[ "$opt_r" == "net" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    echo ""
    echo_warn "Docker Network starting..."
    if ! docker network ls --format '{{.Name}}' | grep -wq "$DOCKER_NETWORK_NAME"; then
        docker network create --subnet=$DOCKER_NETWORK_SUBNET --gateway=$DOCKER_NETWORK_GATEWAY "$DOCKER_NETWORK_NAME"
    fi
    docker network inspect "$DOCKER_NETWORK_NAME"
    if [[ "$opt_a" == "pause" ]]; then
        cool_down "Docker Network started."
    fi
    echo_ok "Docker Network started."
fi


###############################################################
# Generate Root-CA
###############################################################
if [[ "$opt_r" == "root" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    $SCRIPT_DIR/root.sh
    if [[ "$opt_a" == "pause" ]]; then
        cool_down "Root-CA started."
    fi
fi


###############################################################
# Run CA
###############################################################
if [[ "$opt_r" == "ca" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    ./scripts/ca.sh
    if [[ "$opt_a" == "pause" ]]; then
        cool_down "CA running."
    fi
fi


###############################################################
# Enroll certificates
###############################################################
if [[ "$opt_r" == "enroll" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    ./scripts/enroll.sh
    if [[ "$opt_a" == "pause" ]]; then
        cool_down "Certificates enrolled."
    fi
fi


###############################################################
# Run Peer
###############################################################
if [[ "$opt_r" == "peer" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    ./scripts/peer.sh peer
    if [[ "$opt_a" == "pause" ]]; then
        cool_down "Peers running."
    fi
fi


###############################################################
# Run Orderer
###############################################################
if [[ "$opt_r" == "orderer" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    ./scripts/orderer.sh
    if [[ "$opt_a" == "pause" ]]; then
        cool_down "Orderers running."
    fi
fi


###############################################################
# Generate configuration (genesis block and channel configuration)
###############################################################
if [[ "$opt_r" == "config" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    ./scripts/config.sh
    if [[ "$opt_a" == "pause" ]]; then
        cool_down "Genesis Block and Channel Configuration generated."
    fi
fi


###############################################################
# Create Channel
###############################################################
if [[ "$opt_r" == "channel" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    ./scripts/channel.sh
    if [[ "$opt_a" == "pause" ]]; then
        cool_down "Channel created."
    fi
fi


###############################################################
# FINISH
###############################################################
echo_ok "Script for $DOCKER_NETWORK_NAME completed"
exit 0













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