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
SCHOLAR_CRON="${PX_SCHOLAR_CRON:-1}"  # Enable scholar cron (1=on, 0=off)
LAST_SCHOLAR_HOUR=""
REPO_DIR="${PX_REPO_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
MAX_RESULT=100000  # 100KB max result size

# ─── Board Constants ─────────────────────────────────────
GH_PROJECT="PVT_kwHOAGdgHc4A-axm"
GH_STATUS_FIELD="PVTSSF_lAHOAGdgHc4A-axmzgx076o"
GH_STATUS_IN_PROGRESS="47fc9ee4"
GH_STATUS_IN_REVIEW="aba860b9"

# Move issue on project board (best-effort, don't block on failure)
move_board_status() {
    local issue_num="$1" target_status="$2"
    local item_id
    item_id=$(gh project item-list 6 --owner gHashTag --format json --limit 50 2>/dev/null | \
        python3 -c "import json,sys; items=json.load(sys.stdin).get('items',[]); [print(i['id']) for i in items if i.get('content',{}).get('number')==$issue_num]" 2>/dev/null | head -1)
    if [ -n "$item_id" ]; then
        gh project item-edit --project-id "$GH_PROJECT" --id "$item_id" \
            --field-id "$GH_STATUS_FIELD" --single-select-option-id "$target_status" > /dev/null 2>&1 || true
    fi
}

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
    "timeout 600 claude"
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

        # Parse issue number from claude commands: '#N:' at start of prompt
        ISSUE_NUM=$(echo "$CMD" | grep -oE "'#[0-9]+" | head -1 | tr -d "'#")

        # Post "started" comment + move board to In Progress
        if [ -n "$ISSUE_NUM" ]; then
            TASK_DESC=$(echo "$CMD" | sed "s/.*'#[0-9]*://" | sed "s/'.*//")
            JOB_START=$(date -u '+%Y-%m-%d %H:%M UTC')
            gh issue comment "$ISSUE_NUM" --body "🏃 **Agent Started** | \`$JOB_ID\`
**Task:** $TASK_DESC
**Time:** $JOB_START
**Agent:** Bridge → Claude Code" > /dev/null 2>&1 || true
            move_board_status "$ISSUE_NUM" "$GH_STATUS_IN_PROGRESS"
            echo "[bridge-agent] $(date '+%H:%M:%S') #$ISSUE_NUM → In Progress"
        fi

        # Validate command
        if validate_cmd "$CMD"; then
            # claude: commands get 600s timeout (they have their own internal timeout)
            if [[ "$CMD" == timeout\ 600\ claude* ]]; then
                TIMEOUT=620
            else
                TIMEOUT=120
            fi
            # Execute in repo context with timeout
            # Unset CLAUDECODE/CLAUDE_CODE to allow claude CLI when bridge-agent
            # runs inside an existing Claude Code session
            RESULT=$(env -u CLAUDECODE -u CLAUDE_CODE timeout $TIMEOUT bash -c "$CMD" 2>&1 | head -c $MAX_RESULT) || true
            EXIT_CODE=${PIPESTATUS[0]:-0}
        else
            RESULT="BLOCKED: command not in whitelist"
            EXIT_CODE=403
        fi

        # POST result as body (id and exit in query params)
        curl -sf -X POST \
            -H "Content-Type: text/plain" \
            --data-binary "$RESULT" \
            "${RAILWAY_URL}/px/done?token=${TOKEN}&id=${JOB_ID}&exit=${EXIT_CODE}" > /dev/null 2>&1 || \
            echo "[bridge-agent] WARNING: failed to post result for $JOB_ID"

        echo "[bridge-agent] $(date '+%H:%M:%S') done=$JOB_ID exit=$EXIT_CODE (${#RESULT} bytes)"

        # ─── Issue Tracking ──────────────────────────────────
        # Post result comment + move board status
        if [ -n "$ISSUE_NUM" ]; then
            COMMENT_BODY=$(echo "$RESULT" | head -c 2000)
            JOB_END=$(date -u '+%Y-%m-%d %H:%M UTC')
            gh issue comment "$ISSUE_NUM" --body "$(cat <<GHEOF
✅ **Agent Finished** | \`$JOB_ID\`
**Exit:** $EXIT_CODE | **Size:** ${#RESULT} bytes
**Time:** $JOB_END

\`\`\`
$COMMENT_BODY
\`\`\`
GHEOF
)" > /dev/null 2>&1 && \
                echo "[bridge-agent] $(date '+%H:%M:%S') commented on #$ISSUE_NUM" || \
                echo "[bridge-agent] WARNING: failed to comment on #$ISSUE_NUM"

            # Move board: exit=0 → In Review, else stay In Progress
            if [ "$EXIT_CODE" = "0" ]; then
                move_board_status "$ISSUE_NUM" "$GH_STATUS_IN_REVIEW"
                echo "[bridge-agent] $(date '+%H:%M:%S') #$ISSUE_NUM → In Review"
            fi
        fi
    fi

    # ─── Scholar Cron ─────────────────────────────────────────
    # Auto-submit scholar jobs at scheduled UTC hours
    if [ "$SCHOLAR_CRON" = "1" ]; then
        CURRENT_HOUR=$(date -u '+%H')
        if [ "$CURRENT_HOUR" != "$LAST_SCHOLAR_HOUR" ]; then
            case "$CURRENT_HOUR" in
                "06")
                    echo "[bridge-agent] $(date '+%H:%M:%S') CRON: submitting scholar full scan"
                    curl -sf "${RAILWAY_URL}/px/exec?token=${TOKEN}&cmd=claude%3ARun+%2Fscholar+full" > /dev/null 2>&1 || true
                    LAST_SCHOLAR_HOUR="$CURRENT_HOUR"
                    ;;
                "18")
                    echo "[bridge-agent] $(date '+%H:%M:%S') CRON: submitting scholar errors scan"
                    curl -sf "${RAILWAY_URL}/px/exec?token=${TOKEN}&cmd=claude%3ARun+%2Fscholar+errors" > /dev/null 2>&1 || true
                    LAST_SCHOLAR_HOUR="$CURRENT_HOUR"
                    ;;
            esac
        fi
    fi

    sleep "$POLL_INTERVAL"
done
