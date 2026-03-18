#!/bin/bash
# OUTPUT Monitor — Chat only (simplified, no status bar)
cd /Users/playra/trinity/trinity-nexus

RESPONSE="ralph/queue/responses/current.resp"
CHAT_FILE="ralph/queue/chat_history.txt"
INCOMING="ralph/queue/incoming.cmd"
LAST_MD5=""
LAST_INCOMING_MD5=""
LOADING=false
LOADING_FRAME=0

LIME="\033[38;5;154m"
CYAN="\033[1;96m"
YELLOW="\033[38;5;226m"
RESET="\033[0m"
BOLD="\033[1m"
P="  "

touch "$CHAT_FILE"

# Loading animation frames
SPINNER=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")

show_loading() {
    local frame="${SPINNER[$LOADING_FRAME]}"
    printf "\r${P}${YELLOW}${frame} thinking...${RESET}"
    LOADING_FRAME=$(( (LOADING_FRAME + 1) % 10 ))
}

hide_loading() {
    printf "\r${P}                         \r"
}

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

    hide_loading
    LOADING=false

    # Chat output - save to file and display
    local first=true
    {
        echo ""
        echo -e "${P}${LIME}▲${RESET} ${BOLD}${cmd}${RESET}"
        echo ""
        echo "$content" | while IFS= read -r cl; do
            if [ -n "$cl" ]; then
                if $first; then
                    echo -e "${P}${LIME}▼${RESET} ${cl}"
                    first=false
                else
                    echo -e "${P}  ${cl}"
                fi
            fi
        done
        echo ""
    } | tee -a "$CHAT_FILE"
}

# Show existing chat
if [ -s "$CHAT_FILE" ]; then
    tail -50 "$CHAT_FILE"
fi

# Get initial incoming.md5
if [ -f "$INCOMING" ]; then
    LAST_INCOMING_MD5=$(md5 -q "$INCOMING" 2>/dev/null)
fi

# Watch for response changes
while true; do
    # Check if new command was sent
    if [ -f "$INCOMING" ]; then
        current_incoming_md5=$(md5 -q "$INCOMING" 2>/dev/null)
        if [ "$current_incoming_md5" != "$LAST_INCOMING_MD5" ]; then
            LAST_INCOMING_MD5="$current_incoming_md5"
            LOADING=true
        fi
    fi

    # Show loading animation if waiting for response
    if $LOADING; then
        show_loading
    fi

    # Check for response
    if [ -f "$RESPONSE" ]; then
        current_md5=$(md5 -q "$RESPONSE" 2>/dev/null)
        if [ "$current_md5" != "$LAST_MD5" ]; then
            process_response "$RESPONSE"
            LAST_MD5="$current_md5"
        fi
    fi
    sleep 0.1
done
