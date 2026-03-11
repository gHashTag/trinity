#!/bin/bash
# Trinity Cloud Agent Entrypoint
# Solves a single GitHub issue using Claude Code
# Required env: ISSUE_NUMBER, GITHUB_TOKEN, ANTHROPIC_API_KEY
#
# P0 hardened: timeout, SIGTERM handler, heartbeat loop, retry wrapper

set -e
set -o pipefail

REPO_URL="${REPO_URL:-https://github.com/gHashTag/trinity.git}"
ISSUE="${ISSUE_NUMBER:?ISSUE_NUMBER is required}"
AGENT_TIMEOUT="${AGENT_TIMEOUT:-3600}"  # 1 hour default
HEARTBEAT_INTERVAL="${HEARTBEAT_INTERVAL:-30}"
CURRENT_STATUS="STARTING"
CURRENT_DETAIL="Initializing"
HEARTBEAT_PID=""
LAST_TELEGRAM_SEND=0

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

    # 1. HTTP POST to monitor (existing)
    if [ -n "${WS_MONITOR_URL}" ]; then
        curl -s -X POST "${WS_MONITOR_URL}/api/status" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${MONITOR_TOKEN:-trinity}" \
            -d "{\"issue\":${ISSUE},\"status\":\"${CURRENT_STATUS}\",\"detail\":\"${CURRENT_DETAIL}\"}" \
            --connect-timeout 5 --max-time 10 \
            2>/dev/null || log "Warning: monitor unreachable"
    fi

    # 2. GitHub issue comment on status change (skip duplicates)
    if [ "${CURRENT_STATUS}" != "${LAST_STATUS}" ]; then
        gh issue comment "${ISSUE}" --body "${EMOJI} **Trinity Agent** | ${TIMESTAMP}
📋 **Step**: ${STEP_NUM}/${TOTAL_STEPS} — ${CURRENT_DETAIL}
🔄 **Status**: ${CURRENT_STATUS}
⏱️ **Elapsed**: ${ELAPSED}s" 2>/dev/null || log "Warning: GitHub comment failed"
    fi
    LAST_STATUS="${CURRENT_STATUS}"

    # 3. Dashboard comment (create or update)
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
        DASHBOARD_COMMENT_ID=$(gh issue comment "${ISSUE}" --body "${DASHBOARD_BODY}" 2>/dev/null | grep -o '/[0-9]*$' | tr -d '/' || true)
        # Fallback: fetch last comment ID
        if [ -z "${DASHBOARD_COMMENT_ID}" ]; then
            DASHBOARD_COMMENT_ID=$(gh api "repos/{owner}/{repo}/issues/${ISSUE}/comments" --jq '.[-1].id' 2>/dev/null || true)
        fi
    elif [ -n "${DASHBOARD_COMMENT_ID}" ]; then
        gh api "repos/{owner}/{repo}/issues/comments/${DASHBOARD_COMMENT_ID}" \
            -X PATCH -f body="${DASHBOARD_BODY}" 2>/dev/null || log "Warning: Dashboard update failed"
    fi

    # 4. Telegram notification on status change
    if [ "${CURRENT_STATUS}" != "${LAST_STATUS}" ] || echo "${CURRENT_STATUS}" | grep -qE "STUCK|ERROR|FAILED|KILLED|DONE"; then
        send_telegram "${EMOJI} Agent #${ISSUE}: ${CURRENT_STATUS} — ${CURRENT_DETAIL} (${ELAPSED}s)"
    fi
}

