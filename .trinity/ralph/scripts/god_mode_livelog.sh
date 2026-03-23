#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# GOD MODE LIVE LOG — Real-time Agent Activity Monitor (Russian)
# ═══════════════════════════════════════════════════════════════
# Monitors: Claude stream logs, GOD MODE events, MCP audit
# Append-only output (no clear, no tput cup)
# ═══════════════════════════════════════════════════════════════

set -uo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT" || exit 1

# ═══ DATA FILES ═══
LOG_DIR="$PROJECT_ROOT/.ralph/logs"
GOD_LOG="$PROJECT_ROOT/.ralph/god_mode_log.jsonl"
MCP_AUDIT="$PROJECT_ROOT/.trinity/mcp_audit.log"

# ═══ TRINITY COLORS ═══
GOLD="\033[38;5;220m"
CYAN="\033[38;5;075m"
GREEN="\033[38;5;042m"
RED="\033[38;5;196m"
YELLOW="\033[38;5;226m"
PURPLE="\033[38;5;141m"
GRAY="\033[38;5;244m"
WHITE="\033[38;5;255m"
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

# ═══ TOOL ICONS ═══
tool_icon() {
    case "$1" in
        Bash)           echo "🔧" ;;
        Read)           echo "📖" ;;
        Edit|Write)     echo "✏️ " ;;
        Grep|Glob)      echo "🔍" ;;
        Task)           echo "🤖" ;;
        WebFetch|WebSearch) echo "🌐" ;;
        Skill)          echo "⚡" ;;
        TodoWrite)      echo "📋" ;;
        NotebookEdit)   echo "📓" ;;
        AskUserQuestion) echo "❓" ;;
        KillShell)      echo "💀" ;;
        mcp__*)         echo "🔌" ;;
        *)              echo "▶ " ;;
    esac
}

# ═══ PIDS FOR CLEANUP ═══
CHILD_PIDS=()

cleanup() {
    for pid in "${CHILD_PIDS[@]}"; do
        kill "$pid" 2>/dev/null
    done
    wait 2>/dev/null
}
trap cleanup EXIT INT TERM

