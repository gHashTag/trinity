#!/bin/bash
# tmux_status.sh - Output formatted status for Ralph Dashboard panels
# Usage: ./tmux_status.sh <panel_name|statusline>

RALPH_DIR="/Users/playra/trinity"
cd "$RALPH_DIR" 2>/dev/null || exit 1

# Source cache layer
if [ -f ".ralph/scripts/tmux_cache.sh" ]; then
    . .ralph/scripts/tmux_cache.sh
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
    local status_file=".ralph/logs/status.json"
    local loop="#?"
    local api="#?/100"
    local cb="UNKNOWN"
    local last_action="unknown"
    local status="unknown"
    local next_reset="#?"

    if [ -f "$status_file" ]; then
        # OPTIMIZED: Single jq call to get all fields at once
        eval "$(jq -r '
            .loop_count as $lc |
            .calls_made_this_hour as $cm |
            .status as $st |
            .last_action as $la |
            .next_reset as $nr |
            "loop=\($lc | tostring | "#?"")",
            "calls=\($cm | tostring | "#?")",
            "status=\($st)",
            "last_action=\($la)",
            "next_reset=\($nr)"
        ' "$status_file" 2>/dev/null)"
        api="${calls}/100"
    fi

    # Check circuit breaker state
    local cb_state="CLOSED"
    if [ -f ".ralph/internal/.circuit_breaker_state" ]; then
        cb_state=$(jq -r '.state // "CLOSED"' ".ralph/internal/.circuit_breaker_state" 2>/dev/null || echo "CLOSED")
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
    if [ -f ".ralph/internal/.ralph_session" ]; then
        local last_used=$(jq -r '.last_used // "unknown"' ".ralph/internal/.ralph_session" 2>/dev/null)
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
            task=$(echo "$line" | sed 's/.*- \[ \] \[P1\] //' | cut -d: -f1)
            echo -e "  ${GRAY}[ ]${RESET} ${task}"
        done
        echo ""
    fi

    # Show P2 tasks
    if [ "$p2_count" -gt 0 ]; then
        echo -e "${ORANGE}P2 (${p2_count} tasks):${RESET}"
        grep "^\- \[ \] \[P2\]" "$fix_plan" 2>/dev/null | head -3 | while read -r line; do
            task=$(echo "$line" | sed 's/.*- \[ \] \[P2\] //' | cut -d: -f1)
            echo -e "  ${GRAY}[ ]${RESET} ${task}"
        done
        echo ""
    fi

    # Show P3 tasks
    if [ "$p3_count" -gt 0 ]; then
        echo -e "${YELLOW}P3 (${p3_count} tasks):${RESET}"
        grep "^\- \[ \] \[P3\]" "$fix_plan" 2>/dev/null | head -2 | while read -r line; do
            task=$(echo "$line" | sed 's/.*- \[ \] \[P3\] //' | cut -d: -f1)
            echo -e "  ${GRAY}[ ]${RESET} ${task}"
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

    if [ ! -f ".ralph/TECH_TREE.md" ]; then
        echo -e "${RED}No TECH_TREE.md found${RESET}"
        return
    fi

    # Show recently completed nodes (from table)
    echo -e "Recently Completed:"
    grep -E '\|\s*\*\*[^*]+\*\*' ".ralph/TECH_TREE.md" 2>/dev/null | grep -i "COMPLETED\|Done" | head -5 | while read -r line; do
        # Extract node ID and name from table row
        echo -e "${GREEN}✓${RESET} ${line}"
    done

    echo ""
    echo -e "Available Nodes:"
    local available=$(grep -c "Available Nodes" ".ralph/TECH_TREE.md" 2>/dev/null || echo "0")
    echo -e "  ${available} nodes available"
}

