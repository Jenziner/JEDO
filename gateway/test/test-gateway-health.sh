#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../jedo.dev" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/params.sh"

echo_warn "Testing Fabric Gateway Connection..."
for REGNUM in $REGNUMS; do
    for AGER in $AGERS; do
        GATEWAY_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.Name" $CONFIG_FILE)
        GATEWAY_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.IP" $CONFIG_FILE)
        GATEWAY_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.Port" $CONFIG_FILE)
        CERT_DIR="../../$ORBIS.$ORBIS_ENV/infrastructure/$ORBIS/$REGNUM/$AGER/admin.$AGER.$REGNUM.$ORBIS.$ORBIS_ENV/msp/signcerts"
        KEY_DIR="../../$ORBIS.$ORBIS_ENV/infrastructure/$ORBIS/$REGNUM/$AGER/admin.$AGER.$REGNUM.$ORBIS.$ORBIS_ENV/msp/keystore"

        CERT_FILE=$(ls $CERT_DIR/*.pem 2>/dev/null | head -1)
        if [ -z "$CERT_FILE" ]; then
          echo_error "Certificate not found in: $CERT_DIR"
          exit 1
        fi

        KEY_FILE=$(ls $KEY_DIR/*_sk 2>/dev/null | head -1)
        if [ -z "$KEY_FILE" ]; then
          echo_error "Private key not found in: $KEY_DIR"
          exit 1
        fi

        CERT_B64=$(cat "$CERT_FILE" | base64 -w 0)
        KEY_B64=$(cat "$KEY_FILE" | base64 -w 0)

        echo_info "Certificates loaded"
        echo_info "- Cert: $(basename $CERT_FILE)"
        echo_info "- Key:  $(basename $KEY_FILE)"

        echo ""
        echo_info "Testing Health Endpoint..."
        curl -s http://$GATEWAY_IP:$GATEWAY_PORT/health | jq '.'

    done
done

echo ""
echo_ok "Test completed!"
