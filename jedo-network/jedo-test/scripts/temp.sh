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

# fabric-ca-server start \
#     --port 7040 \
#     --tls.certfile /etc/hyperledger/fabric-ca/tls/signcerts/ca-cert.pem \
#     --tls.keyfile /etc/hyperledger/fabric-ca/tls/keystore/ca-key.pem \
#     --operations.listenaddress 172.25.1.10:7049 \
#     --operations.tls.enabled \
#     --operations.tls.certfile /etc/hyperledger/fabric-ca/tls/signcerts/ca-cert.pem \
#     --operations.tls.keyfile /etc/hyperledger/fabric-ca/tls/keystore/ca-key.pem \
#     --ca.name ca.jenziner.jedo.test


docker run -d \
  --name ca.jenziner.jedo.test \
  --ip 172.25.1.10 \
    -e FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server \
    -e FABRIC_CA_SERVER_CA_NAME=ca.jenziner.jedo.test \
    -e FABRIC_CA_SERVER_LISTENADDRESS=172.25.1.10 \
    -e FABRIC_CA_SERVER_PORT=7040 \
    -e FABRIC_CA_SERVER_TLS_ENABLED=true \
    -e FABRIC_CA_SERVER_TLS_CERTFILE=/etc/hyperledger/fabric-ca/tls/signcerts/ca-cert.pem \
    -e FABRIC_CA_SERVER_TLS_KEYFILE=/etc/hyperledger/fabric-ca/tls/keystore/ca-key.pem \
    -e FABRIC_CA_OPERATIONS_LISTENADDRESS=0.0.0:7049 \
    -e FABRIC_CA_OPERATIONS_TLS_ENABLED=true \
    -e FABRIC_CA_OPERATIONS_TLS_CERTFILE=/etc/hyperledger/fabric-ca/tls/signcerts/ca-cert.pem \
    -e FABRIC_CA_OPERATIONS_TLS_KEYFILE=/etc/hyperledger/fabric-ca/tls/keystore/ca-key.pem \
    -v ${PWD}/production/JenzinerOrg/ca.jenziner.jedo.test:/etc/hyperledger/fabric-ca-server \
    -v ${PWD}/keys/JenzinerOrg/ca.jenziner.jedo.test:/etc/hyperledger/fabric-ca \
    -p 7040:7040 \
    -p 7049:7049 \
    hyperledger/fabric-ca:latest \
    sh -c "fabric-ca-server start -b ca.jenziner.jedo.test:Test1 --idemix.curve gurvy.Bn254 -d"
