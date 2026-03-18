#!/bin/bash
# flash.sh — Flash FPGA via Platform Cable USB II
# Usage: ./fpga/tools/flash.sh [bitstream.bit]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOLS_DIR="$SCRIPT_DIR"
BITFILE="${1:-$SCRIPT_DIR/../openxc7-synth/temporal_heartbeat.bit}"

if [ ! -f "$BITFILE" ]; then
    echo "Error: bitstream not found: $BITFILE"
    exit 1
fi

echo "═══════════════════════════════════════════════"
echo " TRINITY FPGA FLASH"
echo " Cable: Platform Cable USB II"
echo " File: $BITFILE"
echo "═══════════════════════════════════════════════"
echo ""

# Check if firmware needs loading
if system_profiler SPUSBDataType 2>/dev/null | grep -q "Product ID: 0x0013"; then
    echo "[0] Loading Platform Cable firmware..."
    sudo "$TOOLS_DIR/fxload" -v -t fx2 -d 03fd:0013 -i "$TOOLS_DIR/xusb_xp2.hex"
    echo "  Waiting for re-enumeration..."
    for i in $(seq 1 10); do
        sleep 1
        if system_profiler SPUSBDataType 2>/dev/null | grep -q "Product ID: 0x0008"; then
            echo "  Cable ready (PID=0x0008) after ${i}s"
            break
        fi
        [ "$i" = "10" ] && echo "  WARNING: Cable not detected after 10s"
    done
    echo ""
fi

echo "[1] Programming FPGA..."
sudo "$TOOLS_DIR/jtag_program" "$BITFILE"

echo ""
echo "═══════════════════════════════════════════════"
echo " DONE"
echo " φ² + 1/φ² = 3 = TRINITY"
echo "═══════════════════════════════════════════════"
