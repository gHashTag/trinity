#!/bin/bash
# Simple Telegram Reporter
# Sends messages to configured chat

TELEGRAM_BOT_TOKEN="8110000341:AAHn9c7e8Jx0f1eY-4hT5Gd9Xh8iJ0kL1mN"
TELEGRAM_CHAT_ID="144022504"

send_message() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="${message}" \
        -d parse_mode="Markdown" \
        > /dev/null 2>&1
}

# If called with argument, send it
if [ -n "$1" ]; then
    send_message "$1"
fi
