#!/bin/bash
# Trinity Cloud Agent Entrypoint
# Solves a single GitHub issue using Claude Code
# Required env: ISSUE_NUMBER, GITHUB_TOKEN, ANTHROPIC_API_KEY
#
# P0 hardened: timeout, SIGTERM handler, heartbeat loop, retry wrapper

<<<<<<< HEAD
set -eo pipefail
=======
set -e
set -o pipefail
>>>>>>> feat/issue-137

REPO_URL="${REPO_URL:-https://github.com/gHashTag/trinity.git}"
# Extract owner/repo for gh --repo flag (bare-repo worktrees lack git remote context)
GH_REPO=$(echo "${REPO_URL}" | sed 's|.*github.com[:/]||; s|\.git$||')
ISSUE="${ISSUE_NUMBER:?ISSUE_NUMBER is required}"
AGENT_TIMEOUT="${AGENT_TIMEOUT:-3600}"  # 1 hour default
HEARTBEAT_INTERVAL="${HEARTBEAT_INTERVAL:-30}"
CURRENT_STATUS="STARTING"
CURRENT_DETAIL="Initializing"
HEARTBEAT_PID=""
<<<<<<< HEAD
TRACE_ID="agent-${ISSUE}-$(date +%s)"
=======
LAST_TELEGRAM_SEND=0
>>>>>>> feat/issue-137

log() { echo "[agent-${ISSUE}] $1"; }

# ═══════════════════════════════════════════════════════════════════════════════
# SECRET REDACTION FILTER
# ═══════════════════════════════════════════════════════════════════════════════

redact_secrets() {
    # Redact known secret patterns from input text
    sed -E \
        -e 's/(ANTHROPIC_API_KEY|OPENAI_API_KEY|TELEGRAM_BOT_TOKEN|GITHUB_TOKEN|MONITOR_TOKEN|RAILWAY_API_TOKEN|AGENT_GH_TOKEN|PROJECT_TOKEN)=[^ "'\'']+/\1=[REDACTED]/g' \
        -e 's/sk-ant-[a-zA-Z0-9_-]+/[REDACTED]/g' \
        -e 's/github_pat_[a-zA-Z0-9_]+/[REDACTED]/g' \
        -e 's/ghp_[a-zA-Z0-9]+/[REDACTED]/g' \
        -e 's/gho_[a-zA-Z0-9]+/[REDACTED]/g' \
        -e 's/xoxb-[a-zA-Z0-9_-]+/[REDACTED]/g' \
        -e 's/Bearer [a-zA-Z0-9_.-]+/Bearer [REDACTED]/g'
}

# ═══════════════════════════════════════════════════════════════════════════════
# STATUS REPORTING
# ═══════════════════════════════════════════════════════════════════════════════

LAST_STATUS=""
DASHBOARD_COMMENT_ID=""
START_TIME=$(date +%s)
STEP_NUM=0
TG_TIMELINE=""
TOTAL_STEPS=8

status_emoji() {
    case "$1" in
        AWAKENING)  echo "🌅" ;;
        READING)    echo "📖" ;;
        PLANNING)   echo "📋" ;;
        CODING)     echo "⚡" ;;
        TESTING)    echo "🧪" ;;
        PR_CREATED) echo "🚀" ;;
        DONE)       echo "✅" ;;
        REVIEWING)  echo "🔍" ;;
        REPAIRING)  echo "🔧" ;;
        STUCK)      echo "⏰" ;;
        FAILED)     echo "❌" ;;
        ERROR)      echo "💥" ;;
        KILLED)     echo "☠️" ;;
        *)          echo "🔄" ;;
    esac
}

report_status() {
    CURRENT_STATUS="$1"
    CURRENT_DETAIL="$2"
    STEP_NUM=$((STEP_NUM + 1))
    ELAPSED=$(( $(date +%s) - START_TIME ))
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    EMOJI=$(status_emoji "${CURRENT_STATUS}")

    log "Status: ${CURRENT_STATUS} — ${CURRENT_DETAIL}"

    # Update heartbeat file so background heartbeat reads current state
    echo "${CURRENT_STATUS}|${CURRENT_DETAIL}" > "${HEARTBEAT_FILE}"

    # 1. HTTP POST to monitor (use jq for safe JSON escaping)
    if [ -n "${WS_MONITOR_URL}" ]; then
        SAFE_PAYLOAD=$(jq -n --argjson issue "${ISSUE}" --arg status "${CURRENT_STATUS}" --arg detail "${CURRENT_DETAIL}" \
            '{issue: $issue, status: $status, detail: $detail}' 2>/dev/null || \
            echo "{\"issue\":${ISSUE},\"status\":\"${CURRENT_STATUS}\",\"detail\":\"status update\"}")
        curl -s -X POST "${WS_MONITOR_URL}/api/status" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${MONITOR_TOKEN:-trinity}" \
            -d "${SAFE_PAYLOAD}" \
            --connect-timeout 5 --max-time 10 \
            2>/dev/null || log "Warning: monitor unreachable"
    fi

    # 2. Telegram: edit-in-place ONLY (no new messages — zero spam)
    # send_telegram removed — all updates go through update_telegram_dashboard below

    # 3. GitHub issue comment on status change (skip duplicates)
    if [ "${CURRENT_STATUS}" != "${LAST_STATUS}" ]; then
        gh issue comment "${ISSUE}" --repo "${GH_REPO}" --body "${EMOJI} **Trinity Agent** | ${TIMESTAMP}
📋 **Step**: ${STEP_NUM}/${TOTAL_STEPS} — ${CURRENT_DETAIL}
🔄 **Status**: ${CURRENT_STATUS}
⏱️ **Elapsed**: ${ELAPSED}s" 2>/dev/null || log "Warning: GitHub comment failed"
    fi
    LAST_STATUS="${CURRENT_STATUS}"

    # 4. Dashboard comment (create or update)
    DASHBOARD_BODY="${EMOJI} **Trinity Agent Dashboard** — Issue #${ISSUE}

| Field | Value |
|-------|-------|
| **Status** | ${CURRENT_STATUS} |
| **Step** | ${STEP_NUM}/${TOTAL_STEPS} |
| **Detail** | ${CURRENT_DETAIL} |
| **Elapsed** | ${ELAPSED}s |
| **Container** | agent-${ISSUE} |
| **Updated** | ${TIMESTAMP} |"

    if [ -z "${DASHBOARD_COMMENT_ID}" ]; then
        DASHBOARD_COMMENT_ID=$(gh issue comment "${ISSUE}" --repo "${GH_REPO}" --body "${DASHBOARD_BODY}" 2>/dev/null | grep -o '/[0-9]*$' | tr -d '/' || true)
        if [ -z "${DASHBOARD_COMMENT_ID}" ]; then
            DASHBOARD_COMMENT_ID=$(gh api "repos/{owner}/{repo}/issues/${ISSUE}/comments" --jq '.[-1].id' 2>/dev/null || true)
        fi
    elif [ -n "${DASHBOARD_COMMENT_ID}" ]; then
        gh api "repos/{owner}/{repo}/issues/comments/${DASHBOARD_COMMENT_ID}" \
            -X PATCH -f body="${DASHBOARD_BODY}" 2>/dev/null || log "Warning: Dashboard update failed"
    fi

    # 5. Telegram live card (edit-in-place, timeline accumulates)
    local mins=$((ELAPSED / 60))
    local secs=$((ELAPSED % 60))
    local ts_fmt=$(printf "%02d:%02d" "$mins" "$secs")

    # Append to timeline
    TG_TIMELINE="${TG_TIMELINE}${ts_fmt} ${EMOJI} ${CURRENT_DETAIL}
"
    # Build progress bar
    local pbar=""
    for i in $(seq 1 ${TOTAL_STEPS}); do
        if [ "$i" -le "${STEP_NUM}" ]; then pbar="${pbar}#"; else pbar="${pbar}."; fi
    done

    TG_DASH="🔧 <b>#${ISSUE}</b> — ${ISSUE_TITLE:-issue}
━━━━━━━━━━━━━━━━━━━━
<pre>${TG_TIMELINE}</pre>━━━━━━━━━━━━━━━━━━━━
[${pbar}] ${STEP_NUM}/${TOTAL_STEPS}
⏱ ${mins}m${secs}s"
    update_telegram_dashboard "${TG_DASH}"
}

