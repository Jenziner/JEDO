###############################################################
#!/bin/bash
#
# This script tests the infrastructure
#
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
#check_script
echo ""
echo_error "Test Infrastructure starting..."


###############################################################
# Params
###############################################################
CONFIG_FILE="$SCRIPT_DIR/infrastructure-cc.yaml"


###############################################################
# CA-Server Test
###############################################################
echo ""
echo_info "Test CA-Server starting..."

echo_info "ORBIS CA-Server:"
CA=$(yq eval ".Orbis | .CA | .Name" $CONFIG_FILE)
CA_IP=$(yq eval ".Orbis | .CA | .IP" $CONFIG_FILE)
CA_PORT=$(yq eval ".Orbis | .CA | .Port" $CONFIG_FILE)
echo_warn "Testing $CA"
curl -k -w "\n" https://$CA_IP:$CA_PORT/cainfo

echo_info "REGNUM CA-Server:"
REGNUMS=$(yq eval '.Regnum[] | .Name' "$CONFIG_FILE")
for REGNUM in $REGNUMS; do
    CA=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .CA | .Name" $CONFIG_FILE)
    CA_IP=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .CA | .IP" $CONFIG_FILE)
    CA_PORT=$(yq eval ".Regnum[] | select(.Name == \"$REGNUM\") | .CA | .Port" $CONFIG_FILE)
    echo_warn "Testing $CA"
    curl -k -w "\n" https://$CA_IP:$CA_PORT/cainfo
done

echo_info "AGER CA-Server:"
AGERS=$(yq eval '.Ager[] | .Name' "$CONFIG_FILE")
for AGER in $AGERS; do
    CA=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA | .Name" $CONFIG_FILE)
    CA_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA | .IP" $CONFIG_FILE)
    CA_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .CA | .Port" $CONFIG_FILE)
    echo_warn "Testing $CA"
    curl -k -w "\n" https://$CA_IP:$CA_PORT/cainfo
done

echo_info "Test CA-Server completed."
echo ""


###############################################################
# Channel Test
###############################################################
echo ""
echo_info "Channel Test starting..."
AGERS=$(yq eval '.Ager[] | .Name' "$CONFIG_FILE")
for AGER in $AGERS; do
    PEERS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[].Name" $CONFIG_FILE)
    for PEER in $PEERS; do
        echo_warn "Testing $PEER"
        PEER_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Peers[] | select(.Name == \"$PEER\") | .Name" $CONFIG_FILE)
        echo_ok "Channel list:"
        docker exec -e FABRIC_LOGGING_SPEC=error $PEER_NAME peer channel list
        echo_ok "Installed chaincode:"
        docker exec -e FABRIC_LOGGING_SPEC=error $PEER_NAME peer lifecycle chaincode queryinstalled
        echo_ok "Committed chaincode:"
        docker exec -e FABRIC_LOGGING_SPEC=error $PEER_NAME peer lifecycle chaincode querycommitted -C ea
    done
done
echo_info "Channel Test completed."
echo ""


###############################################################
# SmartBFT Consensus Healt Test
###############################################################
echo ""
echo_info "Test SmartBFT Consensus Healt starting..."
AGERS=$(yq eval '.Ager[] | .Name' "$CONFIG_FILE")
for AGER in $AGERS; do
    ORDERERS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[].Name" $CONFIG_FILE)
    for ORDERER in $ORDERERS; do
        echo_warn "Testing $ORDERER"
        ORDERER_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Name" $CONFIG_FILE)
        docker logs $ORDERER_NAME 2>&1 | grep "Deliver.*writing block" | tail -5
    done
done
echo_info "Test SmartBFT Consensus Healt completed."
echo ""


###############################################################
# Last Tasks
###############################################################
echo ""
echo_error "Test Infrastructure completed..."




