#!/bin/bash
# Ralph Dashboard Launcher
# Launches Trinity TMUX Dashboard with Chat Bot + Golden Chain

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Go to trinity-nexus root
cd "$SCRIPT_DIR/../.." || exit 1

echo "Starting Trinity Dashboard from: $(pwd)"
echo ""

# Launch the tmux dashboard
bash ralph/scripts/tmux/launch.sh
