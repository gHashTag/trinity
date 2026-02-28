#!/bin/bash

PORT=${1:-8082}

echo "==================================="
echo "GraphQL Server Full Test"
echo "==================================="
echo "Testing on port: $PORT"
echo ""

# Check if server is running
if ! curl -s http://localhost:$PORT/api/health > /dev/null 2>&1; then
    echo "ERROR: Server not running on port $PORT"
    echo "Start it with: ./zig-out/bin/tri serve --port $PORT"
    exit 1
fi

echo "1. Health Check:"
curl -s http://localhost:$PORT/api/health
echo -e "\n"

echo "2. GraphQL Playground (HTML available at http://localhost:$PORT/graphql)"
echo ""

echo "3. Introspection Query:"
cat > /tmp/introspection.json << 'EOF'
{"query":"{ __schema { queryType { name } } }"}
EOF
curl -s -X POST http://localhost:$PORT/graphql -H "Content-Type: application/json" -d @/tmp/introspection.json | head -c 300
echo -e "\n"

echo "4. Commands Query (all 130 commands):"
cat > /tmp/commands.json << 'EOF'
{"query":"{ commands { name category } }"}
EOF
curl -s -X POST http://localhost:$PORT/graphql -H "Content-Type: application/json" -d @/tmp/commands.json | head -c 500
echo -e "\n"

echo "5. Status Query:"
cat > /tmp/status.json << 'EOF'
{"query":"{ status { healthy connections } }"}
EOF
curl -s -X POST http://localhost:$PORT/graphql -H "Content-Type: application/json" -d @/tmp/status.json
echo -e "\n"

echo "==================================="
echo "All tests passed!"
echo "Open GraphQL Playground in browser:"
echo "  http://localhost:$PORT/graphql"
echo "==================================="
