#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# GOD MODE ORACLE — Live Agent Monitoring (Russian)
# ═══════════════════════════════════════════════════════════════
# Smart refresh: every 30s check for changes, full redraw every 10min
# No flicker: uses tput cup instead of clear
# ═══════════════════════════════════════════════════════════════

set -uo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_ROOT" || exit 1

# ═══ DATA FILES ═══
FIX_PLAN="$PROJECT_ROOT/.ralph/fix_plan.md"
TECH_TREE="$PROJECT_ROOT/.ralph/TECH_TREE.md"
CB_STATE="$PROJECT_ROOT/.ralph/internal/.circuit_breaker_state"
GOD_LOG="$PROJECT_ROOT/.ralph/god_mode_log.jsonl"
SUCCESS_HIST="$PROJECT_ROOT/.ralph/memory/SUCCESS_HISTORY.md"
REGRESS_PAT="$PROJECT_ROOT/.ralph/memory/REGRESSION_PATTERNS.md"

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

# ═══ BRAILLE SPINNER ═══
SPINNER_CHARS=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
SPINNER_IDX=0

# ═══ PROGRESS BAR ═══
progress_bar() {
    local done=$1 total=$2 width=${3:-20}
    if [ "$total" -eq 0 ]; then
        printf '%s' "░░░░░░░░░░░░░░░░░░░░ 0/0"
        return
    fi
    local pct=$((done * 100 / total))
    local filled=$((done * width / total))
    local empty=$((width - filled))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    if [ "$pct" -eq 100 ]; then
        printf '%s' "$bar $done/$total (${pct}%) ✅"
    else
        printf '%s' "$bar $done/$total (${pct}%)"
    fi
}

