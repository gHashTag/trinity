#!/bin/bash
# TRI COMMANDER — Simple version using tmux status bar
# User types commands, they go to queue, responses show in status bar

RALPH_DIR="/Users/playra/trinity"
QUEUE_DIR="$RALPH_DIR/.ralph/queue"
mkdir -p "$QUEUE_DIR"

# Colors
GREEN="\033[38;5;042m"
CYAN="\033[38;5;075m"
RESET="\033[0m"

echo -e "${CYAN}TRI COMMANDER${RESET} —type command, press Enter"
echo -e "${GREEN}Commands go to: $QUEUE_DIR/incoming.cmd${RESET}"
echo ""

# Simple REPL
while true; do
    echo -ne "${CYAN}►${RESET} "
    read -r cmd < /dev/tty || break

    [ -z "$cmd" ] && continue

    # Save command
    echo "$cmd" > "$QUEUE_DIR/incoming.cmd"

    # Show queued
    echo -e "${GREEN}✓ Queued: $cmd${RESET}"
    echo ""
done