escape_html() {
    echo "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

TG_DASHBOARD_MSG_ID=""

send_telegram() {
    if [ -n "${TELEGRAM_BOT_TOKEN}" ] && [ -n "${TELEGRAM_CHAT_ID}" ]; then
<<<<<<< HEAD
        local msg_file="/tmp/tg_msg_$$.json"
        local escaped_text
        escaped_text=$(echo "$1" | sed 's/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')
        printf '{"chat_id":"%s","text":"%s","parse_mode":"HTML"}' \
            "${TELEGRAM_CHAT_ID}" "${escaped_text}" > "${msg_file}"
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -H "Content-Type: application/json" \
            -d "@${msg_file}" \
            --connect-timeout 5 --max-time 10 \
            2>/dev/null || log "Warning: Telegram send failed"
        rm -f "${msg_file}"
    fi
}

# Update existing Telegram message (reduces spam, stays under rate limit)
update_telegram_dashboard() {
    if [ -n "${TELEGRAM_BOT_TOKEN}" ] && [ -n "${TELEGRAM_CHAT_ID}" ]; then
        local msg_file="/tmp/tg_dash_$$.json"
        local escaped_text
        escaped_text=$(echo "$1" | sed 's/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')

        if [ -z "${TG_DASHBOARD_MSG_ID}" ]; then
            # First call: send new message, capture message_id
            printf '{"chat_id":"%s","text":"%s","parse_mode":"HTML"}' \
                "${TELEGRAM_CHAT_ID}" "${escaped_text}" > "${msg_file}"
            local resp
            resp=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
                -H "Content-Type: application/json" \
                -d "@${msg_file}" \
                --connect-timeout 5 --max-time 10 2>/dev/null || true)
            TG_DASHBOARD_MSG_ID=$(echo "${resp}" | grep -o '"message_id":[0-9]*' | head -1 | cut -d: -f2)
        else
            # Subsequent calls: edit existing message
            printf '{"chat_id":"%s","message_id":%s,"text":"%s","parse_mode":"HTML"}' \
                "${TELEGRAM_CHAT_ID}" "${TG_DASHBOARD_MSG_ID}" "${escaped_text}" > "${msg_file}"
            curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/editMessageText" \
                -H "Content-Type: application/json" \
                -d "@${msg_file}" \
                --connect-timeout 5 --max-time 10 \
                2>/dev/null || log "Warning: Telegram edit failed"
        fi
        rm -f "${msg_file}"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# TELEGRAM LOG STREAMING — Batch streaming every 5 seconds to avoid rate limits
# ═══════════════════════════════════════════════════════════════════════════════

TELEGRAM_BUFFER=""
TELEGRAM_LAST_SEND=0
TELEGRAM_STREAM="${TELEGRAM_STREAM:-false}"  # Disabled: edit-in-place replaces streaming
TELEGRAM_BATCH_INTERVAL="${TELEGRAM_BATCH_INTERVAL:-5}"

stream_to_telegram() {
    [ "$TELEGRAM_STREAM" != "true" ] && return
    local line="$1"
    TELEGRAM_BUFFER="${TELEGRAM_BUFFER}${line}
"

    local now=$(date +%s)
    local diff=$((now - TELEGRAM_LAST_SEND))

    if [ $diff -ge $TELEGRAM_BATCH_INTERVAL ] || [ ${#TELEGRAM_BUFFER} -gt 3000 ]; then
        if [ -n "$TELEGRAM_BUFFER" ] && [ -n "$TELEGRAM_BOT_TOKEN" ]; then
            local msg=$(echo -e "$TELEGRAM_BUFFER" | head -c 3900)
            curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
                -d "chat_id=${TELEGRAM_CHAT_ID}" \
                -d "parse_mode=HTML" \
                -d "text=<pre>🤖 #${ISSUE} LOG
${msg}</pre>" \
                --max-time 5 || true
            TELEGRAM_BUFFER=""
            TELEGRAM_LAST_SEND=$now
        fi
    fi
}

flush_telegram() {
    if [ -n "$TELEGRAM_BUFFER" ] && [ -n "$TELEGRAM_BOT_TOKEN" ]; then
        local msg=$(echo -e "$TELEGRAM_BUFFER" | head -c 3900)
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "parse_mode=HTML" \
            -d "text=<pre>🤖 #${ISSUE} LOG
${msg}</pre>" \
            --max-time 5 || true
        TELEGRAM_BUFFER=""
=======
        # HTML escape for Telegram
        local escaped=$(echo -e "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
        # Rate limit protection: minimum 3 seconds between sends
        local now=$(date +%s)
        local diff=$((now - LAST_TELEGRAM_SEND))
        if [ $diff -lt 3 ]; then
            log "Skipping telegram send (rate limited, ${diff}s since last send)"
            return
        fi
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -H "Content-Type: application/json" \
            -d "{\"chat_id\":\"${TELEGRAM_CHAT_ID}\",\"text\":\"${escaped}\",\"parse_mode\":\"HTML\"}" \
            --connect-timeout 5 --max-time 10 \
            2>/dev/null || log "Warning: Telegram send failed"
        LAST_TELEGRAM_SEND=$now
    fi
}

stream_to_telegram() {
    local line="$1"
    # Stream line to telegram with HTML escaping
    if [ -n "${TELEGRAM_BOT_TOKEN}" ] && [ -n "${TELEGRAM_CHAT_ID}" ]; then
        local escaped=$(echo -e "${line}" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' | head -c 3900)
        # Rate limit protection
        local now=$(date +%s)
        local diff=$((now - LAST_TELEGRAM_SEND))
        if [ $diff -lt 3 ]; then
            return
        fi
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -H "Content-Type: application/json" \
            -d "{\"chat_id\":\"${TELEGRAM_CHAT_ID}\",\"text\":\"${escaped}\"}" \
            --connect-timeout 2 --max-time 5 \
            2>/dev/null || true
        LAST_TELEGRAM_SEND=$now
>>>>>>> feat/issue-137
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# EVENT STREAM (OpenHands-style structured events)
# ═══════════════════════════════════════════════════════════════════════════════

report_metrics() {
    FILES_CHANGED=$(git diff --stat main..HEAD 2>/dev/null | grep -c '|' || echo "0")
    LINES_ADDED=$(git diff --stat main..HEAD 2>/dev/null | tail -1 | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
    COMMITS_COUNT=$(git log --oneline main..HEAD 2>/dev/null | wc -l | tr -d ' ')

    # Emit structured metric event via ACI protocol
    emit_metric \
        "tests_passed" "${TESTS_PASSED:-0}" \
        "tests_total" "${TESTS_TOTAL:-0}" \
        "files_changed" "${FILES_CHANGED}" \
        "lines_added" "${LINES_ADDED}" \
        "commits" "${COMMITS_COUNT}" \
        "status" "\"${CURRENT_STATUS}\""
}

# ═══════════════════════════════════════════════════════════════════════════════
# ACI PROTOCOL (Agent-Computer Interface)
# ═══════════════════════════════════════════════════════════════════════════════
# All events follow the structured ACI protocol:
#   {"type":"status|log|metric|error|pr","issue":N,"payload":{...},"ts":"ISO8601"}
#
# Event types:
#   status  - Agent status change (THINKING, CODING, DONE, FAILED, etc.)
#   log     - General log message with level and message
#   metric  - Quantitative metrics (tests_passed, tests_total, files_changed, etc.)
#   error   - Error condition with message and optional stack trace
#   pr      - Pull request created with URL and commit count
# ═══════════════════════════════════════════════════════════════════════════════

emit_event() {
    local type="$1"
    local payload="$2"
    local ts
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    # Determine surface category for three-surface taxonomy
    local surface="operational"
    case "${type}" in
        status)
            case "$(echo "${payload}" | grep -oP '"status":"[^"]*"' | cut -d'"' -f4)" in
                AWAKENING|DONE|FAILED|KILLED) surface="operational" ;;
                READING|PLANNING|CODING|REVIEWING|REPAIRING) surface="cognitive" ;;
                *) surface="operational" ;;
            esac
            ;;
        file_edit|test_run|command|pr|metric) surface="contextual" ;;
        log) surface="contextual" ;;
        error) surface="operational" ;;
    esac
    local event="{\"type\":\"${type}\",\"issue\":${ISSUE},\"trace_id\":\"${TRACE_ID}\",\"surface\":\"${surface}\",\"payload\":${payload},\"ts\":\"${ts}\"}"

    # Rotate event file if >10MB
    if [ -f /tmp/agent_events.jsonl ]; then
        EVENT_SIZE=$(stat -f%z /tmp/agent_events.jsonl 2>/dev/null || stat -c%s /tmp/agent_events.jsonl 2>/dev/null || echo "0")
        if [ "${EVENT_SIZE}" -gt 10485760 ]; then
            tail -1000 /tmp/agent_events.jsonl > /tmp/agent_events.jsonl.tmp
            mv /tmp/agent_events.jsonl.tmp /tmp/agent_events.jsonl
        fi
    fi
    echo "${event}" >> /tmp/agent_events.jsonl

    if [ -n "${WS_MONITOR_URL}" ]; then
        curl -s -X POST "${WS_MONITOR_URL}/api/event" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${MONITOR_TOKEN:-trinity}" \
            -d "${event}" \
            --connect-timeout 5 --max-time 10 \
            2>/dev/null || true
    fi
}

# Convenience wrappers for ACI protocol
emit_status() {
    emit_event "status" "{\"status\":\"$1\",\"detail\":\"$2\"}"
}

emit_log() {
    local level="${1:-info}"
    local msg="$2"
    emit_event "log" "{\"level\":\"${level}\",\"message\":\"${msg}\"}"
}

emit_metric() {
    # Usage: emit_metric "tests_passed" 5 "tests_total" 8
    local payload="{"
    local first=true
    while [ $# -ge 2 ]; do
        if [ "$first" = true ]; then
            first=false
        else
            payload="${payload},"
        fi
        payload="${payload}\"$1\":$2"
        shift 2
    done
    payload="${payload}}"
    emit_event "metric" "${payload}"
}

emit_error() {
    local msg="$1"
    local code="${2:-1}"
    emit_event "error" "{\"message\":\"${msg}\",\"code\":${code}}"
}

emit_pr() {
    local url="$1"
    local commits="${2:-1}"
    emit_event "pr" "{\"url\":\"${url}\",\"commits\":${commits}}"
}

<<<<<<< HEAD
# P0.4: Structured file_edit and test_run event types
emit_file_edit() {
    local path="$1"
    local action="${2:-modify}"  # create|modify|delete
    emit_event "file_edit" "{\"path\":\"${path}\",\"action\":\"${action}\"}"
}

emit_test_run() {
    local passed="$1"
    local total="$2"
    local duration_s="${3:-0}"
    emit_event "test_run" "{\"passed\":${passed},\"total\":${total},\"duration_s\":${duration_s}}"
}

=======
>>>>>>> feat/issue-126
# ═══════════════════════════════════════════════════════════════════════════════
# HEARTBEAT LOOP (P0.6) — background process sends status every 30s
# ═══════════════════════════════════════════════════════════════════════════════

HEARTBEAT_FILE="/tmp/agent_heartbeat_state"

start_heartbeat() {
    echo "STARTING|Initializing" > "${HEARTBEAT_FILE}"
    (
        while true; do
            sleep "${HEARTBEAT_INTERVAL}"
            if [ -f "${HEARTBEAT_FILE}" ]; then
                HB_STATUS=$(cut -d'|' -f1 "${HEARTBEAT_FILE}")
                HB_DETAIL=$(cut -d'|' -f2 "${HEARTBEAT_FILE}")
                ELAPSED=$(( $(date +%s) - ${START_TIME:-0} ))
                if [ -n "${WS_MONITOR_URL}" ]; then
                    curl -s -X POST "${WS_MONITOR_URL}/api/status" \
                        -H "Content-Type: application/json" \
                        -H "Authorization: Bearer ${MONITOR_TOKEN:-trinity}" \
                        -d "{\"issue\":${ISSUE},\"trace_id\":\"${TRACE_ID}\",\"status\":\"${HB_STATUS}\",\"detail\":\"heartbeat: ${HB_DETAIL} (${ELAPSED}s)\"}" \
                        --connect-timeout 5 --max-time 10 2>/dev/null || true
                fi
            fi
        done
    ) &
    HEARTBEAT_PID=$!
}

stop_heartbeat() {
    if [ -n "${HEARTBEAT_PID}" ]; then
        kill "${HEARTBEAT_PID}" 2>/dev/null || true
        wait "${HEARTBEAT_PID}" 2>/dev/null || true
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# RETRY WRAPPER (P1.7) — 3 attempts with exponential backoff
# ═══════════════════════════════════════════════════════════════════════════════

retry() {
    local max_attempts=3
    local attempt=1
    local delay=5

    while [ $attempt -le $max_attempts ]; do
        if "$@"; then
            return 0
        fi
        log "Attempt ${attempt}/${max_attempts} failed: $*"
        if [ $attempt -lt $max_attempts ]; then
            log "Retrying in ${delay}s..."
            sleep $delay
            delay=$((delay * 2))
        fi
        attempt=$((attempt + 1))
    done
    return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# GRACEFUL SHUTDOWN (P0.2)
# ═══════════════════════════════════════════════════════════════════════════════

# Health marker
touch /tmp/agent-alive

cleanup() {
    log "Shutting down (signal received)..."
    stop_heartbeat

    # Kill all child processes (prevents zombies from claude, zig build, etc.)
    pkill -P $$ 2>/dev/null || true

    report_status "KILLED" "Container terminated by signal"

    # Cleanup worktree if it exists
    if [ -n "${WORKTREE_PATH}" ] && [ -d "${WORKTREE_PATH}" ]; then
        log "Cleaning up worktree on exit..."
        cd /bare-repo.git 2>/dev/null || true
        git worktree unlock "${WORKTREE_PATH}" 2>/dev/null || true
        git worktree remove "${WORKTREE_PATH}" --force 2>/dev/null || true
        log "Worktree removed: ${WORKTREE_PATH}"
    fi

    rm -f /tmp/agent-alive
    exit 1
}
trap cleanup TERM INT

log "Starting Trinity Cloud Agent"
log "Issue: #${ISSUE}, Timeout: ${AGENT_TIMEOUT}s"

# Start heartbeat
start_heartbeat

# === 1. Auth ===
report_status "AWAKENING" "Authenticating with GitHub"
log "GITHUB_TOKEN present: $([ -n "${GITHUB_TOKEN}" ] && echo 'yes' || echo 'NO')"

# gh auth login reads token from stdin; NEVER log output (may contain token)
printf '%s\n' "${GITHUB_TOKEN}" | gh auth login --with-token >/dev/null 2>&1 || true
AUTH_EXIT=$?
log "gh auth login exit: ${AUTH_EXIT}"

if [ "${AUTH_EXIT}" -ne 0 ]; then
    # Retry once more with explicit host
    printf '%s\n' "${GITHUB_TOKEN}" | gh auth login --with-token --hostname github.com >/dev/null 2>&1 || true
    AUTH_EXIT=$?
    log "gh auth login retry exit: ${AUTH_EXIT}"
fi

if [ "${AUTH_EXIT}" -ne 0 ]; then
    report_status "FAILED" "GitHub auth failed (exit ${AUTH_EXIT})"
    update_telegram_dashboard "❌ <b>#${ISSUE}</b> GitHub auth failed (exit ${AUTH_EXIT})"
    stop_heartbeat
    rm -f /tmp/agent-alive
    exit 1
fi

# Verify auth worked — redact token from output
GH_STATUS=$(gh auth status 2>&1 | sed 's/Token: .*/Token: [REDACTED]/' | sed 's/github_pat_[^ ]*/[REDACTED]/g') || true
log "gh auth status: ${GH_STATUS}"
git config --global user.name "Trinity Agent"
git config --global user.email "trinity-agent@users.noreply.github.com"

# Configure git to use gh as credential helper (fixes push auth)
gh auth setup-git 2>/dev/null || true
log "gh auth setup-git done — git push will use GITHUB_TOKEN"

# === 2. Setup worktree from shared bare repo ===
report_status "AWAKENING" "Creating worktree from bare repository"

# Check if bare repo needs to be created or updated
# Use flock to prevent concurrent git operations on shared bare repo (#14)
BARE_LOCK="/tmp/bare-repo.lock"
(
    flock -w 120 9 || { log "Warning: could not acquire bare repo lock after 120s"; }

    if [ ! -d /bare-repo.git/objects ]; then
        log "Bare repo not found, creating from remote..."
        if ! retry git clone --bare --depth=1 --single-branch --branch main "${REPO_URL}" /bare-repo.git; then
            report_status "FAILED" "Git bare clone failed after 3 attempts"
            stop_heartbeat
            rm -f /tmp/agent-alive
            exit 1
        fi
    else
        log "Updating bare repo from remote..."
        cd /bare-repo.git
        # Fetch with explicit refspec to ensure origin/main exists
        retry git fetch origin '+refs/heads/main:refs/remotes/origin/main' --depth=1 || log "Warning: bare repo update failed"
        # Update local main ref to match remote (bare repo has stale pre-baked main)
        git update-ref refs/heads/main refs/remotes/origin/main 2>/dev/null || \
            git update-ref refs/heads/main FETCH_HEAD 2>/dev/null || \
            log "Warning: could not update main ref"
    fi
) 9>"${BARE_LOCK}"

# Create worktree for this agent (fast! ~5-10s vs ~60s for full clone)
WORKTREE_PATH="/workspace/trinity-${ISSUE}"
if [ -d "${WORKTREE_PATH}" ]; then
    log "Removing existing worktree..."
    cd /bare-repo.git
    git worktree unlock "${WORKTREE_PATH}" 2>/dev/null || true
    git worktree remove "${WORKTREE_PATH}" --force 2>/dev/null || true
    rm -rf "${WORKTREE_PATH}"
fi

cd /bare-repo.git
# Clean up stale branch from previous run/retry (Bug #28)
git branch -D "agent-${ISSUE}" 2>/dev/null || true
git worktree prune 2>/dev/null || true

if ! retry git worktree add -b "agent-${ISSUE}" "${WORKTREE_PATH}" main; then
    # Fallback: try without -b (branch may exist from prior run)
    log "Retrying worktree add without -b flag..."
    git branch -D "agent-${ISSUE}" 2>/dev/null || true
    git worktree prune 2>/dev/null || true
    if ! git worktree add "${WORKTREE_PATH}" -b "agent-${ISSUE}" main 2>&1; then
        report_status "FAILED" "Git worktree add failed after all attempts"
        stop_heartbeat
        rm -f /tmp/agent-alive
        exit 1
    fi
fi
cd "${WORKTREE_PATH}"

# Lock worktree to prevent accidental pruning
git worktree lock "${WORKTREE_PATH}" 2>/dev/null || true
log "Worktree created and locked at ${WORKTREE_PATH}"

# === 3. Prepare SOUL.md ===
log "Injecting soul..."
sed "s/{ISSUE_NUMBER}/${ISSUE}/g" /etc/trinity/SOUL.md > "${WORKTREE_PATH}/CLAUDE.md.agent"

# === 4. Read issue ===
report_status "READING" "Reading issue #${ISSUE}"
ISSUE_BODY=$(gh issue view "${ISSUE}" --repo "${GH_REPO}" --json title,body,labels --jq '.' 2>/dev/null || echo '{"title":"Unknown","body":"Failed to fetch issue"}')
ISSUE_TITLE=$(echo "${ISSUE_BODY}" | grep -oP '"title"\s*:\s*"[^"]*"' | head -1 | sed 's/"title"\s*:\s*"//;s/"$//' || echo "issue #${ISSUE}")
log "Issue title: ${ISSUE_TITLE}"
update_telegram_dashboard "📖 <b>#${ISSUE}</b> читает задачу:
<i>${ISSUE_TITLE}</i>"

# === 4b. Role-based SOUL.md — strip non-matching role blocks ===
AGENT_ROLE=$(echo "${ISSUE_BODY}" | grep -oP '"name"\s*:\s*"agent:(ralph|scholar|mu)"' | head -1 | sed 's/.*agent://;s/".*//' || echo "ralph")
if [ -z "${AGENT_ROLE}" ]; then
    AGENT_ROLE="ralph"
fi
log "Agent role: ${AGENT_ROLE}"

# === 4b2. Chain role detection (v5.0) — role:planner/coder/reviewer/tester/integrator ===
# Chain roles override agent roles for decomposed sub-issues
CHAIN_ROLE=$(echo "${ISSUE_BODY}" | grep -oP '"name"\s*:\s*"role:(planner|coder|reviewer|tester|integrator)"' | head -1 | sed 's/.*role://;s/".*//' || echo "")
if [ -n "${CHAIN_ROLE}" ]; then
    log "Chain role detected: ${CHAIN_ROLE} (overrides agent role)"
    # Map chain roles to link ranges (start-end inclusive)
    case "${CHAIN_ROLE}" in
        planner)    CHAIN_LINKS="0-6"   ; CHAIN_DESC="TVC Gate → Spec Creation" ;;
        coder)      CHAIN_LINKS="7-8"   ; CHAIN_DESC="Code Generation → Sacred Analysis" ;;
        reviewer)   CHAIN_LINKS="8-10"  ; CHAIN_DESC="Analysis → Benchmark Comparison" ;;
        tester)     CHAIN_LINKS="9-13"  ; CHAIN_DESC="Test → Theoretical Benchmark" ;;
        integrator) CHAIN_LINKS="14-19" ; CHAIN_DESC="Delta Report → Loop Decision" ;;
        *)          CHAIN_LINKS=""      ; CHAIN_DESC="" ;;
    esac
