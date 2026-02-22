#!/bin/bash
# OUTPUT Monitor — Chat only
cd /Users/playra/trinity

RESPONSE=".ralph/queue/responses/current.resp"
CHAT_FILE=".ralph/queue/chat_history.txt"
LAST_MD5=""

CYAN="\033[38;5;075m"
RESET="\033[0m"
BOLD="\033[1m"
P="  "

> "$CHAT_FILE"

process_response() {
    local resp="$1"
    local cmd=$(grep ">" "$resp" 2>/dev/null | sed 's/.*|  > //' | sed 's/ *|.*//' | head -1)
    local content=$(cat "$resp" 2>/dev/null | \
        grep "^|" | \
        grep -v "^|-" | \
        grep -v "^|," | \
        grep -v "^|'" | \
        grep -v "^|  >" | \
        grep -v "OK.*|" | \
        sed 's/^|  //;s/ *|$//' | \
        grep -v "^$")

    # Chat output
    echo ""
    echo -e "${P}${CYAN}►${RESET} ${BOLD}${cmd}${RESET}"
    echo ""
    echo "$content" | while IFS= read -r cl; do
        [ -n "$cl" ] && echo -e "${P}${cl}"
    done
    echo ""
}

# Show existing chat
clear
if [ -s "$CHAT_FILE" ]; then
    tail -50 "$CHAT_FILE"
fi

# Watch for response changes
while true; do
    if [ -f "$RESPONSE" ]; then
        current_md5=$(md5 -q "$RESPONSE" 2>/dev/null)
        if [ "$current_md5" != "$LAST_MD5" ]; then
            process_response "$RESPONSE"
            LAST_MD5="$current_md5"
        fi
    fi
    sleep 0.3
done
