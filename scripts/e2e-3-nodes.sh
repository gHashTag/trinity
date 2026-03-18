#!/bin/bash
# E2E Test: 3 Node Cluster Bootstrap
# φ² + 1/φ² = 3 = TRINITY

set -e

PORTS=(9001 9002 9003)
PID_FILE=".tri-serve-cluster.pid"
LOG_DIR=".tri-serve-logs"

echo "════════════════════════════════════════════════════════════════"
echo "  E2E TEST: 3 NODE CLUSTER BOOTSTRAP"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo "=== CLEANUP ==="
    if [ -f "$PID_FILE" ]; then
        while read -r pid; do
            kill "$pid" 2>/dev/null || true
        done < "$PID_FILE"
        rm -f "$PID_FILE"
    fi
    echo "All nodes stopped"
}

trap cleanup EXIT INT TERM

# Create log directory
mkdir -p "$LOG_DIR"

# Start nodes
echo "=== STARTING 3 NODES ==="
for i in "${!PORTS[@]}"; do
    port=${PORTS[$i]}
    role="primary"
    if [ $i -eq 1 ]; then role="secondary"; fi
    if [ $i -eq 2 ]; then role="worker"; fi
    
    echo "Node $((i+1)): port=$port role=$role"
    ./zig-out/bin/tri serve --port "$port" > "$LOG_DIR/node-$port.log" 2>&1 &
    pid=$!
    echo "$pid" >> "$PID_FILE"
    
    # Wait for node to start
    sleep 1
    
    # Verify node is listening
    if curl -s "http://127.0.0.1:$port/health" > /dev/null 2>&1; then
        echo "  ✅ Node $port responding"
    else
        echo "  ❌ Node $port NOT responding"
        exit 1
    fi
done

echo ""
echo "=== CLUSTER STATUS ==="
for port in "${PORTS[@]}"; do
    echo ""
    echo "Node $port:"
    curl -s "http://127.0.0.1:$port/health" | head -5 || echo "  Health check failed"
done

echo ""
echo "=== E2E TEST PASSED ==="
echo "3 nodes started, all responding to health checks"
echo "Logs: $LOG_DIR/"
echo ""
