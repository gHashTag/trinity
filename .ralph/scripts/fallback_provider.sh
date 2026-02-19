#!/bin/bash
# Fallback Provider — switch between Claude and GLM-5
# Called when Claude hits rate limit

RALPH_DIR="${RALPH_DIR:-.ralph}"
FALLBACK_STATE="$RALPH_DIR/internal/.fallback_state"
RATE_LIMIT_FILE="$RALPH_DIR/internal/.claude_rate_limit"

# Simple log function
log_status() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >&2
}

# Load config
source "$RALPH_DIR/.ralphrc" 2>/dev/null

# Check if we're in fallback mode
is_fallback_active() {
    if [[ -f "$FALLBACK_STATE" ]]; then
        local state=$(cat "$FALLBACK_STATE" 2>/dev/null)
        if [[ "$state" == "glm5" ]]; then
            return 0
        fi
    fi
    return 1
}

# Check if Claude rate limit has expired
is_claude_available() {
    if [[ -f "$RATE_LIMIT_FILE" ]]; then
        local reset_time=$(cat "$RATE_LIMIT_FILE" 2>/dev/null)
        local current_time=$(date +%s)
        if [[ "$reset_time" -gt "$current_time" ]]; then
            return 1  # Still in rate limit
        fi
    fi
    return 0  # Available or no rate limit
}

# Switch to GLM-5
activate_fallback() {
    echo "glm5" > "$FALLBACK_STATE"
    log_status "WARN" "🔄 Switched to GLM-5 (fallback mode)"
}

# Switch back to Claude
deactivate_fallback() {
    rm -f "$FALLBACK_STATE" 2>/dev/null
    log_status "SUCCESS" "🔄 Switched back to Claude (primary mode)"
}

# Execute with GLM-5
execute_glm5() {
    local prompt="$1"
    local output_file="$2"
    
    if [[ -z "$FALLBACK_API_KEY" ]]; then
        echo "ERROR: FALLBACK_API_KEY not configured" >&2
        return 1
    fi
    
    # Build request
    local request=$(cat << JSONEOF
{
    "model": "glm-5",
    "messages": [{"role": "user", "content": $(echo "$prompt" | jq -Rs .)}],
    "thinking": {"type": "enabled"},
    "max_tokens": 4096,
    "temperature": 1.0
}
JSONEOF
)
    
    # Execute
    curl -s -X POST "$FALLBACK_API_BASE/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $FALLBACK_API_KEY" \
        -d "$request" > "$output_file" 2>&1
    
    local exit_code=$?
    
    # Check for errors
    if grep -q '"error"' "$output_file" 2>/dev/null; then
        log_status "ERROR" "GLM-5 API error: $(cat "$output_file")"
        return 1
    fi
    
    return $exit_code
}

# Get current provider
get_current_provider() {
    if is_fallback_active; then
        echo "glm5"
    else
        echo "claude"
    fi
}

# Main entry point
case "${1:-}" in
    --check)
        if is_fallback_active; then
            echo "fallback:glm5"
        else
            echo "primary:claude"
        fi
        ;;
    --activate)
        activate_fallback
        ;;
    --deactivate)
        deactivate_fallback
        ;;
    --available)
        if is_claude_available; then
            echo "claude:available"
        else
            echo "claude:rate_limited"
        fi
        ;;
    --execute)
        execute_glm5 "$2" "$3"
        ;;
    *)
        echo "Usage: $0 --check|--activate|--deactivate|--available|--execute <prompt> <output_file>"
        exit 1
        ;;
esac
