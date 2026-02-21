#!/bin/bash
# TRI COMMANDER — Clean input at bottom
RALPH_DIR="/Users/playra/trinity"
QUEUE_DIR="$RALPH_DIR/.ralph/queue"
HISTORY_FILE="$QUEUE_DIR/.history"
mkdir -p "$QUEUE_DIR"

# Consistent salad green theme
SALAD="\033[38;5;151m"
CYAN="\033[38;5;075m"
GRAY="\033[38;5;244m"
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

# Padding constant
P="    "  # 4 spaces padding

touch "$HISTORY_FILE"

# Initial screen
clear
echo ""
echo -e "${P}${BOLD}${SALAD}TRI COMMANDER${RESET} — Input Mode"
echo ""
echo -e "${P}${DIM}Commands: /help • /status • /tasks • /clear${RESET}"
echo ""

while true; do
    # Prompt with padding
    echo -ne "${P}${CYAN}►${RESET} "

    # Read with history
    history -r "$HISTORY_FILE" 2>/dev/null
    read -e -r cmd < /dev/tty || break

    # Handle empty input
    [ -z "$cmd" ] && continue

    # Handle slash commands
    case "$cmd" in
        /clear)
            clear
            echo ""
            echo -e "${P}${BOLD}${SALAD}TRI COMMANDER${RESET} — Input Mode"
            echo ""
            continue
            ;;
        /help)
            echo ""
            echo -e "${P}${SALAD}Available commands:${RESET}"
            echo -e "${P}  /clear   Clear input screen"
            echo -e "${P}  /help    Show this help"
            echo -e "${P}  /status  Show system status"
            echo -e "${P}  /tasks   Show task progress"
            echo ""
            continue
            ;;
        /status)
            if [ -f ".ralph/logs/status.json" ]; then
                echo ""
                jq -r 'to_entries | .[] | "  \(.key | ascii_upcase): \(.value)"' .ralph/logs/status.json 2>/dev/null | sed "s/^/${P}/"
                echo ""
            else
                echo -e "${P}${GRAY}No status available${RESET}"
                echo ""
            fi
            continue
            ;;
        /tasks)
            local plan=""
            [ -f ".ralph/fix_plan.md" ] && plan=".ralph/fix_plan.md"
            [ -f ".ralph/internal/fix_plan.md" ] && plan=".ralph/internal/fix_plan.md"
            if [ -n "$plan" ] && [ -f "$plan" ]; then
                echo ""
                grep -E "^- \[(x| )\]" "$plan" 2>/dev/null | head -10 | sed "s/^/${P}/"
                echo ""
            else
                echo -e "${P}${GRAY}No tasks found${RESET}"
                echo ""
            fi
            continue
            ;;
    esac

    # Save to history
    grep -qxF "$cmd" "$HISTORY_FILE" 2>/dev/null || echo "$cmd" >> "$HISTORY_FILE"
    tail -100 "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" 2>/dev/null && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE" 2>/dev/null

    # Send command
    echo "$cmd" > "$QUEUE_DIR/incoming.cmd"

    # Clear and redraw for clean input
    clear
    echo ""
    echo -e "${P}${BOLD}${SALAD}TRI COMMANDER${RESET} — Input Mode"
    echo ""
    echo -e "${P}${DIM}Commands: /help • /status • /tasks • /clear${RESET}"
    echo ""
done
