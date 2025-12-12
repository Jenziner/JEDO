#!/bin/sh

echo "Testing Infrastructure Access..."
echo ""

# Check if infrastructure is mounted
if [ -d "/app/infrastructure" ]; then
    echo "✅ Infrastructure directory mounted"
else
    echo "❌ Infrastructure directory NOT mounted"
    exit 1
fi

# Check specific paths
PATHS=(
    "/app/infrastructure/jedo/ea/alps"
    "/app/infrastructure/jedo/ea/alps/iss.alps.ea.jedo.cc"
    "/app/infrastructure/jedo/ea/alps/peer.alps.ea.jedo.cc"
    "/app/infrastructure/jedo/ea/alps/worb.alps.ea.jedo.cc"
)

for path in "${PATHS[@]}"; do
    if [ -d "$path" ]; then
        echo "✅ Found: $path"
    else
        echo "❌ Missing: $path"
    fi
done

# List available identities
echo ""
echo "Available identities:"
ls -1 /app/infrastructure/jedo/ea/alps/ | grep -E "\.(alps|worb)\."

echo ""
echo "Test completed."
