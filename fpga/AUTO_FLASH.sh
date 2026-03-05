#!/bin/bash
# ═════════════════════════════════════════════════════════════════════════
# VSA FPGA — FULLY AUTONOMOUS FLASH + TEST
# ═════════════════════════════════════════════════════════════════════════

set -e

BITFILE="/Users/playra/trinity-w1/fpga/openxc7-synth/vsa_uart_top.bit"
TOOLS="/Users/playra/trinity-w1/fpga/tools"
TEST_BIN="/Users/playra/trinity-w1/fpga/openxc7-synth/vsa_fpga_test"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     VSA FPGA — AUTONOMOUS FLASH + TEST                       ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Load firmware
echo "[1/4] Loading firmware to cable..."
"$TOOLS/fxload" -v -t fx2 -d 03fd:0013 -i "$TOOLS/xusb_xp2.hex"
echo "  Firmware loaded! PID should be 0x0008 now"
echo ""

# Step 2: Tell user to reconnect
echo "════════════════════════════════════════════════════════════════"
echo "🔌 RECONNECT USB CABLE NOW! (unplug & plug back in)"
echo "════════════════════════════════════════════════════════════════"
echo ""
read -p "Press ENTER after reconnecting..."

# Step 3: Flash
echo ""
echo "[2/4] Programming FPGA..."
"$TOOLS/jtag_program" "$BITFILE"
echo "  ✓ Flash complete!"
echo ""

# Step 4: Build test if needed
if [ ! -f "$TEST_BIN" ]; then
    echo "[3/4] Building test program..."
    cd /Users/playra/trinity-w1/fpga/openxc7-synth
    zig build-exe vsa_fpga_test.zig -O ReleaseFast
    echo "  ✓ Test program built"
fi

# Step 5: Run ping test
echo ""
echo "[4/4] Running tests..."
echo "─────────────────────────────────────────────────────────────────"

echo ""
echo "TEST: Ping..."
if "$TEST_BIN" ping 2>&1; then
    echo "  ✓ PING PASSED"
else
    echo "  ✗ PING FAILED (UART not connected?)"
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓ COMPLETE! φ² + 1/φ² = 3 = TRINITY"
echo "════════════════════════════════════════════════════════════════"