fi

# Keep matching role block, strip others (awk for portable block deletion)
SOUL_FILE="${WORKTREE_PATH}/CLAUDE.md.agent"
strip_blocks() {
    # Usage: strip_blocks "TAG1" "TAG2" < input > output
    # Removes lines between {TAG1}...{/TAG1} and {TAG2}...{/TAG2} inclusive
    local t1="$1" t2="$2"
    awk -v t1="$t1" -v t2="$t2" '
        $0 ~ "\\{IF_"t1"\\}" { skip=1; next }
        $0 ~ "\\{/IF_"t1"\\}" { skip=0; next }
        $0 ~ "\\{IF_"t2"\\}" { skip=1; next }
        $0 ~ "\\{/IF_"t2"\\}" { skip=0; next }
        skip==0 { print }
    '
}
strip_markers() {
    # Remove remaining {IF_X}/{/IF_X} markers for the kept role
    grep -v "^{IF_$1}$" | grep -v "^{/IF_$1}$"
}
case "${AGENT_ROLE}" in
    ralph)
        strip_blocks "SCHOLAR" "MU" < "${SOUL_FILE}" | strip_markers "RALPH" > "${SOUL_FILE}.tmp"
        mv "${SOUL_FILE}.tmp" "${SOUL_FILE}"
        ;;
    scholar)
        strip_blocks "RALPH" "MU" < "${SOUL_FILE}" | strip_markers "SCHOLAR" > "${SOUL_FILE}.tmp"
        mv "${SOUL_FILE}.tmp" "${SOUL_FILE}"
        ;;
    mu)
        strip_blocks "RALPH" "SCHOLAR" < "${SOUL_FILE}" | strip_markers "MU" > "${SOUL_FILE}.tmp"
        mv "${SOUL_FILE}.tmp" "${SOUL_FILE}"
        ;;
    *)
        log "Warning: unknown AGENT_ROLE '${AGENT_ROLE}', defaulting to ralph"
        AGENT_ROLE="ralph"
        strip_blocks "SCHOLAR" "MU" < "${SOUL_FILE}" | strip_markers "RALPH" > "${SOUL_FILE}.tmp"
        mv "${SOUL_FILE}.tmp" "${SOUL_FILE}"
        ;;
