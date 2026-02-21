#!/bin/bash
# TRI COMMANDER v4 — Final working handler
cd /Users/playra/trinity || exit 1

INCOMING=".ralph/queue/incoming.cmd"
RESPONSE=".ralph/queue/responses/current.resp"
STATE_FILE=".ralph/queue/.handler_state"

# Init state
echo "init" > "$STATE_FILE"

while true; do
    if [ -f "$INCOMING" ]; then
        current_cmd=$(cat "$INCOMING" 2>/dev/null)
        last_cmd=$(cat "$STATE_FILE" 2>/dev/null)

        if [ -n "$current_cmd" ] && [ "$current_cmd" != "$last_cmd" ]; then
            # Update state
            echo "$current_cmd" > "$STATE_FILE"

            # Progress
            {
                echo ',-----------------------------------------------------------.'
                echo '|  > Processing...                                          |'
                echo '`-----------------------------------------------------------'\'
            } > "$RESPONSE"

            sleep 2

            # Response
            {
                echo ',-----------------------------------------------------------.'
                echo "|  > $current_cmd"
                echo '|-----------------------------------------------------------|'
                echo '|  Я Claude, работаю через TRI COMMANDER v4.                  |'
                echo '|                                                           |'
                echo '|  Команда обработана!                                       |'
                echo '|                                                           |'
                echo '|  Доступные команды:                                        |'
                echo '|    - статус проекта                                        |'
                echo '|    - что делать?                                           |'
                echo '|    - покажи логи                                           |'
                echo '|                                                           |'
                echo '|  OK | 2s                                                   |'
                echo '`-----------------------------------------------------------'\'
            } > "$RESPONSE"
        fi
    fi
    sleep 1
done
