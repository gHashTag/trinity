#!/bin/bash
# TRI COMMANDER — Minimal input
RALPH_DIR="/Users/playra/trinity"
QUEUE_DIR="$RALPH_DIR/.ralph/queue"
HISTORY_FILE="$QUEUE_DIR/.history"
mkdir -p "$QUEUE_DIR"

CYAN="\033[38;5;075m"
RESET="\033[0m"

# Hide cursor, clear startup noise
tput civis 2>/dev/null
clear

touch "$HISTORY_FILE"

while true; do
    # Prompt - with margin
    echo -ne "  ${CYAN}►${RESET} "

    # Read with history
    history -r "$HISTORY_FILE" 2>/dev/null
    read -e -r cmd < /dev/tty || break

    # Handle empty input
    [ -z "$cmd" ] && continue

    # Save to history
    grep -qxF "$cmd" "$HISTORY_FILE" 2>/dev/null || echo "$cmd" >> "$HISTORY_FILE"
    tail -100 "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" 2>/dev/null && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE" 2>/dev/null

    # Send command
    echo "$cmd" > "$QUEUE_DIR/incoming.cmd"
done
