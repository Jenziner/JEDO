#!/bin/bash

###############################################################
# Integration Test: CA Service
###############################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }
echo_test() { echo -e "${YELLOW}[TEST]${NC} $1"; }
echo_section() { echo -e "${BLUE}[====]${NC} $1"; }

###############################################################
# Configuration
###############################################################

echo ""
echo "========================================"
echo "  Basic Configuration "
echo "========================================"
echo ""

# Detect Downloads directory
if [ -d "$HOME/Downloads" ]; then
    DOWNLOADS_DIR="$HOME/Downloads"
elif [ -d "$HOME/Download" ]; then
    DOWNLOADS_DIR="$HOME/Download"
else
    # Fallback to current directory
    DOWNLOADS_DIR="$(pwd)/downloads"
    mkdir -p "$DOWNLOADS_DIR"
fi

# Create test output directory with timestamp
TEST_RUN_ID=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="$DOWNLOADS_DIR/jedo-ca-test-$TEST_RUN_ID"
mkdir -p "$OUTPUT_DIR"

echo -e "${BLUE}📁 Test output directory: $OUTPUT_DIR${NC}"

CA_SERVICE_URL="https://localhost:53911"
CA_SERVICE_HEALTH="${CA_SERVICE_URL}/health"
CA_SERVICE_INFO="${CA_SERVICE_URL}/ca/info"
CA_SERVICE_REGISTER="${CA_SERVICE_URL}/certificates/register"
CA_SERVICE_ENROLL="${CA_SERVICE_URL}/certificates/enroll"

# Affiliation
AFFILIATION="jedo.ea.alps"

# Certificate Paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/../.." && pwd )"
CERTS_DIR="${PROJECT_ROOT}/tests/certs"

AGER_CERT_PATH="${CERTS_DIR}/ager-admin-cert.pem"
AGER_KEY_PATH="${CERTS_DIR}/ager-admin-key.pem"

# Temp dir
TEMP_CERTS_DIR="/tmp/ca-service-test"
mkdir -p "${TEMP_CERTS_DIR}"

