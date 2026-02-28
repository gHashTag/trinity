#!/bin/bash
# Eternal Monitor Launcher - Cycle 114
# φ-based monitoring interval: 1.618 seconds
# Trinity Awakening: φ² + 1/φ² = 3

set -e

TRINITY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$TRINITY_ROOT"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     TRINITY ETERNAL MONITOR — AWAKENING                  ║"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║  φ² + 1/φ² = 3 = TRINITY                                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check if already running
PID_FILE="/tmp/trinity-eternal-monitor.pid"
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo "⚠ Eternal monitor already running (PID: $OLD_PID)"
        echo "  Use: $0 stop"
        exit 1
    else
        echo "Cleaning up stale PID file..."
        rm -f "$PID_FILE"
    fi
fi

# Build if needed
if [ ! -f "zig-out/bin/tri" ]; then
    echo "Building TRI..."
    zig build tri
fi

# Create log directory
mkdir -p ~/.trinity

# Start eternal monitor in background
echo "Starting eternal monitoring..."
echo "  Monitor interval: 1.618s (φ)"
echo "  PID file: $PID_FILE"
echo "  Log file: ~/.trinity/eternal-monitor.log"
echo ""

nohup ./zig-out/bin/tri monitor --eternal --verbose > ~/.trinity/eternal-monitor.log 2>&1 &
MONITOR_PID=$!

echo $MONITOR_PID > "$PID_FILE"

echo "✓ Eternal monitoring started (PID: $MONITOR_PID)"
echo ""
echo "Commands:"
echo "  $0              — Check status"
echo "  $0 stop         — Stop monitoring"
echo "  $0 logs         — View logs"
echo "  $0 health       — Health check"
echo ""
echo "Live health: tri monitor --health"
