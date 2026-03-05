#!/bin/bash
# ═════════════════════════════════════════════════════════════════════════
# DAY 2 — UART MODE + LED CONTROL AUTOMATED TEST SCRIPT
#
# This script runs all Day 2 tests:
# 1. Loopback test (no FPGA needed)
# 2. Flash vsa_quantum_top.bit to FPGA
# 3. PING-PONG test over UART
# 4. MODE command test (all 4 LED modes)
# ═════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UART_HOST="$SCRIPT_DIR/uart_host_v2"
BITSTREAM="$SCRIPT_DIR/vsa_quantum_top.bit"
TOOLS_DIR="$SCRIPT_DIR/../tools"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║     DAY 2 — UART MODE + LED CONTROL TEST                    ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "This script will:"
echo "  1. Test UART cable (loopback)"
echo "  2. Flash bitstream to FPGA"
echo "  3. Run PING-PONG test"
echo "  4. Test all 4 LED MODE commands"
echo ""
read -p "Press ENTER to start..."
echo ""

# ===== CHECK BINARY =====
if [ ! -f "$UART_HOST" ]; then
    echo "❌ uart_host_v2 not found. Compiling..."
    cd "$SCRIPT_DIR"
    zig build-exe uart_host_v2.zig -O ReleaseFast
    if [ $? -eq 0 ]; then
        echo "✅ Compilation successful"
    else
        echo "❌ Compilation failed"
        exit 1
    fi
fi

# ===== TEST 1: Loopback =====
echo "═══════════════════════════════════════════════════════════════"
echo "[TEST 1/5] UART LOOPBACK (no FPGA needed)"
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
echo "[TEST 2/5] FLASH BITSTREAM TO FPGA"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "📌 SETUP: Connect Platform Cable USB II to FPGA"
echo ""

# Check if bitstream exists
if [ ! -f "$BITSTREAM" ]; then
    echo "❌ Bitstream not found: $BITSTREAM"
    echo ""
    echo "Run synthesis first:"
    echo "  cd $SCRIPT_DIR"
    echo "  ./synth.sh vsa_quantum_top.v vsa_quantum_top"
    echo ""
    read -p "Press ENTER after synthesis to continue, or Ctrl+C to abort..."
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

if [ -f "$BITSTREAM" ]; then
    echo "Flashing bitstream..."
    if sudo "$TOOLS_DIR/jtag_program" "$BITSTREAM" 2>&1 | grep -q "COMPLETE"; then
        echo "✅ FLASH SUCCESSFUL"
        FLASH_PASS=1
    else
        echo "❌ FLASH FAILED"
        FLASH_PASS=0
    fi
else
    echo "⏭️  FLASH SKIPPED (bitstream not found)"
    FLASH_PASS=0
fi
echo ""

# ===== TEST 3: PING-PONG =====
echo "═══════════════════════════════════════════════════════════════"
echo "[TEST 3/5] PING-PONG OVER UART"
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

# ===== TEST 4: LED MODE Commands =====
echo "═══════════════════════════════════════════════════════════════"
echo "[TEST 4/5] LED MODE COMMANDS (all 4 modes)"
echo "═══════════════════════════════════════════════════════════════"
echo ""

if [ $PING_PASS -eq 1 ]; then
    echo "Testing all 4 LED modes..."
    echo ""

    # Mode 0: SEPARABLE
    echo "[4.1/4.4] Testing SEPARABLE mode (0x01 0x00)"
    if "$UART_HOST" led 0 2>&1 | grep -q "successfully"; then
        echo "  ✅ SEPARABLE mode set"
        echo "  → LED should blink at ~1.5 Hz (clean periodic)"
        MODE0_PASS=1
    else
        echo "  ❌ SEPARABLE mode failed"
        MODE0_PASS=0
    fi
    echo ""
    sleep 1

    # Mode 1: VIOLATION
    echo "[4.2/4.4] Testing VIOLATION mode (0x01 0x01)"
    if "$UART_HOST" led 1 2>&1 | grep -q "successfully"; then
        echo "  ✅ VIOLATION mode set"
        echo "  → LED should blink chaotically (LFSR-driven)"
        MODE1_PASS=1
    else
        echo "  ❌ VIOLATION mode failed"
        MODE1_PASS=0
    fi
    echo ""
    sleep 1

    # Mode 2: ZERO
    echo "[4.3/4.4] Testing ZERO mode (0x01 0x02)"
    if "$UART_HOST" led 2 2>&1 | grep -q "successfully"; then
        echo "  ✅ ZERO mode set"
        echo "  → LED should blink slowly at ~0.75 Hz"
        MODE2_PASS=1
    else
        echo "  ❌ ZERO mode failed"
        MODE2_PASS=0
    fi
    echo ""
    sleep 1

    # Mode 3: NEGATIVE
    echo "[4.4/4.4] Testing NEGATIVE mode (0x01 0x03)"
    if "$UART_HOST" led 3 2>&1 | grep -q "successfully"; then
        echo "  ✅ NEGATIVE mode set"
        echo "  → LED should blink fast at ~3 Hz"
        MODE3_PASS=1
    else
        echo "  ❌ NEGATIVE mode failed"
        MODE3_PASS=0
    fi
    echo ""

    # Overall MODE test result
    if [ $MODE0_PASS -eq 1 ] && [ $MODE1_PASS -eq 1 ] && [ $MODE2_PASS -eq 1 ] && [ $MODE3_PASS -eq 1 ]; then
        MODE_PASS=1
        echo "✅ ALL 4 LED MODES PASSED"
    else
        MODE_PASS=0
        echo "❌ SOME LED MODES FAILED"
    fi
