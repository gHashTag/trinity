#!/bin/bash
BRIDGE="https://vibee-telegram-bridge.fly.dev"
SESSION="sess_dexnakkcozww"

echo "Verifying 2FA..."
curl --max-time 30 -s -X POST "$BRIDGE/api/v1/auth/2fa" \
  -H "Content-Type: application/json" \
  -H "X-Session-ID: $SESSION" \
  -d '{"password": "Vishnu8087"}'
