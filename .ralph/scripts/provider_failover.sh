#!/bin/bash
# Provider Failover Monitor
# Detects rate limits, switches providers, notifies user

set -uo pipefail

RALPH_LOG="/Users/playra/trinity/.ralph/logs/ralph.log"
RALPHRC="/Users/playra/trinity/.ralph/.ralphrc"
REPORT_SCRIPT="/Users/playra/trinity/.ralph/scripts/report.sh"
STATE_FILE="/tmp/ralph_provider_state"

# Current provider from log
CURRENT_PROVIDER=$(grep -i "Provider status:" "$RALPH_LOG" 2>/dev/null | tail -1 | grep -o "primary:[a-z0-9]*\|fallback:[a-z0-9]*" | cut -d: -f2 || echo "unknown")
RATE_LIMIT_HITS=$(grep -i "rate.limit\|429" "$RALPH_LOG" 2>/dev/null | tail -10 | wc -l | tr -d ' ')
FALLBACK_ACTIVE=$(grep -i "fallback.*glm\|Activating GLM" "$RALPH_LOG" 2>/dev/null | tail -5 | wc -l | tr -d ' ')

# Load previous state
if [ -f "$STATE_FILE" ]; then
    source "$STATE_FILE"
fi

# Check for provider change
if [ "${LAST_PROVIDER:-}" != "$CURRENT_PROVIDER" ]; then
    if [ "$CURRENT_PROVIDER" = "glm5" ]; then
        MSG="⚠️ **PROVIDER SWITCHED**

Claude → GLM-5 (fallback)

Reason: Rate limit or error
Loops will continue on GLM-5"
        "$REPORT_SCRIPT" custom "$MSG" 2>/dev/null &
    elif [ "$CURRENT_PROVIDER" = "claude" ] && [ "${LAST_PROVIDER:-}" = "glm5" ]; then
        MSG="✅ **BACK TO CLAUDE**

GLM-5 → Claude (primary)

Claude rate limit reset"
        "$REPORT_SCRIPT" custom "$MSG" 2>/dev/null &
    fi
fi

# Check if both providers are rate limited
if [ "$RATE_LIMIT_HITS" -gt 5 ] && [ "$FALLBACK_ACTIVE" -gt 0 ]; then
    if [ "${LAST_BOTH_LIMITED:-0}" -lt $(($(date +%s) - 300)) ]; then
        MSG="🚨 **BOTH PROVIDERS LIMITED**

Claude: rate limited
GLM-5: rate limited

Ralph is waiting for reset.
Consider checking API quotas."
        "$REPORT_SCRIPT" custom "$MSG" 2>/dev/null &
        echo "LAST_BOTH_LIMITED=$(date +%s)" >> "$STATE_FILE"
    fi
fi

# Save state
echo "LAST_PROVIDER=$CURRENT_PROVIDER" > "$STATE_FILE"
echo "LAST_CHECK=$(date +%s)" >> "$STATE_FILE"

# Output for logs
echo "Provider: $CURRENT_PROVIDER | Rate limits: $RATE_LIMIT_HITS | Fallback: $FALLBACK_ACTIVE"
