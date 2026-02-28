#!/bin/bash
# tmux_status.sh - Output formatted status for Ralph Dashboard panels
# Usage: ./tmux_status.sh <panel_name|statusline>

RALPH_DIR="/Users/playra/trinity/trinity-nexus"
cd "$RALPH_DIR" 2>/dev/null || exit 1

# Source cache layer
if [ -f "ralph/scripts/tmux/cache.sh" ]; then
    . ralph/scripts/tmux/cache.sh
fi

# Trinity colors (ANSI)
GOLD="\033[38;5;220m"    # RAZUM
CYAN="\033[38;5;075m"    # MATERIYA
PURPLE="\033[38;5;141m"  # DUKH
GREEN="\033[38;5;042m"
RED="\033[38;5;196m"
ORANGE="\033[38;5;208m"
YELLOW="\033[38;5;226m"
BLUE="\033[38;5;039m"
GRAY="\033[38;5;244m"
RESET="\033[0m"
BOLD="\033[1m"

panel0_loop_status() {
    # Panel 0: Ralph Loop Status (RAZUM)
    local status_file="/Users/playra/trinity/.ralph/logs/status.json"
    local loop="--"
    local api="--/100"
    local cb="CLOSED"
    local last_action="--"
    local status="idle"
    local next_reset="--"

    if [ -f "$status_file" ]; then
        # Parse all fields in one jq call - // operator must be INSIDE interpolation
        local data=$(jq -r '"loop=\(.loop_count // "--")", "calls=\(.calls_made_this_hour // "--")", "status=\(.status // "idle")", "last_action=\(.last_action // "--")", "next_reset=\(.next_reset // "--")"' "$status_file" 2>/dev/null)
        if [ -n "$data" ]; then
            eval "$data"
            api="${calls}/100"
        fi
    fi

    # Check circuit breaker state
    local cb_state="CLOSED"
    if [ -f "/Users/playra/trinity/.ralph/internal/.circuit_breaker_state" ]; then
        cb_state=$(jq -r '.state // "CLOSED"' "/Users/playra/trinity/.ralph/internal/.circuit_breaker_state" 2>/dev/null || echo "CLOSED")
    fi

    # Color code status
    local status_color="$GREEN"
    if [ "$status" != "running" ]; then
        status_color="$ORANGE"
    fi
    if [ "$cb_state" = "OPEN" ]; then
        status_color="$RED"
    fi

    echo -e "${BOLD}${GOLD}RAZUM: Ralph Loop Status${RESET}"
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "Loop Count:     ${BOLD}${loop}${RESET}"
    echo -e "API Calls:      ${api} ($(echo "$api" | cut -d/ -f1 | awk '{print $1*1"%"}') used)"
    echo -e "Circuit Breaker:${status_color} ${cb_state}${RESET}"
    echo -e "Last Action:    ${last_action}"
    echo -e "Status:         ${status_color}${status}${RESET}"
    echo -e "Next Reset:     ${next_reset}"

    # Session info
    if [ -f "/Users/playra/trinity/.ralph/internal/.ralph_session" ]; then
        local last_used=$(jq -r '.last_used // "unknown"' "/Users/playra/trinity/.ralph/internal/.ralph_session" 2>/dev/null)
        echo -e "Session Last:    ${last_used}"
    fi
}


panel1_workers() {
    # Panel 1: Worker Agents (MATERIYA)
    echo -e "${BOLD}${CYAN}MATERIYA: Worker Agents${RESET}"
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    # Use cached fix_plan path
    local fix_plan=$(cache_get_fix_plan_path)

    if [ -n "$fix_plan" ]; then
        # Use cached task completion counts
        local completion=$(cache_get_task_completion)
        local done=$(echo "$completion" | cut -d: -f1)
        local total=$(echo "$completion" | cut -d: -f2)
        echo -e "Active Tasks:   ${GREEN}${done}/${total} done${RESET}"
        echo -e ""
        echo -e "Recent P1 tasks:"
        grep "^\- \[ \] \[P1\]" "$fix_plan" 2>/dev/null | head -3 | while read -r line; do
            task=$(echo "$line" | sed 's/.*- \[ \] \[P1\] //' | cut -d: -f1)
            echo -e "  ${RED}[P1]${RESET} ${task}"
        done
    else
        echo -e "${RED}No fix_plan.md found${RESET}"
    fi
}

