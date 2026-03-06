#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# RALPH ROLLBACK SYSTEM — Safety Net for Autonomous Improvements
# ═══════════════════════════════════════════════════════════════════════════════
#
# Automatically rolls back failed changes, notifies via Telegram
#
# φ² + 1/φ² = 3
# ═══════════════════════════════════════════════════════════════════════════════

set -e

RALPH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_SCRIPT="${RALPH_DIR}/scripts/report.sh"
STATE_FILE="${RALPH_DIR}/rollback_state.json"

log() {
    local level="$1"
    shift
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $*" | tee -a "${RALPH_DIR}/logs/rollback.log"
}

report_telegram() {
    [[ -f "$REPORT_SCRIPT" ]] && "$REPORT_SCRIPT" "$*" 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════════════════════
# ROLLBACK FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

save_state_before_change() {
    local change_type="$1"  # "evolution", "vision", "publish"
    local commit_hash=$(git -C "$(dirname "$RALPH_DIR")" rev-parse HEAD 2>/dev/null || echo "unknown")

    cat > "$STATE_FILE" << EOF
{
  "before_commit": "$commit_hash",
  "change_type": "$change_type",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "in_progress"
}
EOF

    log INFO "State saved: $commit_hash before $change_type"
}

mark_change_success() {
    if [[ -f "$STATE_FILE" ]]; then
        local tmp=$(mktemp)
        jq '.status = "success"' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
    fi
    log SUCCESS "Change marked as successful"
}

rollback_last_change() {
    local reason="$1"

    if [[ ! -f "$STATE_FILE" ]]; then
        log WARN "No state file found, nothing to rollback"
        return 1
    fi

    local before_commit=$(jq -r '.before_commit // empty' "$STATE_FILE")
    local change_type=$(jq -r '.change_type // "unknown"' "$STATE_FILE")

    if [[ -z "$before_commit" ]] || [[ "$before_commit" == "null" ]]; then
        log ERROR "Invalid state file - no commit to rollback to"
        return 1
    fi

    log WARN "Rolling back $change_type change: $reason"

    cd "$(dirname "$RALPH_DIR")"

    # Reset to previous commit
    git reset --hard "$before_commit" 2>&1 | tee -a "${RALPH_DIR}/logs/rollback.log"

    # Clean untracked files
    git clean -fd 2>&1 | tee -a "${RALPH_DIR}/logs/rollback.log"

    log INFO "Rollback complete: returned to $before_commit"

    # Notify via Telegram
    report_telegram "🔄 RALPH ROLLBACK

Type: $change_type
Reason: $reason
Returned to: ${before_commit:0:8}

φ² + 1/φ² = 3"

    # Update state file
    cat > "$STATE_FILE" << EOF
{
  "before_commit": "$before_commit",
  "change_type": "$change_type",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "rolled_back",
  "rollback_reason": "$reason"
}
EOF
}

# ═══════════════════════════════════════════════════════════════════════════════
# COMMAND DISPATCH
# ═══════════════════════════════════════════════════════════════════════════════

mkdir -p "$(dirname "$RALPH_DIR/logs/rollback.log")"

case "${1:-}" in
    save)
        save_state_before_change "${2:-unknown}"
        ;;
    success)
        mark_change_success
        ;;
    rollback)
        rollback_last_change "${2:-unknown reason}"
        ;;
    status)
        if [[ -f "$STATE_FILE" ]]; then
            cat "$STATE_FILE" | jq -r '.'
        else
            echo "No rollback state found"
        fi
        ;;
    *)
        echo "Usage: $0 {save|success|rollback|status} [reason]"
        echo ""
        echo "Commands:"
        echo "  save <type>   - Save state before change"
        echo "  success       - Mark change as successful"
        echo "  rollback <r>  - Rollback last failed change"
        echo "  status        - Show current state"
        exit 1
        ;;
esac
