#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../infrastructure/dev" && pwd)"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/params.sh"

export LOGLEVEL="DEBUG"

echo_section "Testing Gateway Connection..."
for REGNUM in $REGNUMS; do
    for AGER in $AGERS; do
        GATEWAY_NAME=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.Name" $CONFIG_FILE)
        GATEWAY_IP=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.IP" $CONFIG_FILE)
        GATEWAY_PORT=$(yq eval ".Ager[] | select(.Name == \"$AGER\") | .Gateway.Port" $CONFIG_FILE)

        GATEWAY_URL="https://$GATEWAY_IP:$GATEWAY_PORT"  # Anpassen!

        log_debug "Gateway URL:" "$GATEWAY_URL" 

        echo "🧪 Testing CORS Configuration..."
        echo ""

        # ===== 1. file:// Origin (null) =====
        echo "1️⃣  OPTIONS with null Origin (file://):"
        curl -i -k -X OPTIONS \
        -H "Origin: null" \
        -H "Access-Control-Request-Method: POST" \
        -H "Access-Control-Request-Headers: Content-Type, Authorization" \
        "$GATEWAY_URL/api/v1/ca/certificates/register"

        echo ""
        echo "---"
        echo ""

        # ===== 2. Localhost Origin =====
        echo "2️⃣  OPTIONS with localhost Origin:"
        curl -i -k -X OPTIONS \
        -H "Origin: http://localhost:8080" \
        -H "Access-Control-Request-Method: POST" \
        -H "Access-Control-Request-Headers: Content-Type, Authorization" \
        "$GATEWAY_URL/api/v1/ca/certificates/register"

        echo ""
        echo "---"
        echo ""

        # ===== 3. Actual POST Request =====
        echo "3️⃣  POST with localhost Origin:"
        curl -i -k -X POST \
        -H "Origin: http://localhost:8080" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer test" \
        -d '{"enrollmentID":"testuser","secret":"testpw"}' \
        "$GATEWAY_URL/api/v1/ca/certificates/register"

        echo ""
        echo "---"
        echo ""

        # ===== 4. IP-basierte Origin (wie Browser) =====
        echo "4️⃣  POST with IP Origin (simulating your browser):"
        curl -i -k -X POST \
        -H "Origin: http://172.16.3.91:53911" \
        -H "Content-Type: application/json" \
        -d '{"enrollmentID":"testuser","secret":"testpw"}' \
        "$GATEWAY_URL/api/v1/ca/certificates/register"


    done
done

echo ""
echo_ok "Test completed!"
