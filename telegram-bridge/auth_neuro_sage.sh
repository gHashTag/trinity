#!/bin/bash
SESSION_ID="sess_df0oylijluil"

echo "🔐 Authenticating @neuro_sage..."
echo "Phone: +79933420465"
echo ""

# Step 1: Send phone number
echo "Step 1: Sending phone number..."
PHONE_RESPONSE=$(curl -s -X POST http://localhost:8081/api/v1/auth/phone \
  -H "Content-Type: application/json" \
  -d "{
    \"session_id\": \"$SESSION_ID\",
    \"phone\": \"+79933420465\"
  }")

echo "Response: $PHONE_RESPONSE"
echo ""

# Check if code was sent
if echo "$PHONE_RESPONSE" | grep -q "code_sent\|phone_code_hash"; then
    echo "✅ SMS code sent to +7 (993) 342-04-65"
    echo ""
    echo "⚠️  Please check your phone and enter the code:"
    echo ""
    echo "To complete authentication, run:"
    echo "curl -X POST http://localhost:8081/api/v1/auth/code \\"
    echo "  -H 'Content-Type: application/json' \\"
    echo "  -d '{\"session_id\": \"$SESSION_ID\", \"phone\": \"+79933420465\", \"code\": \"YOUR_CODE\"}'"
    echo ""
    echo "If 2FA is required:"
    echo "curl -X POST http://localhost:8081/api/v1/auth/2fa \\"
    echo "  -H 'Content-Type: application/json' \\"
    echo "  -d '{\"session_id\": \"$SESSION_ID\", \"password\": \"Vishnu8087\"}'"
else
    echo "❌ Failed to send code"
    echo "Response: $PHONE_RESPONSE"
fi
