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

CA_SERVICE_URL="https://localhost:53911"
CA_SERVICE_HEALTH="${CA_SERVICE_URL}/health"
CA_SERVICE_INFO="${CA_SERVICE_URL}/ca/info"
CA_SERVICE_REGISTER="${CA_SERVICE_URL}/certificates/register"
CA_SERVICE_ENROLL="${CA_SERVICE_URL}/certificates/enroll"

# Test User Data
TEST_GENS_USER="test-gens-$(uuidgen)"
TEST_GENS_PASS="TestGens123!"
TEST_HUMAN_USER="test-human-$(uuidgen)"
TEST_HUMAN_PASS="TestHuman123!"

echo_info "Gens:  ${TEST_GENS_USER}"
echo_info "Human: ${TEST_HUMAN_USER}"

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
cp ~/Entwicklung/JEDO/jedo.dev/infrastructure/jedo/ea/alps/admin.alps.ea.jedo.dev/msp/keystore/*_sk \
    ~/Entwicklung/JEDO/services/ca-service/tests/certs/ager-admin-key.pem
cp ~/Entwicklung/JEDO/jedo.dev/infrastructure/jedo/ea/alps/admin.alps.ea.jedo.dev/msp/signcerts/cert.pem \
    ~/Entwicklung/JEDO/services/ca-service/tests/certs/ager-admin-cert.pem
openssl x509 -in tests/certs/ager-admin-cert.pem -noout -text > /dev/null && \
    echo "✅ Certificate valid" || \
    echo "❌ Certificate INVALID"

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
  "enrollmentType": "x509"
}
EOF
    )
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -eq 200 ]; then
        echo_info "✅ Gens enrolled successfully"
        
        # VALIDATE X.509 RESPONSE STRUCTURE
        cert=$(echo "$body" | jq -r '.data.certificate')
        key=$(echo "$body" | jq -r '.data.privateKey')
        root=$(echo "$body" | jq -r '.data.rootCertificate')
        
        if [ -z "$cert" ] || [ "$cert" == "null" ]; then
            echo_error "❌ Missing certificate in response"
            return 1
        fi
        
        if [ -z "$key" ] || [ "$key" == "null" ]; then
            echo_error "❌ Missing privateKey in response"
            return 1
        fi
        
        if [ -z "$root" ] || [ "$root" == "null" ]; then
            echo_error "❌ Missing rootCertificate in response"
            return 1
        fi
        
        echo_info "✅ X.509 Response structure valid"
        
        # Save certificates
        echo "$cert" > "${TEMP_CERTS_DIR}/${TEST_GENS_USER}-cert.pem"
        echo "$key" > "${TEMP_CERTS_DIR}/${TEST_GENS_USER}-key.pem"
        
        echo_info "Certificates saved to: ${TEMP_CERTS_DIR}/"
        
        # Verify certificate validity
        if openssl x509 -in "${TEMP_CERTS_DIR}/${TEST_GENS_USER}-cert.pem" -noout -text > /dev/null 2>&1; then
            echo_info "✅ Certificate is valid X.509"
            echo_info "Certificate Subject:"
            openssl x509 -in "${TEMP_CERTS_DIR}/${TEST_GENS_USER}-cert.pem" -noout -subject
            
            # Check if role attribute is in certificate
            if openssl x509 -in "${TEMP_CERTS_DIR}/${TEST_GENS_USER}-cert.pem" -noout -text | grep -q "role"; then
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
    
    GENS_CERT_PATH="${TEMP_CERTS_DIR}/${TEST_GENS_USER}-cert.pem"
    GENS_KEY_PATH="${TEMP_CERTS_DIR}/${TEST_GENS_USER}-key.pem"
    
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
        -d @- <<EOF
{
  "username": "${TEST_HUMAN_USER}",
  "secret": "${TEST_HUMAN_PASS}",
  "enrollmentType": "idemix",
  "idemixCurve": "gurvy.Bn254"
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
        
        # Save SignerConfig for debugging
        echo "$signerConfig" > "${TEMP_CERTS_DIR}/${TEST_HUMAN_USER}-signerconfig.json"
        echo_info "SignerConfig saved to: ${TEMP_CERTS_DIR}/${TEST_HUMAN_USER}-signerconfig.json"
        
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
    
    # test_health || exit 1
    # echo ""
    
    # test_info || exit 1
    # echo ""
    
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
    echo ""
}

# Run main
main