panel4_memory() {
    # Panel 4: Memory Systems (RAZUM)
    echo -e "${BOLD}${GOLD}RAZUM: Memory Systems${RESET}"
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    # SUCCESS_HISTORY
    local success_count=0
    if [ -f ".ralph/memory/SUCCESS_HISTORY.md" ]; then
        success_count=$(grep -c "^-" ".ralph/memory/SUCCESS_HISTORY.md" 2>/dev/null || echo "0")
        echo -e "${GREEN}SUCCESS_HISTORY:${RESET}     ${success_count} entries"
        echo -e "${GRAY}Recent:${RESET}"
        grep "^-" ".ralph/memory/SUCCESS_HISTORY.md" 2>/dev/null | tail -2 | while read -r line; do
            echo -e "  ${GREEN}✓${RESET} ${line}"
        done
    else
        echo -e "${GREEN}SUCCESS_HISTORY:${RESET}     No file"
    fi

    echo ""

    # REGRESSION_PATTERNS
    local regression_count=0
    if [ -f ".ralph/memory/REGRESSION_PATTERNS.md" ]; then
        regression_count=$(grep -c "^-" ".ralph/memory/REGRESSION_PATTERNS.md" 2>/dev/null || echo "0")
        echo -e "${RED}REGRESSION_PATTERNS:${RESET}  ${regression_count} patterns"
        echo -e "${GRAY}Recent:${RESET}"
        grep "^-" ".ralph/memory/REGRESSION_PATTERNS.md" 2>/dev/null | tail -2 | while read -r line; do
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

statusline() {
    # Status line for tmux status bar
    local loop="#?"
    local api="#?/100"
    local cb="CLOSED"
    local p1=0 p2=0 p3=0
    local branch="no-git"
    local changes=0

    # Parse status.json - OPTIMIZED: Single jq call
    if [ -f ".ralph/logs/status.json" ]; then
        eval "$(jq -r '
            .loop_count as $lc |
            .calls_made_this_hour as $cm |
            "loop=\($lc | tostring | "#?"")",
            "calls=\($cm | tostring | "#?")"
        ' ".ralph/logs/status.json" 2>/dev/null)"
        api="${calls}/100"
    fi

    # Parse circuit breaker - OPTIMIZED: Use head -1 instead of jq (faster)
    if [ -f ".ralph/internal/.circuit_breaker_state" ]; then
        cb=$(grep -o '"state": "[^"]*' ".ralph/internal/.circuit_breaker_state" 2>/dev/null | cut -d'"' -f4 || echo "CLOSED")
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
    [ -f ".ralph/DONE_W1" ] || w1="act"
    [ -f ".ralph/DONE_W2" ] || w2="act"
    [ -f ".ralph/DONE_W3" ] || w3="act"

    # Format: Loop:#15 API:38/100 CB:CLOSED P1:3 P2:1 Tech:93% W1:act W2:idle W3:idle main Changes:5
    echo "Loop:${loop} API:${api} CB:${cb} P1:${p1} P2:${p2} P3:${p3} W1:${w1} W2:${w2} W3:${w3} ${branch} Chg:${changes}"
}

panel_welcome() {
  clear
  echo -e "${BOLD}${GOLD}╔════════════════════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${GOLD}║${RESET}               ${BOLD}RALPH AUTONOMOUS DEVELOPMENT SYSTEM${RESET}               ${BOLD}${GOLD}║${RESET}"
  echo -e "${BOLD}${GOLD}║${RESET}                    ${CYAN}v10.6 — TRUTH MODE${RESET}                     ${BOLD}${GOLD}║${RESET}"
  echo -e "${BOLD}${GOLD}╚════════════════════════════════════════════════════════════════════════════╝${RESET}"
  echo ""

  echo -e "${BOLD}⚡ QUICK STATUS${RESET}"
  echo -e "${GRAY}────────────────────────────────────────────────────────────────────────────${RESET}"
  .ralph/scripts/tmux_status.sh panel0 2>/dev/null | tail -8 || echo "  Status: initializing..."
  echo ""

  echo -e "${BOLD}📺 WINDOWS GUIDE${RESET}"
  echo -e "${GRAY}────────────────────────────────────────────────────────────────────────────${RESET}"
  echo -e " ${CYAN}[0] HOME${RESET}     → Ethat admandntoa (ty zdewith)"
  echo -e " ${CYAN}[1] Loop${RESET}     → Ralph Golden Chain, API, Circuit Breaker, Workers"
  echo -e " ${CYAN}[2] Tasks${RESET}    → Atotandinnye zadachand from fix_plan.md (P1/P2/P3)"
  echo -e " ${CYAN}[3] Memory${RESET}   → SUCCESS_HISTORY + REGRESSION_PATTERNS"
  echo -e " ${CYAN}[4] Log${RESET}      → Paboutny live-log ally armandand"
  echo ""

  echo -e "${BOLD}🎨 COLOR LEGEND${RESET}"
  echo -e "${GRAY}────────────────────────────────────────────────────────────────────────────${RESET}"
  echo -e " ${GOLD}🟡 GOLD${RESET}   = RAZUM (Mind)   — andnthoselletot, routing, reshenandya"
  echo -e " ${CYAN}🔵 CYAN${RESET}   = MATERIYA (Matter) — andnfrastructure, data, filey"
  echo -e " ${PURPLE}🟣 PURPLE${RESET} = DUKH (Spirit)  — deywithtinandya, tooly, dabouttoazathoselwithtina"
  echo ""

  echo -e "${BOLD}⌨️  KEYBINDINGS${RESET}"
  echo -e "${GRAY}────────────────────────────────────────────────────────────────────────────${RESET}"
  echo -e " ${BOLD}Ctrl+b${RESET} ${CYAN}0-4${RESET}   → Perekeyenande abouttoaboutn"
  echo -e " ${BOLD}Ctrl+b${RESET} ${CYAN}|${RESET}       → Razdelandt gaboutrfromaboutnthatlnabout"
  echo -e " ${BOLD}Ctrl+b${RESET} ${CYAN}-${RESET}       → Razdelandt inertandtoalnabout"
  echo -e " ${BOLD}Ctrl+b${RESET} ${CYAN}q${RESET}       → Pabouttoazat numbera paneley"
  echo -e " ${BOLD}Ctrl+b${RESET} ${CYAN}d${RESET}       → Otwithaboutedandnandtwithya from withewithwithandand"
  echo -e " ${BOLD}Ctrl+b${RESET} ${CYAN}?${RESET}       → Vwithe tolainandshand tmux"
  echo ""
  echo -e "${GREEN}Prandwithaboutedandnyaywithya: tmux attach -t ralph${RESET}"
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

    # Wait for all background jobs to complete
    wait

    # Display all panels
    cat "$tmp_dir/panel0"
    cat "$tmp_dir/panel1"
    cat "$tmp_dir/panel2"
    cat "$tmp_dir/panel3"
    cat "$tmp_dir/panel4"

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
    all|prefetch|parallel) prefetch_all_panels ;;  # NEW: Parallel panel fetch
    statusline)     statusline ;;
    *)
        echo "Usage: $0 {welcome|panel0|panel1|panel2|panel3|panel4|panel5|panel6|panel7|panel8|all|statusline}"
        echo "  panel5 = Golden Chain v8.26"
        echo "  panel6 = MCP NEXUS"
        echo "  panel7 = VIBEE Compiler"
        echo "  panel8 = AI Model Status"
        exit 1
        ;;
esac
