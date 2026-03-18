#!/bin/bash
# TRI COMMAND INPUT - Interactive REPL for command entry
# Fixed: reads from /dev/tty for proper tmux integration

RALPH_DIR="/Users/playra/trinity"
QUEUE_SCRIPT="$RALPH_DIR/.ralph/scripts/tri_cmd_queue.sh"

# Trinity colors
GOLD="\033[38;5;220m"
CYAN="\033[38;5;075m"
GREEN="\033[38;5;042m"
RED="\033[38;5;196m"
GRAY="\033[38;5;244m"
YELLOW="\033[38;5;226m"
RESET="\033[0m"
BOLD="\033[1m"

# Narrow pane formatting (22 chars wide)
show_mini_banner() {
    clear
    echo -e "${BOLD}${GOLD}┏━━━━━━━━━━━━━━━━┓${RESET}"
    echo -e "${BOLD}${GOLD}┃${RESET} ${CYAN}TRI COMMANDER${RESET} ${BOLD}${GOLD}┃${RESET}"
    echo -e "${BOLD}${GOLD}┃${RESET}  ${GREEN}INPUT${RESET}       ${BOLD}${GOLD}┃${RESET}"
    echo -e "${BOLD}${GOLD}┗━━━━━━━━━━━━━━━━┛${RESET}"
    echo ""
}

# Command history
HISTFILE="$RALPH_DIR/.ralph/queue/.cmd_history"
mkdir -p "$(dirname "$HISTFILE")"
touch "$HISTFILE"

# Show help
show_help() {
    echo -e "${CYAN}Built-in commands:${RESET}"
    echo "  /h, /?    Help"
    echo "  /c        Clear"
    echo "  /s        Status"
    echo "  /hst      History"
    echo "  /x        Exit"
}

# Show history
show_history() {
    echo -e "${CYAN}Recent commands:${RESET}"
    tail -5 "$HISTFILE" 2>/dev/null | nl -w2 -s'. ' || echo "  (empty)"
}

# Initialize queue
"$QUEUE_SCRIPT" init >/dev/null 2>&1

# Show banner once
show_mini_banner

# REPL loop - Use /dev/tty for direct terminal access
while true; do
    # Compact prompt for narrow pane
    echo -ne "${BOLD}${CYAN}►${RESET} "

    # Read directly from /dev/tty instead of stdin (KEY FIX!)
    if ! read -r cmd < /dev/tty; then
        break
    fi

    # Skip empty
    [ -z "$cmd" ] && continue

    # Trim whitespace
    cmd=$(echo "$cmd" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -z "$cmd" ] && continue

    # Built-in commands
    case "$cmd" in
        /h|/\?|/help)
            show_help
            echo ""
            continue
            ;;
        /c|/clear)
            show_mini_banner
            continue
            ;;
        /s|/status)
            "$QUEUE_SCRIPT" status
            echo ""
            continue
            ;;
        /hst|/history)
            show_history
            echo ""
            continue
            ;;
        /x|/exit|/quit)
            echo -e "${GRAY}Bye!${RESET}"
            break
            ;;
    esac

    # Add to history
    echo "$cmd" >> "$HISTFILE"

    # Enqueue command (silent)
    "$QUEUE_SCRIPT" enqueue "$cmd" >/dev/null 2>&1

    # Visual feedback (compact)
    echo -e "${GREEN}✓${RESET}"
done

# Return to normal shell on exit
exec bash --noprofile --norc
