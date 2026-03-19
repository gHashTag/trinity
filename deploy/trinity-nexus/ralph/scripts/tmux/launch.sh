#!/bin/bash
# launch.sh - Launch Trinity Dashboard v3.1
# NEW STRUCTURE: [0]=Welcome, [1]=Chat, others shifted

set -e

SESSION_NAME="trinity"
RALPH_DIR="/Users/playra/trinity/trinity-nexus"

cd "$RALPH_DIR" || exit 1

# Kill existing session if it exists
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Killing existing session '$SESSION_NAME'..."
    tmux kill-session -t "$SESSION_NAME"
fi

# Kill any existing handler
pkill -f tri_cmd_real_handler_v2 2>/dev/null || true

echo "Starting Trinity Dashboard v3.1..."

# ═══════════════════════════════════════════════════════════════════════════════
# WINDOW 0: WELCOME (ASCII Art Banner + System Status)
# ═══════════════════════════════════════════════════════════════════════════════

tmux new-session -d -s "$SESSION_NAME" -n "WELCOME"
tmux send-keys -t "$SESSION_NAME:0.0" "cd $RALPH_DIR && bash ralph/scripts/tmux/status.sh welcome" C-m

# ═══════════════════════════════════════════════════════════════════════════════
# WINDOW 1: HOME (Chat Interface — Interactive Command Input)
# ═══════════════════════════════════════════════════════════════════════════════

tmux new-window -t "$SESSION_NAME:1" -n "HOME"

# Split vertically - bottom pane for input (10% height)
tmux split-window -v -p 10 -t "$SESSION_NAME:1" -c "$RALPH_DIR"

# Top pane: output monitor (shows responses)
tmux send-keys -t "$SESSION_NAME:1.0" "cd $RALPH_DIR && bash ralph/scripts/tmux/output.sh" C-m

# Bottom pane: input script
tmux send-keys -t "$SESSION_NAME:1.1" "bash ralph/scripts/tmux/input.sh" C-m

tmux select-pane -t "$SESSION_NAME:1.1"

# ═══════════════════════════════════════════════════════════════════════════════
# WINDOW 2: LOOP (Ralph Loop Status + Worker Agents)
# ═══════════════════════════════════════════════════════════════════════════════

tmux new-window -t "$SESSION_NAME:2" -n "Loop"
tmux send-keys -t "$SESSION_NAME:2.0" "cd $RALPH_DIR && while true; do clear; ralph/scripts/tmux/status.sh panel0; sleep 2; done" C-m
tmux split-window -h -t "$SESSION_NAME:2.0"
tmux send-keys -t "$SESSION_NAME:2.1" "cd $RALPH_DIR && while true; do clear; ralph/scripts/tmux/status.sh panel1; sleep 5; done" C-m

# ═══════════════════════════════════════════════════════════════════════════════
# WINDOW 3: TASKS (Active Tasks + Tech Tree)
# ═══════════════════════════════════════════════════════════════════════════════

tmux new-window -t "$SESSION_NAME:3" -n "Tasks"
tmux send-keys -t "$SESSION_NAME:3.0" "cd $RALPH_DIR && while true; do clear; ralph/scripts/tmux/status.sh panel2; sleep 5; done" C-m
tmux split-window -h -t "$SESSION_NAME:3.0"
tmux send-keys -t "$SESSION_NAME:3.1" "cd $RALPH_DIR && while true; do clear; ralph/scripts/tmux/status.sh panel3; sleep 10; done" C-m

# ═══════════════════════════════════════════════════════════════════════════════
# WINDOW 4: GOLDEN CHAIN (Golden Chain Status + MCP Nexus)
# ═══════════════════════════════════════════════════════════════════════════════

tmux new-window -t "$SESSION_NAME:4" -n "GoldenChain"
tmux send-keys -t "$SESSION_NAME:4.0" "cd $RALPH_DIR && while true; do clear; ralph/scripts/tmux/status.sh panel4; sleep 5; done" C-m
tmux split-window -h -t "$SESSION_NAME:4.0"
tmux send-keys -t "$SESSION_NAME:4.1" "cd $RALPH_DIR && while true; do clear; ralph/scripts/tmux/status.sh panel5; sleep 5; done" C-m

# ═══════════════════════════════════════════════════════════════════════════════
# WINDOW 5: VIBEE (VIBEE Compiler Status)
# ═══════════════════════════════════════════════════════════════════════════════

tmux new-window -t "$SESSION_NAME:5" -n "VIBEE"
tmux send-keys -t "$SESSION_NAME:5.0" "cd $RALPH_DIR && while true; do clear; ralph/scripts/tmux/status.sh panel6; sleep 5; done" C-m

# ═══════════════════════════════════════════════════════════════════════════════
# WINDOW 6: SYSINFO (System Information - CPU, Memory, Disk, Network)
# ═══════════════════════════════════════════════════════════════════════════════

tmux new-window -t "$SESSION_NAME:6" -n "Sysinfo"
tmux send-keys -t "$SESSION_NAME:6.0" "cd $RALPH_DIR && while true; do clear; ralph/scripts/tmux/status.sh panel9; sleep 3; done" C-m

