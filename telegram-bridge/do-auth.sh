#!/bin/bash
BRIDGE_URL="https://vibee-telegram-bridge.fly.dev"
APP_ID="94892"
APP_HASH="***API_HASH***"
PHONE="+66624014170"

echo "Creating session..."
RESP=$(curl --max-time 60 -s -X POST "$BRIDGE_URL/api/v1/connect" \
  -H "Content-Type: application/json" \
  -d "{\"app_id\": $APP_ID, \"app_hash\": \"$APP_HASH\"}")
echo "$RESP"

SID=$(echo "$RESP" | grep -o '"session_id":"[^"]*"' | cut -d'"' -f4)
echo "Session: $SID"

echo "Waiting 10s for Telegram connection..."
sleep 10

echo "Sending code to $PHONE..."
curl --max-time 90 -s -X POST "$BRIDGE_URL/api/v1/auth/phone" \
  -H "Content-Type: application/json" \
  -H "X-Session-ID: $SID" \
  -d "{\"phone\": \"$PHONE\"}"
