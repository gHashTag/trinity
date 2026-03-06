#!/bin/bash
BRIDGE="https://vibee-telegram-bridge.fly.dev"
SESSION="sess_dexnakkcozww"

echo "Sending auth code to +79933420465..."
curl --max-time 30 -s -X POST "$BRIDGE/api/v1/auth/phone" \
  -H "Content-Type: application/json" \
  -H "X-Session-ID: $SESSION" \
  -d '{"phone": "+79933420465"}'
