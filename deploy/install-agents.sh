#!/bin/bash
# install-agents.sh — Install LaunchAgent plist files with tokens from .env
# Usage: ./deploy/install-agents.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env not found at $ENV_FILE"
    exit 1
fi

# Source .env
set -a
source "$ENV_FILE"
set +a

LAUNCH_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$LAUNCH_DIR"

for plist in "$SCRIPT_DIR"/com.trinity.*.plist; do
    name=$(basename "$plist")
    echo "Installing $name..."
    sed \
        -e "s|__TELEGRAM_BOT_TOKEN__|${TELEGRAM_BOT_TOKEN}|g" \
        -e "s|__TELEGRAM_CHAT_ID__|${TELEGRAM_CHAT_ID}|g" \
        -e "s|__GH_TOKEN__|${GH_TOKEN:-$GITHUB_TOKEN}|g" \
        -e "s|__MU_REPORT_ISSUE__|${MU_REPORT_ISSUE}|g" \
        "$plist" > "$LAUNCH_DIR/$name"
    echo "  → $LAUNCH_DIR/$name"
done

echo ""
echo "Installed. To activate:"
echo "  launchctl load ~/Library/LaunchAgents/com.trinity.mu-agent.plist"
echo "  launchctl load ~/Library/LaunchAgents/com.trinity.ralph-agent.plist"
echo ""
echo "To reload after changes:"
echo "  launchctl unload ~/Library/LaunchAgents/com.trinity.mu-agent.plist"
echo "  launchctl load ~/Library/LaunchAgents/com.trinity.mu-agent.plist"
