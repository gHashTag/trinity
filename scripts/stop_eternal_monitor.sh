#!/bin/bash
# Stop Eternal Monitor

PID_FILE="/tmp/trinity-eternal-monitor.pid"

if [ ! -f "$PID_FILE" ]; then
    echo "⚠ Eternal monitor not running (no PID file)"
    exit 1
fi

PID=$(cat "$PID_FILE")

if ! ps -p "$PID" > /dev/null 2>&1; then
    echo "⚠ Process $PID not running (cleaning up stale PID file)"
    rm -f "$PID_FILE"
    exit 1
fi

echo "Stopping eternal monitor (PID: $PID)..."
kill "$PID"

# Wait for graceful shutdown
for i in {1..10}; do
    if ! ps -p "$PID" > /dev/null 2>&1; then
        echo "✓ Eternal monitor stopped"
        rm -f "$PID_FILE"
        exit 0
    fi
    sleep 1
done

# Force kill if needed
echo "⚠ Force killing..."
kill -9 "$PID" 2>/dev/null || true
rm -f "$PID_FILE"
echo "✓ Eternal monitor force-stopped"
