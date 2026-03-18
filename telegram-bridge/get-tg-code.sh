#!/bin/bash
# Get messages from Telegram official account (login codes)
echo "Messages from Telegram (777000):"
curl -s "http://localhost:8081/api/v1/history/777000?limit=5&session_id=sess_deukljn4q4mo"
