#!/bin/bash
# Test Telegram Bot @vibee_dev_bot

TOKEN="8729158167:AAFUIozc36MOsj4bVH_g2Yt-xO6sX0AgVkk"
CHAT_ID="144022504"

# Test 1: getMe - verify bot exists
echo "=== Test 1: getMe ==="
wget -qO- "https://api.telegram.org/bot$TOKEN/getMe" | head -5

echo ""

# Test 2: sendMessage - send pulse to user
echo "=== Test 2: sendMessage ==="
wget -qO- --post-data="chat_id=$CHAT_ID&text=🧠 THINKING: Ralph Pulse of Life v1.0 is ALIVE!" \
    "https://api.telegram.org/bot$TOKEN/sendMessage" | head -5

echo ""

# Test 3: sendMessage - send keyboard
echo "=== Test 3: sendMessage with ReplyKeyboardMarkup ==="
wget -qO- --post-data="chat_id=$CHAT_ID&text=RALPH PULSE CONTROL PANEL:" \
    --header="Content-Type: application/json" \
    --post-data='{"chat_id": "'"$CHAT_ID"'", "text": "RALPH PULSE CONTROL PANEL:", "reply_markup": {"keyboard": [["/status", "/tasks", "/logs"], ["/pause", "/pulse", "/approve"], ["/git", "/bench", "/verbose"], ["/resume", "/stop", "/clear"]], "resize_keyboard": true}}' \
    "https://api.telegram.org/bot$TOKEN/sendMessage" | head -5
