#!/bin/bash
# Ralph Worktree Status Reporter — Trinity Dev
# Reports parallel work across all git worktrees

RALPH_DIR="/Users/playra/trinity/.ralph"
INTERNAL_DIR="$RALPH_DIR/internal"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Main repo status
echo "=== Trinity Worktree Status Report ==="
echo ""

# Circuit breaker
CB_STATE=$(cat "$INTERNAL_DIR/.circuit_breaker_state" 2>/dev/null | jq -r '.state // "UNKNOWN"')
CB_LOOP=$(cat "$INTERNAL_DIR/.circuit_breaker_state" 2>/dev/null | jq -r '.current_loop // 0')
CB_NOPROG=$(cat "$INTERNAL_DIR/.circuit_breaker_state" 2>/dev/null | jq -r '.consecutive_no_progress // 0')

echo "🔌 Circuit Breaker: $CB_STATE (Loop: $CB_LOOP, No-prog: $CB_NOPROG)"
echo ""

# Worktrees status
echo "🌲 Worktrees:"
echo ""

WTS=$(git -C /Users/playra/trinity worktree list | tail -n +2)
ACTIVE_COUNT=0
IDLE_COUNT=0

while IFS= read -r line; do
    WT_PATH=$(echo "$line" | awk '{print $1}')
    WT_SHA=$(echo "$line" | awk '{print $2}' | tr -d '[]')
    WT_BRANCH=$(echo "$line" | awk '{print $3}' | tr -d '[]')

    # Get last commit message
    LAST_MSG=$(git -C "$WT_PATH" log --oneline -1 2>/dev/null | cut -d' ' -f2- | head -c 60)

    # Check for changes
    CHANGES=$(git -C "$WT_PATH" status --short 2>/dev/null | wc -l | tr -d ' ')

    # Check if Ralph is active in this worktree
    WT_RALPH_DIR="$WT_PATH/.ralph"
    if [ -f "$WT_RALPH_DIR/internal/.circuit_breaker_state" ]; then
        WT_CB=$(cat "$WT_RALPH_DIR/internal/.circuit_breaker_state" 2>/dev/null | jq -r '.state // "UNKNOWN"')
        WT_LOOP=$(cat "$WT_RALPH_DIR/internal/.circuit_breaker_state" 2>/dev/null | jq -r '.current_loop // 0')
        WT_CALLS=$(cat "$WT_RALPH_DIR/internal/.call_count" 2>/dev/null || echo "0")

        echo "  📂 $(basename $WT_PATH)"
        echo "     Branch: $WT_BRANCH"
        echo "     Last: $LAST_MSG..."
        echo "     CB: $WT_CB | Loop: $WT_LOOP | Calls: $WT_CALLS"
        echo "     Changes: $CHANGES files"
        echo ""
        ((ACTIVE_COUNT++))
    else
        echo "  📂 $(basename $WT_PATH)"
        echo "     Branch: $WT_BRANCH"
        echo "     Last: $LAST_MSG..."
        echo "     Status: 💤 No Ralph"
        echo ""
        ((IDLE_COUNT++))
    fi
done <<< "$WTS"

echo "📊 Summary: $ACTIVE_COUNT active, $IDLE_COUNT idle"
echo ""

# Orchestrator status
if [ -f "$RALPH_DIR/logs/orchestrator.log" ]; then
    LAST_ORCH=$(tail -1 "$RALPH_DIR/logs/orchestrator.log" 2>/dev/null)
    echo "🎭 Orchestrator: $LAST_ORCH"
fi
echo ""

# Recent commits across all worktrees
echo "📝 Recent Commits (main):"
git -C /Users/playra/trinity log --oneline -3 2>/dev/null | while read line; do
    echo "   • $line"
done
echo ""

echo "Generated at $(date '+%Y-%m-%d %H:%M:%S')"
