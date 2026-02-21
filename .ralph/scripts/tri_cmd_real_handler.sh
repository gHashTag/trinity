#!/bin/bash
# TRI COMMANDER v4 — Real Claude API Handler
cd /Users/playra/trinity || exit 1

INCOMING=".ralph/queue/incoming.cmd"
RESPONSE=".ralph/queue/responses/current.resp"
STATE_FILE=".ralph/queue/.handler_state"
LOG_FILE=".ralph/queue/handler.log"

# Claude API
API_KEY="${ANTHROPIC_AUTH_TOKEN}"
BASE_URL="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}"
MODEL="claude-sonnet-4-20250514"

mkdir -p "$(dirname "$RESPONSE")"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Init
echo "init" > "$STATE_FILE"
log "Handler started with MODEL=$MODEL"

format_box() {
    local cmd="$1"
    local text="$2"
    local duration="${3:-0}"

    # Create response file
    {
        echo ",-----------------------------------------------------------."
        echo "|  > $cmd"
        echo "|-----------------------------------------------------------|"
        echo "$text" | fold -w 58 -s | while IFS= read -r line; do
            echo "|  $line"
        done
        echo "|                                                           |"
        echo "|  OK | ${duration}s                                           |"
        echo "\`-----------------------------------------------------------'"
    } > "$RESPONSE"
}

call_claude() {
    local cmd="$1"
    local start=$(date +%s)

    log "Calling Claude API for: $cmd"

    # Build prompt (clean, no newlines inside JSON)
    local prompt="Ты работаешь в TRI COMMANDER v4. Отвечай КРАТКО (3-5 предложений), без Markdown, только ASCII. Команда: $cmd. Доступные команды: статус проекта, что делать?, покажи логи. Отвечай на русском."

    # Build JSON with jq to avoid escaping issues
    local request=$(jq -n \
        --arg model "$MODEL" \
        --arg prompt "$prompt" \
        '{
            model: $model,
            max_tokens: 2000,
            messages: [{role: "user", content: $prompt}]
        }')

    # Call API
    local response=$(curl -s "$BASE_URL/v1/messages" \
        -H "x-api-key: $API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d "$request" 2>&1)

    local end=$(date +%s)
    local duration=$((end - start))

    # Parse response
    if echo "$response" | grep -q '"content"'; then
        local content=$(echo "$response" | jq -r '.content[0].text' 2>/dev/null)
        if [ -n "$content" ]; then
            format_box "$cmd" "$content" "$duration"
            log "Response written (${duration}s)"
            return 0
        fi
    fi

    # Error fallback
    log "API Error: $response"
    format_box "$cmd" "Ошибка API. Проверьте лог: $LOG_FILE" "$duration"
    return 1
}

while true; do
    if [ -f "$INCOMING" ]; then
        current_cmd=$(cat "$INCOMING" 2>/dev/null)
        last_cmd=$(cat "$STATE_FILE" 2>/dev/null)

        if [ -n "$current_cmd" ] && [ "$current_cmd" != "$last_cmd" ]; then
            echo "$current_cmd" > "$STATE_FILE"

            # Process command
            case "$current_cmd" in
                "статус проекта"|"статус"|"status")
                    # Build status text via file to avoid newline issues
                    local status_json=".ralph/logs/status.json"
                    local status_file="/tmp/ralph_status_$$.txt"

                    {
                        if [ -f "$status_json" ]; then
                            local st=$(jq -r '.status' "$status_json" 2>/dev/null)
                            local lc=$(jq -r '.loop_count' "$status_json" 2>/dev/null)
                            local ca=$(jq -r '.calls_made_this_hour' "$status_json" 2>/dev/null)
                            local ma=$(jq -r '.max_calls_per_hour' "$status_json" 2>/dev/null)
                            echo "Status: $st | Loop: #$lc"
                            echo "API: $ca/$ma | Tasks:"
                        else
                            echo "Status: unknown | Loop: #?"
                            echo "API: ?/? | Tasks:"
                        fi

                        # Add tasks count
                        local fix_plan=""
                        [ -f ".ralph/fix_plan.md" ] && fix_plan=".ralph/fix_plan.md"
                        [ -f ".ralph/internal/fix_plan.md" ] && fix_plan=".ralph/internal/fix_plan.md"

                        if [ -n "$fix_plan" ] && [ -f "$fix_plan" ]; then
                            local tasks=$(grep -c "^- \[.\]" "$fix_plan" 2>/dev/null || echo "?")
                            local done=$(grep -c "^- \[x\]" "$fix_plan" 2>/dev/null || echo "0")
                            echo "$done/$tasks"
                        else
                            echo "?/?"
                        fi
                    } > "$status_file"

                    format_box "$current_cmd" "$(cat "$status_file")" "0"
                    rm -f "$status_file"
                    ;;
                "что делать"*|"задачи"*)
                    local fix_plan=""
                    [ -f ".ralph/fix_plan.md" ] && fix_plan=".ralph/fix_plan.md"
                    [ -f ".ralph/internal/fix_plan.md" ] && fix_plan=".ralph/internal/fix_plan.md"

                    if [ -n "$fix_plan" ] && [ -f "$fix_plan" ]; then
                        local top_tasks=$(grep "^- \[ \]" "$fix_plan" 2>/dev/null | head -3 | sed 's/^- \[ \] //')
                        format_box "$current_cmd" "Top 3 tasks:
$top_tasks
Используй: ralph --monitor" "0"
                    else
                        format_box "$current_cmd" "fix_plan.md не найден. Используй: ralph --monitor" "0"
                    fi
                    ;;
                "покажи логи"|"логи")
                    local log_file=".ralph/logs/ralph.log"
                    if [ -f "$log_file" ]; then
                        tail -5 "$log_file" > /tmp/ralph_log_tail.txt
                        format_box "$current_cmd" "$(cat /tmp/ralph_log_tail.txt)" "0"
                    else
                        format_box "$current_cmd" "Логов нет" "0"
                    fi
                    ;;
                *)
                    call_claude "$current_cmd"
                    ;;
            esac
        fi
    fi
    sleep 1
done