esac
log "SOUL.md processed for role: ${AGENT_ROLE}"

# === 4c. Abstract issue decomposition — detect issues without file paths ===
if echo "${ISSUE_BODY}" | grep -qE '\.(zig|tri|json|toml|sh|md)|src/|tools/|deploy/|specs/' 2>/dev/null; then
    ISSUE_HAS_FILES=1
else
    ISSUE_HAS_FILES=0
fi
if [ "${ISSUE_HAS_FILES}" -eq 0 ]; then
    log "Abstract issue detected — injecting decomposition prompt"
    cat >> "${SOUL_FILE}" << 'DECOMP_EOF'

## Abstract Issue Protocol

This issue does not reference specific file paths. Before coding:
1. Search the codebase for relevant files using Grep/Glob
2. If the task is large (>3 files, >100 lines), create 2-3 concrete sub-issues first
3. Each sub-issue should reference specific file paths and describe exact changes
4. Then solve the first sub-issue in this container
DECOMP_EOF
fi


# === 4d. Cross-issue learning — inject lessons from past agents ===
EVENTS_FILE=".trinity/cloud_events.jsonl"
if [ -f "${EVENTS_FILE}" ]; then
    # Extract lessons (|| true guards against pipefail when grep finds no matches)
    LESSONS=$(grep '"type":"status"' "${EVENTS_FILE}" 2>/dev/null | grep -E '"DONE"|"FAILED"' 2>/dev/null | tail -10 | \
        while IFS= read -r line; do
            status=$(echo "$line" | grep -oP '"status":"[^"]*"' | cut -d'"' -f4 || true)
            detail=$(echo "$line" | grep -oP '"detail":"[^"]*"' | cut -d'"' -f4 | head -c 200 || true)
            issue=$(echo "$line" | grep -oP '"issue":[0-9]+' | cut -d: -f2 || true)
            echo "- Issue #${issue}: ${status} — ${detail}"
        done || true)
    if [ -n "${LESSONS}" ]; then
        cat >> "${SOUL_FILE}" << LESSONS_EOF

