#!/bin/bash
# TRI COMMANDER v4 — Handler с progress индикацией и форматированными ответами
# Uses clean ASCII format (no ANSI in file) for proper tail -f display

RALPH_DIR="/Users/playra/trinity"
QUEUE_DIR="$RALPH_DIR/.ralph/queue"
INCOMING="$QUEUE_DIR/incoming.cmd"
RESPONSE="$QUEUE_DIR/responses/current.resp"

mkdir -p "$QUEUE_DIR"

last_md5=""

# Progress indicator (clean ASCII)
show_progress() {
    cat > "$RESPONSE" << 'EOF'
,-------------------------------------------------------------------.
|                        TRI COMMANDER v4                            |
|                                                                   |
|  > Processing command...                                          |
|                                                                   |
|  Command received. Generating response...                         |
|                                                                   |
|  Please wait...                                                    |
|                                                                   |
`-------------------------------------------------------------------'
EOF
}

# Formatted response (clean ASCII)
format_response() {
    local cmd="$1"
    local response="$2"
    local duration="$3"

    cat > "$RESPONSE" << EOF
,-------------------------------------------------------------------.
|  > $cmd
|-------------------------------------------------------------------|
|                                                                   |
|  $response
|                                                                   |
|-------------------------------------------------------------------|
|  OK | ${duration}s
`-------------------------------------------------------------------'
EOF
}

# Main loop
while true; do
    if [ -f "$INCOMING" ] && [ -s "$INCOMING" ]; then
        current_md5=$(md5 "$INCOMING" 2>/dev/null | awk '{print $NF}')

        # Новая команда
        if [ "$current_md5" != "$last_md5" ]; then
            cmd=$(cat "$INCOMING" 2>/dev/null)
            start_time=$(date +%s)

            # Show progress for 2 seconds
            for i in {1..2}; do
                show_progress
                sleep 1
            done

            # Generate response
            end_time=$(date +%s)
            duration=$((end_time - start_time))

            response="Я Claude, работаю через TRI COMMANDER v4.0.

Твоя команда: \"$cmd\"

Что хочешь сделать? Доступные команды:
  - статус проекта
  - что делать?
  - покажи логи"

            format_response "$cmd" "$response" "$duration"

            last_md5="$current_md5"
        fi
    fi

    sleep 2
done
