#!/bin/bash
# DAY 4 TEST SCRIPT — SIMILARITY + BENCHMARK
# Tests UART communication with VSA FPGA for Day 4 features
#
# Usage: ./day4_test.sh [device]
# Default device: /dev/tty.usbserial-FT0HQCT4

set -e

DEVICE="${1:-/dev/tty.usbserial-FT0HQCT4}"
HOST="./uart_host_v4"

echo "╔════════════════════════════════════════╗"
echo "║     DAY 4 TEST — SIMILARITY            ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "Device: $DEVICE"
echo "Host: $HOST"
echo ""

# Check if host binary exists
if [ ! -f "$HOST" ]; then
    echo "❌ ERROR: Host binary not found: $HOST"
    echo "   Run: zig build-exe uart_host_v4.zig -O ReleaseFast"
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

# Test cases
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
echo "DAY 4 TEST COMPLETE"
echo "════════════════════════════════════════"
