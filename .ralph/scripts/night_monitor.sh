#!/bin/bash
# Night Monitor -_coordination with Ralph Loop
# Runs every 15 minutes, checks progress, sends updates
# DOES NOT conflict with Ralph Loop (PID 1497)

RALPH_LOG="/Users/playra/trinity/.ralph/logs/ralph.log"
STATUS_FILE="/Users/playra/trinity/.ralph/night_status.json"
TELEGRAM_CHAT="-5160767429"

# Check if Ralph Loop is running
RALPH_PID=$(pgrep -f "ralph_loop.sh")
if [ -z "$RALPH_PID" ]; then
    echo "⚠️ Ralph Loop not running!"
    # Send alert
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="$TELEGRAM_CHAT" \
        -d text="🚨 ALERT: Ralph Loop stopped!" > /dev/null 2>&1
    exit 1
fi

# Get last loop number
LAST_LOOP=$(tail -20 "$RALPH_LOG" | grep "Starting Loop #" | tail -1 | grep -o "#[0-9]*" | tr -d "#")
LAST_STATUS=$(tail -20 "$RALPH_LOG" | grep -E "SUCCESS|Rate limit|ERROR" | tail -1)

# Get git changes
cd /Users/playra/trinity
CHANGES=$(git status --short | wc -l | tr -d ' ')
LAST_COMMIT=$(git log --oneline -1)

# Check rate limit
if echo "$LAST_STATUS" | grep -q "Rate limit"; then
    STATUS="⏸️ Rate limit waiting"
elif echo "$LAST_STATUS" | grep -q "SUCCESS"; then
    STATUS="✅ Working"
else
    STATUS="🔄 Processing"
fi

# Save status
cat > "$STATUS_FILE" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "ralph_pid": $RALPH_PID,
    "last_loop": $LAST_LOOP,
    "status": "$STATUS",
    "changes": $CHANGES,
    "last_commit": "$LAST_COMMIT"
}
EOF

# Send update every hour (4 cycles)
MINUTE=$(date +%M)
if [ "$MINUTE" == "00" ] || [ "$MINUTE" == "15" ] || [ "$MINUTE" == "30" ] || [ "$MINUTE" == "45" ]; then
    MESSAGE="🌙 **Night Monitor** $(date +%H:%M)

Loop #$LAST_LOOP | $STATUS
Changes: $CHANGES files
$LAST_COMMIT

_Ralph PID: $RALPH_PID_"

    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="$TELEGRAM_CHAT" \
        -d parse_mode="Markdown" \
        -d text="$MESSAGE" > /dev/null 2>&1
fi

echo "Night monitor check: Loop #$LAST_LOOP, Status: $STATUS"
