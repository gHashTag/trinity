#!/bin/bash
# TRI COMMAND QUEUE - FIFO command queue for Claude integration
# Usage: ./tri_cmd_queue.sh {init|enqueue|dequeue|complete}

RALPH_DIR="/Users/playra/trinity"
QUEUE_DIR="$RALPH_DIR/.ralph/queue"
INCOMING="$QUEUE_DIR/incoming.cmd"
PROCESSING="$QUEUE_DIR/processing.lock"
RESPONSES="$QUEUE_DIR/responses"
CURRENT_RESP="$RESPONSES/current.resp"
HISTORY="$QUEUE_DIR/history"
STATE="$RALPH_DIR/.ralph/internal/.cmd_queue_state"
LOCK_TIMEOUT=300  # 5 minutes
MAX_QUEUE=50

# Colors
GOLD="\033[38;5;220m"
CYAN="\033[38;5;075m"
GREEN="\033[38;5;042m"
RED="\033[38;5;196m"
GRAY="\033[38;5;244m"
RESET="\033[0m"
BOLD="\033[1m"

# Initialize queue directories
init_queue() {
    mkdir -p "$QUEUE_DIR" "$RESPONSES" "$HISTORY"
    # Use regular file for simplicity (no blocking)
    touch "$INCOMING"
    chmod 600 "$INCOMING" 2>/dev/null
    echo -e "${GREEN}✓${RESET} Queue initialized at $QUEUE_DIR"
}

# Enqueue a command
enqueue() {
    local cmd="$*"
    [ -z "$cmd" ] && echo "Usage: $0 enqueue <command>" && return 1

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local cmd_file="$HISTORY/${timestamp}.cmd"

    # Save command
    echo "$cmd" > "$cmd_file"
    echo "$cmd" > "$INCOMING"

    # Update state
    jq -n --arg cmd "$cmd" --arg ts "$timestamp" \
        '{queued: $cmd, timestamp: $ts, status: "pending"}' > "$STATE" 2>/dev/null || \
        echo "{\"queued\":\"$cmd\",\"timestamp\":\"$timestamp\",\"status\":\"pending\"}" > "$STATE"

    # Signal Claude
    touch "$RALPH_DIR/.ralph/internal/.claude_signal"

    echo -e "${GREEN}✓${RESET} Command queued: $cmd"
}

# Get next command (for Claude)
dequeue() {
    # Check for stale lock
    if [ -f "$PROCESSING" ]; then
        # Get file modification time (macOS compatible)
        local mod_time=0
        if [ "$(uname)" = "Darwin" ]; then
            mod_time=$(stat -f %m "$PROCESSING" 2>/dev/null || echo 0)
        else
            mod_time=$(stat -c %Y "$PROCESSING" 2>/dev/null || echo 0)
        fi
        local current_time=$(date +%s)
        local age=$((current_time - mod_time))

        if [ $age -gt $LOCK_TIMEOUT ]; then
            rm -f "$PROCESSING"
        else
            echo "BUSY"
            return 1
        fi
    fi

    if [ -f "$INCOMING" ] && [ -s "$INCOMING" ]; then
        touch "$PROCESSING"
        cat "$INCOMING"
        return 0
    fi

    echo "EMPTY"
    return 1
}

# Mark command complete
complete() {
    rm -f "$PROCESSING" "$INCOMING"
    echo "{\"status\":\"idle\",\"last_completed\":\"$(date -Iseconds)\"}" > "$STATE"
    echo -e "${GREEN}✓${RESET} Command completed"
}

# Show queue status
status() {
    echo -e "${BOLD}${CYAN}QUEUE STATUS${RESET}"
    echo -e "${GRAY}───────────────────${RESET}"

    if [ -f "$STATE" ]; then
        local st=$(cat "$STATE")
        echo -e "Status: ${CYAN}$(echo "$st" | jq -r '.status // "unknown')${RESET}"
        if [ -f "$PROCESSING" ]; then
            echo -e "State:   ${YELLOW}Processing...${RESET}"
        else
            echo -e "State:   ${GREEN}Idle${RESET}"
        fi
    else
        echo -e "Status: ${GRAY}Not initialized${RESET}"
    fi

    local count=$(ls -1 "$HISTORY"/*.cmd 2>/dev/null | wc -l | xargs)
    echo -e "History: ${count} commands"

    if [ -f "$INCOMING" ] && [ -s "$INCOMING" ]; then
        echo -e "Queued: ${GREEN}$(cat "$INCOMING")${RESET}"
    fi
}

# Main router
case "${1:-}" in
    init)   init_queue ;;
    enqueue) shift; enqueue "$*" ;;
    dequeue) dequeue ;;
    complete) complete ;;
    status)  status ;;
    *)
        echo "TRI COMMAND QUEUE v1.0"
        echo "Usage: $0 {init|enqueue|dequeue|complete|status}"
        ;;
esac
