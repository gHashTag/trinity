#!/bin/bash
# Trinity Cloud Agent Entrypoint
# Solves a single GitHub issue using Claude Code
# Required env: ISSUE_NUMBER, GITHUB_TOKEN, ANTHROPIC_API_KEY
#
# P0 hardened: timeout, SIGTERM handler, heartbeat loop, retry wrapper

set -eo pipefail

REPO_URL="${REPO_URL:-https://github.com/gHashTag/trinity.git}"
# Extract owner/repo for gh --repo flag (bare-repo worktrees lack git remote context)
GH_REPO=$(echo "${REPO_URL}" | sed 's|.*github.com[:/]||; s|\.git$||')
ISSUE="${ISSUE_NUMBER:?ISSUE_NUMBER is required}"
AGENT_TIMEOUT="${AGENT_TIMEOUT:-3600}"  # 1 hour default
HEARTBEAT_INTERVAL="${HEARTBEAT_INTERVAL:-30}"
CURRENT_STATUS="STARTING"
CURRENT_DETAIL="Initializing"
HEARTBEAT_PID=""

log() { echo "[agent-${ISSUE}] $1"; }

# ═══════════════════════════════════════════════════════════════════════════════
# STATUS REPORTING
# ═══════════════════════════════════════════════════════════════════════════════

