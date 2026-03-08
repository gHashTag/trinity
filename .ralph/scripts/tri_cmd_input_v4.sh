#!/bin/bash
# TRI COMMANDER v4 — INPUT с историей и readline
# Features: readline (↑/↓), blinking prompt, history file, no technical paths

RALPH_DIR="/Users/playra/trinity"
QUEUE_DIR="$RALPH_DIR/.ralph/queue"
HISTORY_FILE="$QUEUE_DIR/.history"
mkdir -p "$QUEUE_DIR"

# Colors
CYAN="\033[38;5;075m"
GREEN="\033[38;5;042m"
GRAY="\033[38;5;244m"
BOLD="\033[1m"
RESET="\033[0m"

# Blinking prompt (tmux compatible)
BLINK_ON="\033[5m"
BLINK_OFF="\033[0m"

# Инициализация истории
touch "$HISTORY_FILE"
HISTORY=$(tail -20 "$HISTORY_FILE" 2>/dev/null)

# Показ последних команд при старте
if [ -n "$HISTORY" ]; then
    echo -e "${GRAY}Последние команды:${RESET}"
    echo "$HISTORY" | nl -w2 -s'. ' | tail -5
    echo ""
fi

echo -e "${CYAN}TRI COMMANDER v4${RESET} — используй ↑/↓ для истории"
echo ""

# REPL с readline
while true; do
    # Blinking prompt
    echo -ne "${CYAN}${BLINK_ON}►${BLINK_OFF}${RESET} "

    # readline с историей и стрелками
    history -r "$HISTORY_FILE" 2>/dev/null
    read -e -r cmd < /dev/tty || break

    [ -z "$cmd" ] && continue

    # Сохранить в историю (без дубликатов)
    grep -qxF "$cmd" "$HISTORY_FILE" 2>/dev/null || echo "$cmd" >> "$HISTORY_FILE"

    # Ограничить историю 100 строками
    tail -100 "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" 2>/dev/null && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE" 2>/dev/null

    # Отправить в очередь
    echo "$cmd" > "$QUEUE_DIR/incoming.cmd"

    # Визуальная обратная связь (без путей!)
    echo -e "${GREEN}✓ Queued: $cmd${RESET}"
    echo ""
done
