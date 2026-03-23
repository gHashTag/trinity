#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# GOD MODE — Agent Monitoring & Status Collector
# ═══════════════════════════════════════════════════════════════
# Usage: bash .ralph/god_mode.sh [--json|--text]
# No hardcoded paths — portable across Railway/macOS/Linux
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SWARM_STATE="$PROJECT_ROOT/.trinity/swarm_state.json"
CB_STATE="$PROJECT_ROOT/.ralph/internal/.circuit_breaker_state"
GOD_LOG="$PROJECT_ROOT/.ralph/god_mode_log.jsonl"
FORMAT="${1:---text}"

# ═══════════════════════════════════════════════════════════════
# CROSS-PLATFORM NOTIFICATION
# ═══════════════════════════════════════════════════════════════
notify() {
    local title="$1" msg="$2"
    if command -v osascript &>/dev/null; then
        osascript -e "display notification \"$msg\" with title \"$title\" sound name \"Glass\"" 2>/dev/null || true
    elif command -v notify-send &>/dev/null; then
        notify-send "$title" "$msg" 2>/dev/null || true
    else
        echo "[GOD MODE] $title: $msg" >> "$GOD_LOG"
    fi
}

# ═══════════════════════════════════════════════════════════════
# SECTION 1: SWARM AGENTS
# ═══════════════════════════════════════════════════════════════
print_agents() {
    echo "=== AGENTS ==="
    if [ -f "$SWARM_STATE" ]; then
        jq -r '.agents[]? | "\(.id)\t\(.status)\ttasks:\(.tasks_completed)/\(.tasks_failed)\tno_progress:\(.no_progress_count)\tbranch:\(.current_branch)"' "$SWARM_STATE" 2>/dev/null || echo "  (no agents registered)"
    else
        echo "  (no swarm state file)"
    fi
    echo ""
}

# ═══════════════════════════════════════════════════════════════
# SECTION 2: TASK QUEUE
# ═══════════════════════════════════════════════════════════════
print_tasks() {
    echo "=== TASKS ==="
    if [ -f "$SWARM_STATE" ]; then
        jq -r '.tasks[]? | select(.status != "completed") | "[\(.priority)] \(.status)\t\(.slug)\tassigned:\(.assigned_to)"' "$SWARM_STATE" 2>/dev/null || echo "  (no active tasks)"
    else
        echo "  (no swarm state file)"
    fi
    echo ""
}

# ═══════════════════════════════════════════════════════════════
# SECTION 3: GIT STATUS
# ═══════════════════════════════════════════════════════════════
print_git() {
    echo "=== GIT ==="
    echo "Branch: $(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || echo 'unknown')"
    echo "Worktrees:"
    git -C "$PROJECT_ROOT" worktree list 2>/dev/null | sed 's/^/  /'
    echo ""
    echo "Recent commits:"
    git -C "$PROJECT_ROOT" log --oneline -5 --all --graph 2>/dev/null | sed 's/^/  /'
    echo ""
}

# ═══════════════════════════════════════════════════════════════
# SECTION 4: CIRCUIT BREAKER
# ═══════════════════════════════════════════════════════════════
print_circuit_breaker() {
    echo "=== CIRCUIT BREAKER ==="
    if [ -f "$CB_STATE" ]; then
        cat "$CB_STATE"
    else
        echo "  CLOSED (default)"
    fi
    echo ""
}

# ═══════════════════════════════════════════════════════════════
# SECTION 5: PIPELINE COMPLIANCE
# ═══════════════════════════════════════════════════════════════
print_compliance() {
    echo "=== PIPELINE COMPLIANCE ==="
    local violations=0

    # Check: not on main
    local branch
    branch=$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || echo 'unknown')
    if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
        echo "  VIOLATION: On main branch (agents must use feature branches)"
        violations=$((violations + 1))
    else
        echo "  OK: Branch = $branch"
    fi

    # Check: swarm circuit breakers
    if [ -f "$SWARM_STATE" ]; then
        local stuck
        stuck=$(jq -r '.agents[]? | select(.no_progress_count >= 3) | .id' "$SWARM_STATE" 2>/dev/null)
        if [ -n "$stuck" ]; then
            echo "  WARNING: Stuck agents (no_progress >= 3): $stuck"
            violations=$((violations + 1))
        else
            echo "  OK: No stuck agents"
        fi
    fi

    # Check: GitHub issues with assign:ralph
    if command -v gh &>/dev/null; then
        local issue_count
        issue_count=$(gh issue list --label "assign:ralph" --state open --json number --jq 'length' 2>/dev/null || echo "0")
        echo "  Issues with assign:ralph: $issue_count open"
    fi

    echo "  Violations: $violations"
    echo ""
}

# ═══════════════════════════════════════════════════════════════
# SECTION 6: EVENT LOG (last 10)
# ═══════════════════════════════════════════════════════════════
print_log() {
    echo "=== RECENT EVENTS ==="
    if [ -f "$GOD_LOG" ]; then
        tail -10 "$GOD_LOG" | while IFS= read -r line; do
            echo "  $line"
        done
    else
        echo "  (no events yet)"
    fi
    echo ""
}

# ═══════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════
if [ "$FORMAT" = "--json" ]; then
    # JSON output for programmatic consumption
    jq -n \
        --arg branch "$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || echo 'unknown')" \
        --arg cb "$(cat "$CB_STATE" 2>/dev/null || echo 'CLOSED')" \
        --argjson swarm "$(cat "$SWARM_STATE" 2>/dev/null || echo '{}')" \
        '{branch: $branch, circuit_breaker: $cb, swarm: $swarm}'
else
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║          GOD MODE — Agent Oversight Dashboard         ║"
    echo "║              phi^2 + 1/phi^2 = 3 = TRINITY            ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""
    print_agents
    print_tasks
    print_git
    print_circuit_breaker
    print_compliance
    print_log
fi