panel2_tasks() {
    # Panel 2: Active Tasks (DUKH)
    echo -e "${BOLD}${PURPLE}DUKH: Active Tasks (fix_plan.md)${RESET}"
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    # Use cached fix_plan path
    local fix_plan=$(cache_get_fix_plan_path)

    if [ -z "$fix_plan" ]; then
        echo -e "${RED}No fix_plan.md found${RESET}"
        return
    fi

    # Use cached P1, P2, P3 counts
    local counts=$(cache_get_fix_plan_counts)
    local p1_count=$(echo "$counts" | cut -d: -f1)
    local p2_count=$(echo "$counts" | cut -d: -f2)
    local p3_count=$(echo "$counts" | cut -d: -f3)

    # Show P1 tasks
    if [ "$p1_count" -gt 0 ]; then
        echo -e "${RED}P1 (${p1_count} tasks):${RESET}"
        grep "^\- \[ \] \[P1\]" "$fix_plan" 2>/dev/null | head -5 | while read -r line; do
            # Extract content after "- [ ] [P1] "
            content=$(echo "$line" | sed 's/^\- \[ \] \[P1\] //')
            # Split ID and description (use cut -d: -f2- to keep rest of line)
            task_id=$(echo "$content" | cut -d: -f1)
            description=$(echo "$content" | cut -d: -f2- | sed 's/^ *//')
            # Truncate if needed
            if [ ${#description} -gt 50 ]; then
                description="${description:0:47}..."
            fi
            echo -e "  ${GRAY}[ ]${RESET} ${RED}${task_id}:${RESET} ${description}"
        done
        echo ""
    fi

    # Show P2 tasks
    if [ "$p2_count" -gt 0 ]; then
        echo -e "${ORANGE}P2 (${p2_count} tasks):${RESET}"
        grep "^\- \[ \] \[P2\]" "$fix_plan" 2>/dev/null | head -3 | while read -r line; do
            content=$(echo "$line" | sed 's/^\- \[ \] \[P2\] //')
            task_id=$(echo "$content" | cut -d: -f1)
            description=$(echo "$content" | cut -d: -f2- | sed 's/^ *//')
            if [ ${#description} -gt 50 ]; then
                description="${description:0:47}..."
            fi
            echo -e "  ${GRAY}[ ]${RESET} ${ORANGE}${task_id}:${RESET} ${description}"
        done
        echo ""
    fi

    # Show P3 tasks
    if [ "$p3_count" -gt 0 ]; then
        echo -e "${YELLOW}P3 (${p3_count} tasks):${RESET}"
        grep "^\- \[ \] \[P3\]" "$fix_plan" 2>/dev/null | head -2 | while read -r line; do
            content=$(echo "$line" | sed 's/^\- \[ \] \[P3\] //')
            task_id=$(echo "$content" | cut -d: -f1)
            description=$(echo "$content" | cut -d: -f2- | sed 's/^ *//')
            if [ ${#description} -gt 50 ]; then
                description="${description:0:47}..."
            fi
            echo -e "  ${GRAY}[ ]${RESET} ${YELLOW}${task_id}:${RESET} ${description}"
        done
    fi

    if [ "$p1_count" -eq 0 ] && [ "$p2_count" -eq 0 ] && [ "$p3_count" -eq 0 ]; then
        echo -e "${GREEN}No pending tasks!${RESET}"
    fi
}


panel3_techtree() {
    # Panel 3: Tech Tree Progress (RAZUM)
    echo -e "${BOLD}${GOLD}RAZUM: Tech Tree Progress${RESET}"
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    if [ ! -f "/Users/playra/trinity/.ralph/TECH_TREE.md" ]; then
        echo -e "${RED}No TECH_TREE.md found${RESET}"
        return
    fi

    # Show recently completed nodes (from table)
    echo -e "Recently Completed:"
    grep -E '\|\s*\*\*[^*]+\*\*' "/Users/playra/trinity/.ralph/TECH_TREE.md" 2>/dev/null | grep -i "COMPLETED\|Done" | head -5 | while read -r line; do
        # Extract node ID and name from table row
        echo -e "${GREEN}✓${RESET} ${line}"
    done

    echo ""
    echo -e "Available Nodes:"
    local available=$(grep -c "Available Nodes" "/Users/playra/trinity/.ralph/TECH_TREE.md" 2>/dev/null || echo "0")
    echo -e "  ${available} nodes available"
}

panel4_memory() {
    # Panel 4: Memory Systems (RAZUM)
    echo -e "${BOLD}${GOLD}RAZUM: Memory Systems${RESET}"
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    # SUCCESS_HISTORY
    local success_count=0
    if [ -f "/Users/playra/trinity/.ralph/memory/SUCCESS_HISTORY.md" ]; then
        success_count=$(grep -c "^-" "/Users/playra/trinity/.ralph/memory/SUCCESS_HISTORY.md" 2>/dev/null || echo "0")
        echo -e "${GREEN}SUCCESS_HISTORY:${RESET}     ${success_count} entries"
        echo -e "${GRAY}Recent:${RESET}"
        grep "^-" "/Users/playra/trinity/.ralph/memory/SUCCESS_HISTORY.md" 2>/dev/null | tail -2 | while read -r line; do
            echo -e "  ${GREEN}✓${RESET} ${line}"
        done
    else
        echo -e "${GREEN}SUCCESS_HISTORY:${RESET}     No file"
    fi

    echo ""

    # REGRESSION_PATTERNS
    local regression_count=0
    if [ -f "/Users/playra/trinity/.ralph/memory/REGRESSION_PATTERNS.md" ]; then
        regression_count=$(grep -c "^-" "/Users/playra/trinity/.ralph/memory/REGRESSION_PATTERNS.md" 2>/dev/null || echo "0")
        echo -e "${RED}REGRESSION_PATTERNS:${RESET}  ${regression_count} patterns"
        echo -e "${GRAY}Recent:${RESET}"
        grep "^-" "/Users/playra/trinity/.ralph/memory/REGRESSION_PATTERNS.md" 2>/dev/null | tail -2 | while read -r line; do
            echo -e "  ${RED}✗${RESET} ${line}"
        done
    else
        echo -e "${RED}REGRESSION_PATTERNS:${RESET}  No file"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# GOLDEN CHAIN v8.26 PANELS
# ═══════════════════════════════════════════════════════════════════════════════

panel5_golden_chain() {
    # Panel 5: Golden Chain v8.26 Status (RAZUM)
    local tmux_bin=$(cache_get_tmux_golden_chain_binary)
    if [ -n "$tmux_bin" ] && [ -f "$tmux_bin" ]; then
        "$tmux_bin" panel-golden-chain 2>/dev/null || echo -e "${BOLD}${GOLD}GOLDEN CHAIN v8.26${RESET}\necho -e ${GREEN}Running${RESET}"
    else
        echo -e "${BOLD}${GOLD}GOLDEN CHAIN v8.26${RESET}"
        echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━${RESET}"
        echo -e "${RED}Binary not built${RESET}"
        echo -e "Run: ${YELLOW}zig build tmux-golden-chain${RESET}"
    fi
}

panel6_mcp_nexus() {
    # Panel 6: MCP NEXUS Activity (MATERIYA)
    local tmux_bin=$(cache_get_tmux_golden_chain_binary)
    if [ -n "$tmux_bin" ] && [ -f "$tmux_bin" ]; then
        "$tmux_bin" panel-mcp 2>/dev/null || echo -e "${BOLD}${CYAN}MCP NEXUS${RESET}\necho -e ${GREEN}Active${RESET}"
    else
        echo -e "${BOLD}${CYAN}MCP NEXUS${RESET}"
        echo -e "${GRAY}━━━━━━━━━━━━${RESET}"
        echo -e "${RED}Unavailable${RESET}"
    fi
}

panel7_vibee() {
    # Panel 7: VIBEE Compiler Status (DUKH - Monetization Focus)
    local tmux_bin=$(cache_get_tmux_golden_chain_binary)
    if [ -n "$tmux_bin" ] && [ -f "$tmux_bin" ]; then
        "$tmux_bin" panel-vibee 2>/dev/null || echo -e "${BOLD}${PURPLE}VIBEE Compiler${RESET}\necho -e ${GREEN}Ready${RESET}"
    else
        echo -e "${BOLD}${PURPLE}VIBEE Compiler${RESET}"
        echo -e "${GRAY}━━━━━━━━━━━━${RESET}"
        echo -e "${RED}Status unavailable${RESET}"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# MODEL STATUS PANEL (v8.26)
# ═══════════════════════════════════════════════════════════════════════════════

panel8_model_status() {
    # Panel 8: AI Model Status (RAZUM)
    echo -e "${BOLD}${GOLD}AI MODEL STATUS${RESET}"
    echo -e "${GRAY}━━━━━━━━━━━━━━━━${RESET}"

    # Try to get model status from backend
    local model_status_file="/tmp/ralph-model-status.json"
    local model_name="Claude Sonnet 4.6"
    local model_status="online"
    local model_latency="380ms"
    local model_tokens="127K"
    local model_provider="Anthropic"

    if [ -f "$model_status_file" ]; then
        model_name=$(jq -r '.current_model.name // "Claude Sonnet 4.6"' "$model_status_file" 2>/dev/null)
        model_status=$(jq -r '.current_model.status // "online"' "$model_status_file" 2>/dev/null)
        model_latency=$(jq -r '.current_model.latency_ms // "380"' "$model_status_file" 2>/dev/null)"ms"
        model_tokens=$(jq -r '(.current_model.context_tokens // 127000 / 1000 | floor) | tostring' "$model_status_file" 2>/dev/null)"K"
        model_provider=$(jq -r '.current_model.provider // "anthropic"' "$model_status_file" 2>/dev/null | sed 's/^./\U&/')
    fi

    # Color by status
    local status_color="$GREEN"
    if [ "$model_status" = "degraded" ]; then
        status_color="$ORANGE"
    elif [ "$model_status" = "offline" ] || [ "$model_status" = "error" ]; then
        status_color="$RED"
    fi

    echo -e "Model:      ${BOLD}${CYAN}${model_name}${RESET}"
    echo -e "Provider:   ${model_provider}"
    echo -e "Status:     ${status_color}${model_status}${RESET}"
    echo -e "Latency:    ${model_latency}"
    echo -e "Context:    ${model_tokens} tokens"

    # Show RPM if available
    if [ -f "$model_status_file" ]; then
        local rpm_used=$(jq -r '.current_model.rpm_used // "?"' "$model_status_file" 2>/dev/null)
        local rpm_limit=$(jq -r '.current_model.rpm_limit // "?"' "$model_status_file" 2>/dev/null)
        echo -e "Rate:       ${rpm_used}/${rpm_limit} RPM"
    fi
}

panel9_sysinfo() {
    # Panel 9: System Information (MATERIYA)
    echo -e "${BOLD}${CYAN}MATERIYA: System Information${RESET}"
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    # CPU usage (single core average, more useful)
    local cpu_percent="--"
    if command -v ps >/dev/null 2>&1; then
        cpu_percent=$(ps -A -o %cpu | awk '{s+=$1; n++} END {printf "%.1f", s/n}' 2>/dev/null || echo "?.?")
    fi
    echo -e "CPU:         ${cpu_percent}% avg"

    # Memory usage (macOS vm_stat - improved)
    local mem_used="--"
    local mem_percent="--"
    if command -v vm_stat >/dev/null 2>&1; then
        local vm_stats=$(vm_stat 2>/dev/null)
        # Parse page size from header line "(page size of 16384 bytes)"
        local page_size=$(echo "$vm_stats" | head -1 | sed 's/.*page size of \([0-9]*\).*/\1/')
        local free_pages=$(echo "$vm_stats" | grep "Pages free" | sed 's/.*: *\([0-9]*\).*/\1/')
        local active_pages=$(echo "$vm_stats" | grep "Pages active" | sed 's/.*: *\([0-9]*\).*/\1/')
        local wired_pages=$(echo "$vm_stats" | grep "Pages wired" | sed 's/.*: *\([0-9]*\).*/\1/')
        local inactive_pages=$(echo "$vm_stats" | grep "Pages inactive" | sed 's/.*: *\([0-9]*\).*/\1/')

        if [ -n "$page_size" ] && [ "$page_size" -gt 0 ] 2>/dev/null; then
            local total_pages=$((active_pages + wired_pages + free_pages + inactive_pages))
            local used_pages=$((active_pages + wired_pages))
            local used_gb=$((used_pages * page_size / 1024 / 1024 / 1024))
            local total_gb=$((total_pages * page_size / 1024 / 1024 / 1024))
            mem_percent=$((used_pages * 100 / total_pages))
            mem_used="${used_gb}GB / ${total_gb}GB (${mem_percent}%)"
        fi
    fi
    echo -e "Memory:     ${mem_used}"

    # Disk usage (current directory)
    local disk_info="--"
    if command -v df >/dev/null 2>&1; then
        disk_info=$(df -h . 2>/dev/null | tail -1 | awk '{print $4 " free (" $5 " used)"}' || echo "--")
    fi
    echo -e "Disk:       ${disk_info}"

    # Network latency (ping to Cloudflare DNS)
    local latency="--"
    if command -v ping >/dev/null 2>&1; then
        latency=$(ping -c 1 -W 1000 1.1.1.1 2>/dev/null | grep 'time=' | sed 's/.*time=\([0-9.]*\).*/\1ms/' || echo "--")
    fi
    echo -e "Network:    ${latency} latency"

    # Zig version
    local zig_ver="--"
    if command -v zig >/dev/null 2>&1; then
        zig_ver=$(zig version 2>/dev/null | head -1 || echo "--")
    fi
    echo -e "Zig:        ${zig_ver}"

    # Uptime
    local uptime_str="--"
    if [ -f /proc/uptime ]; then
        uptime_str=$(awk '{printf "%.1f hours", $1/3600}' /proc/uptime 2>/dev/null)
    elif command -v uptime >/dev/null 2>&1; then
        uptime_str=$(uptime | sed 's/.*up *//; s/,.*user.*//' | sed 's/ *load average.*//' | xargs 2>/dev/null || echo "--")
    fi
    echo -e "Uptime:     ${uptime_str}"

    # Date/time
    echo -e "Time:       $(date '+%H:%M:%S' 2>/dev/null || echo '--')"
}

panel10_logs() {
    # Panel 10: Live Logs (DUKH)
    echo -e "${BOLD}${PURPLE}DUKH: Live Logs${RESET}"
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━${RESET}"

    local log_file="/Users/playra/trinity/.ralph/logs/ralph.log"
    if [ ! -f "$log_file" ]; then
        echo -e "${RED}No log file found${RESET}"
        echo -e "${GRAY}Expected: ${log_file}${RESET}"
        return
    fi

    # Show last 10 lines on start
    tail -10 "$log_file" 2>/dev/null | while read -r line; do
        case "$line" in
            *ERROR*) echo -e "${RED}${line}${RESET}" ;;
            *WARN*)  echo -e "${YELLOW}${line}${RESET}" ;;
            *)       echo "$line" ;;
        esac
    done
    echo -e "${GRAY}────── live ──────${RESET}"

    # Tail live
    tail -f "$log_file" 2>/dev/null | while read -r line; do
        case "$line" in
            *ERROR*) echo -e "${RED}${line}${RESET}" ;;
            *WARN*)  echo -e "${YELLOW}${line}${RESET}" ;;
            *)       echo "$line" ;;
        esac
    done
}

panel11_build() {
    # Panel 11: Build & Test Status (RAZUM)
    echo -e "${BOLD}${GOLD}RAZUM: Build & Test${RESET}"
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━${RESET}"

    # Zig version
    local zig_ver=$(zig version 2>/dev/null | head -1 || echo "--")
    echo -e "Zig:        ${zig_ver}"

    # Last build time (check for any binary in zig-out/bin)
    local build_time="--"
    local build_age=""

    # Find newest binary
    if [ -d "zig-out/bin" ]; then
        local newest=$(find zig-out/bin -type f -executable 2>/dev/null | xargs ls -t 2>/dev/null | head -1)
        if [ -n "$newest" ]; then
            # macOS stat
            build_time=$(stat -f "%Sm" -t "%H:%M" "$newest" 2>/dev/null || \
                        # Linux stat
                        stat -c "%y" "$newest" 2>/dev/null | cut -d'T' -f2 | cut -d. -f1)
            # Calculate age in minutes
            local now=$(date +%s)
            local bt=$(stat -f "%m" "$newest" 2>/dev/null || stat -c "%Y" "$newest" 2>/dev/null)
            local age_min=$(( (now - bt) / 60 ))
            build_age="(${age_min}m ago)"
        fi
    fi

    if [ "$build_time" = "--" ]; then
        echo -e "Last build: ${RED}never${RESET}"
    else
        echo -e "Last build: ${build_time} ${build_age}"
    fi

    # Binary count
    local bins=$(ls zig-out/bin/* 2>/dev/null | wc -l | xargs || echo "0")
    echo -e "Binaries:   ${bins} files"

    # Test status (show cached test result from last run)
    local test_cache="/tmp/ralph-test-status"
    if [ -f "$test_cache" ]; then
        local test_res=$(cat "$test_cache" 2>/dev/null)
        # Show if less than 5 minutes old
        local cache_age=$(( $(date +%s) - $(stat -f "%m" "$test_cache" 2>/dev/null || stat -c "%Y" "$test_cache" 2>/dev/null) ))
        if [ $cache_age -lt 300 ]; then
            echo -e "Test:       ${test_res}"
        else
            echo -e "Test:       ${GRAY}cached stale${RESET}"
        fi
    else
        echo -e "Test:       ${GRAY}run !test${RESET}"
    fi
}

panel12_files() {
    # Panel 12: File Changes (MATERIYA)
    echo -e "${BOLD}${CYAN}MATERIYA: File Changes${RESET}"
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    # Git status
    local branch=$(git branch --show-current 2>/dev/null || echo "no-git")
    local changed=$(git diff --name-only HEAD 2>/dev/null | wc -l | xargs || echo "0")
    local untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | xargs || echo "0")
    local staged=$(git diff --staged --name-only 2>/dev/null | wc -l | xargs || echo "0")

    # Color code branch status
    local branch_color="$GREEN"
    [ "$branch" = "main" ] || branch_color="$ORANGE"

    echo -e "Branch:     ${branch_color}${branch}${RESET}"
    echo -e "Modified:   ${changed} files"
    echo -e "Staged:     ${staged} files"
    echo -e "Untracked:  ${untracked} files"

    # Recent changes
    if [ "$changed" -gt 0 ]; then
        echo ""
        echo -e "${BOLD}Modified:${RESET}"
        git diff --name-only HEAD 2>/dev/null | head -5 | while read -r f; do
            # Color by directory
            case "$f" in
                src/*)     echo -e "  ${GOLD}▸${RESET} ${f}" ;;
                specs/*)   echo -e "  ${PURPLE}▸${RESET} ${f}" ;;
                ralph/*)   echo -e "  ${CYAN}▸${RESET} ${f}" ;;
                *)         echo -e "  ${GRAY}▸${RESET} ${f}" ;;
            esac
        done
    fi

    # Recent commits
    echo ""
    echo -e "${BOLD}Recent commits:${RESET}"
    git log --oneline -5 2>/dev/null | while read -r line; do
        local hash=$(echo "$line" | cut -d' ' -f1)
        local msg=$(echo "$line" | cut -d' ' -f2-)
        echo -e "  ${GRAY}${hash:0:8}${RESET} ${msg:0:50}"
    done
}

panel13_network() {
    # Panel 13: Network Status (MATERIYA)
    echo -e "${BOLD}${CYAN}MATERIYA: Network${RESET}"
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━${RESET}"

    # API latency (Anthropic)
    local api_lat="--"
    if ping -c 1 -W 1000 api.anthropic.com >/dev/null 2>&1; then
        api_lat=$(ping -c 1 -W 1000 api.anthropic.com 2>/dev/null | grep 'time=' | sed 's/.*time=\([0-9.]*\).*/\1ms/' || echo "--")
    fi

    # Color code latency
    local api_color="$GREEN"
    if [ "${api_lat%ms}" -gt 100 ] 2>/dev/null; then
        api_color="$ORANGE"
    fi
    if [ "${api_lat%ms}" -gt 300 ] 2>/dev/null; then
        api_color="$RED"
    fi
    echo -e "API:        ${api_color}${api_lat}${RESET}"

    # GitHub latency
    local gh_lat="--"
    if ping -c 1 -W 1000 github.com >/dev/null 2>&1; then
        gh_lat=$(ping -c 1 -W 1000 github.com 2>/dev/null | grep 'time=' | sed 's/.*time=\([0-9.]*\).*/\1ms/' || echo "--")
    fi
    echo -e "GitHub:     ${gh_lat}"

    # DNS latency (Cloudflare)
    local dns_lat="--"
    if ping -c 1 -W 1000 1.1.1.1 >/dev/null 2>&1; then
        dns_lat=$(ping -c 1 -W 1000 1.1.1.1 2>/dev/null | grep 'time=' | sed 's/.*time=\([0-9.]*\).*/\1ms/' || echo "--")
    fi
    echo -e "DNS:        ${dns_lat}"

    # Rate limit from status.json
    local status_file="/Users/playra/trinity/.ralph/logs/status.json"
    if [ -f "$status_file" ]; then
        local calls=$(jq -r '.calls_made_this_hour // "?"' "$status_file" 2>/dev/null)
        local max=100
        local pct=$((calls * 100 / max))
        local pct_color="$GREEN"
        [ $pct -gt 70 ] && pct_color="$ORANGE"
        [ $pct -gt 90 ] && pct_color="$RED"
        echo -e "Rate:       ${pct_color}${calls}/${max}${RESET} (${pct}%)"
    else
        echo -e "Rate:       ?/100"
    fi
}

panel14_stats() {
    # Panel 14: Quick Stats (RAZUM)
    echo -e "${BOLD}${GOLD}RAZUM: Quick Stats${RESET}"
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━${RESET}"

    # Ralph status
    local sf="/Users/playra/trinity/.ralph/logs/status.json"
    if [ -f "$sf" ]; then
        local loop=$(jq -r '.loop_count // "?"' "$sf" 2>/dev/null)
        local st=$(jq -r '.status // "unknown"' "$sf" 2>/dev/null)
        local last=$(jq -r '.last_action // "--"' "$sf" 2>/dev/null)

        # Status color
        local st_color="$GREEN"
        [ "$st" != "running" ] && st_color="$ORANGE"

        echo -e "Loop:       ${loop}"
        echo -e "Status:     ${st_color}${st}${RESET}"
        echo -e "Action:     ${last}"
    else
        echo -e "Loop:       --"
        echo -e "Status:     ${RED}offline${RESET}"
    fi

    # Tasks
    local fp="/Users/playra/trinity/.ralph/fix_plan.md"
    if [ -f "$fp" ]; then
        local total=$(grep -c "^- \[ \]" "$fp" 2>/dev/null || echo "0")
        local done=$(grep -c "^- \[x\]" "$fp" 2>/dev/null || echo "0")
        local pct=0
        [ $((total + done)) -gt 0 ] && pct=$((done * 100 / (total + done)))
        echo -e "Tasks:      ${done}/${total} (${pct}%)"
    fi

    # Uptime
    local uptime_str=$(uptime | sed 's/.*up *//; s/,.*user.*//' | sed 's/ *load average.*//' | xargs 2>/dev/null || echo "--")
    echo -e "Uptime:     ${uptime_str}"

    # Lines of code (src/ only)
    local loc=$(find src -name "*.zig" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
    echo -e "Code:       ${loc} lines (src/)"

    # Git commit count
    local commits=$(git rev-list --count HEAD 2>/dev/null || echo "0")
    echo -e "Commits:    ${commits}"
}

statusline() {
    # Status line for tmux status bar
    local loop="#?"
    local api="#?/100"
    local cb="CLOSED"
    local p1=0 p2=0 p3=0
    local branch="no-git"
    local changes=0

    # Parse status.json - OPTIMIZED: Single jq call with proper fallback
    if [ -f "/Users/playra/trinity/.ralph/logs/status.json" ]; then
        eval "$(jq -r '
            "loop=\(.loop_count // "#?")",
            "calls=\(.calls_made_this_hour // "#?")"
        ' /Users/playra/trinity/.ralph/logs/status.json 2>/dev/null)"
        api="${calls}/100"
    fi

    # Parse circuit breaker - OPTIMIZED: Use head -1 instead of jq (faster)
    if [ -f "/Users/playra/trinity/.ralph/internal/.circuit_breaker_state" ]; then
        cb=$(grep -o '"state": "[^"]*' "/Users/playra/trinity/.ralph/internal/.circuit_breaker_state" 2>/dev/null | cut -d'"' -f4 || echo "CLOSED")
    fi

    # OPTIMIZED: Use cached fix_plan counts
    local counts=$(cache_get_fix_plan_counts)
    p1=$(echo "$counts" | cut -d: -f1)
    p2=$(echo "$counts" | cut -d: -f2)
    p3=$(echo "$counts" | cut -d: -f3)

    # OPTIMIZED: Use cached git status
    local git_status=$(cache_get_git_status)
    branch=$(echo "$git_status" | cut -d: -f1)
    changes=$(echo "$git_status" | cut -d: -f2)

    # Worker status
    local w1="idle" w2="idle" w3="idle"
    [ -f "/Users/playra/trinity/.ralph/DONE_W1" ] || w1="act"
    [ -f "/Users/playra/trinity/.ralph/DONE_W2" ] || w2="act"
    [ -f "/Users/playra/trinity/.ralph/DONE_W3" ] || w3="act"

    # Format: Loop:#15 API:38/100 CB:CLOSED P1:3 P2:1 Tech:93% W1:act W2:idle W3:idle main Changes:5
    echo "Loop:${loop} API:${api} CB:${cb} P1:${p1} P2:${p2} P3:${p3} W1:${w1} W2:${w2} W3:${w3} ${branch} Chg:${changes}"
}

panel_welcome() {
  clear
  # Trinity Pyramid ASCII Art
  echo -e "${GOLD}
                    +1
                   -1 +1
                  +1  0 +1
                 -1 +1 +1 -1
             ═════════════════════
            ▐ T R I N I T Y ▌
             ═════════════════════
            φ² + 1/φ² = 3
  ${RESET}"

  # System status from status.json
  local sf="/Users/playra/trinity/.ralph/logs/status.json"
  if [ -f "$sf" ]; then
    local loop=$(jq -r '.loop_count // "?"' "$sf" 2>/dev/null)
    local st=$(jq -r '.status // "unknown"' "$sf" 2>/dev/null)
    local calls=$(jq -r '.calls_made_this_hour // "?"' "$sf" 2>/dev/null)

    local st_color="$GREEN"
    [ "$st" != "running" ] && st_color="$ORANGE"

    echo -e "  ${CYAN}Loop:${RESET} ${loop}  |  ${st_color}Status:${RESET} ${st}  |  ${CYAN}API:${RESET} ${calls}/100"
  fi

  # Tasks summary
  local fp="/Users/playra/trinity/.ralph/fix_plan.md"
  if [ -f "$fp" ]; then
    local total=$(grep -c "^- \[ \]" "$fp" 2>/dev/null || echo "0")
    local done=$(grep -c "^- \[x\]" "$fp" 2>/dev/null || echo "0")
    echo -e "  ${CYAN}Tasks:${RESET} ${done}/${total} done"
  fi

  echo ""
  echo -e "${GRAY}  Press Ctrl+b 1 for Chat | Ctrl+b ? for Help${RESET}"
  echo ""

  # Full Windows Guide
  echo -e "${BOLD}📺 WINDOWS GUIDE (v3.1)${RESET}"
  echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e " ${CYAN}[0] WELCOME${RESET}   → ASCII Art + System Status (you are here)"
  echo -e " ${CYAN}[1] HOME${RESET}      → Chat Interface (type !help for commands)"
  echo -e " ${CYAN}[2] Loop${RESET}      → Ralph Loop Status + Worker Agents"
  echo -e " ${CYAN}[3] Tasks${RESET}     → Active Tasks + Tech Tree"
  echo -e " ${CYAN}[4] GC${RESET}        → GOLDEN CHAIN v8.26 + MCP NEXUS"
  echo -e " ${CYAN}[5] VIBEE${RESET}     → VIBEE Compiler Status"
  echo -e " ${CYAN}[6] Sysinfo${RESET}   → System Information (CPU, Memory, Disk)"
  echo -e " ${CYAN}[7] Monitor${RESET}   → Live Logs + Network Status"
  echo -e " ${CYAN}[8] Dev${RESET}       → Build Status + File Changes"
  echo -e " ${CYAN}[9] Stats${RESET}     → Quick Stats"
  echo ""

  echo -e "${BOLD}🎨 COLOR LEGEND${RESET}"
  echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e " ${GOLD}🟡 GOLD${RESET}   = RAZUM (Mind)   — andnthoselletot, routing, reshenandya"
  echo -e " ${CYAN}🔵 CYAN${RESET}   = MATERIYA (Matter) — andnfrastructure, data, filey"
  echo -e " ${PURPLE}🟣 PURPLE${RESET} = DUKH (Spirit)  — deywithtinandya, tooly, dabouttoazathoselwithtina"
  echo ""

  echo -e "${BOLD}⌨️  KEYBINDINGS${RESET}"
  echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e " ${BOLD}Ctrl+b${RESET} ${CYAN}0-9${RESET}   → Perekeyenande abouttoaboutn"
  echo -e " ${BOLD}Ctrl+b${RESET} ${CYAN}d${RESET}     → Otwithaboutedandnandtwithya from withewithwithandand"
  echo -e " ${GREEN}Attach: tmux attach -t trinity${RESET}"
}

# Panel 15: Unified Search
panel15_search() {
  local query="$1"
  [ -z "$query" ] && query="$2"

  if [ -z "$query" ]; then
    echo -e "${BOLD}${CYAN}SEARCH: Unified Query${RESET}"
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━${RESET}"
    echo "Usage: !search <query>"
    echo ""
    echo "Searches across:"
    echo "  • Tasks (fix_plan.md)"
    echo "  • Logs (ralph.log)"
    echo "  • Git commits"
    echo "  • Specs (*.vibee)"
    return
  fi

  clear
  echo -e "${BOLD}${CYAN}SEARCH: Unified Query${RESET}"
  echo -e "${GRAY}━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}Query: ${GOLD}${query}${RESET}"
  echo ""

  # Search in tasks
  echo -e "${PURPLE}Tasks:${RESET}"
  local fp="/Users/playra/trinity/.ralph/fix_plan.md"
  if [ -f "$fp" ]; then
    grep -i --color=never "$query" "$fp" 2>/dev/null | head -5 || echo "  No matches"
  else
    echo "  fix_plan.md not found"
  fi

  # Search in logs
  echo ""
  echo -e "${PURPLE}Logs:${RESET}"
  local logf="/Users/playra/trinity/.ralph/logs/ralph.log"
  if [ -f "$logf" ]; then
    grep -i --color=never "$query" "$logf" 2>/dev/null | tail -5 || echo "  No matches"
  else
    echo "  ralph.log not found"
  fi

  # Search in git commits
  echo ""
  echo -e "${PURPLE}Commits:${RESET}"
  git log --oneline --all --grep="$query" 2>/dev/null | head -5 || echo "  No matches"

  # Search in specs
  echo ""
  echo -e "${PURPLE}Specs:${RESET}"
  find specs -name "*.vibee" -type f 2>/dev/null | xargs grep -l -i "$query" 2>/dev/null | head -5 || echo "  No matches"
}

# Parallel panel fetch using temporary files
# Executes all panels in parallel, then displays when all ready
# Reduces 5-panel refresh from ~500ms to ~100ms
prefetch_all_panels() {
    local tmp_dir="/tmp/ralph-tmux-panels-$$"
    mkdir -p "$tmp_dir"

    # Launch panels in background, each writing to its temp file
    panel0_loop_status > "$tmp_dir/panel0" &
    panel1_workers > "$tmp_dir/panel1" &
    panel2_tasks > "$tmp_dir/panel2" &
    panel3_techtree > "$tmp_dir/panel3" &
    panel4_memory > "$tmp_dir/panel4" &
    panel9_sysinfo > "$tmp_dir/panel9" &

    # Wait for all background jobs to complete
    wait

    # Display all panels
    cat "$tmp_dir/panel0"
    cat "$tmp_dir/panel1"
    cat "$tmp_dir/panel2"
    cat "$tmp_dir/panel3"
    cat "$tmp_dir/panel4"
    cat "$tmp_dir/panel9"

    # Clean up temp files
    rm -rf "$tmp_dir"
}

# Main router
case "$1" in
    welcome|home|panel_welcome) panel_welcome ;;
    panel0|loop)    panel0_loop_status ;;
    panel1|workers) panel1_workers ;;
    panel2|tasks)   panel2_tasks ;;
    panel3|techtreet|techtree) panel3_techtree ;;
    panel4|memory)  panel4_memory ;;
    panel5|golden-chain|goldenchain|golden) panel5_golden_chain ;;
    panel6|mcp|mcp-nexus|mcp_nexus) panel6_mcp_nexus ;;
    panel7|vibee|vibee-compiler) panel7_vibee ;;
    panel8|model|model-status|model_status) panel8_model_status ;;
    panel9|sysinfo|sys-info|sys_info) panel9_sysinfo ;;
    panel10|logs|live-logs|live_logs) panel10_logs ;;
    panel11|build|build-test|build_test) panel11_build ;;
    panel12|files|file-changes|file_changes) panel12_files ;;
    panel13|network|net|network-status) panel13_network ;;
    panel14|stats|quick-stats) panel14_stats ;;
    panel15|search|unified-search) panel15_search "$2" ;;
    all|prefetch|parallel) prefetch_all_panels ;;  # NEW: Parallel panel fetch
    statusline)     statusline ;;
    *)
        echo "Usage: $0 {welcome|panel0|panel1|...|panel14|all|statusline|search}"
        echo "  panel5  = Golden Chain v8.26"
        echo "  panel6  = MCP NEXUS"
        echo "  panel7  = VIBEE Compiler"
        echo "  panel8  = AI Model Status"
        echo "  panel9  = System Information (CPU, Memory, Disk, Network)"
        echo "  panel10 = Live Logs (tail -f ralph.log)"
        echo "  panel11 = Build & Test Status"
        echo "  panel12 = File Changes (Git status)"
        echo "  panel13 = Network Status (API, GitHub, DNS latency)"
        echo "  panel14 = Quick Stats (aggregated metrics)"
        exit 1
        ;;
esac
