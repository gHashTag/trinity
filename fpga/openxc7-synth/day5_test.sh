#!/bin/bash
# DAY 5 TEST SCRIPT — TINY BITNET INFERENCE VIA UART
# Tests UART communication with VSA FPGA for Day 5 features
#
# Usage: ./day5_test.sh [device]
# Default device: /dev/tty.usbserial-FT0HQCT4

set -e

DEVICE="${1:-/dev/tty.usbserial-FT0HQCT4}"
HOST="./uart_host_v5"

echo "╔════════════════════════════════════════╗"
echo "║   DAY 5 TEST — BITNET INFERENCE       ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "Device: $DEVICE"
echo "Host: $HOST"
echo ""

# Check if host binary exists
if [ ! -f "$HOST" ]; then
    echo "❌ ERROR: Host binary not found: $HOST"
    echo "   Run: zig build-exe uart_host_v5.zig -O ReleaseFast"
    exit 1
fi

# Check if device exists (but don't fail - user may not have cable)
if [ ! -e "$DEVICE" ]; then
    echo "⚠️  WARNING: UART device not found: $DEVICE"
    echo "   Connect UART cable and update device path"
    echo ""
    echo "Showing available serial devices:"
    ls -1 /dev/tty.usb* 2>/dev/null || echo "   No USB serial devices found"
    echo ""
    echo "Continuing with dry-run mode (shows commands)..."
    DRY_RUN=1
else
    DRY_RUN=0
fi

echo "════════════════════════════════════════"
echo "TEST SEQUENCE"
echo "════════════════════════════════════════"
echo ""

tests=(
    "loopback"
    "ping"
    "bind"
    "bundle"
    "similarity"
    "run-model 0"
    "run-model 1"
    "run-model 42"
    "benchmark"
)

if [ $DRY_RUN -eq 1 ]; then
    for test in "${tests[@]}"; do
        echo "[DRY RUN] $HOST $test"
    done
    echo ""
    echo "⚠️  Connect UART cable to run actual tests"
else
    for test in "${tests[@]}"; do
        echo "Running: $test"
        echo "---"
        $HOST $test || echo "⚠️  Test failed: $test"
        echo ""
    done
fi

echo "════════════════════════════════════════"
echo "DAY 5 TEST COMPLETE"
echo "════════════════════════════════════════"
echo ""
echo "Expected results:"
echo "  run-model 0  → Token: '0' (0x30)"
echo "  run-model 1  → Token: '1' (0x31)"
echo "  run-model 42 → Token: '!' (0x21) ← The Answer!"
