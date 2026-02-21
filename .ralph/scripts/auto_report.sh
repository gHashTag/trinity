#!/bin/bash
# Auto-report Ralph progress to Telegram (minimal)
# Only sends when: task complete, blocked, or significant progress

set -uo pipefail

PROJECT_ROOT="/Users/playra/trinity"
RESPONSE_FILE="$PROJECT_ROOT/.ralph/.response_analysis"
LAST_HASH_FILE="/tmp/ralph_response_last_hash"
REPORT_SCRIPT="$PROJECT_ROOT/.ralph/scripts/report.sh"

# Get current hash of response file
if [ -f "$RESPONSE_FILE" ]; then
    CURRENT_HASH=$(md5 -q "$RESPONSE_FILE" 2>/dev/null || md5sum "$RESPONSE_FILE" | cut -d' ' -f1)
else
    exit 0
fi

# Check if changed
if [ -f "$LAST_HASH_FILE" ]; then
    LAST_HASH=$(cat "$LAST_HASH_FILE")
    if [ "$CURRENT_HASH" = "$LAST_HASH" ]; then
        exit 0
    fi
fi

echo "$CURRENT_HASH" > "$LAST_HASH_FILE"

# Parse response
if [ -f "$RESPONSE_FILE" ]; then
    LOOP_NUM=$(cat "$RESPONSE_FILE" | grep -o '"loop_number":[0-9]*' | cut -d: -f2)
    FILES_MODIFIED=$(cat "$RESPONSE_FILE" | grep -o '"files_modified":[0-9]*' | cut -d: -f2)
    STATUS=$(cat "$RESPONSE_FILE" | grep -o '"status":"[^"]*"' | head -1 | cut -d: -f2 | tr -d '"')
    WORK_SUMMARY=$(cat "$RESPONSE_FILE" | grep -o '"work_summary":"[^"]*"' | head -1 | sed 's/"work_summary":"//;s/"$//' | head -c 200)
    
    # Only report important events
    SEND=false
    REASON=""
    
    if [ "$STATUS" = "COMPLETE" ]; then
        SEND=true
        REASON="✅ Complete"
    elif [ "$STATUS" = "BLOCKED" ]; then
        SEND=true
        REASON="⚠️ Blocked"
    elif [ "${FILES_MODIFIED:-0}" -gt 5 ]; then
        SEND=true
        REASON="$FILES_MODIFIED files"
    fi
    
    if [ "$SEND" = "true" ]; then
        MESSAGE="🔄 #$LOOP_NUM $REASON
$WORK_SUMMARY"
        "$REPORT_SCRIPT" custom "$MESSAGE" 2>/dev/null || true
    fi
fi
