#!/bin/bash
# Trinity Agent Loop — TRI Pipeline + Git Worktree
# Polls orchestrator for tasks, creates worktrees, runs Golden Chain
# Usage: bash scripts/agent-loop.sh
set -uo pipefail

# ─── Configuration ───────────────────────────────────────────
AGENT_ID="${AGENT_ID:-agent-$(hostname | cut -c1-8)}"
REPO_DIR="${TRINITY_PROJECT_ROOT:-/data/trinity}"
WORKTREE_BASE="${WORKTREE_BASE:-/data/worktrees}"
WORKTREE_DIR="${WORKTREE_BASE}/${AGENT_ID}"
ORCHESTRATOR="${ORCHESTRATOR_URL:-https://vibee-telegram-bridge.fly.dev}"
POLL_INTERVAL="${POLL_INTERVAL:-30}"
LOG_DIR="${REPO_DIR}/.ralph/logs"

mkdir -p "$LOG_DIR"

echo "=== Trinity Agent Loop: $AGENT_ID ==="
echo "    Repo:        $REPO_DIR"
echo "    Worktree:    $WORKTREE_DIR"
echo "    Orchestrator: $ORCHESTRATOR"
echo "    Poll interval: ${POLL_INTERVAL}s"
echo ""

# ─── Heartbeat function ─────────────────────────────────────
send_heartbeat() {
    local status="${1:-idle}"
    local branch="${2:-none}"
    local task_id="${3:-none}"
    curl -s -X POST "${ORCHESTRATOR}/api/v1/swarm/heartbeat" \
        -H "Content-Type: application/json" \
        -d "{
            \"agent_id\": \"${AGENT_ID}\",
            \"status\": \"${status}\",
            \"branch\": \"${branch}\",
            \"task_id\": \"${task_id}\",
            \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
        }" 2>/dev/null || true
}

# ─── Cleanup worktree function ───────────────────────────────
cleanup_worktree() {
    cd "$REPO_DIR"
    if [ -d "$WORKTREE_DIR" ]; then
        git worktree remove "$WORKTREE_DIR" --force 2>/dev/null || true
    fi
    git worktree prune 2>/dev/null || true
}

# ─── Trap for clean shutdown ─────────────────────────────────
trap 'echo "Shutting down agent ${AGENT_ID}..."; send_heartbeat "shutdown"; cleanup_worktree; exit 0' SIGTERM SIGINT

# ─── Main Loop ───────────────────────────────────────────────
LOOP_COUNT=0

while true; do
    LOOP_COUNT=$((LOOP_COUNT + 1))

    # 1. Send heartbeat
    send_heartbeat "polling"

    # 2. Fetch task from orchestrator
    TASK=$(curl -s "${ORCHESTRATOR}/api/v1/swarm/task?agent_id=${AGENT_ID}" 2>/dev/null) || TASK=""

    # 3. Check if task available
    if [ -n "$TASK" ] && [ "$TASK" != "null" ] && [ "$TASK" != "{}" ] && echo "$TASK" | jq -e '.slug' >/dev/null 2>&1; then
        SLUG=$(echo "$TASK" | jq -r '.slug')
        DESC=$(echo "$TASK" | jq -r '.description')
        TASK_ID=$(echo "$TASK" | jq -r '.id // "unknown"')
        PRIORITY=$(echo "$TASK" | jq -r '.priority // "P1"')
        BRANCH="ralph/${AGENT_ID}/${SLUG}"

        echo ""
        echo "══════════════════════════════════════════"
        echo "  TASK RECEIVED: ${SLUG}"
        echo "  Priority: ${PRIORITY}"
        echo "  Branch: ${BRANCH}"
        echo "══════════════════════════════════════════"
        echo ""

        send_heartbeat "working" "$BRANCH" "$TASK_ID"

        # 4. Fetch latest from origin
        cd "$REPO_DIR"
        git fetch origin main --depth 1 2>/dev/null || true

        # 5. Cleanup old worktree
        cleanup_worktree

        # 6. Create fresh worktree with new branch
        git worktree add -b "$BRANCH" "$WORKTREE_DIR" origin/main 2>&1 || {
            echo "ERROR: Failed to create worktree"
            send_heartbeat "error" "none" "$TASK_ID"
            sleep "$POLL_INTERVAL"
            continue
        }

        # 7. Work in worktree
        cd "$WORKTREE_DIR"
        echo "Working in: $(pwd)"
        echo "Branch: $(git branch --show-current)"

        # 8. Run TRI PIPELINE via Claude Code
        LOG_FILE="${LOG_DIR}/${AGENT_ID}-${SLUG}-$(date +%Y%m%d-%H%M%S).log"

        claude --print "You are Ralph agent '${AGENT_ID}' executing a task in a Git Worktree.

## Task
${DESC}

## Instructions
Execute the Ralph Golden Chain (9 links) using TRI Pipeline commands:

1. \`tri decompose '${DESC}'\` — Break task into subtasks
2. \`tri plan '${DESC}'\` — Create implementation plan
3. \`tri spec_create\` — Create .vibee spec (if new module needed)
4. \`tri gen specs/tri/<spec>.vibee\` — Generate code (if spec created)
5. \`tri verify\` / \`zig build test\` — Run tests
6. \`tri bench\` — Compare performance to baseline
7. \`tri verdict\` — Write honest toxic verdict
8. \`tri commit 'feat(${SLUG}): ${DESC}'\` — Commit to branch
9. \`tri loop_decide\` — Decide: continue improving or done

## Environment
- Branch: ${BRANCH}
- Working directory: ${WORKTREE_DIR}
- Agent ID: ${AGENT_ID}
- Priority: ${PRIORITY}

## Rules
- Follow .ralph/RULES.md strictly
- All quality gates must pass before commit
- Never commit to main — you are on branch ${BRANCH}
- Use MCP tools: tri_execute, tri_pipeline, needle_quality_gates
" 2>&1 | tee "$LOG_FILE"

        # 9. Push branch
        cd "$WORKTREE_DIR"
        git push origin "$BRANCH" 2>&1 || echo "WARNING: Push failed"

        # 10. Report completion
        send_heartbeat "completed" "$BRANCH" "$TASK_ID"

        echo ""
        echo "  TASK COMPLETED: ${SLUG}"
        echo "  Branch pushed: ${BRANCH}"
        echo "  Log: ${LOG_FILE}"
        echo ""

        # 11. Cleanup worktree for next task
        cleanup_worktree

    else
        # No task available — idle
        if [ $((LOOP_COUNT % 10)) -eq 0 ]; then
            echo "[${AGENT_ID}] Idle (loop ${LOOP_COUNT}, waiting for tasks...)"
        fi
    fi

    sleep "$POLL_INTERVAL"
done
