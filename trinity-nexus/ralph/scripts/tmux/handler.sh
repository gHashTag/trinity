#!/bin/bash
# TRI COMMANDER v4 — Simplified Real Handler with API Failover
cd /Users/playra/trinity/trinity-nexus || exit 1

INCOMING="ralph/queue/incoming.cmd"
RESPONSE="ralph/queue/responses/current.resp"
STATE_FILE="ralph/queue/.handler_state"
KEYS_CONF="ralph/queue/.api_keys.conf"
ACTIVE_KEY_FILE="ralph/queue/.active_key"

MODEL="claude-sonnet-4-20250514"

# Initialize API keys from config or env
init_api_keys() {
    mkdir -p "$(dirname "$RESPONSE")"

    # Load config if exists
    if [ -f "$KEYS_CONF" ]; then
        . "$KEYS_CONF"
    fi

    # Set keys from env if config empty
    [ -z "$KEY_1" ] && KEY_1="${ANTHROPIC_AUTH_TOKEN}"
    [ -z "$BASE_URL" ] && BASE_URL="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}"

    # Set KEY_2 from env if available
    [ -z "$KEY_2" ] && KEY_2="${ANTHROPIC_AUTH_TOKEN_2}"

    # Get current active index
    if [ -f "$ACTIVE_KEY_FILE" ]; then
        CURRENT_INDEX=$(cat "$ACTIVE_KEY_FILE")
    else
        CURRENT_INDEX=1
        echo "$CURRENT_INDEX" > "$ACTIVE_KEY_FILE"
    fi

    # Select active key
    if [ "$CURRENT_INDEX" = "1" ]; then
        API_KEY="$KEY_1"
    else
        API_KEY="$KEY_2"
    fi

    # Validate we have at least one key
    if [ -z "$API_KEY" ]; then
        echo "ERROR: No API key configured. Set ANTHROPIC_AUTH_TOKEN or edit $KEYS_CONF"
        exit 1
    fi
}

# Switch to backup API key
switch_api_key() {
    local old_index="$CURRENT_INDEX"

    if [ "$CURRENT_INDEX" = "1" ] && [ -n "$KEY_2" ]; then
        CURRENT_INDEX=2
    elif [ "$CURRENT_INDEX" = "2" ] && [ -n "$KEY_1" ]; then
        CURRENT_INDEX=1
    else
        echo "WARN: No backup key available"
        return 1
    fi

    echo "$CURRENT_INDEX" > "$ACTIVE_KEY_FILE"
    if [ "$CURRENT_INDEX" = "1" ]; then
        API_KEY="$KEY_1"
    else
        API_KEY="$KEY_2"
    fi

    echo "[$(date '+%H:%M:%S')] Switched API key: #$old_index → #$CURRENT_INDEX" >> "ralph/queue/api_failover.log"
    return 0
}

# Initialize
init_api_keys
mkdir -p "$(dirname "$RESPONSE")"

# Log startup with active key
echo "[$(date '+%H:%M:%S')] Handler started with KEY #$CURRENT_INDEX" >> "ralph/queue/api_failover.log"

echo "init" > "$STATE_FILE"

write_box() {
    local cmd="$1"
    local resp="$2"
    local dur="${3:-0}"

    printf ',-----------------------------------------------------------.\n' > "$RESPONSE"
    printf '|  > %s\n' "$cmd" >> "$RESPONSE"
    printf '|-----------------------------------------------------------|\n' >> "$RESPONSE"
    printf '%s\n' "$resp" | fold -w 58 -s | sed 's/^/|  /' >> "$RESPONSE"
    printf '|                                                           |\n' >> "$RESPONSE"
    printf '|  OK | %ss                                           |\n' "$dur" >> "$RESPONSE"
    printf "'\`-----------------------------------------------------------'\n" >> "$RESPONSE"
}

