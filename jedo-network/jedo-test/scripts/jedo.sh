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
source ./scripts/settings.sh
source ./scripts/help.sh
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
            if [[ "$OPTARG" != "ca" && "$OPTARG" != "cert" && "$OPTARG" != "ch" && "$OPTARG" != "cfg" && "$OPTARG" != "net" && "$OPTARG" != "node" && "$OPTARG" != "orderer" && "$OPTARG" != "peer" ]]; then
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
ls scripts/jedo.sh || { echo_error "ScriptInfo: run this script from the root directory: ./scripts/jedo.sh"; exit 1; }
echo_info "ScriptInfo: Checking prerequisites"
docker version
git --version
go version
orderer version
peer version
configtxgen --version
configtxlator version
cryptogen version
if [[ "$opt_a" == "pause" ]] then
    cool_down "Prerequisites checked."
fi


###############################################################
# Delete previous installation
###############################################################
if $opt_d || [[ "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    ./scripts/down.sh
    if [[ "$opt_a" == "pause" ]]; then
        cool_down "Previous installation deleted."
    fi
fi


###############################################################
# Create Docker Network
###############################################################
if [[ "$opt_r" == "net" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    if ! docker network ls --format '{{.Name}}' | grep -wq "$DOCKER_NETWORK_NAME"; then
        docker network create --subnet=$DOCKER_NETWORK_SUBNET "$DOCKER_NETWORK_NAME"
    fi
    docker network inspect "$DOCKER_NETWORK_NAME"
    if [[ "$opt_a" == "pause" ]]; then
        cool_down "Docker Network created."
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
if [[ "$opt_r" == "cert" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    ./scripts/enroll.sh
    if [[ "$opt_a" == "pause" ]]; then
        cool_down "Certificates enrolled."
    fi
fi


###############################################################
# Generate configuration (genesis block and channel configuration)
###############################################################
if [[ "$opt_r" == "cert" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    ./scripts/config.sh
    if [[ "$opt_a" == "pause" ]]; then
        cool_down "Genesis Block and Channel Configuration generated."
    fi
fi


###############################################################
# Run Orderer and/or Peer
###############################################################
if [[ "$opt_r" == "node" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    echo_info "ScriptInfo: Make sure, all Servers are reachable via DNS or hosts-File - starting $DOCKER_NETWORK_NAME"
    ./scripts/node.sh node
    if [[ "$opt_a" == "pause" ]]; then
        cool_down "Nodes running."
    fi
fi

# if [[ "$opt_r" == "orderer" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
#     echo_info "ScriptInfo: Make sure, all Servers are reachable via DNS or hosts-File - starting $DOCKER_NETWORK_NAME"
#     ./scripts/node.sh orderer
#     if [[ "$opt_a" == "pause" ]]; then
#         cool_down "Orderers running."
#     fi
# fi

# if [[ "$opt_r" == "peer" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
#     echo_info "ScriptInfo: Make sure, all Servers are reachable via DNS or hosts-File - starting $DOCKER_NETWORK_NAME"
#     ./scripts/node.sh peer
#     if [[ "$opt_a" == "pause" ]]; then
#         cool_down "Peers running."
#     fi
# fi


###############################################################
# Create Channel
###############################################################
if [[ "$opt_r" == "ch" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    ./scripts/channel.sh
    if [[ "$opt_a" == "pause" ]]; then
        cool_down "Channel created."
    fi
fi



echo_error "Temporary END of Script"
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