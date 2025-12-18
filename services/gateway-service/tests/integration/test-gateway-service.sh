#!/bin/bash

###############################################################
# Integration Test: Gateway → CA Service
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
echo "  Gateway Integration Test"
echo "========================================"
echo ""

# Detect Downloads directory
if [ -d "$HOME/Downloads" ]; then
  DOWNLOADS_DIR="$HOME/Downloads"
elif [ -d "$HOME/Download" ]; then
  DOWNLOADS_DIR="$HOME/Download"
else
  DOWNLOADS_DIR="$(pwd)/downloads"
  mkdir -p "$DOWNLOADS_DIR"
fi

# Create test output directory with timestamp
TEST_RUN_ID=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="$DOWNLOADS_DIR/jedo-gateway-test-$TEST_RUN_ID"
mkdir -p "$OUTPUT_DIR"
echo -e "${BLUE}📁 Test output directory: $OUTPUT_DIR${NC}"

# Service URLs
GATEWAY_URL="https://localhost:53901"
CA_SERVICE_URL="https://localhost:53911"
LEDGER_SERVICE_URL="http://localhost:53921"

# Gateway endpoints
GATEWAY_HEALTH="${GATEWAY_URL}/health"
GATEWAY_READY="${GATEWAY_URL}/ready"

# Direct service endpoints (for comparison)
CA_HEALTH="${CA_SERVICE_URL}/health"
LEDGER_HEALTH="${LEDGER_SERVICE_URL}/health"

# Gateway API endpoints (proxied to CA-Service)
GATEWAY_CA_REGISTER_GENS="${GATEWAY_URL}/api/v1/ca/certificates/register/gens"
GATEWAY_CA_REGISTER_HUMAN="${GATEWAY_URL}/api/v1/ca/certificates/register/human"
GATEWAY_CA_ENROLL="${GATEWAY_URL}/api/v1/ca/certificates/enroll"
GATEWAY_CA_INFO="${GATEWAY_URL}/api/v1/ca/ca/info"

# Certificate Paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/../.." && pwd )"
CERTS_DIR="${PROJECT_ROOT}/tests/certs"
AGER_CERT_PATH="${CERTS_DIR}/ager-admin-cert.pem"
AGER_KEY_PATH="${CERTS_DIR}/ager-admin-key.pem"

# Temp dir
TEMP_CERTS_DIR="/tmp/jedo-gateway-test"
mkdir -p "${TEMP_CERTS_DIR}"

###############################################################
# Copy Ager certs
###############################################################

