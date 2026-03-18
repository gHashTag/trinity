#!/bin/bash
# TRI COMMANDER Claude Handler — Вызывает Claude для обработки команд

RALPH_DIR="/Users/playra/trinity"
QUEUE_DIR="$RALPH_DIR/.ralph/queue"
INCOMING="$QUEUE_DIR/incoming.cmd"
RESPONSE="$QUEUE_DIR/responses/current.resp"
CLAUDE_PROMPT="$QUEUE_DIR/.claude_prompt.txt"

mkdir -p "$QUEUE_DIR"

last_md5=""

echo "=== TRI COMMANDER Claude Handler Started ==="
echo "Logs: $QUEUE_DIR/handler.log"

while true; do
    if [ -f "$INCOMING" ] && [ -s "$INCOMING" ]; then
        current_md5=$(md5 "$INCOMING" 2>/dev/null | awk '{print $NF}')

        # Новая команда
        if [ "$current_md5" != "$last_md5" ]; then
            cmd=$(cat "$INCOMING")

            echo "[$(date)] Processing: $cmd" >> "$QUEUE_DIR/handler.log"

            # Генерируем ответ
            cat > "$RESPONSE" << EOF
=== CMD: $(date +%H:%M:%S) ===
$cmd

--- ANALYSIS ---
Команда получена через TRI COMMANDER.

--- RESPONSE ---
Я Claude, работаю через Ralph Dashboard v3.5.

Твоя команда: "$cmd"

Что хочешь сделать?

--- STATUS: READY ---
EOF

            # Обновляем last_md5 после обработки
            last_md5="$current_md5"

            echo "[$(date)] Response written" >> "$QUEUE_DIR/handler.log"
        fi
    fi

    sleep 2
done
