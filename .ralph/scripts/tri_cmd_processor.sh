#!/bin/bash
# TRI COMMANDER Processor — Обрабатывает команды и вызывает Claude
# Запускается в фоне, следит за incoming.cmd

RALPH_DIR="/Users/playra/trinity"
QUEUE_DIR="$RALPH_DIR/.ralph/queue"
INCOMING="$QUEUE_DIR/incoming.cmd"
RESPONSE="$QUEUE_DIR/responses/current.resp"
PROCESSING="$QUEUE_DIR/.processing.lock"
PING="$QUEUE_DIR/.ping"

mkdir -p "$QUEUE_DIR"

last_cmd=""
last_md5=""

echo "=== TRI COMMANDER Processor Started ===" >> "$QUEUE_DIR/processor.log"

while true; do
    if [ -f "$INCOMING" ]; then
        current_md5=$(md5 "$INCOMING" 2>/dev/null | awk '{print $NF}')

        # Новая команда обнаружена
        if [ "$current_md5" != "$last_md5" ]; then
            cmd=$(cat "$INCOMING" 2>/dev/null)

            # Проверяем что команда не пустая
            if [ -n "$cmd" ] && [ "$cmd" != "$last_cmd" ]; then
                echo "[$(date)] Processing: $cmd" >> "$QUEUE_DIR/processor.log"

                # Создаём ping файл для Claude
                cat > "$PING" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "command": "$cmd",
  "status": "pending"
}
EOF

                last_cmd="$cmd"
                last_md5="$current_md5"

                # Временный ответ
                cat > "$RESPONSE" << EOF
=== TRI COMMANDER ===
CMD: $cmd

Статус: Команда получена!
Ожидание обработки...

EOF
            fi
        fi
    fi

    sleep 1
done
