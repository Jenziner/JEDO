###############################################################
#!/bin/bash
#
# Register and enroll all identities needed for the JEDO-Token-Test network.
#
# Prerequisits:
#   - yq: 
#       - installation: sudo wget https://github.com/mikefarah/yq/releases/download/v4.6.3/yq_linux_amd64 -O /usr/local/bin/yq
#       - make it executable: chmod +x /usr/local/bin/yq
#
###############################################################
set -Exeuo pipefail
ls scripts/enroll.sh || { echo "ScriptInfo: run this script from the root directory: ./scripts/enroll.sh"; exit 1; }


###############################################################
# Params - from ./config/network-config.yaml
###############################################################
CONFIG_FILE="./config/network-config.yaml"
NETWORK_CA_NAME=$(yq eval '.Network.CA.Name' "$CONFIG_FILE")
NETWORK_CA_PORT=$(yq eval '.Network.CA.Port' "$CONFIG_FILE")
NETWORK_CA_ADMIN_NAME=$(yq eval '.Network.CA.Admin.Name' "$CONFIG_FILE")
NETWORK_CA_ADMIN_PASS=$(yq eval '.Network.CA.Admin.Pass' "$CONFIG_FILE")
FSCS=$(yq e '.Network.FSCs[] | .Name' $CONFIG_FILE)
FSCS_PASSWORD=$(yq e '.Network.FSCs[] | .Pass' $CONFIG_FILE)
FSCS_OWNER=$(yq e '.Network.FSCs[] | .Owner' $CONFIG_FILE)
AUDITORS=$(yq e '.Network.Auditors[] | .Name' $CONFIG_FILE)
AUDITORS_PASSWORD=$(yq e '.Network.Auditors[] | .Pass' $CONFIG_FILE)
AUDITORS_OWNER=$(yq e '.Network.Auditors[] | .Owner' $CONFIG_FILE)
ISSUERS=$(yq e '.Network.Issuers[] | .Name' $CONFIG_FILE)
ISSUERS_PASSWORD=$(yq e '.Network.Issuers[] | .Pass' $CONFIG_FILE)
ISSUERS_OWNER=$(yq e '.Network.Issuers[] | .Owner' $CONFIG_FILE)
USERS=$(yq e '.Network.Users[] | .Name' $CONFIG_FILE)
USERS_PASSWORD=$(yq e '.Network.Users[] | .Pass' $CONFIG_FILE)
USERS_OWNER=$(yq e '.Network.Users[] | .Owner' $CONFIG_FILE)


###############################################################
# Certificat Enrollement
###############################################################
# enroll admin
fabric-ca-client enroll -u http://$NETWORK_CA_ADMIN_NAME:$NETWORK_CA_ADMIN_PASS@$NETWORK_CA_NAME:$NETWORK_CA_PORT

# Fabric Smart Client node identities (identity of the node, used when talking to other nodes)
echo "ScriptInfo: register fsc"
for index in $(seq 0 $(($(echo "$FSCS" | wc -l) - 1))); do
  FSC=$(echo "$FSCS" | sed -n "$((index+1))p")
  FSC_PASSWORD=$(echo "$FSCS_PASSWORD" | sed -n "$((index+1))p")
  FSC_OWNER=$(echo "$FSCS_OWNER" | sed -n "$((index+1))p")
  fabric-ca-client register -u http://$NETWORK_CA_NAME:$NETWORK_CA_PORT --id.name fsc$FSC --id.secret $FSC_PASSWORD --id.type client
  fabric-ca-client enroll -u http://fsc$FSC:$FSC_PASSWORD@$NETWORK_CA_NAME:$NETWORK_CA_PORT -M "$(pwd)/keys/$FSC_OWNER/fsc/msp"
  # make private key name predictable
  mv "$(pwd)/keys/$FSC_OWNER/fsc/msp/keystore/"* "$(pwd)/keys/$FSC_OWNER/fsc/msp/keystore/priv_sk"
done

# Issuer and Auditor wallet users (non-anonymous)
echo "ScriptInfo: register auditors"
for index in $(seq 0 $(($(echo "$AUDITORS" | wc -l) - 1))); do
  AUDITOR=$(echo "$AUDITORS" | sed -n "$((index+1))p")
  AUDITOR_PASSWORD=$(echo "$AUDITORS_PASSWORD" | sed -n "$((index+1))p")
  AUDITOR_OWNER=$(echo "$AUDITORS_OWNER" | sed -n "$((index+1))p")
  fabric-ca-client register -u http://$NETWORK_CA_NAME:$NETWORK_CA_PORT --id.name $AUDITOR --id.secret $AUDITOR_PASSWORD --id.type client
  fabric-ca-client enroll -u http://$AUDITOR:$AUDITOR_PASSWORD@$NETWORK_CA_NAME:$NETWORK_CA_PORT -M "$(pwd)/keys/$AUDITOR_OWNER/$AUDITOR/msp"
done
echo "ScriptInfo: register issuers"
for index in $(seq 0 $(($(echo "$ISSUERS" | wc -l) - 1))); do
  ISSUER=$(echo "$ISSUERS" | sed -n "$((index+1))p")
  ISSUER_PASSWORD=$(echo "$ISSUERS_PASSWORD" | sed -n "$((index+1))p")
  ISSUER_OWNER=$(echo "$ISSUERS_OWNER" | sed -n "$((index+1))p")
  fabric-ca-client register -u http://$NETWORK_CA_NAME:$NETWORK_CA_PORT --id.name $ISSUER --id.secret $ISSUER_PASSWORD --id.type client
  fabric-ca-client enroll -u http://$ISSUER:$ISSUER_PASSWORD@$NETWORK_CA_NAME:$NETWORK_CA_PORT -M "$(pwd)/keys/$ISSUER_OWNER/$ISSUER/msp"
done

# Owner wallet users (pseudonymous) on all owner nodes
echo "ScriptInfo: register users"
for index in $(seq 0 $(($(echo "$USERS" | wc -l) - 1))); do
  USER=$(echo "$USERS" | sed -n "$((index+1))p")
  USER_PASSWORD=$(echo "$USERS_PASSWORD" | sed -n "$((index+1))p")
  USER_OWNER=$(echo "$USERS_OWNER" | sed -n "$((index+1))p")
  fabric-ca-client register -u http://$NETWORK_CA_NAME:$NETWORK_CA_PORT --id.name $USER --id.secret $USER_PASSWORD --id.type client --enrollment.type idemix --idemix.curve gurvy.Bn254
  fabric-ca-client enroll -u http://$USER:$USER_PASSWORD@$NETWORK_CA_NAME:$NETWORK_CA_PORT -M "$(pwd)/keys/$USER_OWNER/wallet/$USER/msp" --enrollment.type idemix --idemix.curve gurvy.Bn254
done

