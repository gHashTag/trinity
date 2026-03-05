#!/bin/bash
# ═════════════════════════════════════════════════════════════════════════
# DAY 1 — UART AUTOMATED TEST SCRIPT
#
# This script runs all Day 1 tests:
# 1. Loopback test (no FPGA needed)
# 2. Flash vsa_quantum_top.bit to FPGA
# 3. PING-PONG test over UART
# ═════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UART_HOST="$SCRIPT_DIR/uart_host_v2"
BITSTREAM="$SCRIPT_DIR/vsa_quantum_top.bit"
TOOLS_DIR="$SCRIPT_DIR/../tools"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║     DAY 1 — UART AUTOMATED TEST                             ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "This script will:"
echo "  1. Test UART cable (loopback)"
echo "  2. Flash bitstream to FPGA"
echo "  3. Run PING-PONG test"
echo ""
read -p "Press ENTER to start..."
echo ""

# ===== TEST 1: Loopback =====
echo "═══════════════════════════════════════════════════════════════"
echo "[TEST 1/3] UART LOOPBACK (no FPGA needed)"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "📌 SETUP: Short TX-RX on your USB-UART adapter"
echo "   ┌─────────────────┐"
echo "   │  USB-UART       │"
echo "   │  ┌───┐ ┌───┐    │"
echo "   │  │TX├─┼RX │    │  ← SHORT THESE!"
echo "   │  └───┘ └───┘    │"
echo "   └─────────────────┘"
echo ""

read -p "Press ENTER when ready..."

echo ""
echo "Running loopback test..."
if "$UART_HOST" loopback 2>&1 | grep -q "PASS"; then
    echo "✅ LOOPBACK TEST PASSED"
    LOOPBACK_PASS=1
else
    echo "❌ LOOPBACK TEST FAILED (or skipped)"
    LOOPBACK_PASS=0
fi
echo ""

# ===== TEST 2: Flash FPGA =====
echo "═══════════════════════════════════════════════════════════════"
echo "[TEST 2/3] FLASH BITSTREAM TO FPGA"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "📌 SETUP: Connect Platform Cable USB II to FPGA"
echo ""

# Check if bitstream exists
if [ ! -f "$BITSTREAM" ]; then
    echo "❌ Bitstream not found: $BITSTREAM"
    echo "   Run: ./synth.sh vsa_quantum_top.v vsa_quantum_top"
    exit 1
fi

# Check if Platform Cable is connected
if ! system_profiler SPUSBDataType 2>/dev/null | grep -q "03fd.*0013\|03fd.*0008"; then
    echo "⚠️  Platform Cable USB II not detected"
    echo ""
    echo "📌 SETUP: Connect Platform Cable USB II"
    echo "   If firmware not loaded, run:"
    echo "   sudo $TOOLS_DIR/fxload -v -t fx2 -d 03fd:0013 -i $TOOLS_DIR/xusb_xp2.hex"
    echo "   Then reconnect cable"
    echo ""
    read -p "Press ENTER when ready..."
fi

echo "Flashing bitstream..."
if sudo "$TOOLS_DIR/jtag_program" "$BITSTREAM" 2>&1 | grep -q "COMPLETE"; then
    echo "✅ FLASH SUCCESSFUL"
    FLASH_PASS=1
else
    echo "❌ FLASH FAILED"
    FLASH_PASS=0
fi
echo ""

# ===== TEST 3: PING-PONG =====
echo "═══════════════════════════════════════════════════════════════"
echo "[TEST 3/3] PING-PONG OVER UART"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "📌 SETUP: Connect USB-UART adapter to FPGA"
echo ""
echo "   USB-UART (FT232RL)      FPGA (QMTECH XC7A100T)"
echo "   ──────────────────────   ───────────────────────"
echo "   GND ───────────────→    GND"
echo "   TX ───────────────→    H16 (uart_rx)"
echo "   RX ←───────────────    J16 (uart_tx)"
echo ""

# Check if UART device exists
if [ ! -e "/dev/ttyUSB0" ]; then
    echo "❌ UART device not found: /dev/ttyUSB0"
    echo "   Connect USB-UART adapter"
    PING_PASS=0
else
    # Configure baud rate
    stty -f /dev/ttyUSB0 115200 cs8 -cstopb -parenb 2>/dev/null || true

    echo "Running PING test..."
    echo "Sending: PING (0xFF)"
    echo "Expecting: PONG (0xAA)"
    echo ""

    if "$UART_HOST" ping 2>&1 | grep -q "PASS"; then
        echo "✅ PING-PONG TEST PASSED"
        PING_PASS=1
    else
        echo "❌ PING-PONG TEST FAILED"
        echo "   Check connections:"
        echo "   - TX → H16 (uart_rx)"
        echo "   - RX ← J16 (uart_tx)"
        echo "   - GND → GND"
        PING_PASS=0
    fi
fi
echo ""

# ===== SUMMARY =====
echo "═══════════════════════════════════════════════════════════════"
echo "                    DAY 1 SUMMARY"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  [1/3] Loopback:    $([ $LOOPBACK_PASS -eq 1 ] && echo '✅ PASS' || echo '❌ FAIL')"
echo "  [2/3] Flash:       $([ $FLASH_PASS -eq 1 ] && echo '✅ PASS' || echo '❌ FAIL')"
echo "  [3/3] PING-PONG:   $([ $PING_PASS -eq 1 ] && echo '✅ PASS' || echo '❌ FAIL')"
echo ""

if [ $LOOPBACK_PASS -eq 1 ] && [ $FLASH_PASS -eq 1 ] && [ $PING_PASS -eq 1 ]; then
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║        ✅ DAY 1 COMPLETE — ALL TESTS PASSED!                 ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Next steps:"
    echo "  - Day 2: MODE + LED commands"
    echo "  - Day 3-4: VSA operations"
    echo "  - Day 5: BitNet inference"
    echo ""
    TOTAL_PASS=1
else
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║        ⚠️  SOME TESTS FAILED — CHECK LOGS ABOVE               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    TOTAL_PASS=0
fi

echo ""
echo "φ² + 1/φ² = 3 = TRINITY"

exit $([ $TOTAL_PASS -eq 1 ] && echo 0 || echo 1)
