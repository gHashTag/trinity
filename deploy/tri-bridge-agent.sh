#!/bin/bash
# tri-bridge-agent.sh — Mac-side daemon for Perplexity Bridge (#102)
# Polls Railway command queue, executes locally, posts results back.
#
# Usage:
#   export PX_BRIDGE_TOKEN="your-token"
#   export RAILWAY_URL="https://trinity-production-a1d4.up.railway.app"
#   ./deploy/tri-bridge-agent.sh
#
# The agent polls /px/queue every 3 seconds for pending jobs,
# executes them in the Trinity repo context, and posts results
# back to /px/done.

set -euo pipefail

# ─── Config ──────────────────────────────────────────────────
RAILWAY_URL="${RAILWAY_URL:-https://trinity-production-a1d4.up.railway.app}"
TOKEN="${PX_BRIDGE_TOKEN:?ERROR: PX_BRIDGE_TOKEN not set}"
POLL_INTERVAL="${PX_POLL_INTERVAL:-3}"
REPO_DIR="${PX_REPO_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
MAX_RESULT=50000  # 50KB max result size

# ─── Command Whitelist ───────────────────────────────────────
# Only these command prefixes are allowed to execute.
# The bridge also has its own whitelist — this is defense in depth.
ALLOWED_PREFIXES=(
    "zig build"
    "zig test"
    "git status"
    "git log"
    "git branch"
    "git add"
    "git commit"
    "git push"
    "git diff"
    "gh issue"
    "gh pr"
    "./zig-out/bin/tri"
    "ls "
    "wc "
    "grep "
    "cat "
    "head "
    "tail "
    "PASS="
    "echo "
)

validate_cmd() {
    local cmd="$1"
    for prefix in "${ALLOWED_PREFIXES[@]}"; do
        if [[ "$cmd" == "$prefix"* ]]; then
            return 0
        fi
    done
    echo "[bridge-agent] BLOCKED: $cmd"
    return 1
}

# ─── Main Loop ───────────────────────────────────────────────
echo "[bridge-agent] started"
echo "[bridge-agent] Railway: $RAILWAY_URL"
echo "[bridge-agent] Repo: $REPO_DIR"
echo "[bridge-agent] Poll interval: ${POLL_INTERVAL}s"
echo ""

cd "$REPO_DIR"

while true; do
    # Poll for next pending job
    RESPONSE=$(curl -sf "${RAILWAY_URL}/px/queue?token=${TOKEN}" 2>/dev/null || echo '{"id":null}')
    JOB_ID=$(echo "$RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('id','') or '')" 2>/dev/null || echo "")

    if [ -n "$JOB_ID" ] && [ "$JOB_ID" != "null" ]; then
        CMD=$(echo "$RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('cmd',''))" 2>/dev/null || echo "")
        echo "[bridge-agent] $(date '+%H:%M:%S') job=$JOB_ID cmd=\"$CMD\""

        # Validate command
        if validate_cmd "$CMD"; then
            # Execute in repo context with timeout
            RESULT=$(timeout 120 bash -c "$CMD" 2>&1 | head -c $MAX_RESULT) || true
            EXIT_CODE=${PIPESTATUS[0]:-0}
        else
            RESULT="BLOCKED: command not in whitelist"
            EXIT_CODE=403
        fi

        # URL-encode result and post back
        ENCODED_RESULT=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.stdin.read()))" <<< "$RESULT" 2>/dev/null || echo "encoding_error")

        curl -sf "${RAILWAY_URL}/px/done?token=${TOKEN}&id=${JOB_ID}&exit=${EXIT_CODE}&result=${ENCODED_RESULT}" > /dev/null 2>&1 || \
            echo "[bridge-agent] WARNING: failed to post result for $JOB_ID"

        echo "[bridge-agent] $(date '+%H:%M:%S') done=$JOB_ID exit=$EXIT_CODE (${#RESULT} bytes)"
    fi

    sleep "$POLL_INTERVAL"
done