get_status() {
    local json="/Users/playra/trinity/.ralph/logs/status.json"
    if [ -f "$json" ]; then
        local st=$(jq -r '.status' "$json")
        local lc=$(jq -r '.loop_count' "$json")
        local ca=$(jq -r '.calls_made_this_hour' "$json")
        local ma=$(jq -r '.max_calls_per_hour' "$json")
        echo "Status: $st | Loop: #$lc"
        echo "API: $ca/$ma"
    else
        echo "Status: unknown"
        echo "API: ?/?"
    fi
}

get_tasks() {
    local fp=""
    [ -f "/Users/playra/trinity/.ralph/fix_plan.md" ] && fp="/Users/playra/trinity/.ralph/fix_plan.md"
    [ -f "/Users/playra/trinity/.ralph/internal/fix_plan.md" ] && fp="/Users/playra/trinity/.ralph/internal/fix_plan.md"

    if [ -n "$fp" ] && [ -f "$fp" ]; then
        local all=$(grep -c "^- \[.\]" "$fp")
        local done=$(grep -c "^- \[x\]" "$fp")
        echo "Tasks: $done/$all"
    else
        echo "Tasks: ?/?"
    fi
}

call_claude() {
    local cmd="$1"
    local prompt="You are TRI COMMANDER AI assistant. You HAVE access to all project files via tools. Answer briefly (3-5 sentences), in Russian. You CAN run commands, read files, write code. Command: $cmd"

    local req=$(jq -n --arg m "$MODEL" --arg p "$prompt" \
        '{model: $m, max_tokens: 1500, messages: [{role: "user", content: $p}]}')

    # Try API call with rate limit detection
    local response=$(curl -s "$BASE_URL/v1/messages" \
        -H "x-api-key: $API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d "$req")

    local ans=$(echo "$response" | jq -r '.content[0].text // "Error"')
    local error=$(echo "$response" | jq -r '.error.type // empty')

    # Check for rate limit errors
    if [ "$error" = "rate_limit_error" ] || echo "$ans" | grep -qi "rate limit"; then
        local old_idx="$CURRENT_INDEX"
        echo "[RATE LIMIT] Switching API key..." >> "ralph/queue/api_failover.log"
        if switch_api_key; then
            # Write chat notification about key switch
            write_box "⚠️ SYSTEM" "🔄 Rate Limit detected!\n\nSwitching: KEY #$old_idx → KEY #$CURRENT_INDEX\nRetrying request..." "0"

            # Retry with new key
            response=$(curl -s "$BASE_URL/v1/messages" \
                -H "x-api-key: $API_KEY" \
                -H "anthropic-version: 2023-06-01" \
                -H "content-type: application/json" \
                -d "$req")
            ans=$(echo "$response" | jq -r '.content[0].text // "Error after retry"')
            echo "[RETRY] Success with key #$CURRENT_INDEX" >> "ralph/queue/api_failover.log"
        else
            write_box "⚠️ ERROR" "❌ Rate Limit: No backup keys available!\n\nWait a few minutes or add KEY_2 to:\nralph/queue/.api_keys.conf" "0"
            ans=""
        fi
    fi

    echo "$ans"
}

while true; do
    if [ -f "$INCOMING" ]; then
        current=$(cat "$INCOMING")
        last=$(cat "$STATE_FILE")

        if [ -n "$current" ] && [ "$current" != "$last" ]; then
            echo "$current" > "$STATE_FILE"

            case "$current" in
                "статус"*|"status"*)
                    write_box "$current" "$(get_status; get_tasks)" "0"
                    ;;
                "что делать"*|"задачи"*)
                    local fp=""
                    [ -f "/Users/playra/trinity/.ralph/fix_plan.md" ] && fp="/Users/playra/trinity/.ralph/fix_plan.md"
                    [ -f "/Users/playra/trinity/.ralph/internal/fix_plan.md" ] && fp="/Users/playra/trinity/.ralph/internal/fix_plan.md"
                    if [ -n "$fp" ]; then
                        write_box "$current" "$(grep '^- \[ \]' "$fp" | head -3 | sed 's/^- \[ \] //')" "0"
                    else
                        write_box "$current" "No tasks found" "0"
                    fi
                    ;;
                *)
                    write_box "$current" "$(call_claude "$current")" "2"
                    ;;
            esac
        fi
    fi
    sleep 1
done