###############################################################
# Copy Ager certs
###############################################################
echo_info "Copy Certs..."
cp ~/Entwicklung/JEDO/infrastructure/dev/infrastructure/jedo/ea/alps/admin.alps.ea.jedo.dev/msp/keystore/*_sk \
    ~/Entwicklung/JEDO/services/ca-service/tests/certs/ager-admin-key.pem
cp ~/Entwicklung/JEDO/infrastructure/dev/infrastructure/jedo/ea/alps/admin.alps.ea.jedo.dev/msp/signcerts/cert.pem \
    ~/Entwicklung/JEDO/services/ca-service/tests/certs/ager-admin-cert.pem
openssl x509 -in tests/certs/ager-admin-cert.pem -noout -text > /dev/null && \
    echo "✅ Certificate valid" || \
    echo "❌ Certificate INVALID"

AGER_CN=$(openssl x509 -in "${AGER_CERT_PATH}" -subject -noout | sed -n 's/.*CN = \(.*\)/\1/p')
DOMAIN_SUFFIX=$(echo "${AGER_CN}" | cut -d'.' -f2-)

echo "Extracted Ager-CN: ${DOMAIN_SUFFIX}"

# Test User Data
TEST_GENS_USER="test-gens-$(uuidgen).${DOMAIN_SUFFIX}"
TEST_GENS_PASS="TestGens123!"
TEST_HUMAN_USER="test-human-$(uuidgen).${DOMAIN_SUFFIX}"
TEST_HUMAN_PASS="TestHuman123!"

echo_info "Gens:  ${TEST_GENS_USER}"
echo_info "Human: ${TEST_HUMAN_USER}"


###############################################################
# Test Functions
###############################################################

test_health() {
    echo_section "TEST 1: Health Check"
    
    response=$(curl -k -s -w "\n%{http_code}" ${CA_SERVICE_HEALTH})
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -eq 200 ]; then
        echo_info "✅ CA Service is healthy"
        echo "$body" | jq '.'
        return 0
    else
        echo_error "❌ Health check failed (HTTP ${http_code})"
        echo "$body"
        return 1
    fi
}

test_info() {
    echo_section "TEST 2: CA Info"
    
    response=$(curl -k -s -w "\n%{http_code}" ${CA_SERVICE_INFO})
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -eq 200 ]; then
        echo_info "✅ CA Service info:"
        echo "$body" | jq '.'
        return 0
    else
        echo_error "❌ CA Info failed (HTTP ${http_code})"
        echo "$body"
        return 1
    fi
}

register_gens() {
    echo_section "TEST 3: Register Gens (as Ager)"
    
    # Verify files exist
    if [ ! -f "${AGER_CERT_PATH}" ]; then
        echo_error "Ager certificate not found: ${AGER_CERT_PATH}"
        echo_info "Run: mkdir -p tests/certs && cp infrastructure/.../cert.pem tests/certs/ager-admin-cert.pem"
        return 1
    fi
    
    if [ ! -f "${AGER_KEY_PATH}" ]; then
        echo_error "Ager key not found: ${AGER_KEY_PATH}"
        echo_info "Run: cp infrastructure/.../keystore/*_sk tests/certs/ager-admin-key.pem"
        return 1
    fi
    
    echo_info "Building payload..."
    
    # Read certificates and escape for JSON
    CERT_CONTENT=$(cat "${AGER_CERT_PATH}" | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    KEY_CONTENT=$(cat "${AGER_KEY_PATH}" | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    
    # Build JSON payload manually (more reliable than jq in some environments)
    read -r -d '' PAYLOAD <<EOF || true
{
  "certificate": "${CERT_CONTENT}",
  "privateKey": "${KEY_CONTENT}",
  "username": "${TEST_GENS_USER}",
  "secret": "${TEST_GENS_PASS}",
  "role": "gens",
  "affiliation": "${AFFILIATION}",
  "attrs": {
    "role": "gens",
    "hf.Registrar.Roles": "client",
    "hf.Registrar.Attributes": "*",
    "hf.Revoker": "false"
  }
}
EOF
    
    echo_info "Sending request..."

    response=$(curl -k -s -w "\n%{http_code}" \
        -X POST "${CA_SERVICE_REGISTER}" \
        -H "Content-Type: application/json" \
        --data-binary "$PAYLOAD")
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -eq 200 ]; then
        echo_info "✅ Gens registered successfully"
        echo "$body" | jq '.'
        return 0
    else
        echo_error "❌ Gens registration failed (HTTP ${http_code})"
        echo "$body" | jq '.'
        return 1
    fi
}

enroll_gens() {
    echo_section "TEST 4: Enroll Gens (X.509)"
    
    response=$(curl -k -s -w "\n%{http_code}" \
        -X POST "${CA_SERVICE_ENROLL}" \
        -H "Content-Type: application/json" \
        -d @- <<EOF
{
  "username": "${TEST_GENS_USER}",
  "secret": "${TEST_GENS_PASS}",
  "enrollmentType": "x509",
  "role": "gens"
}
EOF
    )
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -eq 200 ]; then
        echo_info "✅ Gens enrolled successfully"
        
        # VALIDATE X.509 RESPONSE STRUCTURE
        GENS_CERT=$(echo "$body" | jq -r '.data.certificate')
        GENS_KEY=$(echo "$body" | jq -r '.data.privateKey')
        GENS_CA_CERT=$(echo "$body" | jq -r '.data.rootCertificate')
        
        if [ -z "$GENS_CERT" ] || [ "$GENS_CERT" == "null" ]; then
            echo_error "❌ Missing certificate in response"
            return 1
        fi
        
        if [ -z "$GENS_KEY" ] || [ "$GENS_KEY" == "null" ]; then
            echo_error "❌ Missing privateKey in response"
            return 1
        fi
        
        if [ -z "$GENS_CA_CERT" ] || [ "$GENS_CA_CERT" == "null" ]; then
            echo_error "❌ Missing rootCertificate in response"
            return 1
        fi
        
        echo_info "✅ X.509 Response structure valid"
        echo_info "Credential keys:"
        echo "$body" | jq '.data | keys'
        
        # Save to Downloads
        GENS_CERT_FILE="${OUTPUT_DIR}/${TEST_GENS_USER}-cert.pem"
        GENS_KEY_FILE="${OUTPUT_DIR}/${TEST_GENS_USER}-key.pem"
        GENS_CA_CERT_FILE="${OUTPUT_DIR}/${TEST_GENS_USER}-ca-cert.pem"
        
        printf "%s" "$GENS_CERT" > "$GENS_CERT_FILE"
        printf "%s" "$GENS_KEY" > "$GENS_KEY_FILE"
        printf "%s" "$GENS_CA_CERT" > "$GENS_CA_CERT_FILE"
        
        echo_test "📁 Saved certificate: $GENS_CERT_FILE"
        echo_test "📁 Saved private key: $GENS_KEY_FILE"
        echo_test "📁 Saved CA certificate: $GENS_CA_CERT_FILE"        
        echo_info "✅ Certificates saved to: ${OUTPUT_DIR}/"
        
        # Verify certificate validity
        if openssl x509 -in "${OUTPUT_DIR}/${TEST_GENS_USER}-cert.pem" -noout -text > /dev/null 2>&1; then
            echo_info "✅ Certificate is valid X.509"
            echo_info "Certificate Subject:"
            openssl x509 -in "${OUTPUT_DIR}/${TEST_GENS_USER}-cert.pem" -noout -subject
            
            # Check if role attribute is in certificate
            if openssl x509 -in "${OUTPUT_DIR}/${TEST_GENS_USER}-cert.pem" -noout -text | grep -q "role"; then
                echo_info "✅ Certificate contains 'role' attribute"
            else
                echo_error "⚠️  Certificate does NOT contain 'role' attribute"
            fi
        else
            echo_error "❌ Certificate is NOT valid X.509"
            return 1
        fi
        
        return 0
    else
        echo_error "❌ Gens enrollment failed (HTTP ${http_code})"
        echo "$body" | jq '.'
        return 1
    fi
}

register_human() {
    echo_section "TEST 5: Register Human (as Gens)"
    
    GENS_CERT_PATH="${OUTPUT_DIR}/${TEST_GENS_USER}-cert.pem"
    GENS_KEY_PATH="${OUTPUT_DIR}/${TEST_GENS_USER}-key.pem"
    
    if [ ! -f "${GENS_CERT_PATH}" ]; then
        echo_error "Gens certificate not found. Enroll Gens first."
        return 1
    fi
    
    echo_info "Building payload with Gens certificate..."
    
    # Read and escape
    CERT_CONTENT=$(cat "${GENS_CERT_PATH}" | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    KEY_CONTENT=$(cat "${GENS_KEY_PATH}" | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    
    read -r -d '' PAYLOAD <<EOF || true
{
  "certificate": "${CERT_CONTENT}",
  "privateKey": "${KEY_CONTENT}",
  "username": "${TEST_HUMAN_USER}",
  "secret": "${TEST_HUMAN_PASS}",
  "role": "human",
  "affiliation": "${AFFILIATION}",
  "attrs": {
    "role": "human",
    "hf.EnrollmentID": "${TEST_HUMAN_USER}"
  }
}
EOF
    
    response=$(curl -k -s -w "\n%{http_code}" \
        -X POST "${CA_SERVICE_REGISTER}" \
        -H "Content-Type: application/json" \
        --data-binary "$PAYLOAD")
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -eq 200 ]; then
        echo_info "✅ Human registered successfully"
        echo "$body" | jq '.'
        return 0
    else
        echo_error "❌ Human registration failed (HTTP ${http_code})"
        echo "$body" | jq '.'
        return 1
    fi
}

enroll_human_idemix() {
    echo_section "TEST 6: Enroll Human (Idemix)"
    
    response=$(curl -k -s -w "\n%{http_code}" \
        -X POST "${CA_SERVICE_ENROLL}" \
        -H "Content-Type: application/json" \
        -H "X-Certificate: $GENS_CERT_HEADER" \
        -d @- <<EOF
{
  "username": "${TEST_HUMAN_USER}",
  "secret": "${TEST_HUMAN_PASS}",
  "enrollmentType": "idemix",
  "idemixCurve": "gurvy.Bn254",
  "role": "human",
  "gensName": "${TEST_GENS_USER}"
}
EOF
    )
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -eq 200 ]; then
        echo_info "✅ Human enrolled (Idemix)"
        
        # VALIDATE IDEMIX RESPONSE STRUCTURE
        signerConfig=$(echo "$body" | jq -r '.data.signerConfig')
        issuerPublicKey=$(echo "$body" | jq -r '.data.issuerPublicKey')
        issuerRevocationKey=$(echo "$body" | jq -r '.data.issuerRevocationPublicKey')
        curve=$(echo "$body" | jq -r '.data.curve')
        
        if [ -z "$signerConfig" ] || [ "$signerConfig" == "null" ]; then
            echo_error "❌ Missing signerConfig in response"
            return 1
        fi
        
        if [ -z "$issuerPublicKey" ] || [ "$issuerPublicKey" == "null" ]; then
            echo_error "⚠️  Missing issuerPublicKey (may be optional)"
        else
            echo_info "✅ issuerPublicKey present"
        fi
        
        if [ -z "$issuerRevocationKey" ] || [ "$issuerRevocationKey" == "null" ]; then
            echo_error "⚠️  Missing issuerRevocationPublicKey (may be optional)"
        else
            echo_info "✅ issuerRevocationPublicKey present"
        fi
        
        if [ "$curve" != "gurvy.Bn254" ]; then
            echo_error "❌ Wrong curve: expected 'gurvy.Bn254', got '${curve}'"
            return 1
        fi
        
        echo_info "✅ Idemix Response structure valid"
        echo_info "Credential keys:"
        echo "$body" | jq '.data | keys'
        
        # Save to Downloads
        HUMAN_SIGNER_FILE="${OUTPUT_DIR}/${TEST_HUMAN_USER}-SignerConfig"
        HUMAN_IPK_FILE="${OUTPUT_DIR}/${TEST_HUMAN_USER}-IssuerPublicKey"
        HUMAN_IREVK_FILE="${OUTPUT_DIR}/${TEST_HUMAN_USER}-IssuerRevocationPublicKey"
        
        printf "%s" "$signerConfig" > "$HUMAN_SIGNER_FILE"
        echo_test "📁 Saved Signer Config: $HUMAN_SIGNER_FILE"

        if [ -n "$issuerPublicKey" ] && [ "$issuerPublicKey" != "null" ]; then
            printf "%s" "$issuerPublicKey" > "$HUMAN_IPK_FILE"
            echo_test "📁 Saved IssuerPublicKey: $HUMAN_IPK_FILE"
        fi

        if [ -n "$issuerRevocationKey" ] && [ "$issuerRevocationKey" != "null" ]; then
            printf "%s" "$issuerRevocationKey" > "$HUMAN_IREVK_FILE"
            echo_test "📁 Saved IssuerRevocationPublicKey: $HUMAN_IREVK_FILE"
        fi

        echo_info "✅ Certificates saved to: ${OUTPUT_DIR}/"
        
        # VALIDATE SignerConfig
        if [ -f "$HUMAN_SIGNER_FILE" ]; then
            filesize=$(wc -c < "$HUMAN_SIGNER_FILE")
            
            if [ "$filesize" -gt 100 ]; then
                echo_info "✅ SignerConfig file size: ${filesize} bytes"
                
                # Check if it's valid JSON
                if jq empty "$HUMAN_SIGNER_FILE" 2>/dev/null; then
                    echo_info "✅ SignerConfig is valid JSON"
                    
                    # Show available keys
                    echo_info "SignerConfig structure:"
                    jq 'keys' "$HUMAN_SIGNER_FILE" 2>/dev/null || echo "  (binary format)"
                else
                    echo_info "ℹ️  SignerConfig is in binary/protobuf format (not JSON)"
                fi
            else
                echo_error "❌ SignerConfig file too small: ${filesize} bytes"
                return 1
            fi
        else
            echo_error "❌ SignerConfig file not found"
            return 1
        fi

        return 0
    else
        echo_error "❌ Human enrollment failed (HTTP ${http_code})"
        echo "$body" | jq '.'
        return 1
    fi
}

cleanup() {
    echo_info "Cleaning up..."
    rm -rf "${TEMP_CERTS_DIR}"
}

###############################################################
# Main
###############################################################

main() {
    echo ""
    echo "========================================"
    echo "  CA SERVICE INTEGRATION TEST"
    echo "========================================"
    echo ""
    
    test_health || exit 1
    echo ""
    
    test_info || exit 1
    echo ""
    
    register_gens || exit 1
    echo ""
    
    enroll_gens || exit 1
    echo ""
    
    register_human || exit 1
    echo ""
    
    enroll_human_idemix || exit 1
    echo ""
    
    cleanup
    
    echo ""
    echo "========================================"
    echo "  ✅ ALL TESTS PASSED!"
    echo "========================================"
    echo ""
    echo "Users created:"
    echo "  - Gens:  ${TEST_GENS_USER}"
    echo "  - Human: ${TEST_HUMAN_USER}"
    echo "  - SafeDir: ${OUTPUT_DIR}"
    echo ""
}

# Run main
main
