#!/bin/bash
# Test sending from another account to trigger bot response
BRIDGE="https://vibee-telegram-bridge.fly.dev"
CHAT_ID="-1002737186844"  # VIBEE AGENT group

echo "=== Testing with different sessions ==="

# Try different sessions
for SESSION in "sess_dexa0buo6w29" "sess_desrtl4nry3c" "sess_deukljn4q4mo"; do
  echo ""
  echo "Trying session: $SESSION"
  RESP=$(curl --max-time 10 -s -X POST "$BRIDGE/api/v1/send" \
    -H "Content-Type: application/json" \
    -H "X-Session-ID: $SESSION" \
    -d "{\"chat_id\": $CHAT_ID, \"text\": \"vibee тест от другого аккаунта $(date +%H:%M:%S)\"}")
  echo "Response: $RESP"

  if echo "$RESP" | grep -q "success\":true"; then
    echo "SUCCESS! Session $SESSION works"
    break
  fi
done