## Lessons from Previous Agents

These are outcomes from recent agent runs. Learn from their successes and failures:
${LESSONS}
LESSONS_EOF
        log "Injected $(echo "${LESSONS}" | wc -l | tr -d ' ') lessons from previous agents"
    fi
fi


# === 5. Create branch (delete stale branch from previous restart) ===
git branch -D "feat/issue-${ISSUE}" 2>/dev/null || true
git checkout -b "feat/issue-${ISSUE}"

# === 5b. Circuit breaker for z.ai ===
ZAI_BASE_URL="${ANTHROPIC_BASE_URL:-https://api.z.ai/api/anthropic}"
ZAI_BASE_URL="${ZAI_BASE_URL%/}"       # strip trailing slash
ZAI_BASE_URL="${ZAI_BASE_URL%/v1}"     # strip /v1 if present
ZAI_CIRCUIT_OK=0
ZAI_BACKOFF=30  # Exponential: 30s, 60s, 120s
for ZAI_ATTEMPT in 1 2 3; do
    if curl -s -X POST "${ZAI_BASE_URL}/v1/messages" \
        -H "x-api-key: ${ANTHROPIC_API_KEY}" \
        -H "anthropic-version: 2023-06-01" \
        -H "Content-Type: application/json" \
        -d '{"model":"'"${CLAUDE_MODEL:-glm-5}"'","max_tokens":1,"messages":[{"role":"user","content":"ping"}]}' \
        --connect-timeout 10 --max-time 30 2>/dev/null | grep -q '"content"'; then
        ZAI_CIRCUIT_OK=1
        log "z.ai circuit breaker: OK (attempt ${ZAI_ATTEMPT})"
        break
    fi
    log "z.ai circuit breaker: attempt ${ZAI_ATTEMPT}/3 failed, backoff ${ZAI_BACKOFF}s"
    echo "FAILED" > /tmp/zai_circuit.state
    report_status "FAILED" "z.ai attempt ${ZAI_ATTEMPT}/3, backoff ${ZAI_BACKOFF}s"
    [ "${ZAI_ATTEMPT}" -lt 3 ] && sleep "${ZAI_BACKOFF}"
    ZAI_BACKOFF=$((ZAI_BACKOFF * 2))
