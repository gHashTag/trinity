#!/bin/bash
# TRI COMMANDER Watcher — Instant command detection with fswatch
# Detects new commands and notifies Claude

RALPH_DIR="/Users/playra/trinity"
QUEUE_DIR="$RALPH_DIR/.ralph/queue"
INCOMING="$QUEUE_DIR/incoming.cmd"
PENDING="$QUEUE_DIR/.command_pending"

mkdir -p "$QUEUE_DIR"

# Trinity colors
GREEN="\033[38;5;042m"
CYAN="\033[38;5;075m"
RESET="\033[0m"
BOLD="\033[1m"

echo -e "${CYAN}TRI COMMANDER Watcher${RESET} запущен (fswatch mode)"

# Main watch loop — fswatch gives instant reaction
fswatch -0 -r "$INCOMING" 2>/dev/null | while read -d "" file; do
    if [ -f "$INCOMING" ] && [ -s "$INCOMING" ]; then
        cmd=$(cat "$INCOMING")
        id=$(date +%s)
        timestamp=$(date -Iseconds)

        # Create pending signal for Claude
        cat > "$PENDING" << EOF
{
  "timestamp": "$timestamp",
  "command": "$cmd",
  "id": "$id",
  "status": "pending"
}
EOF

        echo -e "${GREEN}→${RESET} Команда поймана: ${BOLD}$cmd${RESET}"
    fi
done
