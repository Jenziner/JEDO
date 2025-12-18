#!/bin/bash

###############################################################
# Integration Test: CA Service (CLI-based with Affiliation)
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
echo "  CA Service Integration Test"
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
OUTPUT_DIR="$DOWNLOADS_DIR/jedo-ca-test-$TEST_RUN_ID"
mkdir -p "$OUTPUT_DIR"
echo -e "${BLUE}📁 Test output directory: $OUTPUT_DIR${NC}"

# API Endpoints
CA_SERVICE_URL="https://localhost:53911"
CA_SERVICE_HEALTH="${CA_SERVICE_URL}/health"
CA_SERVICE_INFO="${CA_SERVICE_URL}/ca/info"
CA_SERVICE_REGISTER_GENS="${CA_SERVICE_URL}/certificates/register/gens"
CA_SERVICE_REGISTER_HUMAN="${CA_SERVICE_URL}/certificates/register/human"
CA_SERVICE_ENROLL="${CA_SERVICE_URL}/certificates/enroll"

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

echo_info "Copying Ager certificates..."
cp ~/Entwicklung/JEDO/infrastructure/dev/infrastructure/jedo/ea/alps/admin.alps.ea.jedo.dev/msp/keystore/*_sk \
   ~/Entwicklung/JEDO/services/ca-service/tests/certs/ager-admin-key.pem

cp ~/Entwicklung/JEDO/infrastructure/dev/infrastructure/jedo/ea/alps/admin.alps.ea.jedo.dev/msp/signcerts/cert.pem \
   ~/Entwicklung/JEDO/services/ca-service/tests/certs/ager-admin-cert.pem

# Validate Ager certificate
if openssl x509 -in ~/Entwicklung/JEDO/services/ca-service/tests/certs/ager-admin-cert.pem -noout -text > /dev/null 2>&1; then
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
  
  echo_test "Sending registration request to ${CA_SERVICE_REGISTER_GENS}"
  
  # Send request
  response=$(curl -k -s -w "\n%{http_code}" \
    -X POST "${CA_SERVICE_REGISTER_GENS}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")
  
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')
  
  if [ "$http_code" -eq 200 ]; then
    echo_info "✅ Gens registered successfully"
    echo "$body" | jq '.'
    
    # Extract username from response
    REGISTERED_GENS=$(echo "$body" | jq -r '.data.username')
    echo_info "Registered Gens: ${REGISTERED_GENS}"
    
    return 0
  else
    echo_error "❌ Gens registration failed (HTTP ${http_code})"
    echo "$body" | jq '.'
    return 1
  fi
}

enroll_gens() {
  echo_section "TEST 4: Enroll Gens (X.509)"
  
  echo_info "Building enrollment payload..."
  
  read -r -d '' PAYLOAD <<EOF || true
{
  "username": "${TEST_GENS_USER}",
  "secret": "${TEST_GENS_PASS}",
  "enrollmentType": "x509",
  "role": "gens"
}
EOF
  
  echo_test "Sending enrollment request to ${CA_SERVICE_ENROLL}"
  
  response=$(curl -k -s -w "\n%{http_code}" \
    -X POST "${CA_SERVICE_ENROLL}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")
  
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')
  
  if [ "$http_code" -eq 200 ]; then
    echo_info "✅ Gens enrolled successfully"
    
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
    echo_error "❌ Gens enrollment failed (HTTP ${http_code})"
    echo "$body" | jq '.'
    return 1
  fi
}

register_human() {
  echo_section "TEST 5: Register Human (as Gens)"
  
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
  
  echo_test "Sending registration request to ${CA_SERVICE_REGISTER_HUMAN}"
  
  response=$(curl -k -s -w "\n%{http_code}" \
    -X POST "${CA_SERVICE_REGISTER_HUMAN}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")
  
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')
  
  if [ "$http_code" -eq 200 ]; then
    echo_info "✅ Human registered successfully"
    echo "$body" | jq '.'
    
    # Extract username from response
    REGISTERED_HUMAN=$(echo "$body" | jq -r '.data.username')
    echo_info "Registered Human: ${REGISTERED_HUMAN}"
    
    return 0
  else
    echo_error "❌ Human registration failed (HTTP ${http_code})"
    echo "$body" | jq '.'
    return 1
  fi
}

enroll_human_idemix() {
  echo_section "TEST 6: Enroll Human (Idemix)"
  
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
  
  echo_test "Sending Idemix enrollment request to ${CA_SERVICE_ENROLL}"
  
  response=$(curl -k -s -w "\n%{http_code}" \
    -X POST "${CA_SERVICE_ENROLL}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")
  
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')
  
  if [ "$http_code" -eq 200 ]; then
    echo_info "✅ Human enrolled successfully (Idemix)"
    
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
    echo_error "❌ Human enrollment failed (HTTP ${http_code})"
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
  echo "  STARTING CA SERVICE TESTS"
  echo "========================================"
  echo ""
  
  # Run tests sequentially
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
  
  # Success summary
  echo ""
  echo "========================================"
  echo "  ✅ ALL TESTS PASSED!"
  echo "========================================"
  echo ""
  echo "Test Results:"
  echo "  - Gens: ${TEST_GENS_USER}"
  echo "  - Human: ${TEST_HUMAN_USER}"
  echo "  - Affiliation: ${TEST_GENS_AFFILIATION}"
  echo "  - Output: ${OUTPUT_DIR}"
  echo ""
  echo "Files created:"
  ls -lh "${OUTPUT_DIR}"
  echo ""
}

# Execute main function
main