# ═══════════════════════════════════════════════════════════════════════════════
# WINDOW 7: MONITOR (Live Logs + Network Status)
# ═══════════════════════════════════════════════════════════════════════════════

tmux new-window -t "$SESSION_NAME:7" -n "Monitor"
tmux send-keys -t "$SESSION_NAME:7.0" "cd $RALPH_DIR && ralph/scripts/tmux/status.sh panel10" C-m
tmux split-window -h -t "$SESSION_NAME:7.0"
tmux send-keys -t "$SESSION_NAME:7.1" "cd $RALPH_DIR && while true; do clear; ralph/scripts/tmux/status.sh panel13; sleep 5; done" C-m

# ═══════════════════════════════════════════════════════════════════════════════
# WINDOW 8: DEV (Build Status + File Changes)
# ═══════════════════════════════════════════════════════════════════════════════

tmux new-window -t "$SESSION_NAME:8" -n "Dev"
tmux send-keys -t "$SESSION_NAME:8.0" "cd $RALPH_DIR && while true; do clear; ralph/scripts/tmux/status.sh panel11; sleep 5; done" C-m
tmux split-window -h -t "$SESSION_NAME:8.0"
tmux send-keys -t "$SESSION_NAME:8.1" "cd $RALPH_DIR && while true; do clear; ralph/scripts/tmux/status.sh panel12; sleep 5; done" C-m

# ═══════════════════════════════════════════════════════════════════════════════
# WINDOW 9: STATS (Quick Stats)
# ═══════════════════════════════════════════════════════════════════════════════

tmux new-window -t "$SESSION_NAME:9" -n "Stats"
tmux send-keys -t "$SESSION_NAME:9.0" "cd $RALPH_DIR && while true; do clear; ralph/scripts/tmux/status.sh panel14; sleep 3; done" C-m

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

# Select HOME window (chat is now on window 1)
tmux select-window -t "$SESSION_NAME:1"
tmux select-pane -t "$SESSION_NAME:1.1"

# Set status bar
tmux set-option -t "$SESSION_NAME" status-interval 5
tmux set-option -t "$SESSION_NAME" status-left-length 80
tmux set-option -t "$SESSION_NAME" status-left "[bold]TRINITY v3.1 #[default]| WELCOME|HOME|Loop|Tasks|GC|VIBEE|Sys|Mon|Dev|Stats"
tmux set-option -t "$SESSION_NAME" status-right "%H:%M:%S"
tmux set-option -t "$SESSION_NAME" status-style "bg=#1a1a2e fg=#ffd700"
tmux set-option -t "$SESSION_NAME" pane-border-style "fg=#44475a"
tmux set-option -t "$SESSION_NAME" pane-active-border-style "fg=#ffd700"
tmux set-option -t "$SESSION_NAME" mouse on

echo ""
echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║              TRINITY DASHBOARD v3.1 — 10 Windows                       ║"
echo "╠════════════════════════════════════════════════════════════════════════════╣"
echo "║  Windows:                                                                  ║"
echo "║    [0] WELCOME   — ASCII Art Banner + System Status                         ║"
echo "║    [1] HOME      — Interactive Chat Bot (type !help for commands)          ║"
echo "║    [2] Loop      — Ralph Loop Status + Worker Agents                        ║"
echo "║    [3] Tasks     — Active Tasks + Tech Tree                                ║"
echo "║    [4] GC        — GOLDEN CHAIN v8.26 + MCP NEXUS                         ║"
echo "║    [5] VIBEE     — VIBEE Compiler Status                                    ║"
echo "║    [6] Sysinfo   — System Information (CPU, Memory, Disk)                   ║"
echo "║    [7] Monitor   — Live Logs + Network Status                             ║"
echo "║    [8] Dev       — Build Status + File Changes                            ║"
echo "║    [9] Stats     — Quick Stats                                              ║"
echo "╠════════════════════════════════════════════════════════════════════════════╣"
echo "║  NEW: ASCII Welcome | Context Commands | Keyboard Nav | Search            ║"
echo "║  φ² + 1/φ² = 3  ────►  GOLDEN CHAIN v8.26 VALIDATED                        ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Commands: Ctrl+b 0-9 (switch windows) | Ctrl+b d (detach)"
echo "  Chat: Ctrl+b 1  |  Help: type !help or h"
echo "Attach: tmux attach -t $SESSION_NAME"
echo ""

# Start the command handler in background with environment variables
# Handler will read creds from environment or from existing creds file
mkdir -p ralph/queue

# Start handler with explicit env vars (no creds file overwrite!)
ANTHROPIC_AUTH_TOKEN="$ANTHROPIC_AUTH_TOKEN" \
ANTHROPIC_BASE_URL="$ANTHROPIC_BASE_URL" \
nohup bash ralph/scripts/tmux/handler.sh > /dev/null 2>&1 &

# Attach to session immediately - no delay needed!
tmux attach-session -t "$SESSION_NAME"
