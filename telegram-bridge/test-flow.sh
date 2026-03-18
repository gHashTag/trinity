#!/bin/bash
BRIDGE="https://vibee-telegram-bridge.fly.dev"
SESSION="sess_dexasn1fjk2d"
CHAT_ID="-1002737186844"  # VIBEE AGENT group

echo "=== Testing VIBEE Bot Flow ==="
echo ""

echo "1. Sending test message to VIBEE AGENT group..."
SEND_RESP=$(curl --max-time 30 -s -X POST "$BRIDGE/api/v1/send" \
  -H "Content-Type: application/json" \
  -H "X-Session-ID: $SESSION" \
  -d "{\"chat_id\": $CHAT_ID, \"text\": \"vibee привет! Это тест бота. Время: $(date)\"}")
echo "Send response: $SEND_RESP"
echo ""

echo "2. Waiting 10 seconds for bot response..."
sleep 10

echo "3. Checking last messages in VIBEE AGENT..."
curl --max-time 30 -s -H "X-Session-ID: $SESSION" "$BRIDGE/api/v1/history/$CHAT_ID?limit=5"
