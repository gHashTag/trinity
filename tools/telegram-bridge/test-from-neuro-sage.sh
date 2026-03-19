#!/bin/bash
BRIDGE="https://vibee-telegram-bridge.fly.dev"
SESSION="sess_dexnakkcozww"  # neuro_sage
CHAT_ID="-1002737186844"     # VIBEE AGENT group

echo "=== Sending test message from @neuro_sage to trigger bot ==="
curl --max-time 30 -s -X POST "$BRIDGE/api/v1/send" \
  -H "Content-Type: application/json" \
  -H "X-Session-ID: $SESSION" \
  -d "{\"chat_id\": $CHAT_ID, \"text\": \"vibee привет! Что умеешь?\"}"

echo ""
echo "Waiting 10 seconds for bot response..."
sleep 10

echo "Checking messages..."
curl --max-time 30 -s -H "X-Session-ID: $SESSION" "$BRIDGE/api/v1/history/$CHAT_ID?limit=5"
