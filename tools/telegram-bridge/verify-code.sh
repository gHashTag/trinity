#!/bin/bash
BRIDGE_URL="https://vibee-telegram-bridge.fly.dev"
SESSION_ID="sess_dexasn1fjk2d"
CODE_HASH="0e025163fafb6c30bc"
CODE="$1"

if [ -z "$CODE" ]; then
  echo "Usage: ./verify-code.sh <CODE>"
  exit 1
fi

echo "Verifying code $CODE for session $SESSION_ID..."
curl --max-time 60 -s -X POST "$BRIDGE_URL/api/v1/auth/code" \
  -H "Content-Type: application/json" \
  -H "X-Session-ID: $SESSION_ID" \
  -d "{\"code\": \"$CODE\", \"code_hash\": \"$CODE_HASH\"}"
