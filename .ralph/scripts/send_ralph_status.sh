#!/bin/bash
# Ralph Status Reporter for Trinity Dev Telegram Group
# Sends periodic status updates from .ralph internal state

RALPH_DIR="/Users/playra/trinity/.ralph"
INTERNAL_DIR="$RALPH_DIR/internal"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Install with: brew install jq"
    exit 1
fi

# Read circuit breaker state
CB_STATE=$(cat "$INTERNAL_DIR/.circuit_breaker_state" 2>/dev/null || echo '{}')
CB_STATUS=$(echo "$CB_STATE" | jq -r '.state // "UNKNOWN"')
CB_LOOPS=$(echo "$CB_STATE" | jq -r '.consecutive_no_progress // 0')
CB_CURRENT_LOOP=$(echo "$CB_STATE" | jq -r '.current_loop // 0')
CB_REASON=$(echo "$CB_STATE" | jq -r '.reason // ""')

# Read session info
SESSION=$(cat "$INTERNAL_DIR/.ralph_session" 2>/dev/null || echo '{}')
SESSION_LAST_USED=$(echo "$SESSION" | jq -r '.last_used // "N/A"')
SESSION_RESET=$(echo "$SESSION" | jq -r '.reset_at // "N/A"')
SESSION_RESET_REASON=$(echo "$SESSION" | jq -r '.reset_reason // "N/A"')

# Read call count
CALL_COUNT=$(cat "$INTERNAL_DIR/.call_count" 2>/dev/null || echo "0")

# Read progress
PROGRESS=$(cat "$INTERNAL_DIR/progress.json" 2>/dev/null || echo '{}')
PROGRESS_STATUS=$(echo "$PROGRESS" | jq -r '.status // "unknown"')
PROGRESS_TIME=$(echo "$PROGRESS" | jq -r '.timestamp // "N/A"')

# Extract current active task from fix_plan.md
ACTIVE_TASK=$(grep "^\- \[ \] \[P1\]" "$INTERNAL_DIR/fix_plan.md" 2>/dev/null | head -1 | sed 's/^- \[ \] \[P1\] //' | tr -s ' ' | head -c 150)

# Get recent git commits
RECENT_COMMITS=$(git -C /Users/playra/trinity log --oneline -3 2>/dev/null || echo "No git history")

# Format status message
echo "=== Ralph Status Report ==="
echo ""

# Circuit breaker status
if [ "$CB_STATUS" = "CLOSED" ]; then
    echo "🟢 Circuit Breaker: CLOSED (Normal)"
elif [ "$CB_STATUS" = "OPEN" ]; then
    echo "🔴 Circuit Breaker: OPEN ($CB_REASON)"
elif [ "$CB_STATUS" = "HALF_OPEN" ]; then
    echo "🟡 Circuit Breaker: HALF_OPEN (Testing)"
else
    echo "⚪ Circuit Breaker: $CB_STATUS"
fi
echo "   Loop: $CB_CURRENT_LOOP | No progress loops: $CB_LOOPS"
echo ""

# Session status
echo "📊 Session:"
echo "   Last used: $SESSION_LAST_USED"
echo "   Last reset: $SESSION_RESET ($SESSION_RESET_REASON)"
echo "   Total calls: $CALL_COUNT"
echo ""

# Progress
echo "📈 Progress: $PROGRESS_STATUS (last update: $PROGRESS_TIME)"
echo ""

# Active task
if [ -n "$ACTIVE_TASK" ] && [ "$ACTIVE_TASK" != "  " ]; then
    echo "🎯 Current P1 Task:"
    echo "   $ACTIVE_TASK"
else
    echo "🎯 No active P1 tasks"
fi
echo ""

# Recent commits
echo "📝 Recent Commits:"
echo "$RECENT_COMMITS" | while read line; do
    echo "   • $line"
done
echo ""

# Generate formatted message for Telegram
TELEGRAM_MSG="🤖 **Ralph Status Report**

"

# Circuit breaker
if [ "$CB_STATUS" = "CLOSED" ]; then
    TELEGRAM_MSG+="🟢 **Circuit Breaker:** CLOSED (Normal)
"
elif [ "$CB_STATUS" = "OPEN" ]; then
    TELEGRAM_MSG+="🔴 **Circuit Breaker:** OPEN ($CB_REASON)
"
elif [ "$CB_STATUS" = "HALF_OPEN" ]; then
    TELEGRAM_MSG+="🟡 **Circuit Breaker:** HALF_OPEN (Testing)
"
else
    TELEGRAM_MSG+="⚪ **Circuit Breaker:** $CB_STATUS
"
fi

TELEGRAM_MSG+="   Loop: \`$CB_CURRENT_LOOP\` | No progress: \`$CB_LOOPS\`

"

# Session
TELEGRAM_MSG+="📊 **Session**
   Last: \`$SESSION_LAST_USED\`
   Reset: \`$SESSION_RESET\` ($SESSION_RESET_REASON)
   Calls: \`$CALL_COUNT\`

"

# Progress
TELEGRAM_MSG+="📈 **Progress:** \`$PROGRESS_STATUS\`
   Last update: \`$PROGRESS_TIME\`

"

# Active task
if [ -n "$ACTIVE_TASK" ] && [ "$ACTIVE_TASK" != "  " ]; then
    TELEGRAM_MSG+="🎯 **Current P1 Task:**
   $ACTIVE_TASK
"
else
    TELEGRAM_MSG+="🎯 **Current P1 Task:** None
"
fi

TELEGRAM_MSG+="

📝 **Recent Commits:**"

# Add commits
echo "$RECENT_COMMITS" | while read line; do
    TELEGRAM_MSG+="
   • $line"
done

TELEGRAM_MSG+="

---
*Generated at $(date '+%Y-%m-%d %H:%M:%S')*"

# Save message to file
echo "$TELEGRAM_MSG" > "$RALPH_DIR/status_message.txt"

# Save JSON for programmatic access
COMMIT_JSON=$(echo "$RECENT_COMMITS" | head -3 | while read line; do
    echo "\"$line\""
done | paste -sd ',' -)

if [ -z "$COMMIT_JSON" ]; then
    COMMIT_JSON="\"No commits\""
fi

cat > "$RALPH_DIR/status_report.json" <<EOF
{
  "circuit_breaker": {
    "state": "$CB_STATUS",
    "loop": $CB_CURRENT_LOOP,
    "no_progress_loops": $CB_LOOPS,
    "reason": "$CB_REASON"
  },
  "session": {
    "last_used": "$SESSION_LAST_USED",
    "reset_at": "$SESSION_RESET",
    "reset_reason": "$SESSION_RESET_REASON",
    "call_count": $CALL_COUNT
  },
  "progress": {
    "status": "$PROGRESS_STATUS",
    "timestamp": "$PROGRESS_TIME"
  },
  "active_task": "$ACTIVE_TASK",
  "recent_commits": [$COMMIT_JSON]
}
EOF

echo "Status saved to:"
echo "  • $RALPH_DIR/status_message.txt (Telegram format)"
echo "  • $RALPH_DIR/status_report.json (JSON format)"
echo ""
echo "To send to Telegram group -5160767429:"
echo "  openclaw message send --channel telegram --target -5160767429 --message \"\$(cat $RALPH_DIR/status_message.txt)\""
