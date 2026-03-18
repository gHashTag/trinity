#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: ./complete_auth.sh <SMS_CODE>"
    echo "Example: ./complete_auth.sh 12345"
    exit 1
fi

SMS_CODE=$1
SESSION_ID="***SESSION_ID***"

echo "========================================="
echo "  Completing Authentication"
echo "========================================="
echo ""
echo "Session ID: $SESSION_ID"
echo "SMS Code: $SMS_CODE"
echo ""

# Step 3: Verify code
echo "Step 3: Verifying SMS code..."
CODE_RESPONSE=$(curl -s -X POST http://localhost:8081/api/v1/auth/code \
  -H "Content-Type: application/json" \
  -d "{
    \"session_id\": \"$SESSION_ID\",
    \"code\": \"$SMS_CODE\"
  }")

echo "$CODE_RESPONSE" | jq .
echo ""

# Check if 2FA required
if echo "$CODE_RESPONSE" | jq -e '.status == "2fa_required"' > /dev/null; then
    echo "🔐 2FA required. Sending password..."
    
    # Step 4: Send 2FA password
    FA_RESPONSE=$(curl -s -X POST http://localhost:8081/api/v1/auth/2fa \
      -H "Content-Type: application/json" \
      -d "{
        \"session_id\": \"$SESSION_ID\",
        \"password\": \"Vishnu8087\"
      }")
    
    echo "$FA_RESPONSE" | jq .
    echo ""
    
    if echo "$FA_RESPONSE" | jq -e '.status == "authenticated"' > /dev/null; then
        echo "✅ Successfully authenticated with 2FA!"
        echo ""
        echo "Session saved to: sessions/$SESSION_ID.session"
        echo ""
        echo "To use this session in VIBEE:"
        echo "export TELEGRAM_SESSION_ID=$SESSION_ID"
        echo "cd ../gleam && gleam run"
    else
        echo "❌ 2FA authentication failed"
    fi
elif echo "$CODE_RESPONSE" | jq -e '.status == "authenticated"' > /dev/null; then
    echo "✅ Successfully authenticated!"
    echo ""
    echo "Session saved to: sessions/$SESSION_ID.session"
    echo ""
    echo "To use this session in VIBEE:"
    echo "export TELEGRAM_SESSION_ID=$SESSION_ID"
    echo "cd ../gleam && gleam run"
else
    echo "❌ Authentication failed"
    echo "Response: $CODE_RESPONSE"
fi
