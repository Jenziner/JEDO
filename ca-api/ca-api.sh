###############################################################
#!/bin/bash
#
# This script starts JEDO CA API
# 
#
###############################################################
source ./dev/utils/utils.sh
export JEDO_INITIATED="yes"
check_script


###############################################################
# Params - from ./jedo-network/config/network-config.yaml
###############################################################
CONFIG_FILE="./dev/config/infrastructure-dev.yaml"
DOCKER_UNRAID=$(yq eval '.Docker.Unraid' $CONFIG_FILE)
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $CONFIG_FILE)
DOCKER_UNRAID=$(yq eval '.Docker.Unraid' $CONFIG_FILE)
CHANNELS=$(yq e ".FabricNetwork.Channels[].Name" $CONFIG_FILE)

for CHANNEL in $CHANNELS; do
    ORGANIZATIONS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[].Name" $CONFIG_FILE)

    get_hosts


    ###############################################################
    # Remove old stuff
    ###############################################################
    echo_warn "Old Container and Folder removing..."
    docker ps -a -q --filter "name=^api.ca" | xargs -r docker rm -f
    find . -type d -name "api.ca*" -print0 | xargs -0 -r rm -rf
    docker rmi -f jedo-ca-api

    ###############################################################
    # Generate Docker Image
    ###############################################################
    echo_warn "Docker Image generating..."
    docker build --no-cache -t jedo-ca-api ./ca-api

    ###############################################################
    # Start Intermediate-CAs
    ###############################################################
    for ORGANIZATION in $ORGANIZATIONS; do
        CA_EXT=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Ext" $CONFIG_FILE)
        CA_NAME=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Name" $CONFIG_FILE)
        CA_PASS=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Pass" $CONFIG_FILE)
        CA_IP=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.IP" $CONFIG_FILE)
        CA_PORT=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Port" $CONFIG_FILE)
        CA_API_NAME=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.CAAPI.Name" $CONFIG_FILE)
        CA_API_IP=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.CAAPI.IP" $CONFIG_FILE)
        CA_API_PORT=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.CAAPI.Port" $CONFIG_FILE)
        CA_API_SRV_PORT=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.CAAPI.SrvPort" $CONFIG_FILE)

        # skip if external CA is defined
        if ! [[ -n "$CA_EXT" ]]; then
            echo ""
            echo_warn "API-Server for $CA_NAME starting..."

            # Generate jedo-ca-api-config.yaml
            mkdir -p ${PWD}/dev/production/$CHANNEL/$ORGANIZATION/$CA_API_NAME/config
            cp ${PWD}/ca-api/package.json ${PWD}/dev/production/$CHANNEL/$ORGANIZATION/$CA_API_NAME/package.json
            cp ${PWD}/ca-api/server.js ${PWD}/dev/production/$CHANNEL/$ORGANIZATION/$CA_API_NAME/server.js
            cp ${PWD}/ca-api/utils.js ${PWD}/dev/production/$CHANNEL/$ORGANIZATION/$CA_API_NAME/utils.js
            cp ${PWD}/ca-api/start.sh ${PWD}/dev/production/$CHANNEL/$ORGANIZATION/$CA_API_NAME/start.sh
            cat <<EOF > ${PWD}/dev/production/$CHANNEL/$ORGANIZATION/$CA_API_NAME/config/jedo-ca-api-config.yaml
ca_name: "${CA_NAME}"
ca_url: "https://${CA_NAME}:${CA_PORT}"
ca_pass: "${CA_PASS}"
ca_port: "${CA_PORT}"
ca_cli_dir: "/etc/hyperledger/fabric-ca-client/msp"
api_name: ${CA_API_NAME}
api_IP: ${CA_API_IP}
api_port: ${CA_API_SRV_PORT}
unraid_IP: ${DOCKER_UNRAID}
keys_dir: "/etc/hyperledger/keys"
channel: "${CHANNEL}"
organization: "${ORGANIZATION}"
EOF

            # Run Docker Container
            docker run -d \
                --network $DOCKER_NETWORK_NAME \
                --name $CA_API_NAME \
                --ip $CA_API_IP \
                --restart=unless-stopped \
                $hosts_args \
                -e FABRIC_CA_CLIENT_TLS_CERTFILES=/app/tls/tls-cert.pem \
                -v ${PWD}/dev/production/$CHANNEL/$ORGANIZATION/$CA_API_NAME:/app \
                -v ${PWD}/dev/keys:/etc/hyperledger/keys \
                -v ${PWD}/dev/keys/$CHANNEL/_infrastructure/$ORGANIZATION/cli.$CA_NAME/msp:/app/admin \
                -w /app \
                -p $CA_API_PORT:$CA_API_PORT \
                -p $CA_API_SRV_PORT:$CA_API_SRV_PORT \
                jedo-ca-api 

            echo_warn "Server start takes about 20s"
            CheckContainerLog $CA_API_NAME "Server running on port $CA_API_SRV_PORT" "$DOCKER_CONTAINER_WAIT"

            echo_ok "API-Server for $CA_NAME started."

        fi
    done
done



