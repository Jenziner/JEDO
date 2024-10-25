###############################################################
#!/bin/bash
#
# This script starts Hyperledger Fabric Orderer
#
#
###############################################################
source ./utils/utils.sh
source ./utils/help.sh
check_script

echo_ok "Starting Docker-Container for Orderer - see Documentation here: https://hyperledger-fabric.readthedocs.io"


###############################################################
# Params - from ./configinfrastructure-dev.yaml
###############################################################
CONFIG_FILE="./config/infrastructure-dev.yaml"
FABRIC_BIN_PATH=$(yq eval '.Fabric.Path' "$CONFIG_FILE")
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $CONFIG_FILE)
CHANNELS=$(yq e ".FabricNetwork.Channels[].Name" $CONFIG_FILE)


for CHANNEL in $CHANNELS; do
    export FABRIC_CFG_PATH=${PWD}/config/$CHANNEL
    CA_DIR=/etc/hyperledger/fabric-ca
    ORGANIZATIONS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[].Name" $CONFIG_FILE)

    get_hosts

    for ORGANIZATION in $ORGANIZATIONS; do
        CA_EXT=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Ext" $CONFIG_FILE)
        if [[ -n "$CA_EXT" ]]; then
            CA_NAME=$(yq eval ".. | select(has(\"CA\")) | .CA | select(.Name == \"$CA_EXT\") | .Name" "$CONFIG_FILE")
            CA_ORG=$(yq eval ".FabricNetwork.Channels[].Organizations[] | select(.CA.Name == \"$CA_NAME\") | .Name" "$CONFIG_FILE")
        else
            CA_NAME=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .CA.Name" $CONFIG_FILE)
            CA_ORG=$ORGANIZATION
        fi
        ORDERERS=$(yq eval ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Name" $CONFIG_FILE)

        for ORDERER in $ORDERERS; do
            ORDERER_NAME=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Name" $CONFIG_FILE)
            ORDERER_PASS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Pass" $CONFIG_FILE)
            ORDERER_IP=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[] | select(.Name == \"$ORDERER\") | .IP" $CONFIG_FILE)
            ORDERER_PORT=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[] | select(.Name == \"$ORDERER\") | .Port" $CONFIG_FILE)
            ORDERER_OPPORT=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[] | select(.Name == \"$ORDERER\") | .OpPort" $CONFIG_FILE)
            ORDERER_CLUSTER_PORT=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[] | select(.Name == \"$ORDERER\") | .ClusterPort" $CONFIG_FILE)
            
            TLS_PRIVATE_KEY=$(basename $(ls $PWD/keys/$CHANNEL/_infrastructure/$ORGANIZATION/$ORDERER_NAME/tls/keystore/*_sk))

            ORGS=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[].Name" $CONFIG_FILE)
            CLUSTER_PEERS=""
            for ORG in $ORGS; do
                ORG_ORDERERS_NAME=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].Name" $CONFIG_FILE)
                ORG_ORDERERS_PORT=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[].ClusterPort" $CONFIG_FILE)

                for index in $(seq 0 $(($(echo "$ORG_ORDERERS_NAME" | wc -l) - 1))); do
                    ORG_ORDERER_NAME=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[$index].Name" $CONFIG_FILE)
                    ORG_ORDERER_CLUSTER_PORT=$(yq e ".FabricNetwork.Channels[] | select(.Name == \"$CHANNEL\") | .Organizations[] | select(.Name == \"$ORGANIZATION\") | .Orderers[$index].ClusterPort" $CONFIG_FILE)

                    if [ "$ORG_ORDERER_NAME" != "$ORDERER_NAME" ]; then
                        CLUSTER_PEERS+="$ORG_ORDERER_NAME:$ORG_ORDERER_CLUSTER_PORT,"
                    fi
                done
            done
            CLUSTER_PEERS=$(echo $CLUSTER_PEERS | sed 's/,$//')

            WAIT_TIME=0
            SUCCESS=false

            echo ""
            echo_warn "Orderer $ORDERER_NAME starting..."
            docker run -d \
            --name $ORDERER_NAME \
            --network $DOCKER_NETWORK_NAME \
            --ip $ORDERER_IP \
            $hosts_args \
            --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/infrastructure/src/fabric_logo.png" \
            -e ORDERER_GENERAL_LISTENADDRESS=0.0.0.0 \
            -e ORDERER_GENERAL_LISTENPORT=$ORDERER_PORT \
            -e ORDERER_GENERAL_LOCALMSPID=${ORGANIZATION}MSP \
            -e ORDERER_GENERAL_LOCALMSPDIR=/etc/hyperledger/orderer/msp \
            -e ORDERER_GENERAL_TLS_ENABLED=true \
            -e ORDERER_GENERAL_TLS_CERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem \
            -e ORDERER_GENERAL_TLS_PRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/$TLS_PRIVATE_KEY \
            -e ORDERER_GENERAL_TLS_ROOTCAS=[/etc/hyperledger/orderer/msp/ca-chain.pem] \
            -e ORDERER_GENERAL_CLUSTER_LISTENADDRESS=0.0.0.0 \
            -e ORDERER_GENERAL_CLUSTER_LISTENPORT=$ORDERER_CLUSTER_PORT \
            -e ORDERER_GENERAL_CLUSTER_PEERS=[$CLUSTER_PEERS] \
            -e ORDERER_GENERAL_CLUSTER_SERVERCERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem \
            -e ORDERER_GENERAL_CLUSTER_SERVERPRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/$TLS_PRIVATE_KEY \
            -e ORDERER_GENERAL_CLUSTER_ROOTCAS=[/etc/hyperledger/orderer/msp/ca-chain.pem] \
            -e ORDERER_GENERAL_CLUSTER_CLIENTCERTIFICATE=/etc/hyperledger/orderer/tls/signcerts/cert.pem \
            -e ORDERER_GENERAL_CLUSTER_CLIENTPRIVATEKEY=/etc/hyperledger/orderer/tls/keystore/$TLS_PRIVATE_KEY \
            -e ORDERER_GENERAL_BOOTSTRAPMETHOD=none \
            -e ORDERER_CHANNELPARTICIPATION_ENABLED=true \
            -v $FABRIC_BIN_PATH/config/orderer.yaml:/etc/hyperledger/fabric/orderer.yaml \
            -v ${PWD}/keys/$CHANNEL/_infrastructure/$ORGANIZATION/$ORDERER_NAME/msp:/etc/hyperledger/orderer/msp \
            -v ${PWD}/keys/$CHANNEL/_infrastructure/$CA_ORG/$CA_NAME/ca-chain.pem:/etc/hyperledger/orderer/msp/ca-chain.pem \
            -v ${PWD}/keys/$CHANNEL/_infrastructure/$ORGANIZATION/$ORDERER_NAME/tls:/etc/hyperledger/orderer/tls \
            -v ${PWD}/production/$CHANNEL/$ORGANIZATION/$ORDERER_NAME:/var/hyperledger/production \
            -p $ORDERER_PORT:$ORDERER_PORT \
            -p $ORDERER_OPPORT:$ORDERER_OPPORT \
            -p $ORDERER_CLUSTER_PORT:$ORDERER_CLUSTER_PORT \
            --restart unless-stopped \
            hyperledger/fabric-orderer:latest

            # Waiting Intermediate-CA startup
            CheckContainer "$ORDERER_NAME" "$DOCKER_CONTAINER_WAIT"
            CheckContainerLog "$ORDERER_NAME" "Beginning to serve requests" "$DOCKER_CONTAINER_WAIT"
        done
    done
done

