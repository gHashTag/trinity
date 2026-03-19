#!/bin/bash
# TRI COMMANDER — Simple input with quick commands
cd /Users/playra/trinity/trinity-nexus

clear  # Hide launch command

QUEUE_DIR="ralph/queue"
HISTORY_FILE="$QUEUE_DIR/.history"
mkdir -p "$QUEUE_DIR"

GREEN="\033[38;5;154m"  # Bright yellow-green / lime
BOLD="\033[1m"
RESET="\033[0m"
CYAN="\033[38;5;075m"
GRAY="\033[38;5;244m"
RED="\033[38;5;196m"
ORANGE="\033[38;5;208m"

touch "$HISTORY_FILE"

# Quick command handlers
show_help() {
    echo -e "${CYAN}Quick Commands:${RESET}"
    echo "  !status    - Show full Ralph status"
    echo "  !tasks     - Show all tasks (P1/P2/P3)"
    echo "  !tasks-p1  - Show P1 tasks only"
    echo "  !build     - Run zig build"
    echo "  !rebuild   - Clean and rebuild"
    echo "  !test      - Run zig test"
    echo "  !clean     - Clean zig-cache"
    echo "  !clear     - Clear chat history"
    echo "  !diff      - Show git diff"
    echo "  !search    - Unified search: !search <term>"
    echo "  !filter-error   - Show only ERROR from logs"
    echo "  !filter-warn    - Show only WARN from logs"
    echo "  !api-key   - Show current API key status"
    echo "  !switch-key    - Manually switch to backup API key"
    echo ""
    echo -e "${CYAN}Keyboard Shortcuts:${RESET}"
    echo "  q or ?    - Show this help"
    echo "  h         - Help"
    echo "  0-9       - Switch tmux window (Ctrl+b # equivalent)"
    echo "  s         - Search prompt"
    echo "  n         - Next pane"
    echo "  p         - Previous pane"
    echo ""
}

show_status() {
    bash ralph/scripts/tmux/status.sh panel0
    echo ""
}

show_tasks() {
    bash ralph/scripts/tmux/status.sh panel2
    echo ""
}

show_tasks_p1() {
    local fp="/Users/playra/trinity/.ralph/fix_plan.md"
    if [ -f "$fp" ]; then
        echo -e "${RED}P1 Tasks:${RESET}"
        grep "^\- \[ \] \[P1\]" "$fp" 2>/dev/null | head -10 || echo "  No P1 tasks"
    else
        echo -e "${RED}fix_plan.md not found${RESET}"
    fi
    echo ""
}

run_build() {
    echo -e "${CYAN}Building...${RESET}"
    zig build 2>&1 | tail -20
    echo ""
}

run_rebuild() {
    echo -e "${CYAN}Cleaning and rebuilding...${RESET}"
    rm -rf zig-cache
    zig build 2>&1 | tail -20
    echo ""
}

run_tests() {
    echo -e "${CYAN}Testing...${RESET}"
    zig test 2>&1 | tail -30
    echo ""
}

run_clean() {
    echo -e "${CYAN}Cleaning zig-cache...${RESET}"
    rm -rf zig-cache
    echo -e "${GREEN}Done.${RESET}"
    echo ""
}

show_diff() {
    echo -e "${CYAN}Git diff:${RESET}"
    git diff --stat 2>/dev/null || echo "  Not a git repo or no changes"
    echo ""
}

run_search() {
    local term="$1"
    if [ -z "$term" ]; then
        echo -ne "${CYAN}Search term: ${RESET}"
        read -r term
    fi
    [ -z "$term" ] && echo "  No search term" && return
    bash ralph/scripts/tmux/status.sh search "$term"
    echo ""
}

filter_error() {
    local logf="/Users/playra/trinity/.ralph/logs/ralph.log"
    if [ -f "$logf" ]; then
        echo -e "${RED}ERROR entries:${RESET}"
        grep -i "error" "$logf" 2>/dev/null | tail -20 || echo "  No errors found"
    else
        echo -e "${GRAY}ralph.log not found${RESET}"
    fi
    echo ""
}

filter_warn() {
    local logf="/Users/playra/trinity/.ralph/logs/ralph.log"
    if [ -f "$logf" ]; then
        echo -e "${ORANGE}WARN entries:${RESET}"
        grep -i "warn" "$logf" 2>/dev/null | tail -20 || echo "  No warnings found"
    else
        echo -e "${GRAY}ralph.log not found${RESET}"
    fi
    echo ""
}

clear_history() {
    > "$HISTORY_FILE"
    echo -e "${GREEN}History cleared.${RESET}"
    echo ""
}