else
    echo "⏭️  SKIPPED (PING-PONG test must pass first)"
    MODE_PASS=0
fi
echo ""

# ===== TEST 5: Named Mode Commands =====
echo "═══════════════════════════════════════════════════════════════"
echo "[TEST 5/5] NAMED MODE COMMANDS"
echo "═══════════════════════════════════════════════════════════════"
echo ""

if [ $MODE_PASS -eq 1 ]; then
    echo "Testing named mode commands..."
    echo ""

    # Test all 4 named modes
    MODE_NAMES_PASS=1
    for mode_name in separable violation zero negative; do
        echo "Testing: mode $mode_name"
        if "$UART_HOST" mode "$mode_name" 2>&1 | grep -q "successfully"; then
            echo "  ✅ $mode_name OK"
        else
            echo "  ❌ $mode_name FAILED"
            MODE_NAMES_PASS=0
        fi
        echo ""
        sleep 0.5
    done

    if [ $MODE_NAMES_PASS -eq 1 ]; then
        echo "✅ ALL NAMED MODE COMMANDS PASSED"
    else
        echo "❌ SOME NAMED MODE COMMANDS FAILED"
    fi
else
    echo "⏭️  SKIPPED (LED MODE tests must pass first)"
    MODE_NAMES_PASS=0
fi
echo ""

# ===== SUMMARY =====
echo "═══════════════════════════════════════════════════════════════"
echo "                    DAY 2 SUMMARY"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  [1/5] Loopback:        $([ $LOOPBACK_PASS -eq 1 ] && echo '✅ PASS' || echo '❌ FAIL')"
echo "  [2/5] Flash:           $([ $FLASH_PASS -eq 1 ] && echo '✅ PASS' || echo '❌ FAIL')"
echo "  [3/5] PING-PONG:       $([ $PING_PASS -eq 1 ] && echo '✅ PASS' || echo '❌ FAIL')"
echo "  [4/5] LED Modes (4):   $([ $MODE_PASS -eq 1 ] && echo '✅ PASS' || echo '❌ FAIL')"
echo "  [5/5] Named Modes:     $([ $MODE_NAMES_PASS -eq 1 ] && echo '✅ PASS' || echo '❌ FAIL')"
echo ""

if [ $LOOPBACK_PASS -eq 1 ] && [ $FLASH_PASS -eq 1 ] && [ $PING_PASS -eq 1 ] && [ $MODE_PASS -eq 1 ] && [ $MODE_NAMES_PASS -eq 1 ]; then
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║        ✅ DAY 2 COMPLETE — ALL TESTS PASSED!                 ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Day 2 Deliverables:"
    echo "  ✅ Unified MODE command (0x01 XX)"
    echo "  ✅ 4 distinct LED patterns:"
    echo "     - SEPARABLE (0x00): ~1.5 Hz clean blink"
    echo "     - VIOLATION (0x01): Chaotic LFSR"
    echo "     - ZERO (0x02): ~0.75 Hz slow"
    echo "     - NEGATIVE (0x03): ~3 Hz fast"
    echo "  ✅ OK response (0x00) for MODE commands"
    echo "  ✅ PING-PONG (0xFF → 0xAA) still working"
    echo ""
    echo "Next steps:"
    echo "  - Day 3-4: VSA operations (bind, bundle, similarity)"
    echo "  - Day 5: BitNet inference over UART"
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
