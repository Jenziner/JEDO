###############################################################
#!/bin/bash
#
# This script creates all Token-Nodes
#
#
###############################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
check_script


###############################################################
# Params - from ./configinfrastructure-cc.yaml
###############################################################
CONFIG_FILE="$SCRIPT_DIR/infrastructure-cc.yaml"
FABRIC_BIN_PATH=$(yq eval '.Fabric.Path' "$CONFIG_FILE")
DOCKER_NETWORK_NAME=$(yq eval '.Docker.Network.Name' $CONFIG_FILE)
DOCKER_CONTAINER_WAIT=$(yq eval '.Docker.Container.Wait' $CONFIG_FILE)
ORBIS=$(yq eval ".Orbis.Name" "$CONFIG_FILE")

get_hosts


###############################################################
# Function writeDockerfile
###############################################################
writeDockerfile() {
    echo ""
    echo_warn "Dockerfile for Token-Nodes writing..."
    echo_info "Executing with the following:"
    echo_info "- Dockerfile Path: ${ORANGE}${CONFIG_SRC_PATH}${NC}"

cat <<EOF > $CONFIG_SRC_PATH/dockerfile_token_node
#build stage
FROM golang:1.23-bookworm AS builder
WORKDIR /go/src/app
COPY go.mod .
COPY go.sum .
RUN go mod download
COPY . .
RUN go build -o /go/bin/app

#final stage
FROM golang:1.23-bookworm
COPY --from=builder /go/bin/app /app
ENTRYPOINT /app
LABEL Name=tokens Version=0.1.0

ENV PORT=9000
ENV CONF_DIR=/conf
EXPOSE 9000
EXPOSE 9001
EOF

    echo_ok "Dockerfile for Token-Nodes written."
}


###############################################################
# Function buildDockerImages
###############################################################
buildDockerImages() {
    echo ""
    echo_warn "Token-Nodes docker image building... This may take several minutes!"
    echo_info "Executing with the following:"
    echo_info "- APP Path: ${ORANGE}${APP_SRC_PATH}${NC}"
    echo_info "- Dockerfile Path: ${ORANGE}${CONFIG_SRC_PATH}${NC}"

    docker build \
        -f $CONFIG_SRC_PATH/dockerfile_token_node \
        -t token-auditor_image:latest \
        $APP_SRC_PATH

    echo_ok "Token-Nodes docker image built."


}



###############################################################
# Install Token-Nodes
###############################################################
AGERS=$(yq eval '.Ager[] | .Name' "$CONFIG_FILE")
for AGER in $AGERS; do
    ###############################################################
    # Params
    ###############################################################
    ORBIS=$(yq eval ".Orbis.Name" "$CONFIG_FILE")
    REGNUM=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Administration.Parent" $CONFIG_FILE)
    INFRA_SRC_PATH=${PWD}/infrastructure
    CONFIG_SRC_PATH=$INFRA_SRC_PATH/$ORBIS/$REGNUM/configuration

    echo ""
    echo_warn "Token-Nodes installing..."
    echo_info "Executing with the following:"
    echo_info "- Orbis: ${ORANGE}${ORBIS}${NC}"
    echo_info "- Regnum: ${ORANGE}${REGNUM}${NC}"
    echo_info "- Ager: ${ORANGE}${AGER}${NC}"
    echo_info "- Config-Path: ${ORANGE}${CONFIG_SRC_PATH}${NC}"


    ###############################################################
    # Install Auditor-Token-Nodes
    ###############################################################
    AUDITORS=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Auditors[].Name" $CONFIG_FILE)
    for AUDITOR in $AUDITORS; do
        APP_SRC_PATH=$INFRA_SRC_PATH/$ORBIS/$REGNUM/$AGER/$AUDITOR/APP

        echo ""
        echo_warn "Auditor-Token-Nodes installing..."
        echo_info "Executing with the following:"
        echo_info "- Auditor: ${ORANGE}${AUDITOR}${NC}"
        echo_info "- App-Path: ${ORANGE}${APP_SRC_PATH}${NC}"

        # Create APP-Folder for APP, Config and Dockerfile
        mkdir -p $APP_SRC_PATH

        # Copy APP-Files in the configuration-folder
        echo_info "Copy Token-Node-App-Files to: ${ORANGE}${APP_SRC_PATH}${NC}"
        if ! cp -r ${PWD}/tokenSDK/auditor/* $APP_SRC_PATH; then
            echo_error "Copy of Token-Node-App-Files was not successfull"
        fi

        # Generate core.yaml in the configuration-folder

        # Write the Dockerfile in the configuration-folder
        writeDockerfile

        # Build the docker image 
# ERROR in build
#        buildDockerImages

        # Rund the docker image

        echo_ok "Auditor-Token-Nodes installed."
    done

    echo_ok "Token-Nodes installed."

done





# BACKUP

        # AUDITOR_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Auditors[] | select(.Name == \"$AUDITOR\") | .Name" $CONFIG_FILE)


        # # Enroll FSC Node ID
        # docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://fsc.$AUDITOR_NAME:$AUDITOR_PASS@$CA_NAME:$CA_PORT \
        #     --home $ORBIS_TOOLS_CACLI_DIR \
        #     --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        #     --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$AUDITOR_NAME/fsc/msp \
        #     --csr.hosts "$CA_NAME,$CAAPI_NAME,$CAAPI_IP,*.jedo.cc" \
        #     --csr.cn $CN --csr.names "$CSR_NAMES" \
        # # Enroll Wallet User
        # docker exec -it $ORBIS_TOOLS_NAME fabric-ca-client enroll -u https://$AUDITOR_NAME:$AUDITOR_PASS@$CA_NAME:$CA_PORT \
        #     --home $ORBIS_TOOLS_CACLI_DIR \
        #     --tls.certfiles tls-root-cert/tls-ca-cert.pem \
        #     --mspdir $ORBIS_TOOLS_CACLI_DIR/infrastructure/$ORBIS/$REGNUM/$AGER/$AUDITOR_NAME/msp \
        #     --csr.hosts "$CA_NAME,$CAAPI_NAME,$CAAPI_IP,192.168.0.13,*.jedo.cc" \
        #     --csr.cn $CN --csr.names "$CSR_NAMES" \
        #     --enrollment.attrs "jedo.apiPort,jedo.role"