# ═══ SEPARATOR ═══
separator() {
    local label="$1"
    local cols
    cols=$(tput cols 2>/dev/null || echo 65)
    [ "$cols" -gt 70 ] && cols=70
    local pad=$((cols - ${#label} - 4))
    [ "$pad" -lt 2 ] && pad=2
    local line=""
    for ((i=0; i<pad; i++)); do line+="═"; done
    echo -e "${GOLD}══ ${BOLD}${label}${RESET}${GOLD} ${line}${RESET}"
}

# ═══ COMPUTE STATE HASH ═══
compute_hash() {
    local data=""
    [ -f "$CB_STATE" ] && data+=$(cat "$CB_STATE" 2>/dev/null)
    [ -f "$FIX_PLAN" ] && data+=$(md5 -q "$FIX_PLAN" 2>/dev/null || md5sum "$FIX_PLAN" 2>/dev/null | cut -d' ' -f1)
    data+=$(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null)
    data+=$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null | wc -l)
    [ -f "$GOD_LOG" ] && data+=$(tail -1 "$GOD_LOG" 2>/dev/null)
    echo -n "$data" | md5 -q 2>/dev/null || echo -n "$data" | md5sum 2>/dev/null | cut -d' ' -f1
}

# ═══ RENDER DASHBOARD ═══
render() {
    local now
    now=$(date '+%H:%M:%S')
    local branch
    branch=$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || echo "?")

    # CI status (cached — expensive call, graceful fallback if gh unavailable)
    local ci_status="?"
    if [ -n "${CI_CACHE:-}" ] && [ $(($(date +%s) - CI_CACHE_TIME)) -lt 300 ]; then
        ci_status="$CI_CACHE"
    elif command -v gh &>/dev/null; then
        ci_status=$(gh run list --repo gHashTag/trinity --workflow=ci.yml --limit 1 --json conclusion --jq '.[0].conclusion // "pending"' 2>/dev/null || echo "?")
        CI_CACHE="$ci_status"
        CI_CACHE_TIME=$(date +%s)
    fi
    local ci_icon="❓"
    [ "$ci_status" = "success" ] && ci_icon="✅"
    [ "$ci_status" = "failure" ] && ci_icon="❌"

    # Move cursor home (no flicker)
    tput cup 0 0 2>/dev/null || printf '\033[H'
    tput ed 2>/dev/null || printf '\033[J'

    # ═══ HEADER ═══
    echo -e "${BOLD}${GOLD}╔═══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${GOLD}║              ${PURPLE}🔮 ОРАКУЛ — GOD MODE${GOLD}                           ║${RESET}"
    echo -e "${BOLD}${GOLD}║              ${GRAY}φ² + 1/φ² = 3 = TRINITY${GOLD}                        ║${RESET}"
    echo -e "${BOLD}${GOLD}╚═══════════════════════════════════════════════════════════════╝${RESET}"
    echo -e "  ${DIM}⏰ ${now}${RESET} │ ${CYAN}Ветка: ${BOLD}${branch}${RESET} │ CI: ${ci_icon} │ ${DIM}${SPINNER_CHARS[$SPINNER_IDX]}${RESET}"
    echo ""

    # ═══ SECTION 1: WHAT WE'RE WORKING ON ═══
    separator "🎯 СЕЙЧАС РАБОТАЕМ НАД"
    echo ""

    if [ -f "$FIX_PLAN" ]; then
        # Sprint name
        local sprint
        sprint=$(grep -m1 '## 🔥 CURRENT SPRINT' "$FIX_PLAN" 2>/dev/null | sed 's/## 🔥 CURRENT SPRINT: //' || echo "?")
        echo -e "  ${BOLD}${WHITE}Спринт:${RESET} ${CYAN}${sprint}${RESET}"

        # Goal
        local goal
        goal=$(grep -m1 '> \*\*Goal:\*\*' "$FIX_PLAN" 2>/dev/null | sed 's/> \*\*Goal:\*\* //' || echo "?")
        echo -e "  ${BOLD}${WHITE}Цель:${RESET} ${goal}"

        # Progress — count tasks
        local total_tasks done_tasks pending_p1 pending_p2 pending_p3
        total_tasks=$(grep -c '^\- \[.\]' "$FIX_PLAN" 2>/dev/null || echo "0")
        done_tasks=$(grep -c '^\- \[x\]' "$FIX_PLAN" 2>/dev/null || echo "0")
        pending_p1=$(grep -c '^\- \[ \] \[P1\]' "$FIX_PLAN" 2>/dev/null || echo "0")
        pending_p2=$(grep -c '^\- \[ \] \[P2\]' "$FIX_PLAN" 2>/dev/null || echo "0")
        pending_p3=$(grep -c '^\- \[ \] \[P3\]' "$FIX_PLAN" 2>/dev/null || echo "0")

        echo -ne "  ${BOLD}${WHITE}Прогресс:${RESET} "
        progress_bar "$done_tasks" "$total_tasks"
        echo ""
        echo -e "  ${RED}P1: ${pending_p1}${RESET} │ ${YELLOW}P2: ${pending_p2}${RESET} │ ${GRAY}P3: ${pending_p3}${RESET}"
        echo ""

        # Current P1 tasks
        local p1_list
        p1_list=$(grep '^\- \[ \] \[P1\]' "$FIX_PLAN" 2>/dev/null | head -5 | sed 's/- \[ \] \[P1\] //')
        if [ -n "$p1_list" ]; then
            echo -e "  ${RED}${BOLD}▶ ТЕКУЩИЕ P1 ЗАДАЧИ:${RESET}"
            while IFS= read -r task; do
                echo -e "    ${RED}•${RESET} ${task}"
            done <<< "$p1_list"
            echo ""
        fi

        # P2 tasks (brief)
        local p2_list
        p2_list=$(grep '^\- \[ \] \[P2\]' "$FIX_PLAN" 2>/dev/null | head -3 | sed 's/- \[ \] \[P2\] //')
        if [ -n "$p2_list" ]; then
            echo -e "  ${YELLOW}▶ ОЖИДАЮТ (P2):${RESET}"
            while IFS= read -r task; do
                echo -e "    ${YELLOW}•${RESET} ${DIM}${task}${RESET}"
            done <<< "$p2_list"
            echo ""
        fi
    else
        echo -e "  ${DIM}(fix_plan.md не найден)${RESET}"
        echo ""
    fi

    # ═══ SECTION 2: GITHUB ISSUES ═══
    separator "📋 GITHUB ISSUES (assign:ralph)"
    echo ""
    local issues=""
    if command -v gh &>/dev/null; then
        issues=$(gh issue list --repo gHashTag/trinity --label "assign:ralph" --state open --json number,title --jq '.[] | "    #\(.number): \(.title)"' 2>/dev/null)
    fi
    if [ -n "$issues" ]; then
        echo -e "${CYAN}${issues}${RESET}"
    else
        echo -e "  ${DIM}(нет открытых issues или gh CLI не установлен)${RESET}"
    fi
    echo ""

    # ═══ SECTION 3: AGENTS ═══
    separator "🤖 АГЕНТЫ"
    echo ""

    # Circuit breaker
    local cb_st="CLOSED" cb_loop="?" cb_noprog="0"
    if [ -f "$CB_STATE" ]; then
        cb_st=$(jq -r '.state // "CLOSED"' "$CB_STATE" 2>/dev/null || echo "CLOSED")
        cb_loop=$(jq -r '.current_loop // "?"' "$CB_STATE" 2>/dev/null || echo "?")
        cb_noprog=$(jq -r '.consecutive_no_progress // 0' "$CB_STATE" 2>/dev/null || echo "0")
    fi
    local cb_icon="🟢"
    [ "$cb_st" = "OPEN" ] && cb_icon="🔴"
    [ "$cb_st" = "HALF_OPEN" ] && cb_icon="🟡"
    echo -e "  Circuit Breaker: ${cb_icon} ${BOLD}${cb_st}${RESET} (loop ${cb_loop}, застряли: ${cb_noprog})"

    # Worktrees
    local wt_count
    wt_count=$(git -C "$PROJECT_ROOT" worktree list 2>/dev/null | wc -l | tr -d ' ')
    echo -e "  Worktrees: ${wt_count}"

    # Ralph branches
    local ralph_branches
    ralph_branches=$(git -C "$PROJECT_ROOT" branch 2>/dev/null | grep 'ralph/' | wc -l | tr -d ' ')
    if [ "$ralph_branches" -gt 0 ]; then
        local branch_names
        branch_names=$(git -C "$PROJECT_ROOT" branch 2>/dev/null | grep 'ralph/' | head -3 | sed 's/^  //' | tr '\n' ', ' | sed 's/,$//')
        echo -e "  Ralph ветки: ${ralph_branches} (${DIM}${branch_names}${RESET})"
    else
        echo -e "  Ralph ветки: 0"
    fi
    echo ""

    # ═══ SECTION 4: GIT ═══
    separator "📊 GIT"
    echo ""
    local head_short
    head_short=$(git -C "$PROJECT_ROOT" log --oneline -1 2>/dev/null || echo "?")
    echo -e "  HEAD: ${CYAN}${head_short}${RESET}"

    local dirty_count
    dirty_count=$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "$dirty_count" -gt 0 ]; then
        echo -e "  Не закоммичено: ${YELLOW}${dirty_count} файлов${RESET}"
    else
        echo -e "  Рабочая директория: ${GREEN}чисто${RESET}"
    fi

    echo -e "  ${DIM}Последние коммиты:${RESET}"
    git -C "$PROJECT_ROOT" log --oneline -3 2>/dev/null | while IFS= read -r line; do
        echo -e "    ${DIM}•${RESET} ${line}"
    done
    echo ""

    # ═══ SECTION 5: TECH TREE ═══
    separator "🌳 TECH TREE"
    echo ""
    if [ -f "$TECH_TREE" ]; then
        # In progress
        local in_progress
        in_progress=$(sed -n '/## 🏗 In Progress/,/^##/p' "$TECH_TREE" 2>/dev/null | grep '^\|' | head -3 | grep -v '^|-' | grep -v '| ID' || true)
        if [ -n "$in_progress" ] && ! echo "$in_progress" | grep -q '(none)'; then
            echo -e "  ${GREEN}В работе:${RESET}"
            echo "$in_progress" | while IFS= read -r line; do
                local name
                name=$(echo "$line" | awk -F'|' '{print $3}' | sed 's/^\*\*//;s/\*\*$//' | xargs)
                [ -n "$name" ] && echo -e "    ${GREEN}▶${RESET} ${name}"
            done
        else
            echo -e "  В работе: ${DIM}(нет активных узлов)${RESET}"
        fi

        # Last completed
        local last_completed
        last_completed=$(sed -n '/## ✅ Recently Completed/,/^##/p' "$TECH_TREE" 2>/dev/null | grep '^\|' | grep -v '^|-' | grep -v '| ID' | head -1 || true)
        if [ -n "$last_completed" ]; then
            local last_name
            last_name=$(echo "$last_completed" | awk -F'|' '{print $3}' | sed 's/^\*\*//;s/\*\*$//' | xargs)
            echo -e "  Последний: ${PURPLE}${last_name}${RESET}"
        fi

        # Count completed
        local completed_count
        completed_count=$(sed -n '/## ✅ Recently Completed/,/^$/p' "$TECH_TREE" 2>/dev/null | grep -c '^\|' || echo "0")
        echo -e "  Завершено узлов: ${completed_count}"
    else
        echo -e "  ${DIM}(TECH_TREE.md не найден)${RESET}"
    fi
    echo ""

    # ═══ SECTION 6: MEMORY ═══
    separator "🧠 ПАМЯТЬ"
    echo ""
    local success_count=0 regress_count=0
    [ -f "$SUCCESS_HIST" ] && success_count=$(grep -c '^\*\*\|^- \[x\]\|^### ' "$SUCCESS_HIST" 2>/dev/null || echo "0")
    [ -f "$REGRESS_PAT" ] && regress_count=$(grep -c '^\*\*\|^### \|^- ' "$REGRESS_PAT" 2>/dev/null || echo "0")
    echo -e "  Успешные паттерны: ${GREEN}${success_count}${RESET} │ Регрессии: ${RED}${regress_count}${RESET}"
    echo ""

    # ═══ SECTION 7: VIOLATIONS ═══
    local violations=0
    local violation_lines=""

    # Check: on main
    if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
        violation_lines+="    ${YELLOW}⚠${RESET} На ветке ${BOLD}main${RESET} (агенты должны работать на feature branches)\n"
        violations=$((violations + 1))
    fi

    # Check: circuit breaker
    if [ "$cb_noprog" -ge 3 ]; then
        violation_lines+="    ${RED}❌${RESET} Агент застрял: no_progress=${cb_noprog} (порог: 5)\n"
        violations=$((violations + 1))
    fi

    if [ "$violations" -gt 0 ]; then
        separator "⚠ НАРУШЕНИЯ (${violations})"
        echo ""
        echo -e "$violation_lines"
    else
        separator "✅ НАРУШЕНИЙ НЕТ"
        echo ""
        echo -e "  ${GREEN}Все проверки пройдены${RESET}"
        echo ""
    fi

    # ═══ SECTION 8: EVENTS ═══
    separator "📡 ПОСЛЕДНИЕ СОБЫТИЯ"
    echo ""
    if [ -f "$GOD_LOG" ] && [ -s "$GOD_LOG" ]; then
        tail -5 "$GOD_LOG" 2>/dev/null | while IFS= read -r line; do
            local event
            event=$(echo "$line" | jq -r '.event // "?"' 2>/dev/null || echo "?")
            local ts
            ts=$(echo "$line" | jq -r '.ts // 0' 2>/dev/null || echo "0")
            local when
            when=$(date -r "$ts" '+%H:%M:%S' 2>/dev/null || echo "?")
            local br
            br=$(echo "$line" | jq -r '.branch // "?"' 2>/dev/null || echo "?")
            echo -e "    ${DIM}${when}${RESET} │ ${event} │ ${br}"
        done
    else
        echo -e "  ${DIM}(нет событий)${RESET}"
    fi
    echo ""

    # ═══ FOOTER ═══
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    local remaining=$((REFRESH_INTERVAL - TICK_COUNT))
    local mins=$((remaining / 2))
    local secs=$(( (remaining % 2) * 30 ))
    printf "  ${DIM}Ctrl+b 6 → ORACLE │ Ctrl+b 0 → HOME │ Обновление через: %d:%02d ${SPINNER_CHARS[$SPINNER_IDX]}${RESET}\n" "$mins" "$secs"
}

