#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# RALPH TELEGRAM REPORTER via OpenClaw
# ═══════════════════════════════════════════════════════════════════════════════
# Usage:
#   report.sh <event_type> [message]
#
# Event types:
#   gate_pass     - Quality gate passed
#   gate_fail     - Quality gate failed (includes which gate)
#   commit        - New commit created
#   circuit_open  - Circuit breaker opened
#   circuit_close - Circuit breaker closed
#   loop_start    - Ralph loop started
#   loop_end      - Ralph loop ended
#   verdict       - Toxic verdict result
#   status        - RALPH_STATUS block summary
#   custom        - Arbitrary message (pass as $2)
# ═══════════════════════════════════════════════════════════════════════════════

set -uo pipefail

# Save caller's env before sourcing .ralphrc (env overrides config)
_CALLER_ENABLED="${RALPH_REPORT_ENABLED:-}"
_CALLER_CHAT_ID="${RALPH_TELEGRAM_CHAT_ID:-}"
_CALLER_OPENCLAW="${OPENCLAW_BIN:-}"

# Source .ralphrc if available
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RALPHRC="$PROJECT_ROOT/.ralphrc"
if [ -f "$RALPHRC" ]; then
    source "$RALPHRC"
fi

# --- Configuration (caller env > .ralphrc > defaults) ---
CHAT_ID="${_CALLER_CHAT_ID:-${RALPH_TELEGRAM_CHAT_ID:-144022504}}"
ENABLED="${_CALLER_ENABLED:-${RALPH_REPORT_ENABLED:-true}}"
OPENCLAW_BIN="${_CALLER_OPENCLAW:-${OPENCLAW_BIN:-node /Users/playra/openclaw/openclaw.mjs}}"
EVENT_TYPE="${1:-custom}"
CUSTOM_MSG="${2:-}"

# --- Guard: disabled ---
if [ "$ENABLED" = "false" ]; then
    exit 0
fi

# --- Helper: send message with graceful failure ---
send_telegram() {
    local msg="$1"
    $OPENCLAW_BIN message send \
        --channel telegram \
        --target "$CHAT_ID" \
        --message "$msg" \
        --silent 2>/dev/null || {
        echo "[report.sh] WARNING: Failed to send Telegram notification (openclaw gateway may be down)" >&2
        return 0
    }
}

# --- Collect context ---
BRANCH=$(cd "$PROJECT_ROOT" && git branch --show-current 2>/dev/null || echo "unknown")
SHORT_SHA=$(cd "$PROJECT_ROOT" && git rev-parse --short HEAD 2>/dev/null || echo "??????")
TIMESTAMP=$(date "+%H:%M:%S")

# --- Format and send based on event type ---
# NOTE: OpenClaw uses textMode=markdown by default, converting Markdown → HTML.
# Use Markdown formatting: **bold**, \`code\`, etc.
case "$EVENT_TYPE" in
    gate_pass)
        send_telegram "**✅ RALPH GATE PASSED**
Branch: \`$BRANCH\`
SHA: \`$SHORT_SHA\`
Time: $TIMESTAMP
Build + Test + Format: ALL GREEN"
        ;;
    gate_fail)
        FAILED_GATE="${CUSTOM_MSG:-unknown}"
        send_telegram "**❌ RALPH GATE FAILED**
Branch: \`$BRANCH\`
SHA: \`$SHORT_SHA\`
Failed at: **$FAILED_GATE**
Time: $TIMESTAMP"
        ;;
    commit)
        COMMIT_MSG="${CUSTOM_MSG:-$(cd "$PROJECT_ROOT" && git log -1 --pretty=%s 2>/dev/null || echo "no message")}"
        send_telegram "**📦 RALPH COMMIT**
Branch: \`$BRANCH\`
SHA: \`$SHORT_SHA\`
Message: $COMMIT_MSG
Time: $TIMESTAMP"
        ;;
    circuit_open)
        REASON="${CUSTOM_MSG:-no_progress}"
        send_telegram "**🔴 CIRCUIT BREAKER OPEN**
Branch: \`$BRANCH\`
Reason: $REASON
Time: $TIMESTAMP
Ralph is cooling down..."
        ;;
    circuit_close)
        send_telegram "**🟢 CIRCUIT BREAKER CLOSED**
Branch: \`$BRANCH\`
Time: $TIMESTAMP
Ralph resumed normal operation."
        ;;
    loop_start)
        LOOP_NUM="${CUSTOM_MSG:-?}"
        send_telegram "**🔄 RALPH LOOP $LOOP_NUM STARTED**
Branch: \`$BRANCH\`
SHA: \`$SHORT_SHA\`
Time: $TIMESTAMP"
        ;;
    loop_end)
        send_telegram "**⏹ RALPH LOOP ENDED**
Branch: \`$BRANCH\`
SHA: \`$SHORT_SHA\`
Time: $TIMESTAMP"
        ;;
    verdict)
        VERDICT_TEXT="${CUSTOM_MSG:-No verdict text}"
        send_telegram "**⚖️ TOXIC VERDICT**
Branch: \`$BRANCH\`
$VERDICT_TEXT
Time: $TIMESTAMP"
        ;;
    status)
        ANALYSIS_FILE="$PROJECT_ROOT/.ralph/.response_analysis"
        if [ -f "$ANALYSIS_FILE" ]; then
            STATUS=$(python3 -c "
import json, sys
try:
    with open('$ANALYSIS_FILE') as f:
        data = json.load(f)
    a = data.get('analysis', {})
    summary = a.get('work_summary', 'No summary')
    lines = summary.split('\n')
    status_lines = []
    capture = False
    for l in lines:
        if '---RALPH_STATUS---' in l:
            capture = True
            continue
        if '---END_RALPH_STATUS---' in l:
            break
        if capture:
            status_lines.append(l)
    print('\n'.join(status_lines[:15]))
except:
    print('Could not parse status')
" 2>/dev/null || echo "Could not parse status")
            send_telegram "**📊 RALPH STATUS REPORT**
\`\`\`
$STATUS
\`\`\`
Time: $TIMESTAMP"
        fi
        ;;
    custom)
        if [ -n "$CUSTOM_MSG" ]; then
            send_telegram "$CUSTOM_MSG"
        fi
        ;;
    *)
        echo "[report.sh] Unknown event type: $EVENT_TYPE" >&2
        exit 1
        ;;
esac
