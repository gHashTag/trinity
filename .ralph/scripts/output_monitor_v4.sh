#!/bin/bash
# OUTPUT Monitor — Chat only + Model Status Bar
cd /Users/playra/trinity

RESPONSE=".ralph/queue/responses/current.resp"
CHAT_FILE=".ralph/queue/chat_history.txt"
LAST_MD5=""

NEON_GREEN="\033[1;92m"
CYAN="\033[1;96m"
GOLD="\033[1;93m"
GREEN="\033[1;92m"
RED="\033[1;91m"
ORANGE="\033[1;91m"
GRAY="\033[0;90m"
RESET="\033[0m"
BOLD="\033[1m"
P="  "

> "$CHAT_FILE"

# Model Status Bar - show at top, updates every 2 seconds
show_model_status_bar() {
    local model_name="Claude Sonnet 4.6"
    local model_status="online"
    local model_latency="380ms"
    local model_provider="Anthropic"
    local total_tokens="47.9M"
    local call_tokens="0"
    local call_time="0s"
    local is_thinking=false

    # Try to read from status file
    local model_status_file="/tmp/ralph-model-status.json"
    if [ -f "$model_status_file" ]; then
        model_name=$(jq -r '.current_model.name // "Claude Sonnet 4.6"' "$model_status_file" 2>/dev/null)
        model_status=$(jq -r '.current_model.status // "online"' "$model_status_file" 2>/dev/null)
        model_latency=$(jq -r '.current_model.latency_ms // "380"' "$model_status_file" 2>/dev/null)"ms"
        model_provider=$(jq -r '.current_model.provider // "anthropic"' "$model_status_file" 2>/dev/null | sed 's/^./\U&/')
        total_tokens=$(jq -r '.total_tokens // "47.9M"' "$model_status_file" 2>/dev/null)
        call_tokens=$(jq -r '.current_call.tokens // "0"' "$model_status_file" 2>/dev/null)
        call_time=$(jq -r '.current_call.duration // "0s"' "$model_status_file" 2>/dev/null)
        is_thinking=$(jq -r '.current_call.thinking // "false"' "$model_status_file" 2>/dev/null)
    fi

    # Also check current response for active call info
    if [ -f "$RESPONSE" ]; then
        local resp_time=$(grep "thinking" "$RESPONSE" 2>/dev/null | head -1 | sed 's/.*thinking //;s/ .*//')
        if [ -n "$resp_time" ]; then
            call_time="$resp_time"
            is_thinking=true
        fi
        local resp_tokens=$(grep "tokens" "$RESPONSE" 2>/dev/null | tail -1 | sed 's/.*[^0-9]\([0-9.]*[kKmM]\? tokens\).*/\1/')
        if [ -n "$resp_tokens" ] && [ "$resp_tokens" != "" ]; then
            call_tokens="$resp_tokens"
        fi
    fi

    local status_color="$GREEN"
    local status_text="${model_status}"
    if [ "$is_thinking" = "true" ]; then
        status_color="$CYAN"
        status_text="thinking ↓"
    elif [ "$model_status" = "degraded" ]; then
        status_color="$ORANGE"
    elif [ "$model_status" = "offline" ] || [ "$model_status" = "error" ]; then
        status_color="$RED"
    fi

    # Format tokens display
    local tokens_display="D:${total_tokens} W:139.8M"
    if [ "$call_tokens" != "0" ] && [ -n "$call_tokens" ]; then
        tokens_display="D:${total_tokens} · ↓ ${call_tokens}"
    fi

    # Time display
    local time_display="${call_time}"

    # Save cursor pos, show bar, restore
    tput sc
    tput cup 0 0
    echo -e "${GRAY}┌─ AI MODEL ─────────────────────────────────────────────────────────${RESET}"
    echo -ne "│ ${BOLD}${CYAN}${model_name}${RESET} │ ${status_color}${status_text}${RESET} │ ${time_display} │ ${tokens_display} "
    tput rc
    tput el
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

    # Chat output
    echo ""
    echo -e "${P}${NEON_GREEN}▲${RESET} ${BOLD}${cmd}${RESET}"
    echo ""
    echo "$content" | while IFS= read -r cl; do
        [ -n "$cl" ] && echo -e "${P}${NEON_GREEN}▼${RESET} ${cl}"
    done
    echo ""
}

# Show existing chat
clear
if [ -s "$CHAT_FILE" ]; then
    tail -50 "$CHAT_FILE"
fi

# Watch for response changes
last_status_update=0
while true; do
    # Update model status bar every 2 seconds
    now=$(date +%s)
    if [ $((now - last_status_update)) -ge 2 ]; then
        show_model_status_bar
        last_status_update=$now
    fi

    if [ -f "$RESPONSE" ]; then
        current_md5=$(md5 -q "$RESPONSE" 2>/dev/null)
        if [ "$current_md5" != "$LAST_MD5" ]; then
            process_response "$RESPONSE"
            LAST_MD5="$current_md5"
        fi
    fi
    sleep 0.3
done