# ═══ FIND LATEST STREAM LOG ═══
find_latest_stream() {
    ls -t "$LOG_DIR"/*_stream.log 2>/dev/null | head -1
}

# ═══ HEADER ═══
echo ""
echo -e "${BOLD}${GOLD}═══════════════════════════════════${RESET}"
echo -e "${BOLD}${GOLD}  📡 LIVE ЛОГИ АГЕНТОВ${RESET}"
echo -e "${BOLD}${GOLD}═══════════════════════════════════${RESET}"
echo -e "  ${DIM}Мониторинг: stream + god_mode + mcp${RESET}"
echo ""

# ═══ MONITOR: STREAM LOGS ═══
# Parses Claude Code stream JSONL for tool_use and text events
monitor_stream() {
    local current_file=""
    local last_text_time=0

    while true; do
        local latest
        latest=$(find_latest_stream)

        if [ -z "$latest" ]; then
            echo -e "  ${DIM}⏳ Ожидание stream логов...${RESET}"
            sleep 10
            continue
        fi

        # New file detected — announce and restart tail
        if [ "$latest" != "$current_file" ]; then
            current_file="$latest"
            local fname
            fname=$(basename "$current_file")
            echo -e "  ${PURPLE}━━━ Новая сессия: ${fname} ━━━${RESET}"
        fi

        # tail -f with jq parsing, line by line
        tail -n 0 -f "$current_file" 2>/dev/null | while IFS= read -r line; do
            local ltype
            ltype=$(echo "$line" | jq -r '.type // empty' 2>/dev/null) || continue

            local now
            now=$(date '+%H:%M:%S')

            if [ "$ltype" = "assistant" ]; then
                # Full tool_use message with input
                local tool_name input_summary
                tool_name=$(echo "$line" | jq -r '.message.content[0].name // empty' 2>/dev/null) || true
                if [ -n "$tool_name" ]; then
                    # Extract first useful input field
                    input_summary=$(echo "$line" | jq -r '
                        .message.content[0].input |
                        if .command then .command
                        elif .file_path then .file_path
                        elif .pattern then .pattern
                        elif .query then .query
                        elif .prompt then .prompt
                        elif .skill then .skill
                        elif .url then .url
                        elif .description then .description
                        else (to_entries | .[0] | "\(.key)=\(.value)") // ""
                        end
                    ' 2>/dev/null) || true

                    # Truncate
                    [ ${#input_summary} -gt 45 ] && input_summary="${input_summary:0:42}..."

                    local icon
                    icon=$(tool_icon "$tool_name")
                    echo -e "  ${DIM}${now}${RESET} ${icon} ${CYAN}${BOLD}${tool_name}${RESET}: ${WHITE}${input_summary}${RESET}"
                fi

            elif [ "$ltype" = "stream_event" ]; then
                local event_type
                event_type=$(echo "$line" | jq -r '.event.type // empty' 2>/dev/null) || continue

                if [ "$event_type" = "content_block_start" ]; then
                    local block_type tool_name
                    block_type=$(echo "$line" | jq -r '.event.content_block.type // empty' 2>/dev/null) || true
                    if [ "$block_type" = "tool_use" ]; then
                        tool_name=$(echo "$line" | jq -r '.event.content_block.name // empty' 2>/dev/null) || true
                        if [ -n "$tool_name" ]; then
                            local icon
                            icon=$(tool_icon "$tool_name")
                            echo -e "  ${DIM}${now}${RESET} ${icon} ${CYAN}${tool_name}${RESET}${DIM}...${RESET}"
                        fi
                    fi

                elif [ "$event_type" = "content_block_delta" ]; then
                    # Text thinking — show only every 5 seconds max
                    local delta_type
                    delta_type=$(echo "$line" | jq -r '.event.delta.type // empty' 2>/dev/null) || true
                    if [ "$delta_type" = "text_delta" ]; then
                        local now_ts
                        now_ts=$(date +%s)
                        if [ $((now_ts - last_text_time)) -ge 5 ]; then
                            last_text_time=$now_ts
                            local text
                            text=$(echo "$line" | jq -r '.event.delta.text // empty' 2>/dev/null) || true
                            # Only show non-trivial text (>10 chars, skip whitespace)
                            text=$(echo "$text" | tr -d '\n' | sed 's/^[[:space:]]*//')
                            if [ ${#text} -gt 10 ]; then
                                [ ${#text} -gt 50 ] && text="${text:0:47}..."
                                echo -e "  ${DIM}${now} 💬 ${text}${RESET}"
                            fi
                        fi
                    fi

                elif [ "$event_type" = "message_stop" ]; then
                    echo -e "  ${DIM}${now}${RESET} ${GREEN}✓ Сообщение завершено${RESET}"
                fi
            fi
        done

        # tail -f ended (file rotated?) — loop will pick up new file
        sleep 2
    done
}

# ═══ MONITOR: GOD MODE EVENTS ═══
monitor_god_events() {
    # Wait for file to exist
    while [ ! -f "$GOD_LOG" ]; do
        sleep 10
    done

    echo -e "  ${GOLD}━━━ GOD MODE события ━━━${RESET}"

    tail -n 0 -f "$GOD_LOG" 2>/dev/null | while IFS= read -r line; do
        local event ts branch now
        event=$(echo "$line" | jq -r '.event // "?"' 2>/dev/null) || continue
        ts=$(echo "$line" | jq -r '.ts // 0' 2>/dev/null) || true
        branch=$(echo "$line" | jq -r '.branch // "?"' 2>/dev/null) || true
        now=$(date -r "$ts" '+%H:%M:%S' 2>/dev/null || date '+%H:%M:%S')

        local icon="📡"
        case "$event" in
            agent_stop)   icon="🛑" ;;
            commit)       icon="💾" ;;
            error)        icon="❌" ;;
            *)            icon="📡" ;;
        esac

        echo -e "  ${DIM}${now}${RESET} ${icon} ${YELLOW}${event}${RESET} (${branch})"
    done
}

# ═══ MONITOR: MCP AUDIT ═══
monitor_mcp_audit() {
    # Wait for file to exist
    while [ ! -f "$MCP_AUDIT" ]; do
        sleep 10
    done

    echo -e "  ${PURPLE}━━━ MCP аудит ━━━${RESET}"

    tail -n 0 -f "$MCP_AUDIT" 2>/dev/null | while IFS= read -r line; do
        local tool_name decision reason now
        tool_name=$(echo "$line" | jq -r '.tool_name // "?"' 2>/dev/null) || continue
        decision=$(echo "$line" | jq -r '.decision // "?"' 2>/dev/null) || true
        now=$(date '+%H:%M:%S')

        local icon="❓"
        local color="$WHITE"
        if [ "$decision" = "allow" ]; then
            icon="✅"
            color="$GREEN"
        elif [ "$decision" = "deny" ]; then
            icon="❌"
            color="$RED"
        fi

        echo -e "  ${DIM}${now}${RESET} ${icon} ${color}${tool_name}${RESET} → ${decision}"
    done
}

# ═══ LAUNCH ALL MONITORS ═══

monitor_stream &
CHILD_PIDS+=($!)

monitor_god_events &
CHILD_PIDS+=($!)

monitor_mcp_audit &
CHILD_PIDS+=($!)

# Wait for all — script runs until killed
wait
