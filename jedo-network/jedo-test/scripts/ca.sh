###############################################################
#!/bin/bash
#
# This script starts Hyperledger Fabric CA
# 
#
###############################################################
source ./scripts/settings.sh
source ./scripts/help.sh
check_script

echo_ok "Starting CA Docker Container - see Documentation here: https://hyperledger-fabric-ca.readthedocs.io"

###############################################################
# Params - from ./config/network-config.yaml
###############################################################
NETWORK_CONFIG_FILE="./config/network-config.yaml"
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $NETWORK_CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $NETWORK_CONFIG_FILE)
ORGANIZATIONS=$(yq e '.FabricNetwork.Organizations[].Name' $NETWORK_CONFIG_FILE)

get_hosts

###############################################################
# Starting CA Docker-Container
###############################################################
for ORGANIZATION in $ORGANIZATIONS; do
    CA_EXT=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Ext" $NETWORK_CONFIG_FILE)

    # get proper CA Server settings
    if ! [[ -n "$CA_EXT" ]]; then
        # set variables
        CA_NAME=$(yq eval ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Name" $NETWORK_CONFIG_FILE)
        CA_IP=$(yq eval ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.IP" $NETWORK_CONFIG_FILE)
        CA_PORT=$(yq eval ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Port" $NETWORK_CONFIG_FILE)
        CA_PASS=$(yq eval ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Pass" $NETWORK_CONFIG_FILE)
        CA_OPPORT=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.OpPort" $NETWORK_CONFIG_FILE)
        CA_CLI=$(yq e ".FabricNetwork.Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.CLI" $NETWORK_CONFIG_FILE)

        # genereate selfsigned TLS-certificate for CA Server
        mkdir -p "${PWD}/keys/$ORGANIZATION/$CA_NAME/tls/signcerts"
        mkdir -p "${PWD}/keys/$ORGANIZATION/$CA_NAME/tls/keystore"
        TLS_CERT="${PWD}/keys/$ORGANIZATION/$CA_NAME/tls/signcerts/ca-cert.pem"
        TLS_KEY="${PWD}/keys/$ORGANIZATION/$CA_NAME/tls/keystore/ca-key.pem"
        openssl genpkey -algorithm EC -out "$TLS_KEY" -pkeyopt ec_paramgen_curve:P-256
        openssl req -new -x509 -key "$TLS_KEY" -out "$TLS_CERT" -days 365 -subj "/C=US/ST=North Carolina/O=Hyperledger/OU=Fabric/CN=fabric-ca-server"

        # run CA Server
        echo_info "ScriptInfo: running $CA_NAME"
        docker run -d \
            --network $DOCKER_NETWORK_NAME \
            --name $CA_NAME \
            --ip $CA_IP \
            $hosts_args \
            --restart=unless-stopped \
            --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/jedo-network/src/fabric_ca_logo.png" \
            -e FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server \
            -e FABRIC_CA_SERVER_CA_NAME=$CA_NAME \
            -e FABRIC_CA_SERVER_LISTENADDRESS=$CA_IP \
            -e FABRIC_CA_SERVER_PORT=$CA_PORT \
            -e FABRIC_CA_SERVER_TLS_ENABLED=true \
            -e FABRIC_CA_SERVER_TLS_CERTFILE=/etc/hyperledger/fabric-ca/tls/signcerts/ca-cert.pem \
            -e FABRIC_CA_SERVER_TLS_KEYFILE=/etc/hyperledger/fabric-ca/tls/keystore/ca-key.pem \
            -e FABRIC_CA_OPERATIONS_LISTENADDRESS=0.0.0.0:$CA_OPPORT \
            -e FABRIC_CA_OPERATIONS_TLS_ENABLED=true \
            -e FABRIC_CA_OPERATIONS_TLS_CERTFILE=/etc/hyperledger/fabric-ca/tls/signcerts/ca-cert.pem \
            -e FABRIC_CA_OPERATIONS_TLS_KEYFILE=/etc/hyperledger/fabric-ca/tls/keystore/ca-key.pem \
            -v ${PWD}/production/$ORGANIZATION/$CA_NAME:/etc/hyperledger/fabric-ca-server \
            -v ${PWD}/keys/$ORGANIZATION/$CA_NAME:/etc/hyperledger/fabric-ca \
            -p $CA_PORT:$CA_PORT \
            -p $CA_OPPORT:$CA_OPPORT \
            hyperledger/fabric-ca:latest \
            sh -c "fabric-ca-server start -b $CA_NAME:$CA_PASS --idemix.curve gurvy.Bn254 -d"

            # Workaround because fabric reads values from file and not from environment variables
            echo_info "Workaround because fabric reads values from file and not from environment variables"
            sleep 5
            docker cp $CA_NAME:/etc/hyperledger/fabric-ca-server/fabric-ca-server-config.yaml ./fabric-ca-server-config.yaml
            sed -i "s/listenAddress: 127.0.0.1:9443/listenAddress: 0.0.0.0:$CA_OPPORT/" ./fabric-ca-server-config.yaml
            docker cp ./fabric-ca-server-config.yaml $CA_NAME:/etc/hyperledger/fabric-ca-server/fabric-ca-server-config.yaml
            docker restart $CA_NAME
            rm ./fabric-ca-server-config.yaml
            echo_ok "Workaround completed"
            sleep 5

        # waiting startup for CA
        WAIT_TIME=0
        SUCCESS=false
        while [ $WAIT_TIME -lt $DOCKER_CONTAINER_WAIT ]; do
            response=$(curl -vk http://$CA_IP:$CA_OPPORT/healthz 2>&1 | grep "OK")
            if [[ $response == *"OK"* ]]; then
                SUCCESS=true
                echo_info "ScriptInfo: $CA_NAME is up and running!"
                break
            fi
            echo "Waiting for $CA_NAME... ($WAIT_TIME seconds)"
            sleep 2
            WAIT_TIME=$((WAIT_TIME + 2))
        done

        if [ "$SUCCESS" = false ]; then
            echo_error "ScriptError: $CA_NAME did not start."
            docker logs $CA_NAME
            exit 1
        fi

        # run CA Client if defined
        if [[ -n "$CA_CLI" ]]; then
            docker run -d -it \
                --name cli.$CA_NAME \
                --network $DOCKER_NETWORK_NAME \
                --ip $CA_CLI \
                $hosts_args \
                --restart=unless-stopped \
                --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/jedo-network/src/fabric_cli_logo.png" \
                -v /mnt/user/appdata/fabric-ca/crypto-config:/etc/hyperledger/fabric-ca-server \
                hyperledger/fabric-ca:latest bash
        fi
    else
        echo_info "ScriptInfo: $CA_EXT is used for $ORGANIZATION and running!"
    fi

done
