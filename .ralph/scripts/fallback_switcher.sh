#!/bin/bash
# Multi-Provider Fallback Switcher
# Switches between Z.AI accounts when rate limited

set -uo pipefail

RALPHRC="/Users/playra/trinity/.ralph/.ralphrc"
STATE_FILE="/tmp/ralph_fallback_state"
LOG="/Users/playra/trinity/.ralph/logs/ralph.log"
REPORT_SCRIPT="/Users/playra/trinity/.ralph/scripts/report.sh"

# Load config
source "$RALPHRC" 2>/dev/null || true

# Get current state
if [ -f "$STATE_FILE" ]; then
    source "$STATE_FILE"
fi

# Check for rate limit in last 5 minutes ONLY
# Get log entries from last 5 minutes
RECENT_LOGS=$(find "$LOG" -mmin -5 2>/dev/null)
if [ -n "$RECENT_LOGS" ]; then
    RATE_LIMIT_HITS=$(tail -100 "$LOG" 2>/dev/null | grep -i "rate.limit\|429" | wc -l | tr -d ' ')
else
    RATE_LIMIT_HITS=0
fi

CURRENT_ACTIVE="${ACTIVE_FALLBACK:-1}"
LAST_SWITCH="${LAST_SWITCH:-0}"
NOW=$(date +%s)

# Only switch if:
# 1. Rate limit hits > 3 in recent logs
# 2. AND we haven't switched in the last 5 minutes (300 seconds)
NEED_SWITCH=false
if [ "$RATE_LIMIT_HITS" -gt 3 ] && [ $((NOW - LAST_SWITCH)) -gt 300 ]; then
    NEED_SWITCH=true
fi

if [ "$NEED_SWITCH" = "true" ]; then
    # Switch to other account
    if [ "$CURRENT_ACTIVE" = "1" ]; then
        NEW_ACTIVE=2
        NEW_KEY="$FALLBACK_API_KEY_2"
        MSG="🔄 **FALLBACK SWITCH: Account 1 → 2**

Rate limit on Z.AI account 1.
Switched to account 2."
    else
        NEW_ACTIVE=1
        NEW_KEY="$FALLBACK_API_KEY_1"
        MSG="🔄 **FALLBACK SWITCH: Account 2 → 1**

Rate limit on Z.AI account 2.
Switched to account 1."
    fi
    
    # Update active fallback in .ralphrc
    sed -i '' "s/ACTIVE_FALLBACK=.*/ACTIVE_FALLBACK=$NEW_ACTIVE/" "$RALPHRC" 2>/dev/null
    sed -i '' "s/^FALLBACK_API_KEY=\".*\"/FALLBACK_API_KEY=\"$NEW_KEY\"/" "$RALPHRC" 2>/dev/null
    
    # Save state
    echo "ACTIVE_FALLBACK=$NEW_ACTIVE" > "$STATE_FILE"
    echo "LAST_SWITCH=$NOW" >> "$STATE_FILE"
    
    # Notify
    "$REPORT_SCRIPT" "$MSG" 2>/dev/null &
    
    echo "Switched to fallback account $NEW_ACTIVE"
else
    echo "No switch needed. Active: $CURRENT_ACTIVE, Rate limits (5min): $RATE_LIMIT_HITS, Cooldown: $((NOW - LAST_SWITCH))s"
fi
