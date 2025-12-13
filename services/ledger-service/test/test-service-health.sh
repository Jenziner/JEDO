#!/bin/bash
set -e
export LOGLEVEL="DEBUG"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../jedo.dev" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/params.sh"

echo_warn "Testing Service Connection..."
for REGNUM in $REGNUMS; do
    for AGER in $AGERS; do
        SERVICES=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.Services[].Name" $CONFIG_FILE)
        for SERVICE in $SERVICES; do
            SERVICE_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.Services[] | select(.Name == \"$SERVICE\") | .Name" $CONFIG_FILE)
            SERVICE_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.Services[] | select(.Name == \"$SERVICE\") | .IP" $CONFIG_FILE)
            SERVICE_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.Services[] | select(.Name == \"$SERVICE\") | .Port" $CONFIG_FILE)
            CERT_DIR="../../../$ORBIS.$ORBIS_ENV/infrastructure/$ORBIS/$REGNUM/$AGER/admin.$AGER.$REGNUM.$ORBIS.$ORBIS_ENV/msp/signcerts"
            KEY_DIR="../../../$ORBIS.$ORBIS_ENV/infrastructure/$ORBIS/$REGNUM/$AGER/admin.$AGER.$REGNUM.$ORBIS.$ORBIS_ENV/msp/keystore"
            log_debug "Service:" "$SERVICE_NAME ($SERVICE_IP:$SERVICE_PORT)"
            log_debug "Cert Dir:" "$CERT_DIR)"
            log_debug "Key Dir:" "$KEY_DIR)"

            CERT_FILE=$(ls $CERT_DIR/*.pem 2>/dev/null | head -1)
            if [ -z "$CERT_FILE" ]; then
                echo_error "Certificate not found in: $CERT_DIR"
                exit 1
            fi
            log_debug "Cert File:" "$CERT_FILE)"

            KEY_FILE=$(ls $KEY_DIR/*_sk 2>/dev/null | head -1)
            if [ -z "$KEY_FILE" ]; then
                echo_error "Private key not found in: $KEY_DIR"
                exit 1
            fi
            log_debug "Cert Key:" "$KEY_FILE)"

            CERT_B64=$(cat "$CERT_FILE" | base64 -w 0)
            KEY_B64=$(cat "$KEY_FILE" | base64 -w 0)

            echo_info "Certificates loaded"
            echo_info "- Cert: $(basename $CERT_FILE)"
            echo_info "- Key:  $(basename $KEY_FILE)"

            echo ""
            echo_info "Test 1: Testing Service Health..."
            curl -s http://$SERVICE_IP:$SERVICE_PORT/health | jq '.'

        done
    done
done

echo ""
echo_ok "Test completed!"

