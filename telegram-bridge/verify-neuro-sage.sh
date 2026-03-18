#!/bin/bash
BRIDGE="https://vibee-telegram-bridge.fly.dev"
SESSION="sess_dexnakkcozww"

echo "Verifying code..."
curl --max-time 30 -s -X POST "$BRIDGE/api/v1/auth/code" \
  -H "Content-Type: application/json" \
  -H "X-Session-ID: $SESSION" \
  -d '{"code": "33872", "code_hash": "b2ab1d223253b09cb3"}'
