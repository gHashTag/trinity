#!/bin/bash
# TRI COMMANDER v4 — Simplified Real Handler
cd /Users/playra/trinity || exit 1

INCOMING=".ralph/queue/incoming.cmd"
RESPONSE=".ralph/queue/responses/current.resp"
STATE_FILE=".ralph/queue/.handler_state"

# Try env vars, then fallback to file
API_KEY="${ANTHROPIC_AUTH_TOKEN}"
BASE_URL="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}"
MODEL="claude-sonnet-4-20250514"

# Fallback 1: read from creds file
if [ -z "$API_KEY" ] && [ -f ".ralph/queue/.creds" ]; then
    API_KEY=$(grep "^API_KEY=" .ralph/queue/.creds | cut -d= -f2)
    BASE_URL=$(grep "^BASE_URL=" .ralph/queue/.creds | cut -d= -f2)
fi

# Fallback 2: read from Claude Code config
if [ -z "$API_KEY" ] && [ -f "$HOME/.config/claude-code/config.json" ]; then
    API_KEY=$(jq -r '.apiKey // empty' "$HOME/.config/claude-code/config.json" 2>/dev/null)
    BASE_URL=$(jq -r '.apiUrl // "https://api.anthropic.com"' "$HOME/.config/claude-code/config.json" 2>/dev/null)
fi

mkdir -p "$(dirname "$RESPONSE")"

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
    local json=".ralph/logs/status.json"
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
    [ -f ".ralph/fix_plan.md" ] && fp=".ralph/fix_plan.md"
    [ -f ".ralph/internal/fix_plan.md" ] && fp=".ralph/internal/fix_plan.md"

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

    local ans=$(curl -s "$BASE_URL/v1/messages" \
        -H "x-api-key: $API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d "$req" | jq -r '.content[0].text // "Error"')

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
                    [ -f ".ralph/fix_plan.md" ] && fp=".ralph/fix_plan.md"
                    [ -f ".ralph/internal/fix_plan.md" ] && fp=".ralph/internal/fix_plan.md"
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
