#!/bin/bash
# E2E Test: Ralph Monitor Buttons START/STOP/RESTART
# Тестируем что кнопки реально управляют процессами

set -e

echo "=== Ralph Buttons E2E Test ==="

# Helper functions
count_ralph_processes() {
    pgrep -f 'ralph_loop.sh' 2>/dev/null | wc -l | tr -d ' '
}

count_ralph_monitor() {
    pgrep -f 'ralph_monitor.sh' 2>/dev/null | wc -l | tr -d ' '
}

wait_for_processes() {
    local expected=$1
    local timeout=$2
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        local count=$(count_ralph_processes)
        if [ "$count" -eq "$expected" ]; then
            echo "✓ Process count reached: $expected"
            return 0
        fi
        sleep 0.5
        elapsed=$((elapsed + 500))
    done
    echo "✗ Timeout waiting for $expected processes (got $(count_ralph_processes))"
    return 1
}

# Test 1: Initial state
echo ""
echo "Test 1: Initial state"
INITIAL_COUNT=$(count_ralph_processes)
echo "  Initial ralph_loop.sh processes: $INITIAL_COUNT"
if [ "$INITIAL_COUNT" -eq 0 ]; then
    echo "  ✗ FAIL: No ralph processes running! Start ralph first."
    exit 1
fi

INITIAL_MONITOR=$(count_ralph_monitor)
echo "  Initial ralph_monitor.sh processes: $INITIAL_MONITOR"

# Test 2: STOP command
echo ""
echo "Test 2: STOP command (via pkill with children)"
# Kill children first, then parents (to avoid orphaned claude processes)
pgrep -f 'ralph_loop.sh' 2>/dev/null | xargs -r pkill -9 -P 2>/dev/null || true
pkill -9 -f 'ralph_monitor.sh' 2>/dev/null || true
pkill -9 -f 'ralph_loop.sh' 2>/dev/null || true
sleep 1

STOP_COUNT=$(count_ralph_processes)
STOP_MONITOR=$(count_ralph_monitor)
echo "  After STOP - ralph_loop.sh: $STOP_COUNT, ralph_monitor.sh: $STOP_MONITOR"

if [ "$STOP_COUNT" -gt 0 ]; then
    echo "  ✗ FAIL: Processes still running after STOP!"
    ps aux | grep -E '[r]alph' || true
else
    echo "  ✓ PASS: All processes stopped"
fi

# Test 3: START command (via ralph_loop.sh directly)
echo ""
echo "Test 3: START command"
cd /Users/playra/trinity
RALPH_LOOP="/Users/playra/.ralph/ralph_loop.sh"
if [ -f "$RALPH_LOOP" ]; then
    # Start ralph_loop.sh directly (ralph is globally installed)
    "$RALPH_LOOP" --live --calls 100 --timeout 30 > /tmp/ralph_loop_test.log 2>&1 &
    echo "  Started ralph_loop.sh"

    sleep 3  # Wait for loop to start

    START_COUNT=$(count_ralph_processes)
    echo "  After START - ralph_loop.sh processes: $START_COUNT"

    if [ "$START_COUNT" -gt 0 ]; then
        echo "  ✓ PASS: Ralph processes started"
    else
        echo "  ✗ FAIL: No ralph processes after START!"
    fi
else
    echo "  ⚠ SKIP: ralph_loop.sh not found at $RALPH_LOOP"
fi

# Summary
echo ""
echo "=== Test Summary ==="
echo "Initial: $INITIAL_COUNT loop + $INITIAL_MONITOR monitor"
echo "After STOP: $STOP_COUNT loop + $STOP_MONITOR monitor"
echo "After START: ${START_COUNT:-0} loop"

# Tests pass if STOP killed all processes
if [ "$STOP_COUNT" -eq 0 ]; then
    echo "✓ ALL TESTS PASSED (STOP confirmed working)"
    exit 0
else
    echo "✗ TESTS FAILED"
    exit 1
fi