LAST_STATUS=""
DASHBOARD_COMMENT_ID=""
START_TIME=$(date +%s)
STEP_NUM=0
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

    # 1. HTTP POST to monitor
    if [ -n "${WS_MONITOR_URL}" ]; then
        curl -s -X POST "${WS_MONITOR_URL}/api/status" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${MONITOR_TOKEN:-trinity}" \
            -d "{\"issue\":${ISSUE},\"status\":\"${CURRENT_STATUS}\",\"detail\":\"${CURRENT_DETAIL}\"}" \
            --connect-timeout 5 --max-time 10 \
            2>/dev/null || log "Warning: monitor unreachable"
    fi

    # 2. Telegram notification on status change (BEFORE updating LAST_STATUS)
    if [ "${CURRENT_STATUS}" != "${LAST_STATUS}" ] || echo "${CURRENT_STATUS}" | grep -qE "STUCK|ERROR|FAILED|KILLED|DONE"; then
        send_telegram "${EMOJI} <b>Agent #${ISSUE}</b>: ${CURRENT_STATUS}
<i>${ISSUE_TITLE:-issue #${ISSUE}}</i>
${CURRENT_DETAIL} (${ELAPSED}s)"
    fi

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

    # 5. Telegram live dashboard (edit-in-place, not new messages)
    TG_DASH="${EMOJI} <b>Agent #${ISSUE}</b> — ${CURRENT_STATUS}
<i>${ISSUE_TITLE:-issue #${ISSUE}}</i>
Step ${STEP_NUM}/${TOTAL_STEPS}: ${CURRENT_DETAIL}
Elapsed: ${ELAPSED}s"
    update_telegram_dashboard "${TG_DASH}"
}

escape_html() {
    echo "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

TG_DASHBOARD_MSG_ID=""

send_telegram() {
    if [ -n "${TELEGRAM_BOT_TOKEN}" ] && [ -n "${TELEGRAM_CHAT_ID}" ]; then
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
TELEGRAM_STREAM="${TELEGRAM_STREAM:-true}"
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
    local event="{\"type\":\"${type}\",\"issue\":${ISSUE},\"payload\":${payload},\"ts\":\"${ts}\"}"

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
                        -d "{\"issue\":${ISSUE},\"status\":\"${HB_STATUS}\",\"detail\":\"heartbeat: ${HB_DETAIL} (${ELAPSED}s)\"}" \
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
    local cmd="$@"

    while [ $attempt -le $max_attempts ]; do
        if eval "$cmd"; then
            return 0
        fi
        log "Attempt ${attempt}/${max_attempts} failed: ${cmd}"
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

# Load Ralph fallback config (z.ai / GLM-5) if available
if [ -f /etc/trinity/.ralphrc ]; then
    . /etc/trinity/.ralphrc
    log "Loaded .ralphrc — fallback: ${FALLBACK_MODEL:-none}"
fi

# Start heartbeat
start_heartbeat

# === 1. Auth ===
report_status "AWAKENING" "Authenticating with GitHub"
log "GITHUB_TOKEN length: ${#GITHUB_TOKEN}"
log "GITHUB_TOKEN prefix: $(echo "${GITHUB_TOKEN}" | head -c 20)..."

# gh auth login reads token from stdin; log stderr for diagnostics
AUTH_ERR=$(printf '%s\n' "${GITHUB_TOKEN}" | gh auth login --with-token 2>&1) || true
AUTH_EXIT=$?
log "gh auth login exit: ${AUTH_EXIT}, output: ${AUTH_ERR}"

if [ "${AUTH_EXIT}" -ne 0 ]; then
    # Retry once more with explicit host
    AUTH_ERR2=$(printf '%s\n' "${GITHUB_TOKEN}" | gh auth login --with-token --hostname github.com 2>&1) || true
    AUTH_EXIT=$?
    log "gh auth login retry exit: ${AUTH_EXIT}, output: ${AUTH_ERR2}"
fi

if [ "${AUTH_EXIT}" -ne 0 ]; then
    report_status "FAILED" "GitHub auth failed: ${AUTH_ERR}"
    send_telegram "❌ Agent #${ISSUE}: GitHub auth failed — ${AUTH_ERR}"
    stop_heartbeat
    rm -f /tmp/agent-alive
    exit 1
fi

# Verify auth worked
GH_STATUS=$(gh auth status 2>&1) || true
log "gh auth status: ${GH_STATUS}"
git config --global user.name "Trinity Agent"
git config --global user.email "trinity-agent@users.noreply.github.com"

# Configure git to use gh as credential helper (fixes push auth)
gh auth setup-git 2>/dev/null || true
log "gh auth setup-git done — git push will use GITHUB_TOKEN"

# === 2. Setup worktree from shared bare repo ===
report_status "AWAKENING" "Creating worktree from bare repository"

# Check if bare repo needs to be created or updated
if [ ! -d /bare-repo.git/objects ]; then
    log "Bare repo not found, creating from remote..."
    if ! retry "git clone --bare --depth=50 '${REPO_URL}' /bare-repo.git 2>/dev/null"; then
        report_status "FAILED" "Git bare clone failed after 3 attempts"
        stop_heartbeat
        rm -f /tmp/agent-alive
        exit 1
    fi
else
    log "Updating bare repo from remote..."
    cd /bare-repo.git
    retry "git fetch origin main --depth=50 2>/dev/null" || log "Warning: bare repo update failed"
    # Update local main ref to match remote (bare repo has stale pre-baked main)
    git update-ref refs/heads/main origin/main 2>/dev/null || log "Warning: could not update main ref"
fi

# Create worktree for this agent (fast! ~5-10s vs ~60s for full clone)
WORKTREE_PATH="/workspace/trinity-${ISSUE}"
if [ -d "${WORKTREE_PATH}" ]; then
    log "Removing existing worktree..."
    rm -rf "${WORKTREE_PATH}"
fi

cd /bare-repo.git
if ! retry "git worktree add -b 'agent-${ISSUE}' '${WORKTREE_PATH}' main 2>/dev/null"; then
    report_status "FAILED" "Git worktree add failed after 3 attempts"
    stop_heartbeat
    rm -f /tmp/agent-alive
    exit 1
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
send_telegram "📖 <b>Agent #${ISSUE}</b> читает задачу:
<i>${ISSUE_TITLE}</i>"

# === 5. Create branch ===
git checkout -b "feat/issue-${ISSUE}"

# === 6. Run Claude Code (P0.1 — with timeout) ===
report_status "CODING" "Claude Code running (timeout: ${AGENT_TIMEOUT}s)"

PROMPT="You are Trinity Agent solving issue #${ISSUE}.

Issue details:
${ISSUE_BODY}

Instructions:
1. Read CLAUDE.md for code style rules
2. Implement the solution on branch feat/issue-${ISSUE}
3. Run: zig fmt src/ && zig build
4. Commit with message: feat(scope): description (#${ISSUE})
5. Push the branch
6. Create a PR with 'Closes #${ISSUE}' in the body

Comment on the issue at each major step."

emit_event "status" "{\"status\":\"CODING\",\"detail\":\"Claude Code starting\"}"
CLAUDE_EXIT=0
CLAUDE_MODEL="${CLAUDE_MODEL:-glm-5}"
log "Using model: ${CLAUDE_MODEL}"
timeout "${AGENT_TIMEOUT}" claude -p "${PROMPT}" --model "${CLAUDE_MODEL}" --allowedTools "Bash,Read,Write,Edit,Glob,Grep" 2>&1 | \
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
emit_event "command" "{\"cmd\":\"claude\",\"exit_code\":${CLAUDE_EXIT},\"timeout\":${AGENT_TIMEOUT}}"

if [ "${CLAUDE_EXIT}" -eq 124 ]; then
    report_status "STUCK" "Timeout after ${AGENT_TIMEOUT}s"
    gh issue comment "${ISSUE}" --repo "${GH_REPO}" --body "⏰ **Trinity Agent**: Timed out after ${AGENT_TIMEOUT}s. Manual intervention needed." 2>/dev/null || true
elif [ "${CLAUDE_EXIT}" -ne 0 ]; then
    report_status "ERROR" "Claude Code exited with code ${CLAUDE_EXIT}"
fi

# === 6b. Self-review (advisory only — never blocks push) ===
report_status "REVIEWING" "Self-review (advisory)"
stream_to_telegram "Running self-review..."
REVIEW_WARNINGS=0

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
if git diff --name-only main..HEAD 2>/dev/null | grep -qE 'trinity/output/|generated/'; then
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

# NOTE: zig build skipped — too heavy for Railway containers, always fails
# Tests run by CI after PR is created
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
        retry "git push -u origin 'feat/issue-${ISSUE}'" && PUSH_OK=1 || true
        stream_to_telegram "Push completed."

        if [ "${PUSH_OK}" -eq 0 ]; then
            log "Push failed after 3 retries — cannot create PR"
            report_status "FAILED" "Push failed after 3 retries"
            send_telegram "❌ Agent #${ISSUE}: Push failed after 3 retries — code ready but cannot push"
            # Still try to report what happened
            gh issue comment "${ISSUE}" --repo "${GH_REPO}" --body "❌ **Trinity Agent**: Code committed locally but push to origin failed 3 times. Branch: feat/issue-${ISSUE}" 2>/dev/null || true
        fi

        if [ "${PUSH_OK}" -eq 1 ]; then
        log "Creating PR..."
        stream_to_telegram "Creating pull request..."
        PR_URL=$(gh pr create --repo "${GH_REPO}" \
            --title "feat: solve issue #${ISSUE}" \
            --body "Closes #${ISSUE}

Automated by Trinity Cloud Agent.
Commits: ${COMMIT_COUNT}" \
            --head "feat/issue-${ISSUE}" 2>/dev/null || true)

        if [ -n "${PR_URL}" ]; then
            stream_to_telegram "PR created: ${PR_URL}"
            emit_event "pr" "{\"url\":\"${PR_URL}\",\"commits\":${COMMIT_COUNT}}"
            report_status "PR_CREATED" "PR: ${PR_URL}"
            # Send metrics to monitor
            report_metrics
            # Post final summary comment
            DIFF_STAT=$(git diff --stat main..HEAD 2>/dev/null || echo "N/A")
            FINAL_ELAPSED=$(( $(date +%s) - START_TIME ))
            stream_to_telegram "Posting final summary..."
            gh issue comment "${ISSUE}" --repo "${GH_REPO}" --body "🚀 **Trinity Agent — Summary**

| Field | Value |
|-------|-------|
| **PR** | ${PR_URL} |
| **Commits** | ${COMMIT_COUNT} |
| **Tests** | ${TEST_RESULT:-N/A} |
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
    send_telegram "✅ Agent #${ISSUE}: DONE — ${COMMIT_COUNT} commits, PR created"
elif [ "${CLAUDE_EXIT}" -eq 0 ] && [ -n "${EXISTING_PR}" ]; then
    report_status "DONE" "PR #${EXISTING_PR} created by Claude Code"
    send_telegram "✅ Agent #${ISSUE}: DONE — PR #${EXISTING_PR} created"
elif [ "${CLAUDE_EXIT}" -eq 124 ]; then
    : # already reported STUCK
else
    report_status "FAILED" "Exit code: ${CLAUDE_EXIT}, Commits: ${COMMIT_COUNT:-0}"
fi

# === 9. Stay alive briefly for debugging, then exit ===
stop_heartbeat
log "Staying alive for 5 minutes..."
sleep 300
rm -f /tmp/agent-alive
log "Self-destructing."
