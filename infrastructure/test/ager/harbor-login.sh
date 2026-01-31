#!/bin/bash
###############################################################
# Harbor Login Helper
# Liest Credentials aus .env und loggt in Harbor ein
###############################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# Check .env exists
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ ERROR: .env file not found!"
    echo "   Please copy .env.template to .env and configure Harbor credentials"
    exit 1
fi

# Load .env
export $(grep -v '^#' $ENV_FILE | xargs)

# Validate variables
if [ -z "$HARBOR_REGISTRY" ] || [ -z "$HARBOR_USER" ] || [ -z "$HARBOR_PASS" ]; then
    echo "❌ ERROR: Harbor credentials missing in .env"
    echo "   Required: HARBOR_REGISTRY, HARBOR_USER, HARBOR_PASS"
    exit 1
fi

# Login
echo "🔐 Logging in to Harbor Registry: $HARBOR_REGISTRY"
echo "$HARBOR_PASS" | docker login "$HARBOR_REGISTRY" \
    --username "$HARBOR_USER" \
    --password-stdin

if [ $? -eq 0 ]; then
    echo "✅ Harbor login successful"
else
    echo "❌ Harbor login failed"
    exit 1
fi
