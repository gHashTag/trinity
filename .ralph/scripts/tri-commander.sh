#!/bin/bash
# TRI COMMANDER — High-Level Strategic Interface v10
# Правая панель для высокоуровневого управления армией агентов

RALPH_DIR="/Users/playra/trinity"
cd "$RALPH_DIR" 2>/dev/null || exit 1

# Trinity colors
GOLD="\033[38;5;220m"
CYAN="\033[38;5;075m"
PURPLE="\033[38;5;141m"
GREEN="\033[38;5;042m"
GRAY="\033[38;5;244m"
RESET="\033[0m"
BOLD="\033[1m"

# Narrow layout for 22-char wide pane
show_banner() {
    clear
    echo -e "${BOLD}${GOLD}┏━━━━━━━━━━━━━━━━━━━━━━┓${RESET}"
    echo -e "${BOLD}${GOLD}┃${RESET}  ${CYAN}TRI COMMANDER${RESET}   ${BOLD}${GOLD}┃${RESET}"
    echo -e "${BOLD}${GOLD}┃${RESET}  ${GREEN}ARMY CONTROL${RESET}     ${BOLD}${GOLD}┃${RESET}"
    echo -e "${BOLD}${GOLD}┗━━━━━━━━━━━━━━━━━━━━━━┛${RESET}"
    echo ""
    echo -e "${CYAN}Генерал!${RESET}"
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${GREEN}•${RESET} Пиши задачи"
    echo -e "${GREEN}•${RESET} Советуйся"
    echo -e "${GREEN}•${RESET} Приказы армии"
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "${BOLD}${PURPLE}АГЕНТЫ:${RESET}"
    echo -e " ${GRAY}•${RESET} VIBEE"
    echo -e " ${GRAY}•${RESET} Firebird"
    echo -e " ${GRAY}•${RESET} VSA Math"
    echo -e " ${GRAY}•${RESET} VM Squad"
    echo ""
    echo -e "${BOLD}${GOLD}━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}

show_banner

# Start shell with custom prompt
export PS1="${BOLD}${GOLD}►${RESET} "

# Start bash directly (avoid zsh compinit issues)
exec bash --noprofile --norc 2>/dev/null || exec $SHELL
