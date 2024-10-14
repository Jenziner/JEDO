###############################################################
#!/bin/bash
#
# Temporary script.
#
#
###############################################################
source ./scripts/settings.sh
NETWORK_CONFIG_FILE="./config/network-config.yaml"
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $NETWORK_CONFIG_FILE)

ROOTCA_SRV_NAME=jedo.test
ROOTCA_SRV_IP=172.25.5.5


echo_info "Root-CA starting..."
docker run -d \
    --network $DOCKER_NETWORK_NAME \
    --name $ROOTCA_SRV_NAME \
    --ip $ROOTCA_SRV_IP \
    $hosts_args \
    --restart=unless-stopped \
    --label net.unraid.docker.icon="https://raw.githubusercontent.com/Jenziner/JEDO/main/jedo-network/src/fabric_ca_logo.png" \
    -e FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server \
    -e FABRIC_CA_SERVER_LOGLEVEL=debug \
    -e FABRIC_CA_SERVER_CA_NAME=myRootCA \
    -e FABRIC_CA_SERVER_LISTENADDRESS=192.168.0.99 \
    -e FABRIC_CA_SERVER_PORT=5030 \
    -e FABRIC_CA_SERVER_MSPDIR=/etc/hyperledger/fabric-ca-server/msp \
    -e FABRIC_CA_SERVER_TLS_ENABLED=true \
    -e FABRIC_CA_SERVER_TLS_CERTFILE=/etc/hyperledger/fabric-ca-server/ca-cert.pem \
    -e FABRIC_CA_SERVER_TLS_KEYFILE=/etc/hyperledger/fabric-ca-server/ca-key.pem \
    -v ${PWD}/test/myRootCA:/etc/hyperledger/fabric-ca-server \
    -p 5030:5030 \
    hyperledger/fabric-ca:latest \
    sh -c "fabric-ca-server start -b admin:Test1 --idemix.curve gurvy.Bn254 ;"


echo_info "Root-Admin enrolling..."
docker exec -it myRootCA fabric-ca-client enroll \
    --url https://admin:Test1@0.0.0.0:5030 --mspdir /etc/hyperledger/fabric-ca-server/msp


echo_info "Affiliation add..."
docker exec -it myRootCA fabric-ca-client affiliation add myOrg \
    --url https://admin:Test1@0.0.0.0:5030  


echo_info "Intermediate-CA-Admin registering..."
docker exec -it myRootCA fabric-ca-client register \
    --url https://0.0.0.0:5030 --mspdir /etc/hyperledger/fabric-ca-server/msp \
    --id.name myIntCA --id.secret Test1 --id.type client \
#    --tls.client.certfile /etc/hyperledger/fabric-ca-server/msp/signcerts/sign-ca-cert.pem \
#    --tls.client.keyfile /etc/hyperledger/fabric-ca-server/msp/keystore/sign-ca-key.pem \


echo_info "Intermediate-CA-Admin enroll..."
docker exec -it myRootCA fabric-ca-client enroll \
    --url https://myIntCA:Test1@0.0.0.0:5030 --tls.certfiles /etc/hyperledger/fabric-ca-server/msp/cacerts/root-ca-cert.pem --mspdir /etc/hyperledger/fabric-ca-server/myIntCA

chmod -R 777 ./test



    # -e FABRIC_CA_SERVER_TLS_ENABLED=true \
    # -e FABRIC_CA_SERVER_TLS_CERTFILE=/etc/hyperledger/fabric-ca-server/tls/tlscacerts/tls-ca-cert.pem \
    # -e FABRIC_CA_SERVER_TLS_KEYFILE=/etc/hyperledger/fabric-ca-server/tls/tlscacerts/tls-ca-key.pem \


# --tls.certfiles /etc/hyperledger/fabric-ca-server/tls/tlscacerts/tls-ca-cert.pem