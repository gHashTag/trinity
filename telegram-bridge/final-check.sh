#!/bin/bash
echo "=== Fly.io telegram-bridge sessions ==="
curl -s "https://vibee-telegram-bridge.fly.dev/api/v1/auth/status"
echo ""
echo ""
echo "=== Test dialogs with new session ==="
curl -s -H "X-Session-ID: sess_dexa0buo6w29" "https://vibee-telegram-bridge.fly.dev/api/v1/dialogs?limit=5"
