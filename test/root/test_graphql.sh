#!/bin/bash

echo "=== Testing GraphQL Server ==="
echo ""

echo "1. Testing GET /graphql (playground):"
curl -s http://localhost:8080/graphql | head -20

echo ""
echo "2. Testing POST /graphql with query:"
curl -s -X POST http://localhost:8080/graphql \
  -H "Content-Type: application/json" \
  -d '{"query":"{commands{name}}"}'

echo ""
echo "3. Testing health endpoint:"
curl -s http://localhost:8080/api/health

echo ""
echo "=== Done ==="
