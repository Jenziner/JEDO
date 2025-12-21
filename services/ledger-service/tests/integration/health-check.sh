#!/usr/bin/env bash
set -e

SERVICE_URL="${SERVICE_URL:-https://localhost:53921}"
HEALTH_URL="${SERVICE_URL}/health"

echo "=== Ledger-Service Health Check ==="
echo "Checking: ${HEALTH_URL}"

# -k: ignore self-signed certs (dev)
response=$(curl -k -s -w "\n%{http_code}" "${HEALTH_URL}")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" -eq 200 ]; then
  echo "✅ Health check OK (HTTP 200)"
  echo "$body"
  exit 0
else
  echo "❌ Health check failed (HTTP ${http_code})"
  echo "$body"
  exit 1
fi