send_telegram() {
    if [ -n "${TELEGRAM_BOT_TOKEN}" ] && [ -n "${TELEGRAM_CHAT_ID}" ]; then
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
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# EVENT STREAM (OpenHands-style structured events)
# ═══════════════════════════════════════════════════════════════════════════════

report_metrics() {
    FILES_CHANGED=$(git diff --stat main..HEAD 2>/dev/null | grep -c '|' || echo "0")
    LINES_ADDED=$(git diff --stat main..HEAD 2>/dev/null | tail -1 | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
    COMMITS_COUNT=$(git log --oneline main..HEAD 2>/dev/null | wc -l | tr -d ' ')
    if [ -n "${WS_MONITOR_URL}" ]; then
        curl -s -X POST "${WS_MONITOR_URL}/api/status" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${MONITOR_TOKEN:-trinity}" \
            -d "{\"issue\":${ISSUE},\"status\":\"${CURRENT_STATUS}\",\"detail\":\"${CURRENT_DETAIL}\",\"metrics\":{\"tests_passed\":${TESTS_PASSED:-0},\"tests_total\":${TESTS_TOTAL:-0},\"files_changed\":${FILES_CHANGED},\"lines_added\":${LINES_ADDED},\"commits\":${COMMITS_COUNT}}}" \
            --connect-timeout 5 --max-time 10 \
            2>/dev/null || log "Warning: metrics POST failed"
    fi
}

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

# ═══════════════════════════════════════════════════════════════════════════════
# HEARTBEAT LOOP (P0.6) — background process sends status every 30s
# ═══════════════════════════════════════════════════════════════════════════════

start_heartbeat() {
    (
        while true; do
            sleep "${HEARTBEAT_INTERVAL}"
            report_status "${CURRENT_STATUS}" "${CURRENT_DETAIL}"
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

# === 2. Clone (with retry) ===
report_status "AWAKENING" "Cloning repository"
if ! retry "gh repo clone '${REPO_URL}' /workspace/trinity -- --depth=50 2>/dev/null"; then
    report_status "FAILED" "Git clone failed after 3 attempts"
    stop_heartbeat
    rm -f /tmp/agent-alive
    exit 1
fi
cd /workspace/trinity

# === 3. Prepare SOUL.md ===
log "Injecting soul..."
sed "s/{ISSUE_NUMBER}/${ISSUE}/g" /etc/trinity/SOUL.md > /workspace/trinity/CLAUDE.md.agent

# === 4. Read issue ===
report_status "READING" "Reading issue #${ISSUE}"
ISSUE_BODY=$(gh issue view "${ISSUE}" --json title,body,labels --jq '.' 2>/dev/null || echo '{"title":"Unknown","body":"Failed to fetch issue"}')

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

emit_event "status" '{"status":"CODING","detail":"Claude Code starting"}'
CLAUDE_LOG="/tmp/claude_output_${ISSUE}.log"
timeout "${AGENT_TIMEOUT}" claude -p "${PROMPT}" --allowedTools "Bash,Read,Write,Edit,Glob,Grep" 2>&1 | \
    tee "${CLAUDE_LOG}" | \
    while IFS= read -r line; do
        stream_to_telegram "${line}"
    done
CLAUDE_EXIT=${PIPESTATUS[0]:-$?}
emit_event "command" "{\"cmd\":\"claude\",\"exit_code\":${CLAUDE_EXIT},\"timeout\":${AGENT_TIMEOUT}}"

if [ "${CLAUDE_EXIT}" -eq 124 ]; then
    report_status "STUCK" "Timeout after ${AGENT_TIMEOUT}s"
    gh issue comment "${ISSUE}" --body "⏰ **Trinity Agent**: Timed out after ${AGENT_TIMEOUT}s. Manual intervention needed." 2>/dev/null || true
elif [ "${CLAUDE_EXIT}" -ne 0 ]; then
    report_status "ERROR" "Claude Code exited with code ${CLAUDE_EXIT}"
fi

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

# === 7. Self-review (Sweep.dev pattern) ===
report_status "REVIEWING" "Self-review before PR"
REVIEW_ERRORS=0

# 7a. Zig build check
if ! zig build 2>/dev/null; then
    emit_event "command" '{"cmd":"zig build","exit_code":1}'
    report_status "ERROR" "zig build failed"
    REVIEW_ERRORS=$((REVIEW_ERRORS + 1))
else
    emit_event "command" '{"cmd":"zig build","exit_code":0}'
fi

# 7b. Format check — auto-fix
if ! zig fmt --check src/ 2>/dev/null; then
    zig fmt src/ 2>/dev/null || true
    git add -A
    git commit -m "style: zig fmt (#${ISSUE})" 2>/dev/null || true
    emit_event "command" '{"cmd":"zig fmt","exit_code":0,"auto_fixed":true}'
fi

# 7c. Diff size check — warn on >500 lines
DIFF_LINES=$(git diff --stat main..HEAD 2>/dev/null | tail -1 | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
if [ "${DIFF_LINES:-0}" -gt 500 ]; then
    emit_event "error" "{\"msg\":\"Diff too large: ${DIFF_LINES} lines\"}"
    report_status "STUCK" "Diff too large: ${DIFF_LINES} lines"
    REVIEW_ERRORS=$((REVIEW_ERRORS + 1))
fi

# 7d. Generated files check
if git diff --name-only main..HEAD 2>/dev/null | grep -qE 'trinity/output/|generated/'; then
    emit_event "error" '{"msg":"Modified generated files"}'
    report_status "ERROR" "Modified generated files!"
    REVIEW_ERRORS=$((REVIEW_ERRORS + 1))
fi

if [ $REVIEW_ERRORS -gt 0 ]; then
    report_status "STUCK" "${REVIEW_ERRORS} self-review error(s) — needs human help"
    gh issue comment "${ISSUE}" --body "⚠️ **Trinity Agent**: Self-review found ${REVIEW_ERRORS} error(s). Needs manual intervention." 2>/dev/null || true
fi

# === 8. Push and create PR if not already done ===
report_status "TESTING" "Checking/creating PR"
EXISTING_PR=$(gh pr list --head "feat/issue-${ISSUE}" --json number --jq '.[0].number' 2>/dev/null || echo "")

if [ -z "${EXISTING_PR}" ]; then
    # Check if there are actually commits to push
    COMMIT_COUNT=$(git log --oneline main..HEAD 2>/dev/null | wc -l | tr -d ' ')
    if [ "${COMMIT_COUNT}" -gt 0 ]; then
        log "Pushing ${COMMIT_COUNT} commit(s)..."
        retry "git push -u origin 'feat/issue-${ISSUE}' 2>/dev/null" || true

        log "Creating PR..."
        PR_URL=$(gh pr create \
            --title "feat: solve issue #${ISSUE}" \
            --body "Closes #${ISSUE}

Automated by Trinity Cloud Agent.
Commits: ${COMMIT_COUNT}" \
            --head "feat/issue-${ISSUE}" 2>/dev/null || true)

        if [ -n "${PR_URL}" ]; then
            emit_event "pr" "{\"url\":\"${PR_URL}\",\"commits\":${COMMIT_COUNT}}"
            report_status "PR_CREATED" "PR: ${PR_URL}"
            # Send metrics to monitor
            report_metrics
            # Post final summary comment
            DIFF_STAT=$(git diff --stat main..HEAD 2>/dev/null || echo "N/A")
            FINAL_ELAPSED=$(( $(date +%s) - START_TIME ))
            gh issue comment "${ISSUE}" --body "🚀 **Trinity Agent — Summary**

| Field | Value |
|-------|-------|
| **PR** | ${PR_URL} |
| **Commits** | ${COMMIT_COUNT} |
| **Tests** | ${TEST_RESULT:-N/A} |
| **Duration** | ${FINAL_ELAPSED}s |

\`\`\`
${DIFF_STAT}
\`\`\`" 2>/dev/null || true
        fi
    else
        report_status "FAILED" "No commits produced — agent could not solve issue"
        gh issue comment "${ISSUE}" --body "❌ **Trinity Agent**: No solution produced. Issue may need manual attention." 2>/dev/null || true
    fi
fi

# === 8. Report final status ===
if [ "${CLAUDE_EXIT}" -eq 0 ] && [ "${COMMIT_COUNT:-0}" -gt 0 ]; then
    report_status "DONE" "PR created with ${COMMIT_COUNT} commits"
    send_telegram "✅ Agent #${ISSUE}: DONE — ${COMMIT_COUNT} commits, PR created"
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
