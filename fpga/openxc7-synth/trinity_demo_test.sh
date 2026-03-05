#!/bin/bash
# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  TRINITY V1 DEMO TEST — Complete system validation                         ║
# ║  Day 6: Full test of VSA + BitNet + Quantum + UART                         ║
# ╚════════════════════════════════════════════════════════════════════════════╝
#
# Usage: ./trinity_demo_test.sh [device]
# Default device: /dev/tty.usbserial-FT0HQCT4

set -e

DEVICE="${1:-/dev/tty.usbserial-FT0HQCT4}"
HOST="./uart_host_v6"

echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║  TRINITY V1 — COMPLETE SYSTEM DEMO                                        ║"
echo "║  φ² + 1/φ² = 3                                                             ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Device: $DEVICE"
echo "Host: $HOST"
echo ""

# Check if host binary exists
if [ ! -f "$HOST" ]; then
    echo "❌ ERROR: Host binary not found: $HOST"
    echo "   Run: zig build-exe uart_host_v6.zig -O ReleaseFast"
    exit 1
fi

# Check if bitstream exists
if [ ! -f "trinity_v1.bit" ]; then
    echo "❌ ERROR: Bitstream not found: trinity_v1.bit"
    echo "   Run: ./synth.sh trinity_v1.v trinity_v1"
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

echo "══════════════════════════════════════════════════════════════════════════════"
echo "TRINITY V1 TEST SEQUENCE"
echo "══════════════════════════════════════════════════════════════════════════════"
echo ""

tests=(
    "loopback"
    "ping"
    "mode violation"
    "bind"
    "bundle"
    "similarity"
    "run-model 0"
    "run-model 1"
    "run-model 42"
    "benchmark"
)

declare -A expected=(
    ["run-model 0"]="Token: '0' (0x30)"
    ["run-model 1"]="Token: '1' (0x31)"
    ["run-model 42"]="Token: '!' (0x21)"
)

passed=0
failed=0

if [ $DRY_RUN -eq 1 ]; then
    for test in "${tests[@]}"; do
        echo "[DRY RUN] $HOST $test"
    done
    echo ""
    echo "⚠️  Connect UART cable to run actual tests"
else
    for test in "${tests[@]}"; do
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Running: $test"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        if $HOST $test 2>&1; then
            echo "✅ PASS: $test"
            ((passed++))
        else
            echo "❌ FAIL: $test"
            ((failed++))
        fi
        echo ""
    done
fi

echo "══════════════════════════════════════════════════════════════════════════════"
echo "TRINITY V1 TEST SUMMARY"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "Passed: $passed"
echo "Failed: $failed"
echo ""

if [ $DRY_RUN -eq 0 ]; then
    if [ $failed -eq 0 ]; then
        echo "╔════════════════════════════════════════════════════════════════════════════╗"
        echo "║  ✅ TRINITY V1 — ALL TESTS PASSED                                            ║"
        echo "║  The sacred system lives on silicon.                                         ║"
        echo "║  φ² + 1/φ² = 3 = TRINITY                                                      ║"
        echo "╚════════════════════════════════════════════════════════════════════════════╝"
    else
        echo "⚠️  Some tests failed. Check FPGA bitstream and UART connection."
    fi
fi

echo ""
echo "══════════════════════════════════════════════════════════════════════════════"
echo "EXPECTED RESULTS (for verification)"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "  ping          → PONG (0xAA)"
echo "  bind          → 4 bytes (VSA bind result)"
echo "  bundle        → 4 bytes (VSA bundle result)"
echo "  similarity    → Score 0-255 (cosine similarity)"
echo "  run-model 0   → Token: '0' (0x30)"
echo "  run-model 1   → Token: '1' (0x31)"
echo "  run-model 42  → Token: '!' (0x21) ← The Answer!"
echo ""
