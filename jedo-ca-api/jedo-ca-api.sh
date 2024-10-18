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
        cp ${PWD}/start.sh ${PWD}/$CA_API_NAME/start.sh
        cat <<EOF > ${PWD}/$CA_API_NAME/config/jedo-ca-api-config.yaml
ca_name: "${CA_NAME}"
ca_url: "https://${CA_NAME}:${CA_PORT}"
ca_pass: "${CA_PASS}"
api_port: ${CA_API_SRV_PORT}
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
            -v ${PWD}/$CA_API_NAME:/app \
            -v ${PWD}/../jedo-network/keys:/etc/hyperledger/keys \
            -v ${PWD}/../jedo-network/keys/cli.$CA_NAME/msp:/app/admin \
            -v ${PWD}/../jedo-network/keys/tls.$CA_NAME/tls-cert.pem:/app/tls/tls-cert.pem \
            -w /app \
            -p $CA_API_PORT:$CA_API_PORT \
            -p $CA_API_SRV_PORT:$CA_API_SRV_PORT \
            jedo-ca-api 

        CheckContainerLog $CA_API_NAME "Server running on port $CA_API_SRV_PORT" "$DOCKER_CONTAINER_WAIT"

        echo_ok "API-Server for $CA_NAME started."

    fi
done



