#!/bin/bash
# Telegram Auth Script for VIBEE
# Interactive authentication with Go bridge

BRIDGE_URL="http://localhost:8081"
PHONE="+66612141269"
APP_ID="94892"
APP_HASH="***API_HASH***"

echo "=========================================="
echo "  VIBEE Telegram Authentication"
echo "=========================================="
echo ""

# Step 1: Create session
echo "[1/3] Creating session..."
CONNECT_RESPONSE=$(curl -s -X POST "$BRIDGE_URL/api/v1/connect" \
  -H "Content-Type: application/json" \
  -d "{\"app_id\": $APP_ID, \"app_hash\": \"$APP_HASH\", \"phone\": \"$PHONE\"}")

SESSION_ID=$(echo "$CONNECT_RESPONSE" | grep -o '"session_id":"[^"]*"' | cut -d'"' -f4)

if [ -z "$SESSION_ID" ]; then
  echo "Error: Failed to create session"
  echo "Response: $CONNECT_RESPONSE"
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

CODE_HASH=$(echo "$AUTH_RESPONSE" | grep -o '"code_hash":"[^"]*"' | cut -d'"' -f4)

if [ -z "$CODE_HASH" ]; then
  echo "Error: Failed to request code"
  echo "Response: $AUTH_RESPONSE"
  exit 1
fi

echo "Code sent! Check your Telegram app."
echo "Code hash: $CODE_HASH"
echo ""

# Step 3: Enter code
echo "[3/3] Enter the code from Telegram:"
read -p "Code: " USER_CODE

if [ -z "$USER_CODE" ]; then
  echo "Error: No code entered"
  exit 1
fi

echo ""
echo "Verifying code..."

VERIFY_RESPONSE=$(curl -s -X POST "$BRIDGE_URL/api/v1/auth/code" \
  -H "Content-Type: application/json" \
  -H "X-Session-ID: $SESSION_ID" \
  -d "{\"code\": \"$USER_CODE\", \"code_hash\": \"$CODE_HASH\"}")

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
  echo "  SUCCESS! Telegram authorized!"
  echo "=========================================="
  echo ""
  echo "Session ID: $SESSION_ID"
  echo ""
  echo "Save this session ID for future use:"
  echo "export TELEGRAM_SESSION_ID=$SESSION_ID"
  echo ""

  # Test connection
  echo "Testing connection..."
  ME_RESPONSE=$(curl -s "$BRIDGE_URL/api/v1/me" -H "X-Session-ID: $SESSION_ID")
  echo "User info: $ME_RESPONSE"

  # Get dialogs
  echo ""
  echo "Fetching dialogs..."
  curl -s "$BRIDGE_URL/api/v1/dialogs?limit=5" -H "X-Session-ID: $SESSION_ID" | head -500
else
  echo ""
  echo "Error: Authentication failed"
  echo "Response: $VERIFY_RESPONSE"
  exit 1
fi
