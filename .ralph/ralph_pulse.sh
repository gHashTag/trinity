#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# RALPH PULSE OF LIFE - Bash Implementation
# ═══════════════════════════════════════════════════════════════════════════════
#
# Usage: ./ralph_pulse.sh <type> <message>
# Types: thought, action, state_change, error, milestone, heartbeat
#
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Load config from environment
TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-}"
ENABLED="${RALPH_PULSE_ENABLED:-false}"

if [ "$ENABLED" != "true" ] && [ "$ENABLED" != "1" ]; then
    exit 0
fi

if [ -z "$TOKEN" ] || [ -z "$CHAT_ID" ]; then
    exit 0
fi

# Map pulse type to emoji and label
PULSE_TYPE="$1"
MESSAGE="$2"

case "$PULSE_TYPE" in
    thought)
        EMOJI="🧠"
        LABEL="THINKING"
        ;;
    action)
        EMOJI="⚡"
        LABEL="ACTION"
        ;;
    state_change)
        EMOJI="🔄"
        LABEL="STATE"
        ;;
    error)
        EMOJI="⚠️"
        LABEL="ERROR"
        ;;
    milestone)
        EMOJI="⭐"
        LABEL="MILESTONE"
        ;;
    heartbeat)
        EMOJI="💓"
        LABEL="HEARTBEAT"
        ;;
    *)
        EMOJI="📡"
        LABEL="PULSE"
        ;;
esac

# Send to Telegram
TEXT="${EMOJI} ${LABEL}: ${MESSAGE}"

curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\": \"${CHAT_ID}\", \"text\": \"${TEXT}\"}" \
    > /dev/null 2>&1 || true

# Log to file
echo "$(date '+%Y-%m-%d %H:%M:%S') [${LABEL}] ${MESSAGE}" >> /Users/playra/trinity-w1/.ralph/pulse.log
