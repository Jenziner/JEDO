###############################################################
#!/bin/bash
#
# Temporary script.
#
#
###############################################################
source ./scripts/settings.sh


###############################################################
# Set variables
###############################################################
NETWORK_CONFIG_FILE="./config/network-config.yaml"
ORGANIZATIONS=$(yq e '.FabricNetwork.Organizations[].Name' $NETWORK_CONFIG_FILE)


DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $NETWORK_CONFIG_FILE)
ORGANIZATIONS=$(yq e '.FabricNetwork.Organizations[].Name' $NETWORK_CONFIG_FILE)

CA_NAME=ca.jenziner.jedo.test
CA_PORT=7040

ORGANIZATION=NeuLich

USERNAME=Ich
USERPASS=Test1


echo "Admin enrollen"
docker exec -it cli.ca.jenziner.jedo.test fabric-ca-client enroll \
-u https://ca.jenziner.jedo.test:Test1@$CA_NAME:$CA_PORT \
-M /etc/hyperledger/fabric-ca-server/msp

echo "Starte Register"
docker exec -it cli.ca.jenziner.jedo.test fabric-ca-client register \
-u https://$CA_NAME:$CA_PORT \
--id.name $USERNAME --id.secret $USERPASS \
--id.type admin --id.affiliation $ORGANIZATION

echo "Starte Enrollment"
docker exec -it cli.ca.jenziner.jedo.test fabric-ca-client enroll \
-u https://$USERNAME:$USERPASS@$CA_NAME:$CA_PORT \
-M /etc/hyperledger/fabric-ca-client/$USERNAME

