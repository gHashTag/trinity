#!/bin/sh
# Trinity Cloud Agent Entrypoint
# Solves a single GitHub issue using Claude Code
# Required env: ISSUE_NUMBER, GITHUB_TOKEN, ANTHROPIC_API_KEY

set -e

REPO_URL="${REPO_URL:-https://github.com/gHashTag/trinity.git}"
ISSUE="${ISSUE_NUMBER:?ISSUE_NUMBER is required}"

echo "[agent-${ISSUE}] Starting Trinity Cloud Agent"
echo "[agent-${ISSUE}] Issue: #${ISSUE}"

# Health marker
touch /tmp/agent-alive

# Trap signals for graceful shutdown
cleanup() {
    echo "[agent-${ISSUE}] Shutting down..."
    rm -f /tmp/agent-alive
    # Report FAILED status if we're killed externally
    if [ -n "${WS_MONITOR_URL}" ]; then
        curl -s -X POST "${WS_MONITOR_URL}/api/status" \
            -H "Content-Type: application/json" \
            -d "{\"issue\":${ISSUE},\"status\":\"KILLED\",\"detail\":\"Container terminated\"}" \
            2>/dev/null || true
    fi
    exit 0
}
trap cleanup TERM INT

# === 1. Auth ===
echo "[agent-${ISSUE}] Authenticating with GitHub..."
echo "${GITHUB_TOKEN}" | gh auth login --with-token
git config --global user.name "Trinity Agent"
git config --global user.email "trinity-agent@users.noreply.github.com"

# === 2. Clone ===
echo "[agent-${ISSUE}] Cloning repository..."
gh repo clone "${REPO_URL}" /workspace/trinity -- --depth=50
cd /workspace/trinity

# === 3. Prepare SOUL.md ===
echo "[agent-${ISSUE}] Injecting soul..."
sed "s/{ISSUE_NUMBER}/${ISSUE}/g" /etc/trinity/SOUL.md > /workspace/trinity/CLAUDE.md.agent

# === 4. Read issue ===
echo "[agent-${ISSUE}] Reading issue #${ISSUE}..."
ISSUE_BODY=$(gh issue view "${ISSUE}" --json title,body,labels --jq '.')

# Report THINKING status
if [ -n "${WS_MONITOR_URL}" ]; then
    curl -s -X POST "${WS_MONITOR_URL}/api/status" \
        -H "Content-Type: application/json" \
        -d "{\"issue\":${ISSUE},\"status\":\"THINKING\",\"detail\":\"Analyzing issue\"}" \
        2>/dev/null || true
fi

# === 5. Create branch ===
git checkout -b "feat/issue-${ISSUE}"

# === 6. Run Claude Code ===
echo "[agent-${ISSUE}] Starting Claude Code agent..."

# Report ACTING status
if [ -n "${WS_MONITOR_URL}" ]; then
    curl -s -X POST "${WS_MONITOR_URL}/api/status" \
        -H "Content-Type: application/json" \
        -d "{\"issue\":${ISSUE},\"status\":\"ACTING\",\"detail\":\"Claude Code running\"}" \
        2>/dev/null || true
fi

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

claude -p "${PROMPT}" --allowedTools "Bash,Read,Write,Edit,Glob,Grep" 2>&1 || true

# === 7. Push and create PR if not already done ===
echo "[agent-${ISSUE}] Checking if PR exists..."
EXISTING_PR=$(gh pr list --head "feat/issue-${ISSUE}" --json number --jq '.[0].number' 2>/dev/null || echo "")

if [ -z "${EXISTING_PR}" ]; then
    echo "[agent-${ISSUE}] Pushing branch..."
    git push -u origin "feat/issue-${ISSUE}" 2>/dev/null || true

    echo "[agent-${ISSUE}] Creating PR..."
    gh pr create \
        --title "feat: solve issue #${ISSUE}" \
        --body "Closes #${ISSUE}

Automated by Trinity Cloud Agent." \
        --head "feat/issue-${ISSUE}" 2>/dev/null || true
fi

# === 8. Report DONE ===
echo "[agent-${ISSUE}] Done!"
if [ -n "${WS_MONITOR_URL}" ]; then
    curl -s -X POST "${WS_MONITOR_URL}/api/status" \
        -H "Content-Type: application/json" \
        -d "{\"issue\":${ISSUE},\"status\":\"DONE\",\"detail\":\"PR created\"}" \
        2>/dev/null || true
fi

# Keep alive for 5 minutes for debugging, then exit
echo "[agent-${ISSUE}] Staying alive for 5 minutes..."
sleep 300
rm -f /tmp/agent-alive
echo "[agent-${ISSUE}] Self-destructing."