# ═══ MAIN LOOP ═══
REFRESH_INTERVAL=20  # 20 × 30s = 600s = 10 min
TICK_COUNT=0
LAST_HASH=""
CI_CACHE=""
CI_CACHE_TIME=0

# Initial clear
clear

while true; do
    TICK_COUNT=$((TICK_COUNT + 1))
    SPINNER_IDX=$(( (SPINNER_IDX + 1) % ${#SPINNER_CHARS[@]} ))

    # Compute state hash
    CURRENT_HASH=$(compute_hash)

    # Redraw if: hash changed OR 10 minutes elapsed OR first run
    if [ "$CURRENT_HASH" != "$LAST_HASH" ] || [ "$TICK_COUNT" -ge "$REFRESH_INTERVAL" ] || [ "$TICK_COUNT" -eq 1 ]; then
        render
        LAST_HASH="$CURRENT_HASH"
        [ "$TICK_COUNT" -ge "$REFRESH_INTERVAL" ] && TICK_COUNT=0
    else
        # Just update footer with countdown + spinner (no local — we're outside a function)
        FOOTER_LINES=$(tput lines 2>/dev/null || echo 50)
        tput cup $((FOOTER_LINES - 1)) 0 2>/dev/null || true
        FOOTER_REMAINING=$((REFRESH_INTERVAL - TICK_COUNT))
        FOOTER_MINS=$((FOOTER_REMAINING / 2))
        FOOTER_SECS=$(( (FOOTER_REMAINING % 2) * 30 ))
        printf "  ${DIM}Ctrl+b 6 → ORACLE │ Ctrl+b 0 → HOME │ Обновление через: %d:%02d ${SPINNER_CHARS[$SPINNER_IDX]}${RESET}    \n" "$FOOTER_MINS" "$FOOTER_SECS"
    fi

    sleep 30
done
