#!/bin/bash
# tmux_status_v4.sh — Compact status panel (только 5 метрик)
# Usage: ./tmux_status_v4.sh compact

RALPH_DIR="/Users/playra/trinity"
cd "$RALPH_DIR" 2>/dev/null || exit 1

# Trinity colors
GOLD="\033[38;5;220m"
CYAN="\033[38;5;075m"
GREEN="\033[38;5;042m"
RED="\033[38;5;196m"
YELLOW="\033[38;5;226m"
GRAY="\033[38;5;244m"
RESET="\033[0m"
BOLD="\033[1m"

compact() {
    # Читаем статус
    local status="?"
    local api="?/100"
    local cb="CLOSED"
    local total=0 done=0
    local p1=0 p2=0

    # status.json
    if [ -f ".ralph/logs/status.json" ]; then
        status=$(jq -r '.status // "?"' ".ralph/logs/status.json" 2>/dev/null)
        local calls=$(jq -r '.calls_made_this_hour // "?"' ".ralph/logs/status.json" 2>/dev/null)
        api="${calls}/100"
    fi

    # circuit breaker
    if [ -f ".ralph/internal/.circuit_breaker_state" ]; then
        cb=$(jq -r '.state // "CLOSED"' ".ralph/internal/.circuit_breaker_state" 2>/dev/null || echo "CLOSED")
    fi

    # tasks
    local fix_plan=""
    if [ -f ".ralph/fix_plan.md" ]; then
        fix_plan=".ralph/fix_plan.md"
    elif [ -f ".ralph/internal/fix_plan.md" ]; then
        fix_plan=".ralph/internal/fix_plan.md"
    fi

    if [ -n "$fix_plan" ]; then
        total=$(grep -c "^- \[.\]" "$fix_plan" 2>/dev/null || echo "0")
        done=$(grep -c "^- \[x\]" "$fix_plan" 2>/dev/null || echo "0")
        p1=$(grep -c "^\- \[ \] \[P1\]" "$fix_plan" 2>/dev/null || echo "0")
        p2=$(grep -c "^\- \[ \] \[P2\]" "$fix_plan" 2>/dev/null || echo "0")
    fi

    # Color status
    local status_color="$GREEN"
    [ "$status" != "running" ] && status_color="$YELLOW"
    [ "$cb" = "OPEN" ] && status_color="$RED"

    # Compact box (5 строк)
    echo -e "${BOLD}${GOLD}┌─────────────┐${RESET}"
    echo -e "${BOLD}${GOLD}│${RESET} RALPH v4.0  ${BOLD}${GOLD}│${RESET}"
    echo -e "${BOLD}${GOLD}├─────────────┤${RESET}"
    echo -e "${BOLD}${GOLD}│${RESET} ${status_color}● $status${RESET}   ${BOLD}${GOLD}│${RESET}"
    echo -e "${BOLD}${GOLD}│${RESET} API: $api  ${BOLD}${GOLD}│${RESET}"
    echo -e "${BOLD}${GOLD}│${RESET} Tasks: $done/$total${BOLD}${GOLD}│${RESET}"
    echo -e "${BOLD}${GOLD}│${RESET} P1:$p1 P2:$p2  ${BOLD}${GOLD}│${RESET}"
    echo -e "${BOLD}${GOLD}└─────────────┘${RESET}"
}

# Main router
case "$1" in
    compact) compact ;;
    *)
        echo "Usage: $0 {compact}"
        exit 1
        ;;
esac