show_api_key_status() {
    local active_file="ralph/queue/.active_key"
    local keys_conf="ralph/queue/.api_keys.conf"
    local failover_log="ralph/queue/api_failover.log"

    echo -e "${CYAN}API Key Status:${RESET}"

    if [ -f "$active_file" ]; then
        local idx=$(cat "$active_file")
        echo -e "  Active: ${GREEN}KEY #$idx${RESET}"
    else
        echo -e "  Active: ${YELLOW}KEY #1 (default)${RESET}"
    fi

    if [ -f "$keys_conf" ]; then
        local k1=$(grep "^KEY_1=" "$keys_conf" | cut -d= -f2)
        local k2=$(grep "^KEY_2=" "$keys_conf" | cut -d= -f2)
        [ -n "$k1" ] && echo -e "  KEY_1: ${GREEN}configured${RESET}"
        [ -n "$k2" ] && echo -e "  KEY_2: ${GREEN}configured${RESET}"
        [ -z "$k2" ] && echo -e "  KEY_2: ${GRAY}not configured${RESET}"
    else
        echo -e "  Config: ${GRAY}using env vars${RESET}"
    fi

    if [ -f "$failover_log" ]; then
        local last_switch=$(tail -1 "$failover_log" 2>/dev/null)
        [ -n "$last_switch" ] && echo -e "  Last switch: ${GRAY}${last_switch}${RESET}"
    fi

    echo ""
}

switch_api_key_manual() {
    local active_file="ralph/queue/.active_key"
    local keys_conf="ralph/queue/.api_keys.conf"

    if [ -f "$keys_conf" ]; then
        . "$keys_conf"
    fi

    # Get current
    local current=1
    [ -f "$active_file" ] && current=$(cat "$active_file")

    # Determine next
    local next=2
    if [ "$current" = "2" ]; then
        next=1
    fi

    # Check if target key exists
    if [ "$next" = "2" ] && [ -z "$KEY_2" ]; then
        echo -e "${RED}KEY_2 not configured!${RESET} Set it in $keys_conf"
        echo ""
        return
    fi

    # Switch
    echo "$next" > "$active_file"
    echo -e "${GREEN}Switched: KEY #$current → KEY #$next${RESET}"

    # Need to restart handler for change to take effect
    echo -e "${YELLOW}Restart handler to apply: pkill -f tri_cmd_real_handler${RESET}"
    echo ""
}

# tmux window switch helper
switch_window() {
    local win="$1"
    tmux select-window -t "$win" 2>/dev/null && echo -e "${GREEN}Switched to window ${win}${RESET}" || echo -e "${GRAY}Not in tmux or invalid window${RESET}"
    echo ""
}

while true; do
    echo -ne "  ${BOLD}${GREEN}▲${RESET} "
    read -r cmd

    [ -z "$cmd" ] && continue
    [ "$cmd" = "exit" ] && break

    # Handle single-character keyboard shortcuts
    case "$cmd" in
        q|\?|h|help)
            show_help
            continue
            ;;
        [0-9])
            switch_window "$cmd"
            continue
            ;;
        s)
            echo -ne "${CYAN}Search: ${RESET}"
            read -r term
            [ -n "$term" ] && run_search "$term"
            continue
            ;;
        n)
            tmux select-pane -t :.+ 2>/dev/null && echo -e "${GREEN}Next pane${RESET}"
            continue
            ;;
        p)
            tmux select-pane -t :.- 2>/dev/null && echo -e "${GREEN}Previous pane${RESET}"
            continue
            ;;
    esac

    # Handle quick commands
    case "$cmd" in
        !help|!)
            show_help
            continue
            ;;
        !status)
            show_status
            continue
            ;;
        !tasks)
            show_tasks
            continue
            ;;
        !tasks-p1)
            show_tasks_p1
            continue
            ;;
        !build)
            run_build
            continue
            ;;
        !rebuild)
            run_rebuild
            continue
            ;;
        !test)
            run_tests
            continue
            ;;
        !clean)
            run_clean
            continue
            ;;
        !clear)
            clear_history
            continue
            ;;
        !diff)
            show_diff
            continue
            ;;
        !search\ *)
            term="${cmd#!search }"
            run_search "$term"
            continue
            ;;
        !filter-error)
            filter_error
            continue
            ;;
        !filter-warn)
            filter_warn
            continue
            ;;
        !api-key)
            show_api_key_status
            continue
            ;;
        !switch-key)
            switch_api_key_manual
            continue
            ;;
    esac

    # Regular command - send to handler
    grep -qxF "$cmd" "$HISTORY_FILE" 2>/dev/null || echo "$cmd" >> "$HISTORY_FILE"
    tail -100 "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" 2>/dev/null && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE" 2>/dev/null

    echo "$cmd" > "$QUEUE_DIR/incoming.cmd"

    # Clear input and move cursor to start for next prompt
    printf "\033[A\033[2K\r"  # Up 1, clear line, CR
done