done
if [ "${ZAI_CIRCUIT_OK}" -eq 0 ]; then
    # Try fallback API keys before giving up
    for FALLBACK_KEY_VAR in ANTHROPIC_API_KEY_2 ANTHROPIC_API_KEY_3; do
        FALLBACK_KEY="${!FALLBACK_KEY_VAR}"
        [ -z "$FALLBACK_KEY" ] && continue
        log "Trying fallback: ${FALLBACK_KEY_VAR}..."
        if curl -s -X POST "${ZAI_BASE_URL}/v1/messages" \
            -H "x-api-key: ${FALLBACK_KEY}" \
            -H "anthropic-version: 2023-06-01" \
            -H "Content-Type: application/json" \
            -d '{"model":"'"${CLAUDE_MODEL:-glm-5}"'","max_tokens":1,"messages":[{"role":"user","content":"ping"}]}' \
            --connect-timeout 10 --max-time 30 2>/dev/null | grep -q '"content"'; then
            ANTHROPIC_API_KEY="$FALLBACK_KEY"
            export ANTHROPIC_API_KEY
            ZAI_CIRCUIT_OK=1
            log "Fallback OK: using ${FALLBACK_KEY_VAR}"
            emit_log "info" "Fallback API key active: ${FALLBACK_KEY_VAR}"
            break
        fi
        log "Fallback ${FALLBACK_KEY_VAR} also failed"
    done
fi

if [ "${ZAI_CIRCUIT_OK}" -eq 0 ]; then
    report_status "FAILED" "CIRCUIT BREAKER TRIPPED — all keys exhausted"
    emit_error "z.ai circuit breaker tripped (primary + fallbacks)" 5
    gh issue comment "${ISSUE}" --repo "${GH_REPO}" --body "$(printf '🛑 **CIRCUIT BREAKER TRIPPED**\nz.ai unreachable after 3 attempts (30s+60s+120s backoff).\nFallback keys also failed.\nAgent stopped. Manual respawn after API recovers.')" 2>/dev/null || true
    stop_heartbeat
    rm -f /tmp/agent-alive
    # Exit 0 prevents Railway auto-restart (exit 1 = respawn loop)
    exit 0
fi
echo "OK" > /tmp/zai_circuit.state

# === 6. Run Claude Code (P0.1 — with timeout) ===
report_status "CODING" "Claude Code running (timeout: ${AGENT_TIMEOUT}s)"

# === 6a. Build prompt — chain-role-aware (v5.0) ===
if [ -n "${CHAIN_ROLE}" ] && [ "${CHAIN_ROLE}" = "tester" ]; then
    # TESTER role: pure Zig, no LLM needed — skip Claude entirely
    log "Tester role: running zig build test directly (no Claude)"
    report_status "TESTING" "Tester role: zig build test (no LLM)"
    TESTER_EXIT=0
    if timeout 300 zig build test 2>&1 | tee /tmp/test_output.log; then
        TESTER_EXIT=0
        TESTS_PASSED=1
        TESTS_TOTAL=1
        git add -A 2>/dev/null || true
        git commit -m "test(#${ISSUE}): tester role — all tests pass" 2>/dev/null || true
    else
        TESTER_EXIT=1
        TESTS_PASSED=0
        TESTS_TOTAL=1
    fi
    emit_test_run "${TESTS_PASSED}" "${TESTS_TOTAL}" 0
    if [ "${TESTER_EXIT}" -eq 0 ]; then
        report_status "DONE" "Tests passed"
    else
        report_status "FAILED" "Tests failed"
        gh issue comment "${ISSUE}" --repo "${GH_REPO}" --body "$(printf '❌ **Tester Agent**: Tests failed\n```\n%s\n```' "$(tail -20 /tmp/test_output.log | redact_secrets)")" 2>/dev/null || true
    fi
    # Skip Claude Code entirely for tester
    CLAUDE_EXIT=${TESTER_EXIT}
    COMMIT_COUNT=$(git log --oneline main..HEAD 2>/dev/null | wc -l | tr -d ' ')
    # Jump to PR creation (skip Claude invocation below)
    SKIP_CLAUDE=1
elif [ -n "${CHAIN_ROLE}" ]; then
    # Role-specific prompt: focus on chain links for this role
    PROMPT="You are Trinity Agent (role: ${CHAIN_ROLE}) solving issue #${ISSUE}.
Your chain links: ${CHAIN_LINKS} (${CHAIN_DESC}).

Issue details:
${ISSUE_BODY}

Instructions for ${CHAIN_ROLE}:
1. Read CLAUDE.md for code style rules
2. Focus ONLY on your role's responsibilities:
   - planner: analyze, research, create .tri specs (links 0-6)
   - coder: generate code from specs, implement features (links 7-8)
   - reviewer: analyze code quality, compare to baseline (links 8-10)
   - integrator: generate reports, documentation, commit (links 14-19)
3. Run: zig fmt src/ && zig build
4. Commit with message: feat(scope): description (#${ISSUE})
5. STOP — do NOT push or create PR. The entrypoint handles that.

Comment on the issue at each major step."
    SKIP_CLAUDE=0
else
    # Default prompt (no chain role)
    PROMPT="You are Trinity Agent solving issue #${ISSUE}.

Issue details:
${ISSUE_BODY}

Instructions:
1. Read CLAUDE.md for code style rules
2. Implement the solution on branch feat/issue-${ISSUE}
3. Run: zig fmt src/ && zig build
4. Commit with message: feat(scope): description (#${ISSUE})
5. STOP — do NOT push or create PR. The entrypoint handles push + PR automatically.

Comment on the issue at each major step."
    SKIP_CLAUDE=0
fi

<<<<<<< HEAD
emit_event "status" "{\"status\":\"CODING\",\"detail\":\"Claude Code starting\"}"
CLAUDE_EXIT=0
CLAUDE_MODEL="${CLAUDE_MODEL:-glm-5}"
log "Using model: ${CLAUDE_MODEL}"

if [ "${SKIP_CLAUDE:-0}" -eq 1 ]; then
    log "Skipping Claude Code (tester role handled directly)"
else
timeout --kill-after=30 "${AGENT_TIMEOUT}" claude -p "${PROMPT}" --model "${CLAUDE_MODEL}" --allowedTools "Bash,Read,Write,Edit,Glob,Grep" 2>&1 | \
  while IFS= read -r line; do
    echo "$line"
    stream_to_telegram "$line"
    echo "{\"type\":\"log\",\"issue\":${ISSUE},\"line\":\"$(echo "$line" | sed 's/"/\\"/g' | head -c 500)\",\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> /tmp/agent_events.jsonl
    case "$line" in
      *"Read("*|*"cat "*) report_status "READING" "$line" ;;
      *"Write("*|*"Edit("*) report_status "CODING" "$(echo $line | head -c 100)" ;;
      *"Bash("*|*"zig build"*) report_status "TESTING" "$(echo $line | head -c 100)" ;;
      *"error"*|*"Error"*) report_status "ERROR" "$(echo $line | head -c 200)" ;;
    esac
  done || CLAUDE_EXIT=$?
flush_telegram
=======
emit_event "status" '{"status":"CODING","detail":"Claude Code starting"}'
CLAUDE_LOG="/tmp/claude_output_${ISSUE}.log"
timeout "${AGENT_TIMEOUT}" claude -p "${PROMPT}" --allowedTools "Bash,Read,Write,Edit,Glob,Grep" 2>&1 | \
    tee "${CLAUDE_LOG}" | \
    while IFS= read -r line; do
        stream_to_telegram "${line}"
    done
