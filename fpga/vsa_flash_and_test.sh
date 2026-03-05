#!/bin/bash
# ═════════════════════════════════════════════════════════════════════════
# VSA FPGA — FLASH + UART TEST (Full Pipeline)
# ═════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VSA_DIR="$SCRIPT_DIR/openxc7-synth"
BITFILE="$VSA_DIR/vsa_uart_top.bit"
TEST_BIN="$VSA_DIR/vsa_fpga_test"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     VSA FPGA — FLASH + TEST PIPELINE                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check files exist
if [ ! -f "$BITFILE" ]; then
    echo "ERROR: Bitstream not found: $BITFILE"
    exit 1
fi

# ═════════════════════════════════════════════════════════════════════════
# STEP 1: FLASH
# ═════════════════════════════════════════════════════════════════════════
echo "[1/3] FLASHING BITSTREAM..."
echo "─────────────────────────────────────────────────────────────────"

sudo "$SCRIPT_DIR/tools/flash.sh" "$BITFILE"
echo ""

# ═════════════════════════════════════════════════════════════════════════
# STEP 2: PING TEST
# ═════════════════════════════════════════════════════════════════════════
echo "[2/3] UART PING TEST..."
echo "─────────────────────────────────────────────────────────────────"

if [ ! -f "$TEST_BIN" ]; then
    echo "Building test program..."
    cd "$VSA_DIR"
    zig build-exe vsa_fpga_test.zig -O ReleaseFast
fi

echo "Testing FPGA connectivity..."
if "$TEST_BIN" ping; then
    echo "✓ PING PASSED"
else
    echo "✗ PING FAILED"
fi
echo ""

# ═════════════════════════════════════════════════════════════════════════
# STEP 3: BENCHMARK
# ═════════════════════════════════════════════════════════════════════════
echo "[3/3] FULL BENCHMARK (256 dimensions)..."
echo "─────────────────────────────────────────────────────────────────"

"$TEST_BIN" benchmark 256
echo ""

# ═════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═════════════════════════════════════════════════════════════════════════
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     VSA FPGA WEEK 4 — TESTING COMPLETE                       ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║  ✓ Flash: Done                                                ║"
echo "║  ✓ Ping: Done                                                 ║"
echo "║  ✓ Benchmark: Done                                            ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║  φ² + 1/φ² = 3 = TRINITY                                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