echo_info "Copying Ager certificates..."
cp ~/Entwicklung/JEDO/infrastructure/dev/infrastructure/jedo/ea/alps/admin.alps.ea.jedo.dev/msp/keystore/*_sk \
   ~/Entwicklung/JEDO/services/gateway-service/tests/certs/ager-admin-key.pem

cp ~/Entwicklung/JEDO/infrastructure/dev/infrastructure/jedo/ea/alps/admin.alps.ea.jedo.dev/msp/signcerts/cert.pem \
   ~/Entwicklung/JEDO/services/gateway-service/tests/certs/ager-admin-cert.pem

# Validate Ager certificate
if openssl x509 -in "${AGER_CERT_PATH}" -noout -text > /dev/null 2>&1; then
  echo_info "✅ Ager certificate valid"
else
  echo_error "❌ Ager certificate INVALID"
  exit 1
fi

# Extract domain suffix from Ager cert
AGER_CN=$(openssl x509 -in "${AGER_CERT_PATH}" -subject -noout | sed -n 's/.*CN = \(.*\)/\1/p')
DOMAIN_SUFFIX=$(echo "${AGER_CN}" | cut -d'.' -f2-)
echo_info "Extracted domain: ${DOMAIN_SUFFIX}"

# Generate unique test identifiers
TEST_GENS_ID=$(uuidgen | cut -d'-' -f1)
TEST_GENS_USER="testgens${TEST_GENS_ID}.${DOMAIN_SUFFIX}"
TEST_GENS_PASS="TestGens123!"
TEST_GENS_AFFILIATION="jedo.ea.alps.testgens${TEST_GENS_ID}"

TEST_HUMAN_ID=$(uuidgen | cut -d'-' -f1)
TEST_HUMAN_USER="testhuman${TEST_HUMAN_ID}.${DOMAIN_SUFFIX}"
TEST_HUMAN_PASS="TestHuman123!"

echo_info "Gens: ${TEST_GENS_USER}"
echo_info "Gens Affiliation: ${TEST_GENS_AFFILIATION}"
echo_info "Human: ${TEST_HUMAN_USER}"

###############################################################
# Test Functions - Health Checks
###############################################################

test_gateway_health() {
  echo_section "TEST 1: Gateway Health Check"
  
  response=$(curl -k -s -w "\n%{http_code}" ${GATEWAY_HEALTH})
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')
  
  if [ "$http_code" -eq 200 ]; then
    echo_info "✅ Gateway is healthy"
    echo "$body" | jq '.'
    return 0
  else
    echo_error "❌ Gateway health check failed (HTTP ${http_code})"
    echo "$body"
    return 1
  fi
}

test_ca_health() {
  echo_section "TEST 2: CA-Service Health Check (Direct)"
  
  response=$(curl -k -s -w "\n%{http_code}" ${CA_HEALTH})
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')
  
  if [ "$http_code" -eq 200 ]; then
    echo_info "✅ CA-Service is healthy"
    echo "$body" | jq '.'
    return 0
  else
    echo_error "❌ CA-Service health check failed (HTTP ${http_code})"
    echo "$body"
    return 1
  fi
}

test_ledger_health() {
  echo_section "TEST 3: Ledger-Service Health Check (Direct)"
  
  response=$(curl -s -w "\n%{http_code}" ${LEDGER_HEALTH})
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')
  
  if [ "$http_code" -eq 200 ]; then
    echo_info "✅ Ledger-Service is healthy"
    echo "$body" | jq '.'
    return 0
  else
    echo_error "❌ Ledger-Service health check failed (HTTP ${http_code})"
    echo "$body"
    return 1
  fi
}

test_gateway_ready() {
  echo_section "TEST 4: Gateway Readiness Check"
  
  response=$(curl -k -s -w "\n%{http_code}" ${GATEWAY_READY})
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')
  
  if [ "$http_code" -eq 200 ]; then
    echo_info "✅ Gateway is ready - all backend services are up"
    echo "$body" | jq '.'
    
    # Check individual services
    ca_status=$(echo "$body" | jq -r '.data.services[]? | select(.name=="ca") | .status')
    ledger_status=$(echo "$body" | jq -r '.data.services[]? | select(.name=="ledger") | .status')
    
    if [ "$ca_status" = "up" ]; then
      echo_info "  ✅ CA-Service: UP"
    else
      echo_error "  ❌ CA-Service: DOWN"
    fi
    
    if [ "$ledger_status" = "up" ]; then
      echo_info "  ✅ Ledger-Service: UP"
    else
      echo_error "  ❌ Ledger-Service: DOWN"
    fi
    
    return 0
  else
    echo_error "❌ Gateway not ready (HTTP ${http_code})"
    echo "$body" | jq '.'
    return 1
  fi
}

test_ca_info_via_gateway() {
  echo_section "TEST 5: CA Info via Gateway"
  
  response=$(curl -k -s -w "\n%{http_code}" ${GATEWAY_CA_INFO})
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')
  
  if [ "$http_code" -eq 200 ]; then
    echo_info "✅ CA Info retrieved via Gateway"
    echo "$body" | jq '.'
    return 0
  else
    echo_error "❌ CA Info via Gateway failed (HTTP ${http_code})"
    echo "$body"
    return 1
  fi
}

###############################################################
# Test Functions - Certificate Operations via Gateway
###############################################################

register_gens_via_gateway() {
  echo_section "TEST 6: Register Gens via Gateway (as Ager)"
  
  # Verify Ager certificates exist
  if [ ! -f "${AGER_CERT_PATH}" ] || [ ! -f "${AGER_KEY_PATH}" ]; then
    echo_error "Ager certificates not found"
    return 1
  fi
  
  echo_info "Building registration payload..."
  
  # Read and escape certificates for JSON
  CERT_CONTENT=$(cat "${AGER_CERT_PATH}" | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
  KEY_CONTENT=$(cat "${AGER_KEY_PATH}" | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
  
  # Build JSON payload
  read -r -d '' PAYLOAD <<EOF || true
{
  "certificate": "${CERT_CONTENT}",
  "privateKey": "${KEY_CONTENT}",
  "username": "${TEST_GENS_USER}",
  "secret": "${TEST_GENS_PASS}",
  "affiliation": "${TEST_GENS_AFFILIATION}",
  "role": "gens"
}
EOF
  
  echo_test "Sending registration request to ${GATEWAY_CA_REGISTER_GENS}"
  
  # Send request
  response=$(curl -k -s -w "\n%{http_code}" \
    -X POST "${GATEWAY_CA_REGISTER_GENS}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")
  
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')
  
  if [ "$http_code" -eq 200 ]; then
    echo_info "✅ Gens registered successfully via Gateway"
    echo "$body" | jq '.'
    
    # Extract username from response
    REGISTERED_GENS=$(echo "$body" | jq -r '.data.username')
    echo_info "Registered Gens: ${REGISTERED_GENS}"
    
    return 0
  else
    echo_error "❌ Gens registration via Gateway failed (HTTP ${http_code})"
    echo "$body" | jq '.'
    return 1
  fi
}

enroll_gens_via_gateway() {
  echo_section "TEST 7: Enroll Gens via Gateway (X.509)"
  
  echo_info "Building enrollment payload..."
  
  read -r -d '' PAYLOAD <<EOF || true
{
  "username": "${TEST_GENS_USER}",
  "secret": "${TEST_GENS_PASS}",
  "enrollmentType": "x509",
  "role": "gens"
}
EOF
  
  echo_test "Sending enrollment request to ${GATEWAY_CA_ENROLL}"
  
  response=$(curl -k -s -w "\n%{http_code}" \
    -X POST "${GATEWAY_CA_ENROLL}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")
  
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')
  
  if [ "$http_code" -eq 200 ]; then
    echo_info "✅ Gens enrolled successfully via Gateway"
    
    # Extract credentials
    GENS_CERT=$(echo "$body" | jq -r '.data.certificate')
    GENS_KEY=$(echo "$body" | jq -r '.data.privateKey')
    GENS_CA_CERT=$(echo "$body" | jq -r '.data.rootCertificate // .data.caChain')
    
    # Save to files
    GENS_CERT_FILE="${OUTPUT_DIR}/${TEST_GENS_USER}-cert.pem"
    GENS_KEY_FILE="${OUTPUT_DIR}/${TEST_GENS_USER}-key.pem"
    GENS_CA_CERT_FILE="${OUTPUT_DIR}/${TEST_GENS_USER}-ca-cert.pem"
    
    printf "%s" "$GENS_CERT" > "$GENS_CERT_FILE"
    printf "%s" "$GENS_KEY" > "$GENS_KEY_FILE"
    printf "%s" "$GENS_CA_CERT" > "$GENS_CA_CERT_FILE"
    
    echo_test "📁 Saved certificate: $GENS_CERT_FILE"
    echo_test "📁 Saved private key: $GENS_KEY_FILE"
    echo_test "📁 Saved CA certificate: $GENS_CA_CERT_FILE"
    
    # Verify certificate validity
    if openssl x509 -in "${GENS_CERT_FILE}" -noout -text > /dev/null 2>&1; then
      echo_info "✅ Certificate is valid X.509"
      
      # Show certificate details
      echo_info "Certificate Subject:"
      openssl x509 -in "${GENS_CERT_FILE}" -noout -subject
      
      # Check for role attribute
      if openssl x509 -in "${GENS_CERT_FILE}" -noout -text | grep -q "role"; then
        echo_info "✅ Certificate contains 'role' attribute"
      else
        echo_error "⚠️ Certificate does NOT contain 'role' attribute"
      fi
    else
      echo_error "❌ Certificate is NOT valid X.509"
      return 1
    fi
    
    return 0
  else
    echo_error "❌ Gens enrollment via Gateway failed (HTTP ${http_code})"
    echo "$body" | jq '.'
    return 1
  fi
}

register_human_via_gateway() {
  echo_section "TEST 8: Register Human via Gateway (as Gens)"
  
  GENS_CERT_PATH="${OUTPUT_DIR}/${TEST_GENS_USER}-cert.pem"
  GENS_KEY_PATH="${OUTPUT_DIR}/${TEST_GENS_USER}-key.pem"
  
  # Verify Gens certificates exist
  if [ ! -f "${GENS_CERT_PATH}" ] || [ ! -f "${GENS_KEY_PATH}" ]; then
    echo_error "Gens certificates not found. Enroll Gens first."
    return 1
  fi
  
  echo_info "Building registration payload with Gens certificate..."
  
  # Read and escape Gens certificates
  CERT_CONTENT=$(cat "${GENS_CERT_PATH}" | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
  KEY_CONTENT=$(cat "${GENS_KEY_PATH}" | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
  
  # Build JSON payload (with Gens credentials for registrar!)
  read -r -d '' PAYLOAD <<EOF || true
{
  "certificate": "${CERT_CONTENT}",
  "privateKey": "${KEY_CONTENT}",
  "username": "${TEST_HUMAN_USER}",
  "secret": "${TEST_HUMAN_PASS}",
  "affiliation": "${TEST_GENS_AFFILIATION}",
  "gensUsername": "${TEST_GENS_USER}",
  "gensPassword": "${TEST_GENS_PASS}",
  "role": "human"
}
EOF
  
  echo_test "Sending registration request to ${GATEWAY_CA_REGISTER_HUMAN}"
  
  response=$(curl -k -s -w "\n%{http_code}" \
    -X POST "${GATEWAY_CA_REGISTER_HUMAN}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")
  
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')
  
  if [ "$http_code" -eq 200 ]; then
    echo_info "✅ Human registered successfully via Gateway"
    echo "$body" | jq '.'
    
    # Extract username from response
    REGISTERED_HUMAN=$(echo "$body" | jq -r '.data.username')
    echo_info "Registered Human: ${REGISTERED_HUMAN}"
    
    return 0
  else
    echo_error "❌ Human registration via Gateway failed (HTTP ${http_code})"
    echo "$body" | jq '.'
    return 1
  fi
}

enroll_human_idemix_via_gateway() {
  echo_section "TEST 9: Enroll Human via Gateway (Idemix)"
  
  echo_info "Building Idemix enrollment payload..."
  
  read -r -d '' PAYLOAD <<EOF || true
{
  "username": "${TEST_HUMAN_USER}",
  "secret": "${TEST_HUMAN_PASS}",
  "enrollmentType": "idemix",
  "idemixCurve": "gurvy.Bn254",
  "gensName": "${TEST_GENS_USER}",
  "role": "human"
}
EOF
  
  echo_test "Sending Idemix enrollment request to ${GATEWAY_CA_ENROLL}"
  
  response=$(curl -k -s -w "\n%{http_code}" \
    -X POST "${GATEWAY_CA_ENROLL}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")
  
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')
  
  if [ "$http_code" -eq 200 ]; then
    echo_info "✅ Human enrolled successfully via Gateway (Idemix)"
    
    # Extract Idemix credentials
    signerConfig=$(echo "$body" | jq -r '.data.signerConfig')
    issuerPublicKey=$(echo "$body" | jq -r '.data.issuerPublicKey')
    issuerRevocationKey=$(echo "$body" | jq -r '.data.issuerRevocationPublicKey')
    
    # Save to files
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
    
    # Validate SignerConfig
    if [ -f "$HUMAN_SIGNER_FILE" ]; then
      filesize=$(wc -c < "$HUMAN_SIGNER_FILE")
      if [ "$filesize" -gt 100 ]; then
        echo_info "✅ SignerConfig file size: ${filesize} bytes"
        
        # Check if it's valid JSON
        if jq empty "$HUMAN_SIGNER_FILE" 2>/dev/null; then
          echo_info "✅ SignerConfig is valid JSON"
          echo_info "SignerConfig structure:"
          jq 'keys' "$HUMAN_SIGNER_FILE" 2>/dev/null || echo "  (binary format)"
        else
          echo_info "ℹ️ SignerConfig is in binary/protobuf format (not JSON)"
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
    echo_error "❌ Human enrollment via Gateway failed (HTTP ${http_code})"
    echo "$body" | jq '.'
    return 1
  fi
}

cleanup() {
  echo_info "Cleaning up temporary files..."
  rm -rf "${TEMP_CERTS_DIR}"
}

###############################################################
# Main Test Execution
###############################################################

main() {
  echo ""
  echo "========================================"
  echo "  STARTING GATEWAY INTEGRATION TESTS"
  echo "========================================"
  echo ""
  
  # Health Checks
  test_gateway_health || exit 1
  echo ""
  
  test_ca_health || exit 1
  echo ""
  
  test_ledger_health || exit 1
  echo ""
  
  test_gateway_ready || exit 1
  echo ""
  
  test_ca_info_via_gateway || exit 1
  echo ""
  
  # Certificate Operations via Gateway
  register_gens_via_gateway || exit 1
  echo ""
  
  enroll_gens_via_gateway || exit 1
  echo ""
  
  register_human_via_gateway || exit 1
  echo ""
  
  enroll_human_idemix_via_gateway || exit 1
  echo ""
  
  cleanup
  
  # Success summary
  echo ""
  echo "========================================"
  echo "  ✅ ALL GATEWAY TESTS PASSED!"
  echo "========================================"
  echo ""
  echo "Test Results:"
  echo "  - Gateway: ✅ Healthy & Ready"
  echo "  - CA-Service: ✅ Reachable via Gateway"
  echo "  - Ledger-Service: ✅ Healthy"
  echo ""
  echo "Users created via Gateway:"
  echo "  - Gens: ${TEST_GENS_USER}"
  echo "  - Human: ${TEST_HUMAN_USER}"
  echo "  - Affiliation: ${TEST_GENS_AFFILIATION}"
  echo ""
  echo "Certificates saved to:"
  echo "  📁 ${OUTPUT_DIR}"
  echo ""
  echo "Files created:"
  ls -lh "${OUTPUT_DIR}"
  echo ""
}

# Execute main function
main
