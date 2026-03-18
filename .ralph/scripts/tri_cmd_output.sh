#!/bin/bash
# TRI COMMAND OUTPUT - Live response viewer (displays ABOVE input)
# Location: .ralph/scripts/tri_cmd_output.sh

RALPH_DIR="/Users/playra/trinity"
RESPONSE_FILE="$RALPH_DIR/.ralph/queue/responses/current.resp"
QUEUE_DIR="$RALPH_DIR/.ralph/queue"

# Trinity colors
GOLD="\033[38;5;220m"
CYAN="\033[38;5;075m"
GREEN="\033[38;5;042m"
GRAY="\033[38;5;244m"
YELLOW="\033[38;5;226m"
RESET="\033[0m"
BOLD="\033[1m"

mkdir -p "$(dirname "$RESPONSE_FILE")"

# Show header with live indicator
show_header() {
    clear
    local live_indicator="${GREEN}● LIVE${RESET}"
    local timestamp=$(date '+%H:%M:%S')
    echo -e "${BOLD}${CYAN}┏━━━━━━━━━━━━━━━━┓${RESET}"
    echo -e "${BOLD}${CYAN}┃${RESET} ${YELLOW}RESPONSES${RESET} ${live_indicator} ${BOLD}${CYAN}┃${RESET}"
    echo -e "${BOLD}${CYAN}┃${RESET} ${GRAY}Updated: ${timestamp}${RESET}   ${BOLD}${CYAN}┃${RESET}"
    echo -e "${BOLD}${CYAN}┗━━━━━━━━━━━━━━━━┛${RESET}"
    echo ""
}

# Format response for narrow pane
show_response() {
    if [ ! -f "$RESPONSE_FILE" ] || [ ! -s "$RESPONSE_FILE" ]; then
        echo -e "${GRAY}Ожидание команд...${RESET}"
        echo -e "${GRAY}Пиши в панели ниже${RESET}"
        return
    fi

    # Parse and format response (wrap for narrow pane)
    local in_section=0
    while IFS= read -r line; do
        # Skip empty lines at start
        [ -z "$line" ] && [ $in_section -eq 0 ] && continue

        in_section=1

        # Color code sections
        case "$line" in
            ===*===)
                echo -e "${GOLD}${line}${RESET}"
                ;;
            ---*---)
                local section=$(echo "$line" | sed 's/^--- //;s/ ---$//')
                echo -e "${CYAN}▸ ${section}${RESET}"
                ;;
            STATUS:*)
                local status=$(echo "$line" | cut -d: -f2-)
                if echo "$status" | grep -qi "complete"; then
                    echo -e "${GREEN}✓ ${status}${RESET}"
                elif echo "$status" | grep -qi "error"; then
                    echo -e "${RED}✗ ${status}${RESET}"
                else
                    echo -e "${YELLOW}◐ ${status}${RESET}"
                fi
                ;;
            *)
                # Wrap long lines for narrow pane (22 chars)
                if [ ${#line} -gt 20 ]; then
                    echo "$line" | fold -w 20 -s
                else
                    echo "$line"
                fi
                ;;
        esac
    done < "$RESPONSE_FILE"
}

# Show initial state
show_header
show_response

# Track file modifications
last_size=0
last_mod=0

# Watch loop (polling for macOS compatibility)
while true; do
    sleep 0.5

    if [ -f "$RESPONSE_FILE" ]; then
        current_size=$(stat -f %z "$RESPONSE_FILE" 2>/dev/null || stat -c %s "$RESPONSE_FILE" 2>/dev/null || echo 0)
        current_mod=$(stat -f %m "$RESPONSE_FILE" 2>/dev/null || stat -c %Y "$RESPONSE_FILE" 2>/dev/null || echo 0)

        # Refresh if file changed
        if [ "$current_mod" -ne "$last_mod" ] || [ "$current_size" -ne "$last_size" ]; then
            show_header
            show_response
            last_size=$current_size
            last_mod=$current_mod
        fi
    fi
done
