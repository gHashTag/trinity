#!/bin/bash
# OUTPUT Monitor v4 — watch-style display
RESPONSE=".ralph/queue/responses/current.resp"
LAST_MD5=""

while true; do
    if [ -f "$RESPONSE" ]; then
        current_md5=$(md5 -q "$RESPONSE" 2>/dev/null)
        
        if [ "$current_md5" != "$LAST_MD5" ]; then
            clear
            cat "$RESPONSE"
            LAST_MD5="$current_md5"
        fi
    fi
    sleep 0.5
done
