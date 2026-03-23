#!/bin/bash
# fix-tmux.sh - Fix Ralph Dashboard tmux layout
set -e

RALPH_DIR="/Users/playra/trinity"
cd "$RALPH_DIR"

echo "=== TMUX FIX SCRIPT ==="
echo ""

# 1. Create new layout file with correct syntax
echo "[1/4] Creating new layout file..."
cat > .trinity/tmux/layouts/ralph-dashboard.conf << 'EOF'
# Ralph Dashboard - Fixed Layout
# Session name: ralph
new-session -s ralph -n "Loop" -d
send-keys "cd $RALPH_DIR && watch -n 2 -c '.ralph/scripts/tmux_status.sh panel0'" C-m

# Split: Loop | Workers
split-window -h -p 50
send-keys "cd $RALPH_DIR && watch -n 5 -c '.ralph/scripts/tmux_status.sh panel1'" C-m
select-pane -t 0

# Window 2: Tasks | TechTree
new-window -n "Tasks"
send-keys "cd $RALPH_DIR && watch -n 5 -c '.ralph/scripts/tmux_status.sh panel2'" C-m
split-window -h -p 60
send-keys "cd $RALPH_DIR && watch -n 10 -c '.ralph/scripts/tmux_status.sh panel3'" C-m
select-pane -t 0

# Window 3: Memory | Log
new-window -n "Memory"
send-keys "cd $RALPH_DIR && watch -n 15 -c '.ralph/scripts/tmux_status.sh panel4'" C-m
split-window -h -p 60
send-keys "cd $RALPH_DIR/.ralph/logs" C-m
send-keys "sh -c 'tail -f \$(ls -t *.log 2>/dev/null | head -1 || echo ralph.log)'" C-m
select-pane -t 0

# Window 4: Full Log
new-window -n "Log"
send-keys "cd $RALPH_DIR/.ralph/logs" C-m
send-keys "tail -f ralph.log" C-m

# Select first window
select-window -t 1

# Status bar
set-option -g status-interval 2
set-option -g status-left-length 60
set-option -g status-right-length 120
set-option -g status-left '#[fg=colour220]RALPH #[fg=colour075]CMD #[fg=colour141]CENTER'
set-option -g status-right '#(cd /Users/playra/trinity && .ralph/scripts/tmux_status.sh statusline)'
set-option -g status-style "bg=colour235,fg=colour255"
EOF

echo "  Layout file created"

# 2. Fix Panel 1 (Workers) - read from fix_plan instead of non-existent task files
echo "[2/4] Fixing panel1_workers()..."
cat > /tmp/panel1_fix.txt << 'PANEL1'
panel1_workers() {
    # Panel 1: Worker Agents (MATERIYA)
    echo -e "${BOLD}${CYAN}MATERIYA: Worker Agents${RESET}"
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    # Show fix_plan tasks instead of non-existent worker files
    local fix_plan=""
    if [ -f ".ralph/internal/fix_plan.md" ]; then
        fix_plan=".ralph/internal/fix_plan.md"
    elif [ -f ".ralph/fix_plan.md" ]; then
        fix_plan=".ralph/fix_plan.md"
    fi

    if [ -n "$fix_plan" ]; then
        # Count active tasks
        local total=$(grep -c "^- \[ \]" "$fix_plan" 2>/dev/null || echo "0")
        local done=$(grep -c "^- \[x\]" "$fix_plan" 2>/dev/null || echo "0")
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
PANEL1
# Append to tmux_status.sh (backup first)
cp .ralph/scripts/tmux_status.sh .ralph/scripts/tmux_status.sh.bak
# Extract everything before panel1_workers, add new function, then skip old function
awk '
/^panel1_workers\(\)/ { skip=1; print ""; while(getline < "/tmp/panel1_fix.txt") print; next }
skip && /^}/ { skip=0; next }
!skip { print }
' .ralph/scripts/tmux_status.sh.bak > .ralph/scripts/tmux_status.sh
echo "  panel1_workers() updated"

# 3. Fix Panel 3 (TechTree) - parse table format
echo "[3/4] Fixing panel3_techtree()..."
cat > /tmp/panel3_fix.txt << 'PANEL3'
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
PANEL3
# Similar replacement for panel3_techtree
cp .ralph/scripts/tmux_status.sh .ralph/scripts/tmux_status.sh.bak2
awk '
/^panel3_techtree\(\)/ { skip=1; print ""; while(getline < "/tmp/panel3_fix.txt") print; next }
skip && /^}/ { skip=0; next }
!skip { print }
' .ralph/scripts/tmux_status.sh.bak2 > .ralph/scripts/tmux_status.sh
echo "  panel3_techtree() updated"

# 4. Restart session
echo "[4/4] Restarting tmux session..."
tmux kill-session -t ralph 2>/dev/null || true
sleep 1

# Create session with new layout
tmux new-session -d -s ralph
tmux source-file .trinity/tmux/layouts/ralph-dashboard.conf

echo ""
echo "=== DONE ==="
echo ""
echo "Verifying layout..."
tmux list-windows -t ralph -F "#{window_index}: #{window_name} (#{window_panes} panes)"
echo ""
echo "Attach with: tmux attach-session -t ralph"
