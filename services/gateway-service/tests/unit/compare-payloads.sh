#!/bin/bash

# Extract payload from shell script for comparison
AGER_CERT=$(cat ~/Entwicklung/JEDO/services/gateway-service/tests/certs/ager-admin-cert.pem)
AGER_KEY=$(cat ~/Entwicklung/JEDO/services/gateway-service/tests/certs/ager-admin-key.pem)

echo "=== SHELL SCRIPT PAYLOAD ==="
echo "Certificate first 100 chars:"
echo "$AGER_CERT" | head -c 100
echo ""
echo ""
echo "Certificate last 100 chars:"
echo "$AGER_CERT" | tail -c 100
echo ""
echo ""
echo "Key first 100 chars:"
echo "$AGER_KEY" | head -c 100
echo ""
echo ""
echo "Certificate line count:"
echo "$AGER_CERT" | wc -l
echo ""
echo "Key line count:"
echo "$AGER_KEY" | wc -l
echo ""
echo "Has carriage returns:"
echo "$AGER_CERT" | grep -c $'\r' || echo "0"
