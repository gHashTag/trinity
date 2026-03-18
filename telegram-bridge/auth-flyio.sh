#!/bin/bash
# Telegram Auth Script for VIBEE on Fly.io
# Interactive authentication with Go bridge

BRIDGE_URL="https://vibee-telegram-bridge.fly.dev"
PHONE="+66624014170"
APP_ID="94892"
APP_HASH="***API_HASH***"

echo "=========================================="
echo "  VIBEE Telegram Authentication (Fly.io)"
echo "=========================================="
echo ""

# Step 1: Create session
echo "[1/3] Creating session..."
CONNECT_RESPONSE=$(curl -s -X POST "$BRIDGE_URL/api/v1/connect" \
  -H "Content-Type: application/json" \
  -d "{\"app_id\": $APP_ID, \"app_hash\": \"$APP_HASH\", \"phone\": \"$PHONE\"}")

echo "Response: $CONNECT_RESPONSE"

SESSION_ID=$(echo "$CONNECT_RESPONSE" | grep -o '"session_id":"[^"]*"' | cut -d'"' -f4)

if [ -z "$SESSION_ID" ]; then
  echo "Error: Failed to create session"
  exit 1
fi

echo "Session ID: $SESSION_ID"
echo ""

# Step 2: Request code
echo "[2/3] Requesting verification code..."
AUTH_RESPONSE=$(curl -s -X POST "$BRIDGE_URL/api/v1/auth/phone" \
  -H "Content-Type: application/json" \
  -H "X-Session-ID: $SESSION_ID" \
  -d "{\"phone\": \"$PHONE\"}")

echo "Response: $AUTH_RESPONSE"

CODE_HASH=$(echo "$AUTH_RESPONSE" | grep -o '"code_hash":"[^"]*"' | cut -d'"' -f4)

if [ -z "$CODE_HASH" ]; then
  echo "Error: Failed to request code"
  exit 1
fi

echo "Code sent! Check your Telegram app."
echo ""

# Step 3: Enter code
echo "[3/3] Enter the code from Telegram:"
read -p "Code: " USER_CODE

VERIFY_RESPONSE=$(curl -s -X POST "$BRIDGE_URL/api/v1/auth/code" \
  -H "Content-Type: application/json" \
  -H "X-Session-ID: $SESSION_ID" \
  -d "{\"code\": \"$USER_CODE\", \"code_hash\": \"$CODE_HASH\"}")

echo "Response: $VERIFY_RESPONSE"

# Check if 2FA is required
if echo "$VERIFY_RESPONSE" | grep -q "2fa_required"; then
  echo ""
  echo "2FA Required! Enter your password:"
  read -s -p "Password: " USER_PASSWORD
  echo ""

  VERIFY_RESPONSE=$(curl -s -X POST "$BRIDGE_URL/api/v1/auth/2fa" \
    -H "Content-Type: application/json" \
    -H "X-Session-ID: $SESSION_ID" \
    -d "{\"password\": \"$USER_PASSWORD\"}")
fi

# Check result
if echo "$VERIFY_RESPONSE" | grep -q '"status":"authorized"'; then
  echo ""
  echo "=========================================="
  echo "  SUCCESS! Telegram authorized on Fly.io!"
  echo "=========================================="
  echo ""
  echo "Session ID: $SESSION_ID"
  echo ""
  echo "Set this in vibee-mcp secrets:"
  echo "fly secrets set TELEGRAM_SESSION_ID=$SESSION_ID -a vibee-mcp"
else
  echo ""
  echo "Authentication result: $VERIFY_RESPONSE"
fi
