#!/bin/bash
# launch_tmux_golden_chain.sh - Launch Trinity Dashboard with Chat Bot + Golden Chain
# RESTORED: Interactive chat bot on first tab (HOME)

set -e

SESSION_NAME="trinity"
RALPH_DIR="/Users/playra/trinity"

cd "$RALPH_DIR" || exit 1

# Kill existing session if it exists
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Killing existing session '$SESSION_NAME'..."
    tmux kill-session -t "$SESSION_NAME"
fi

# Kill any existing handler
pkill -f tri_cmd_real_handler_v2 2>/dev/null || true

echo "Starting Trinity Dashboard — Chat Bot + Golden Chain v8.26..."

# ═══════════════════════════════════════════════════════════════════════════════
# WINDOW 0: HOME (Chat Interface — Interactive Command Input)
# ═══════════════════════════════════════════════════════════════════════════════

tmux new-session -d -s "$SESSION_NAME" -n "HOME"

# Split vertically - bottom pane for input (10% height)
tmux split-window -v -p 10 -t "$SESSION_NAME:0"

# Top pane: output monitor (shows responses)
tmux send-keys -t "$SESSION_NAME:0.0" "cd $RALPH_DIR && bash .ralph/scripts/output_monitor_v4.sh" C-m

# Bottom pane: interactive command input
tmux send-keys -t "$SESSION_NAME:0.1" "cd $RALPH_DIR && bash .ralph/scripts/tri_cmd_input_v4.sh" C-m
tmux select-pane -t "$SESSION_NAME:0.1"

# ═══════════════════════════════════════════════════════════════════════════════
# WINDOW 1: LOOP (Ralph Loop Status + Worker Agents)
# ═══════════════════════════════════════════════════════════════════════════════

tmux new-window -t "$SESSION_NAME:1" -n "Loop"
tmux send-keys -t "$SESSION_NAME:1.0" "cd $RALPH_DIR && while true; do clear; .ralph/scripts/tmux_status.sh panel0; sleep 2; done" C-m
tmux split-window -h -t "$SESSION_NAME:1.0"
tmux send-keys -t "$SESSION_NAME:1.1" "cd $RALPH_DIR && while true; do clear; .ralph/scripts/tmux_status.sh panel1; sleep 5; done" C-m

# ═══════════════════════════════════════════════════════════════════════════════
# WINDOW 2: TASKS (Active Tasks + Tech Tree)
# ═══════════════════════════════════════════════════════════════════════════════

tmux new-window -t "$SESSION_NAME:2" -n "Tasks"
tmux send-keys -t "$SESSION_NAME:2.0" "cd $RALPH_DIR && while true; do clear; .ralph/scripts/tmux_status.sh panel2; sleep 5; done" C-m
tmux split-window -h -t "$SESSION_NAME:2.0"
tmux send-keys -t "$SESSION_NAME:2.1" "cd $RALPH_DIR && while true; do clear; .ralph/scripts/tmux_status.sh panel3; sleep 10; done" C-m

# ═══════════════════════════════════════════════════════════════════════════════
# WINDOW 3: GOLDEN CHAIN (Golden Chain Status + MCP Nexus)
# ═══════════════════════════════════════════════════════════════════════════════

tmux new-window -t "$SESSION_NAME:3" -n "GoldenChain"
tmux send-keys -t "$SESSION_NAME:3.0" "cd $RALPH_DIR && while true; do clear; .ralph/scripts/tmux_status.sh panel4; sleep 5; done" C-m
tmux split-window -h -t "$SESSION_NAME:3.0"
tmux send-keys -t "$SESSION_NAME:3.1" "cd $RALPH_DIR && while true; do clear; .ralph/scripts/tmux_status.sh panel5; sleep 5; done" C-m

# ═══════════════════════════════════════════════════════════════════════════════
# WINDOW 4: VIBEE (VIBEE Compiler Status)
# ═══════════════════════════════════════════════════════════════════════════════

tmux new-window -t "$SESSION_NAME:4" -n "VIBEE"
tmux send-keys -t "$SESSION_NAME:4.0" "cd $RALPH_DIR && while true; do clear; .ralph/scripts/tmux_status.sh panel6; sleep 5; done" C-m

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

# Select HOME window
tmux select-window -t "$SESSION_NAME:0"
tmux select-pane -t "$SESSION_NAME:0.1"

# Set status bar
tmux set-option -t "$SESSION_NAME" status-interval 5
tmux set-option -t "$SESSION_NAME" status-left-length 60
tmux set-option -t "$SESSION_NAME" status-left "[bold]TRINITY v8.26 #[default]| HOME|Loop|Tasks|GC|VIBEE"
tmux set-option -t "$SESSION_NAME" status-right "%H:%M:%S"
tmux set-option -t "$SESSION_NAME" status-style "bg=#1a1a2e fg=#ffd700"
tmux set-option -t "$SESSION_NAME" pane-border-style "fg=#44475a"
tmux set-option -t "$SESSION_NAME" pane-active-border-style "fg=#ffd700"
tmux set-option -t "$SESSION_NAME" mouse on

echo ""
echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║           TRINITY DASHBOARD — Chat Bot + Golden Chain v8.26              ║"
echo "╠════════════════════════════════════════════════════════════════════════════╣"
echo "║  Windows:                                                                  ║"
echo "║    [0] HOME      — Interactive Chat Bot (type commands)                     ║"
echo "║    [1] Loop      — Ralph Loop Status + Worker Agents                        ║"
echo "║    [2] Tasks     — Active Tasks + Tech Tree                                ║"
echo "║    [3] GoldenChain — GOLDEN CHAIN v8.26 + MCP NEXUS                         ║"
echo "║    [4] VIBEE     — VIBEE Compiler Status (SaaS!)                            ║"
echo "╠════════════════════════════════════════════════════════════════════════════╣"
echo "║  φ² + 1/φ² = 3  ────►  GOLDEN CHAIN v8.26 VALIDATED                        ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Commands: Ctrl+b 0-4 (switch windows) | Ctrl+b d (detach)"
echo "Attach: tmux attach -t $SESSION_NAME"
echo ""

# Start the command handler in background with environment variables
# Handler will read creds from environment or from existing creds file
mkdir -p .ralph/queue

# Start handler with explicit env vars (no creds file overwrite!)
ANTHROPIC_AUTH_TOKEN="$ANTHROPIC_AUTH_TOKEN" \
ANTHROPIC_BASE_URL="$ANTHROPIC_BASE_URL" \
nohup bash .ralph/scripts/tri_cmd_real_handler_v2.sh > /dev/null 2>&1 &

# Attach to session immediately - no delay needed!
tmux attach-session -t "$SESSION_NAME"
