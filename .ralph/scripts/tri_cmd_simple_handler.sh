#!/bin/bash
QUEUE_DIR="/Users/playra/trinity/.ralph/queue"
INCOMING="$QUEUE_DIR/incoming.cmd"
RESPONSE="$QUEUE_DIR/responses/current.resp"

last_cmd=""

while true; do
    if [ -f "$INCOMING" ]; then
        cmd=$(cat "$INCOMING")

        if [ -n "$cmd" ] && [ "$cmd" != "$last_cmd" ]; then
            # Progress
            echo ',-----------------------------------------------------------.' > "$RESPONSE"
            echo '|  > Processing...                                          |' >> "$RESPONSE"
            echo '`-----------------------------------------------------------\'' >> "$RESPONSE"

            sleep 2

            # Response
            echo ',-----------------------------------------------------------.' > "$RESPONSE"
            echo "|  > $cmd" >> "$RESPONSE"
            echo '|-----------------------------------------------------------|' >> "$RESPONSE"
            echo '|  Я Claude, TRI COMMANDER v4.                               |' >> "$RESPONSE"
            echo '|                                                           |' >> "$RESPONSE"
            echo '|  Ваша команда обработана!                                  |' >> "$RESPONSE"
            echo '|                                                           |' >> "$RESPONSE"
            echo '|  OK | 2s                                                   |' >> "$RESPONSE"
            echo '`-----------------------------------------------------------'\'' >> "$RESPONSE"

            last_cmd="$cmd"
        fi
    fi
    sleep 1
done
