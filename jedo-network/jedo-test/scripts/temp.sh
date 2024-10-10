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

        # waiting startup for CA
        WAIT_TIME=0
        SUCCESS=false

        while [ $WAIT_TIME -lt $DOCKER_CONTAINER_WAIT ]; do
            if docker inspect -f '{{.State.Running}}' $CA_NAME | grep true > /dev/null; then
                SUCCESS=true
                echo_info "ScriptInfo: $CA_NAME is up and running!"
                break
            fi
            echo "Waiting for $CA_NAME... ($WAIT_TIME seconds)"
            sleep 2
            WAIT_TIME=$((WAIT_TIME + 2))
        done
