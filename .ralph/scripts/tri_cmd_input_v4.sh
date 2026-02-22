#!/bin/bash
# TRI COMMANDER — Minimal input
RALPH_DIR="/Users/playra/trinity"
QUEUE_DIR="$RALPH_DIR/.ralph/queue"
HISTORY_FILE="$QUEUE_DIR/.history"
mkdir -p "$QUEUE_DIR"

GREEN="\033[32m"
BOLD="\033[1m"
RESET="\033[0m"

# Hide cursor
tput civis 2>/dev/null

touch "$HISTORY_FILE"

while true; do
    # Clear line and show prompt
    printf "\r%70s" " "
    printf "\r${BOLD}${GREEN}▲${RESET} / "

    # Read with history - use read without /dev/tty in tmux
    history -r "$HISTORY_FILE" 2>/dev/null
    IFS= read -e -r cmd

    # Handle empty input or Ctrl+D
    [ -z "$cmd" ] && continue
    [ "$cmd" = "exit" ] && break

    # Save to history
    grep -qxF "$cmd" "$HISTORY_FILE" 2>/dev/null || echo "$cmd" >> "$HISTORY_FILE"
    tail -100 "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" 2>/dev/null && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE" 2>/dev/null

    # Send command
    echo "$cmd" > "$QUEUE_DIR/incoming.cmd"
done
