###############################################################
#!/bin/bash
#
# This script generates a new jedo-network according infrastructure.yaml
# Fabric Documentation: https://hyperledger-fabric.readthedocs.io
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/help.sh"
source "$SCRIPT_DIR/params.sh"

export JEDO_INITIATED="yes"

log_section "JEDO-Ecosystem $DOCKER_NETWORK_NAME starting..."

###############################################################
# Arguments
###############################################################
if [[ $# -eq 0 ]]; then
    up_help
fi
opt_d=false
opt_a="n/a"
opt_r="n/a"
export LOGLEVEL="INFO"
export DEBUG=false
export FABRIC_LOGGING_SPEC="INFO"
export FABRIC_CA_SERVER_LOGLEVEL="info"

while getopts ":hpda:r:-:" opt; do
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
                log_error "invalid argument for -a: $OPTARG" >&2
                echo "use -h for help" >&2
                exit 3
            fi
            opt_a="$OPTARG"
            ;;
        r )
            if [[ "$OPTARG" != "tools" && "$OPTARG" != "ldap" && "$OPTARG" != "ca" && "$OPTARG" != "node" && "$OPTARG" != "enroll" && "$OPTARG" != "channel" && "$OPTARG" != "genesis" && "$OPTARG" != "net" && "$OPTARG" != "orderer" && "$OPTARG" != "peer" && "$OPTARG" != "tokengen" && "$OPTARG" != "ccaas" && "$OPTARG" != "tokennode" && "$OPTARG" != "prereq" && "$OPTARG" != "root" && "$OPTARG" != "gateway" && "$OPTARG" != "wallet" && "$OPTARG" != "services" && "$OPTARG" != "intermediate" ]]; then
                log_error "invalid argument for -r: $OPTARG" >&2
                echo "use -h for help" >&2
                exit 3
            fi
            opt_r="$OPTARG"
            ;;
        - )
            case "${OPTARG}" in
                debug)
                    export LOGLEVEL="DEBUG"
                    export DEBUG=true
                    export FABRIC_LOGGING_SPEC="DEBUG"
                    export FABRIC_CA_SERVER_LOGLEVEL="debug"
                    log_info "Debug-Modus aktiviert" >&2
                    ;;
                *)
                    log_error "invalid long option: --$OPTARG" >&2
                    exit 2
                    ;;
            esac
            ;;
        \? )
            log_error "invalid option: -$OPTARG" >&2
            exit 2
            ;;
        : )
            log_error "option -$OPTARG requires argument." >&2
            exit 2
            ;;
    esac
done


###############################################################
# Checks
###############################################################
if [[ "$opt_r" == "prereq" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    log_section "Prerequisites checking..."
    $SCRIPT_DIR/prereq.sh
    cool_down $opt_a "Prerequisites checked."
fi


###############################################################
# Delete previous installation
###############################################################
if $opt_d || [[ "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    log_section "Previous installation deleting..."
    $SCRIPT_DIR/down.sh
    cool_down $opt_a "Previous installation deleted."
fi


###############################################################
# Create Docker Network
###############################################################
if [[ "$opt_r" == "net" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    log_section "Docker Network starting..."
    if ! docker network ls --format '{{.Name}}' | grep -wq "$DOCKER_NETWORK_NAME"; then
        docker network create --subnet=$DOCKER_NETWORK_SUBNET --gateway=$DOCKER_NETWORK_GATEWAY "$DOCKER_NETWORK_NAME"
    fi
    docker network inspect "$DOCKER_NETWORK_NAME"
    cool_down $opt_a "Docker Network started."
    log_ok "Docker Network started."
fi


###############################################################
# Run CA
###############################################################
if [[ "$opt_r" == "ca" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    log_section "CA starting..."
    $SCRIPT_DIR/ca_tls-node.sh
    $SCRIPT_DIR/ca_tls-certs.sh
    $SCRIPT_DIR/ca_ca-nodes.sh
    $SCRIPT_DIR/enroll.sh
    cool_down $opt_a "CA started."
fi


###############################################################
# Run Orderer
###############################################################
if [[ "$opt_r" == "orderer" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    log_section "Orderers starting..."
    $SCRIPT_DIR/orderer_cert.sh
    $SCRIPT_DIR/orderer_node.sh
    cool_down $opt_a "Orderers started."
fi


###############################################################
# Run Peer
###############################################################
if [[ "$opt_r" == "peer" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    log_section "Peers starting..."
   $SCRIPT_DIR/peer.sh peer
    cool_down $opt_a "Peers started."
fi


###############################################################
# Generate genesis block and channel configuration
###############################################################
if [[ "$opt_r" == "genesis" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    log_section "Genesis Block and Channel Configuration generating..."
    $SCRIPT_DIR/genesis-block-orbis.sh
    $SCRIPT_DIR/genesis-block-regnum.sh
    cool_down $opt_a "Genesis Block and Channel Configuration generated."
fi


###############################################################
# Create Channel
###############################################################
if [[ "$opt_r" == "channel" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    log_section "Channel creating..."
    $SCRIPT_DIR/channel.sh
    cool_down $opt_a "Channel created."
fi


###############################################################
# Chaincode jedo-wallet Deployment
###############################################################
if [[ "$opt_r" == "wallet" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    log_section "Chaincode deploying..."
    $SCRIPT_DIR/cc_jedo-wallet.sh
    cool_down $opt_a "Chaincode deployed."
fi


###############################################################
# Gateway Services
###############################################################
if [[ "$opt_r" == "services" || "$opt_a" == "go" || "$opt_a" == "pause" ]]; then
    log_section "Gateway services deploying..."
    $SCRIPT_DIR/gateway-services.sh
    $SCRIPT_DIR/gateway.sh
    cool_down $opt_a "Gateway services deployed."
fi


###############################################################
# FINISH
###############################################################
log_section "JEDO-Ecosystem $DOCKER_NETWORK_NAME done!"
exit 0

