#!/bin/bash
# TRI COMMANDER — Simple input
cd /Users/playra/trinity

QUEUE_DIR=".ralph/queue"
HISTORY_FILE="$QUEUE_DIR/.history"
mkdir -p "$QUEUE_DIR"

GREEN="\033[32m"
BOLD="\033[1m"
RESET="\033[0m"

touch "$HISTORY_FILE"

while true; do
    echo -ne "${BOLD}${GREEN}▲${RESET} / "
    cmd=$(cat)

    [ -z "$cmd" ] && continue
    [ "$cmd" = "exit" ] && break

    grep -qxF "$cmd" "$HISTORY_FILE" 2>/dev/null || echo "$cmd" >> "$HISTORY_FILE"
    tail -100 "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" 2>/dev/null && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE" 2>/dev/null

    echo "$cmd" > "$QUEUE_DIR/incoming.cmd"
done
