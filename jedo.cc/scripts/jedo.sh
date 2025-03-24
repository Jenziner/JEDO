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
opt_a="n/a"
opt_r="n/a"
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
            if [[ "$OPTARG" != "tools" && "$OPTARG" != "ldap" && "$OPTARG" != "ca" && "$OPTARG" != "node" && "$OPTARG" != "enroll" && "$OPTARG" != "channel" && "$OPTARG" != "config" && "$OPTARG" != "net" && "$OPTARG" != "orderer" && "$OPTARG" != "peer" && "$OPTARG" != "token" && "$OPTARG" != "ccaas" && "$OPTARG" != "tokennode" && "$OPTARG" != "prereq" && "$OPTARG" != "root" && "$OPTARG" != "intermediate" ]]; then
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
CONFIG_FILE="$SCRIPT_DIR/infrastructure-cc.yaml"
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
    cool_down $opt_a "Prerequisites checked."
fi


###############################################################
# Delete previous installation
###############################################################
if $opt_d || [[ "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    $SCRIPT_DIR/down.sh
    cool_down $opt_a "Previous installation deleted."
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
    cool_down $opt_a "Docker Network started."
    echo_ok "Docker Network started."
fi


###############################################################
# Run Fabric Tools
###############################################################
if [[ "$opt_r" == "tools" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    $SCRIPT_DIR/tools.sh
    cool_down $opt_a "Fabric Tools started."
fi


###############################################################
# Run LDAP
###############################################################
# if [[ "$opt_r" == "ldap" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
#     $SCRIPT_DIR/ldap.sh
#     cool_down $opt_a "LDAP started."
# fi


###############################################################
# Run CA
###############################################################
if [[ "$opt_r" == "ca" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    $SCRIPT_DIR/ca_tls-node.sh
    $SCRIPT_DIR/ca_tls-certs.sh
    $SCRIPT_DIR/ca_ca-nodes.sh
    cool_down $opt_a "CA started."
fi


###############################################################
# Run Orderer Certificates
###############################################################
if [[ "$opt_r" == "orderer" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    ./scripts/orderer_cert.sh
    cool_down $opt_a "Orderers running."
fi


###############################################################
# Generate configuration (genesis block and channel configuration)
###############################################################
if [[ "$opt_r" == "config" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    ./scripts/config.sh
    cool_down $opt_a "Genesis Block and Channel Configuration generated."
fi


###############################################################
# Run Orderer Nodes
###############################################################
if [[ "$opt_r" == "orderer" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    ./scripts/orderer_node.sh
    cool_down $opt_a "Orderers running."
fi


###############################################################
# Run Peer
###############################################################
if [[ "$opt_r" == "peer" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    ./scripts/peer.sh peer
    cool_down $opt_a "Peers running."
fi


###############################################################
# Create Channel
###############################################################
if [[ "$opt_r" == "channel" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    ./scripts/channel.sh
    cool_down $opt_a "Channel created."
fi


###############################################################
# Enroll certificates
###############################################################
if [[ "$opt_r" == "enroll" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    ./scripts/enroll.sh
    cool_down $opt_a "Certificates enrolled."
    
fi


###############################################################
# Tokengen
###############################################################
if [[ "$opt_r" == "token" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    ./scripts/tokengen.sh
    cool_down $opt_a "Param for tokenchaincode generated."
    
fi


###############################################################
# Deploy CCAAS
###############################################################
if [[ "$opt_r" == "ccaas" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    ./scripts/ccaas.sh
    cool_down $opt_a "CCAAS deployed."
    
fi


###############################################################
# FINISH
###############################################################
echo_ok "Script for $DOCKER_NETWORK_NAME completed"
echo_error "Run CA-API-Server now: ./ca-api/ca-api.sh"
exit 0




###############################################################
# Start TokenNodes
###############################################################
if [[ "$opt_r" == "tokennode" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    ./scripts/tokennodes.sh
    cool_down $opt_a "Token Nodes started."
    
fi

temp_end

Read:
- fabric-samples/token-sdk/scripts/up.sh --> Zeile 38ff
- fabric-sample/test-network/network.sh --> Function deployCCAASS --> Deploys Chaincode --> scripts/deployCCAAS.sh
- fabric-samples/token-sdk/docker-compose.yaml --> starts token nodes and swagger-ui






# Install and start tokenchaincode as a service
#INIT_REQUIRED="--init-required" "$TEST_NETWORK_HOME/network.sh" deployCCAAS  -ccn tokenchaincode -ccp "$(pwd)/tokenchaincode" -cci "init" -ccs 1

# Start token nodes
#mkdir -p data/auditor data/issuer data/owner1 data/owner2
#docker-compose up -d
#echo "
#Ready!

#Visit http://localhost:8080 in your browser to view the API documentation and try some transactions.
#"