CLAUDE_EXIT=${PIPESTATUS[0]:-$?}
>>>>>>> feat/issue-137
emit_event "command" "{\"cmd\":\"claude\",\"exit_code\":${CLAUDE_EXIT},\"timeout\":${AGENT_TIMEOUT}}"
fi  # end SKIP_CLAUDE else block

if [ "${CLAUDE_EXIT}" -eq 124 ]; then
    report_status "STUCK" "Timeout after ${AGENT_TIMEOUT}s"
    gh issue comment "${ISSUE}" --repo "${GH_REPO}" --body "⏰ **Trinity Agent**: Timed out after ${AGENT_TIMEOUT}s. Manual intervention needed." 2>/dev/null || true
elif [ "${CLAUDE_EXIT}" -ne 0 ]; then
    report_status "ERROR" "Claude Code exited with code ${CLAUDE_EXIT}"
fi

<<<<<<< HEAD
# === 6b. Self-review (advisory only — never blocks push) ===
report_status "REVIEWING" "Self-review (advisory)"
stream_to_telegram "Running self-review..."
REVIEW_WARNINGS=0
=======
# === 6b. Run tests and capture results ===
report_status "TESTING" "Running zig build test"
TEST_LOG="/tmp/test_output_${ISSUE}.log"
zig build test 2>&1 | tee "${TEST_LOG}" | \
    while IFS= read -r line; do
        stream_to_telegram "${line}"
    done
TEST_EXIT=${PIPESTATUS[0]:-$?}
TEST_OUTPUT=$(cat "${TEST_LOG}")
TESTS_PASSED=$(echo "${TEST_OUTPUT}" | grep -c "OK" || echo "0")
TESTS_TOTAL=$(echo "${TEST_OUTPUT}" | grep -cE "OK|FAIL" || echo "0")
if [ "${TEST_EXIT}" -ne 0 ]; then
    TEST_RESULT="FAIL (exit ${TEST_EXIT})"
    emit_event "test" "{\"exit_code\":${TEST_EXIT},\"passed\":${TESTS_PASSED},\"total\":${TESTS_TOTAL}}"
else
    TEST_RESULT="PASS (${TESTS_PASSED}/${TESTS_TOTAL})"
    emit_event "test" "{\"exit_code\":0,\"passed\":${TESTS_PASSED},\"total\":${TESTS_TOTAL}}"
fi
>>>>>>> feat/issue-137

# 7a. Format check — auto-fix silently
stream_to_telegram "Checking zig fmt format..."
if ! zig fmt --check src/ 2>/dev/null; then
    stream_to_telegram "Running zig fmt to fix formatting..."
    zig fmt src/ 2>/dev/null || true
    git add -A
    git commit -m "style: zig fmt (#${ISSUE})" 2>/dev/null || true
    stream_to_telegram "Formatting fixed and committed."
else
    stream_to_telegram "Format check passed."
fi

# 7b. Generated files check (only real blocker)
stream_to_telegram "Checking for generated files..."
if git diff --name-only main..HEAD 2>/dev/null | grep -qE 'var/trinity/output/|generated/'; then
    emit_error "Modified generated files" 1
    REVIEW_WARNINGS=$((REVIEW_WARNINGS + 1))
    stream_to_telegram "Warning: Generated files modified."
fi

