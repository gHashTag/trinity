#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# RALPH PULSE OF LIFE - Telegram Bridge Integration
# ═══════════════════════════════════════════════════════════════════════════════
#
# Uses telegram-bridge (Go + gotd/td) to send pulses via USER ACCOUNT
# This allows testing bot commands through your own Telegram account
#
# ═══════════════════════════════════════════════════════════════════════════════

set -e

BRIDGE_URL="${TELEGRAM_BRIDGE_URL:-http://localhost:8081}"
SESSION_ID="${TELEGRAM_SESSION_ID:-}"

# Load config
if [ -f "/Users/playra/trinity-w1/.ralphrc" ]; then
    source /Users/playra/trinity-w1/.ralphrc
fi

# Check if bridge is running
check_bridge() {
    if ! curl -s "$BRIDGE_URL/api/v1/bot/status" > /dev/null 2>&1; then
        echo "Error: telegram-bridge not running on $BRIDGE_URL"
        echo "Start it with: cd /Users/playra/trinity-w1/telegram-bridge && ./telegram-bridge"
        exit 1
    fi
}

# Map pulse type to emoji
pulse_emoji() {
    case "$1" in
        thought) echo "🧠" ;;
        action) echo "⚡" ;;
        state_change) echo "🔄" ;;
        error) echo "⚠️" ;;
        milestone) echo "⭐" ;;
        heartbeat) echo "💓" ;;
        *) echo "📡" ;;
    esac
}

pulse_label() {
    case "$1" in
        thought) echo "THINKING" ;;
        action) echo "ACTION" ;;
        state_change) echo "STATE" ;;
        error) echo "ERROR" ;;
        milestone) echo "MILESTONE" ;;
        heartbeat) echo "HEARTBEAT" ;;
        *) echo "PULSE" ;;
    esac
}

# Send message via telegram-bridge
send_via_bridge() {
    local text="$1"

    if [ -z "$SESSION_ID" ]; then
        echo "Error: TELEGRAM_SESSION_ID not set"
        echo "Export it from bridge auth or set in .ralphrc"
        return 1
    fi

    curl -s -X POST "$BRIDGE_URL/api/v1/send" \
        -H "Content-Type: application/json" \
        -H "X-Session-ID: $SESSION_ID" \
        -d "{\"text\": \"$text\"}" \
        > /dev/null 2>&1
}

# Main pulse function
ralph_pulse() {
    local pulse_type="$1"
    local message="$2"

    if [ "$RALPH_PULSE_ENABLED" != "true" ] && [ "$RALPH_PULSE_ENABLED" != "1" ]; then
        return 0
    fi

    local emoji=$(pulse_emoji "$pulse_type")
    local label=$(pulse_label "$pulse_type")
    local text="${emoji} ${label}: ${message}"

    echo "$(date '+%Y-%m-%d %H:%M:%S') [${label}] ${message}" >> /Users/playra/trinity-w1/.ralph/pulse.log

    send_via_bridge "$text"
}

# Export for use in other scripts
export -f ralph_pulse

# If called directly with arguments
if [ "${BASH_SOURCE[0]}" = "$0" ] && [ $# -gt 0 ]; then
    check_bridge
    ralph_pulse "$@"
fi
