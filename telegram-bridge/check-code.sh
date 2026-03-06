#!/bin/bash
# Check for Telegram login code in messages
curl -s "http://localhost:8081/api/v1/dialogs?limit=10&session_id=sess_deukljn4q4mo" | head -50
echo ""
echo "---"
# Check Telegram service messages (777000 is Telegram's official account)
curl -s "http://localhost:8081/api/v1/history/777000?limit=5&session_id=sess_deukljn4q4mo"
