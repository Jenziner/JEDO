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

cat <<'EOF' > $CONFIG_SRC_PATH/dockerfile_token_node
#build stage
FROM golang:1.23-bookworm AS builder
WORKDIR /go/src/app

# Kopiere go.mod/go.sum
COPY go.mod .
COPY go.sum .

# CRITICAL: Lösche go.sum
RUN rm -f go.sum

# PATCH: Replace ALLES (Token SDK, FSC, libp2p)
RUN echo "" >> go.mod && \
    echo "// Fabric 3.0 Compatibility Patches (Aggressive Mode)" >> go.mod && \
    echo "replace google.golang.org/genproto/googleapis/rpc v0.0.0-20241007155032-5fefd90f89a9 => google.golang.org/genproto v0.0.0-20230410155749-daa745c078e1" >> go.mod && \
    echo "replace google.golang.org/genproto/googleapis/api v0.0.0-20241007155032-5fefd90f89a9 => google.golang.org/genproto v0.0.0-20230410155749-daa745c078e1" >> go.mod && \
    echo "" >> go.mod && \
    echo "// Force ALLE libp2p Dependencies auf kompatible Versionen" >> go.mod && \
    echo "replace github.com/libp2p/go-libp2p v0.31.0 => github.com/libp2p/go-libp2p v0.36.4" >> go.mod && \
    echo "replace github.com/libp2p/go-libp2p-kad-dht v0.22.0 => github.com/libp2p/go-libp2p-kad-dht v0.26.0" >> go.mod && \
    echo "replace github.com/quic-go/webtransport-go v0.5.3 => github.com/quic-go/webtransport-go v0.9.0" >> go.mod && \
    echo "replace github.com/quic-go/quic-go v0.48.2 => github.com/quic-go/quic-go v0.53.0" >> go.mod && \
    echo "" >> go.mod && \
    echo "// Zusätzliche transitive Dependencies" >> go.mod && \
    echo "replace github.com/multiformats/go-multistream v0.4.1 => github.com/multiformats/go-multistream v0.5.0" >> go.mod && \
    echo "replace github.com/multiformats/go-multiaddr v0.11.0 => github.com/multiformats/go-multiaddr v0.13.0" >> go.mod

# Dependencies neu laden
RUN go mod tidy && go mod download

# Kopiere Source Code
COPY . .

# Build
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
# Function patchTokenSDKDependencies
###############################################################
patchTokenSDKDependencies() {
    echo ""
    echo_warn "Preparing Token SDK for Fabric 3.0..."
    echo_info "Executing with the following:"
    echo_info "- APP Path: ${ORANGE}${APP_SRC_PATH}${NC}"

    cd $APP_SRC_PATH

    # Backup original files (einmalig)
    if [ ! -f "go.mod.backup" ]; then
        cp go.mod go.mod.backup
        [ -f "go.sum" ] && cp go.sum go.sum.backup
        echo_info "Backed up original go.mod/go.sum"
    fi

    echo_ok "Token SDK prepared (patching happens in Dockerfile)"
    cd - > /dev/null
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
        --no-cache \
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

        # Patch TokenSDK Dependencies
        patchTokenSDKDependencies

        # Write the Dockerfile in the configuration-folder
        writeDockerfile

        # Build the docker image 
# ERROR in build
        buildDockerImages

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
