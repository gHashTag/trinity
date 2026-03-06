#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# AUTO FLASH — fxload + flash in ONE command (NO REPLUG NEEDED!)
# ═══════════════════════════════════════════════════════════════════════════════
# Usage: ./flash_auto.sh <bitstream.bit>

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FXLOAD="$SCRIPT_DIR/fxload"
JTAG="$SCRIPT_DIR/jtag_program"
FIRMWARE="$SCRIPT_DIR/xusb_xp2.hex"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <bitstream.bit>"
    echo "Example: $0 ../openxc7-synth/singularity_v200.bit"
    exit 1
fi

BITSTREAM="$1"
if [ ! -f "$BITSTREAM" ]; then
    # Try relative to fpga directory
    BITSTREAM="$SCRIPT_DIR/../openxc7-synth/$(basename "$1")"
    if [ ! -f "$BITSTREAM" ]; then
        echo "ERROR: Bitstream not found: $1"
        exit 1
    fi
fi

echo "═══════════════════════════════════════════════"
echo " AUTO FLASH"
echo " Bitstream: $BITSTREAM"
echo "═══════════════════════════════════════════════"
echo ""

# Step 1: Load firmware (cable → PID 0013 → auto 0008)
echo "[1/2] Loading fxload firmware..."
sudo "$FXLOAD" -v -t fx2 -d 03fd:0013 -i "$FIRMWARE" 2>&1 | grep -E "WROTE|microcontroller" || true

# Step 2: Wait for auto-switch to PID 0008
echo "      Waiting for cable to switch to JTAG mode..."
for i in {1..15}; do
    sleep 1
    if system_profiler SPUSBDataType 2>/dev/null | grep -q "Product ID: 0x0008"; then
        echo "      ✓ Cable at PID 0008 after ${i}s"
        break
    fi
    if [ $i -eq 15 ]; then
        echo "      ✗ Timeout - REPLUG CABLE MANUALY!"
        exit 1
    fi
done

# Extra pause for USB to stabilize
echo "      Waiting for USB to stabilize..."
sleep 3

# Step 3: Flash
echo ""
echo "[2/2] Flashing..."
sudo "$JTAG" "$BITSTREAM"

echo ""
echo "═══════════════════════════════════════════════"
echo " DONE!"
echo "═══════════════════════════════════════════════"