# 7c. Diff size warning (advisory)
stream_to_telegram "Checking diff size..."
DIFF_LINES=$(git diff --stat main..HEAD 2>/dev/null | tail -1 | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
if [ "${DIFF_LINES:-0}" -gt 500 ]; then
    emit_error "Diff large: ${DIFF_LINES} lines" 2
    REVIEW_WARNINGS=$((REVIEW_WARNINGS + 1))
    stream_to_telegram "Warning: Large diff (${DIFF_LINES} lines)."
else
    stream_to_telegram "Diff size OK: ${DIFF_LINES} lines."
fi

# 7d. Compilation gate with self-repair loop (P0.3) — broken code gets 3 repair attempts
stream_to_telegram "Running compilation gate..."
BUILD_PASSED=0
for REPAIR in 1 2 3; do
    if timeout 300 zig build -Dci=true 2>/tmp/zig_build_err.log; then
        BUILD_PASSED=1
        stream_to_telegram "Compilation gate PASSED (attempt ${REPAIR})."
        emit_log "info" "Compilation gate passed (attempt ${REPAIR})"
        break
    fi
    BUILD_ERR=$(cat /tmp/zig_build_err.log 2>/dev/null | tail -20 | head -c 1000)
    if [ "${REPAIR}" -lt 3 ]; then
        emit_event "status" '{"status":"REPAIRING","detail":"attempt '"${REPAIR}"'/3"}'
        report_status "REPAIRING" "Compilation failed, auto-repair attempt ${REPAIR}/3"
        stream_to_telegram "Compilation failed, attempting auto-repair (${REPAIR}/3)..."
        timeout 120 claude -p "Fix this compilation error. Only fix the build error, do not change anything else:\n\n${BUILD_ERR}" \
            --model "${CLAUDE_MODEL}" --allowedTools "Read,Edit,Write" 2>&1 | \
            while IFS= read -r line; do echo "$line"; stream_to_telegram "$line"; done || true
    fi
done

if [ "${BUILD_PASSED}" -eq 1 ]; then
    # 7e. Test gate — run synchronously before PR creation (P0 fix: was background, tests never blocked PR)
    stream_to_telegram "Running test gate..."
    TEST_START=$(date +%s)
    if timeout 120 zig build test 2>&1 | tail -20 > /tmp/zig_test_out.log; then
        TEST_GATE_RESULT="PASSED"
    else
        TEST_GATE_RESULT="FAILED"
    fi
    TEST_GATE_DUR=$(( $(date +%s) - TEST_START ))
else
    emit_error "Compilation gate FAILED after 3 repair attempts" 4
    report_status "FAILED" "Compilation gate failed after 3 repair attempts — skipping PR"
    gh issue comment "${ISSUE}" --repo "${GH_REPO}" --body "❌ **Trinity Agent**: Compilation gate FAILED after 3 repair attempts. Code does not build.

\`\`\`
${BUILD_ERR}
\`\`\`

PR creation skipped. Issue needs manual attention." 2>/dev/null || true
    # Close any PR that Claude Code may have created during CODING phase
    STALE_PR=$(gh pr list --repo "${GH_REPO}" --head "feat/issue-${ISSUE}" --json number --jq '.[0].number' 2>/dev/null || echo "")
    if [ -n "${STALE_PR}" ]; then
        gh pr close "${STALE_PR}" --repo "${GH_REPO}" --comment "🚫 Closed by compilation gate — code does not build after 3 repair attempts." 2>/dev/null || true
        update_telegram_dashboard "🚫 <b>#${ISSUE}</b> Closed PR #${STALE_PR} — compilation gate failed"
    else
        update_telegram_dashboard "❌ <b>#${ISSUE}</b> Compilation FAILED — PR skipped"
    fi
    stop_heartbeat
    rm -f /tmp/agent-alive
    sleep 10
    exit 1
fi

# Process test results (synchronous)
if [ "${TEST_GATE_RESULT}" = "PASSED" ]; then
    stream_to_telegram "Test gate PASSED (${TEST_GATE_DUR}s)."
    emit_log "info" "Test gate passed"
    emit_test_run 1 1 "${TEST_GATE_DUR}"
else
    TEST_OUTPUT=$(cat /tmp/zig_test_out.log 2>/dev/null | head -c 1000)
    emit_error "Test gate failed" 3
    emit_test_run 0 1 "${TEST_GATE_DUR}"
    REVIEW_WARNINGS=$((REVIEW_WARNINGS + 1))
    stream_to_telegram "Warning: Tests failed."
    TEST_GATE_FAILED=1
    TEST_GATE_OUTPUT="${TEST_OUTPUT}"
fi

if [ $REVIEW_WARNINGS -gt 0 ]; then
    stream_to_telegram "Self-review: ${REVIEW_WARNINGS} warning(s) (advisory, not blocking)."
    log "Self-review: ${REVIEW_WARNINGS} warning(s) (advisory, not blocking)"
else
    stream_to_telegram "Self-review: All checks passed."
fi

# === 8. Push and create PR if not already done ===
report_status "TESTING" "Checking/creating PR"
stream_to_telegram "Checking for existing PR..."
EXISTING_PR=$(gh pr list --repo "${GH_REPO}" --head "feat/issue-${ISSUE}" --json number --jq '.[0].number' 2>/dev/null || echo "")

if [ -z "${EXISTING_PR}" ]; then
    # Check if there are actually commits to push
    COMMIT_COUNT=$(git log --oneline main..HEAD 2>/dev/null | wc -l | tr -d ' ')
    stream_to_telegram "Commit count: ${COMMIT_COUNT}"
    if [ "${COMMIT_COUNT}" -gt 0 ]; then
        log "Pushing ${COMMIT_COUNT} commit(s)..."
        stream_to_telegram "Pushing ${COMMIT_COUNT} commit(s) to origin..."
        PUSH_OK=0
        retry git push -u origin "feat/issue-${ISSUE}" && PUSH_OK=1 || true
        stream_to_telegram "Push completed."

        if [ "${PUSH_OK}" -eq 0 ]; then
            log "Push failed after 3 retries — cannot create PR"
            report_status "FAILED" "Push failed after 3 retries"
            update_telegram_dashboard "❌ <b>#${ISSUE}</b> Push failed after 3 retries — code ready but cannot push"
            # Still try to report what happened
            gh issue comment "${ISSUE}" --repo "${GH_REPO}" --body "❌ **Trinity Agent**: Code committed locally but push to origin failed 3 times. Branch: feat/issue-${ISSUE}" 2>/dev/null || true
        fi

        if [ "${PUSH_OK}" -eq 1 ]; then
        log "Creating PR..."
        stream_to_telegram "Creating pull request..."
        # Build PR body with optional test warning
        PR_BODY="Closes #${ISSUE}

Automated by Trinity Cloud Agent.
Commits: ${COMMIT_COUNT}"
        if [ "${TEST_GATE_FAILED:-0}" -eq 1 ]; then
            PR_BODY="${PR_BODY}

⚠️ **Test gate warning**: Tests failed during self-review (advisory).
\`\`\`
${TEST_GATE_OUTPUT:-no output captured}
\`\`\`"
        fi

        PR_URL=$(gh pr create --repo "${GH_REPO}" \
            --title "feat: solve issue #${ISSUE}" \
            --body "${PR_BODY}" \
            --head "feat/issue-${ISSUE}" 2>&1) || {
            log "PR creation failed: ${PR_URL}"
            emit_error "PR creation failed" 6
            PR_URL=""
        }

        # Add warning label if tests failed
        if [ "${TEST_GATE_FAILED:-0}" -eq 1 ] && [ -n "${PR_URL}" ]; then
            PR_NUM=$(echo "${PR_URL}" | grep -oE '[0-9]+$')
            gh pr edit "${PR_NUM}" --repo "${GH_REPO}" --add-label "tests-failing" 2>/dev/null || true
        fi

        if [ -n "${PR_URL}" ]; then
<<<<<<< HEAD
            stream_to_telegram "PR created: ${PR_URL}"
            emit_event "pr" "{\"url\":\"${PR_URL}\",\"commits\":${COMMIT_COUNT}}"
=======
            emit_pr "${PR_URL}" "${COMMIT_COUNT}"
>>>>>>> feat/issue-126
            report_status "PR_CREATED" "PR: ${PR_URL}"
            # Send metrics to monitor
            report_metrics
            # Post final summary comment
            DIFF_STAT=$(git diff --stat main..HEAD 2>/dev/null | redact_secrets || echo "N/A")
            FINAL_ELAPSED=$(( $(date +%s) - START_TIME ))
            stream_to_telegram "Posting final summary..."
            gh issue comment "${ISSUE}" --repo "${GH_REPO}" --body "🚀 **Trinity Agent — Summary**

| Field | Value |
|-------|-------|
| **PR** | ${PR_URL} |
| **Commits** | ${COMMIT_COUNT} |
| **Tests** | ${TEST_GATE_RESULT:-N/A} |
| **Duration** | ${FINAL_ELAPSED}s |

\`\`\`
${DIFF_STAT}
\`\`\`" 2>/dev/null || true
            stream_to_telegram "Summary posted."

            # Cleanup worktree after PR creation (keeps shared bare repo intact)
            log "Cleaning up worktree..."
            stream_to_telegram "Cleaning up worktree..."
            cd /bare-repo.git
            git worktree remove "${WORKTREE_PATH}" --force 2>/dev/null || true
            log "Worktree removed: ${WORKTREE_PATH}"
            stream_to_telegram "Worktree removed."
        else
            stream_to_telegram "Failed to create PR."
        fi
        fi
    else
        stream_to_telegram "No commits produced — agent could not solve issue."
        report_status "FAILED" "No commits produced — agent could not solve issue"
        gh issue comment "${ISSUE}" --repo "${GH_REPO}" --body "❌ **Trinity Agent**: No solution produced. Issue may need manual attention." 2>/dev/null || true
    fi
else
    # Claude Code already created and pushed a PR — count commits on the branch
    COMMIT_COUNT=$(git log --oneline main..HEAD 2>/dev/null | wc -l | tr -d ' ')
    stream_to_telegram "PR already exists: #${EXISTING_PR} (${COMMIT_COUNT} commits on branch)"
    report_status "PR_CREATED" "PR #${EXISTING_PR} already exists"
fi

# === 8. Report final status ===
if [ "${CLAUDE_EXIT}" -eq 0 ] && [ "${COMMIT_COUNT:-0}" -gt 0 ]; then
    report_status "DONE" "PR created with ${COMMIT_COUNT} commits"
    update_telegram_dashboard "✅ <b>#${ISSUE}</b> DONE — ${COMMIT_COUNT} commits, PR created"
elif [ "${CLAUDE_EXIT}" -eq 0 ] && [ -n "${EXISTING_PR}" ]; then
    report_status "DONE" "PR #${EXISTING_PR} created by Claude Code"
    update_telegram_dashboard "✅ <b>#${ISSUE}</b> DONE — PR #${EXISTING_PR} created"
elif [ "${CLAUDE_EXIT}" -eq 124 ]; then
    : # already reported STUCK
else
    report_status "FAILED" "Exit code: ${CLAUDE_EXIT}, Commits: ${COMMIT_COUNT:-0}"
fi

# === 9. Stay alive briefly for debugging, then exit ===
stop_heartbeat
log "Staying alive for 10 seconds..."
sleep 10
rm -f /tmp/agent-alive
log "Self-destructing."
