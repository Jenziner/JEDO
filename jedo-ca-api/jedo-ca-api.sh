###############################################################
#!/bin/bash
#
# This script starts JEDO CA API
# 
#
###############################################################
source ../jedo-network/scripts/settings.sh


###############################################################
# Params - from ./jedo-network/config/network-config.yaml
###############################################################
NETWORK_CONFIG_FILE="../jedo-network/config/network-config.yaml"
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $NETWORK_CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $NETWORK_CONFIG_FILE)
CHANNEL=$(yq e '.FabricNetwork.Channel' $NETWORK_CONFIG_FILE)
ORGANIZATIONS=$(yq e '.FabricNetwork.Organizations[].Name' $NETWORK_CONFIG_FILE)

# CA_DIR=/etc/hyperledger/fabric-ca
# CA_SRV_DIR=/etc/hyperledger/fabric-ca-server
# CA_CLI_DIR=/etc/hyperledger/fabric-ca-client
# KEYS_DIR=/etc/hyperledger/keys
# TLS_CERT_FILE="tls-${ROOTCA_NAME//./-}-${ROOTCA_PORT}.pem"

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
docker build --no-cache -t jedo-ca-api .

###############################################################
# Start Intermediate-CAs
###############################################################
for ORGANIZATION in $ORGANIZATIONS; do
    CA_EXT=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Ext" $NETWORK_CONFIG_FILE)
    CA_NAME=$(yq eval ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Name" $NETWORK_CONFIG_FILE)
    CA_PASS=$(yq eval ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Pass" $NETWORK_CONFIG_FILE)
    CA_IP=$(yq eval ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.IP" $NETWORK_CONFIG_FILE)
    CA_PORT=$(yq eval ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Port" $NETWORK_CONFIG_FILE)
    CA_API_NAME=$(yq eval ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CAAPI.Name" $NETWORK_CONFIG_FILE)
    CA_API_IP=$(yq eval ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CAAPI.IP" $NETWORK_CONFIG_FILE)
    CA_API_PORT=$(yq eval ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CAAPI.Port" $NETWORK_CONFIG_FILE)
    CA_API_SRV_PORT=$(yq eval ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CAAPI.SrvPort" $NETWORK_CONFIG_FILE)

    # skip if external CA is defined
    if ! [[ -n "$CA_EXT" ]]; then
        echo ""
        echo_warn "API-Server for $CA_NAME starting..."

        # Generate jedo-ca-api-config.yaml
        mkdir -p ${PWD}/$CA_API_NAME/config
        cp ${PWD}/package.json ${PWD}/$CA_API_NAME/package.json
        cp ${PWD}/server.js ${PWD}/$CA_API_NAME/server.js
        cp ${PWD}/enrollUser.sh ${PWD}/$CA_API_NAME/enrollUser.sh
        cp ${PWD}/registerUser.sh ${PWD}/$CA_API_NAME/registerUser.sh
        cp ${PWD}/start.sh ${PWD}/$CA_API_NAME/start.sh
        cat <<EOF > ${PWD}/$CA_API_NAME/config/jedo-ca-api-config.yaml
ca_name: "$(basename $CA_NAME)"
ca_pass: "$(basename $CA_PASS)"
ca_port: $(basename $CA_PORT)
api_port: $(basename $CA_API_SRV_PORT)
ca_msp_dir: "/etc/hyperledger/fabric-ca-client/msp"
keys_dir: "/etc/hyperledger/keys"
channel: "$(basename $CHANNEL)"
organization: "$(basename $ORGANIZATION)"
EOF

        # Run Docker Container
        docker run -d \
            --network $DOCKER_NETWORK_NAME \
            --name $CA_API_NAME \
            --ip $CA_API_IP \
            $hosts_args \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v ${PWD}/$CA_API_NAME:/app \
            -w /app \
            -p $CA_API_PORT:$CA_API_PORT \
            -p $CA_API_SRV_PORT:$CA_API_SRV_PORT \
            jedo-ca-api 
#            /bin/sh

#            bash -c "rm -rf node_modules package-lock.json && npm install && node server.js"
        # docker exec -it $CA_API_NAME /bin/sh -c "
        #     apk add --no-cache nodejs npm && \
        #     npm install
        # "
        # docker exec -it $CA_API_NAME /bin/sh
#        docker exec -it $CA_API_NAME node server.js

        echo_ok "API-Server for $CA_NAME started."

    fi
done

#            --restart=unless-stopped \


