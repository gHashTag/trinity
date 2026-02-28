#!/bin/bash
# Check Eternal Monitor Status

PID_FILE="/tmp/trinity-eternal-monitor.pid"

if [ ! -f "$PID_FILE" ]; then
    echo "⚠ Eternal monitor not running"
    exit 1
fi

PID=$(cat "$PID_FILE")

if ! ps -p "$PID" > /dev/null 2>&1; then
    echo "⚠ Eternal monitor PID file exists but process not running"
    echo "  PID: $PID (stale)"
    exit 1
fi

echo "✓ Eternal monitor running"
echo "  PID: $PID"
echo "  Uptime: $(ps -o etime= -p "$PID")"
echo ""
echo "Memory:"
ps -o rss= -p "$PID" | awk '{printf "  %.1f MB\n", $1/1024}'
echo ""
echo "Health check:"
./zig-out/bin/tri monitor --health
