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
ORBIS_TOOLS_INFRA_DIR=/etc/hyperledger/fabric-ca-client/infrastructure

ORBIS=$(yq eval ".Orbis.Name" "$CONFIG_FILE")


###############################################################
# Generate public parameter for tokenchaincode
###############################################################
echo ""
echo_info "Generate public parameter for tokenchaincode"

# Generate List of Issuers and Auditors
AGERS=$(yq eval '.Ager[] | .Name' "$CONFIG_FILE")
ISSUER_LIST=""
AUDITOR_LIST=""
for AGER in $AGERS; do
    REGNUM=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Administration.Parent" $CONFIG_FILE)
    ISSUERS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Issuers[].Name" $CONFIG_FILE)
    for ISSUER in $ISSUERS; do
        ISSUER_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Issuers[] | select(.Name == \"$ISSUER\") | .Name" $CONFIG_FILE)
        ISSUER_LIST=$ISSUER_LIST,$ORBIS_TOOLS_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$ISSUER_NAME/msp
    done
    AUDITORS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Auditors[].Name" $CONFIG_FILE)
    for AUDITOR in $AUDITORS; do
        AUDITOR_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Auditors[] | select(.Name == \"$AUDITOR\") | .Name" $CONFIG_FILE)
        AUDITOR_LIST=$AUDITOR_LIST,$ORBIS_TOOLS_INFRA_DIR/$ORBIS/$REGNUM/$AGER/$AUDITOR_NAME/msp
    done
done

# Remove first coma in each list
ISSUER_LIST=${ISSUER_LIST:1}
AUDITOR_LIST=${AUDITOR_LIST:1}

# Generate zkatdlog_pp.json
docker exec $ORBIS_TOOLS_NAME bash -c "tokengen gen dlog --base 300 --exponent 5 \
    --issuers \"$ISSUER_LIST\" \
    --idemix \"$ORBIS_TOOLS_INFRA_DIR/jedo/ea/alps/WORB/do\" \
    --auditors \"$AUDITOR_LIST\" \
    --output \"$ORBIS_TOOLS_INFRA_DIR/jedo/ea/configuration\""