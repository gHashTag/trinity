#!/bin/bash
# Trinity FPGA Flash Script — QMTECH XC7A100T via Platform Cable USB II
# Usage: sudo bash fpga/flash.sh <bitstream.bit>
#
# Steps:
# 1. Load firmware onto Platform Cable USB II (PID 0x0013 → 0x0008)
# 2. Detect JTAG chain
# 3. Program FPGA with bitstream

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOLS="$SCRIPT_DIR/tools"
FXLOAD="$TOOLS/fxload"
XC3SPROG="$TOOLS/xc3sprog"
DETECTCHAIN="$TOOLS/detectchain"
FIRMWARE="$TOOLS/xusb_xp2.hex"

BITSTREAM="${1:-$SCRIPT_DIR/fly-vivado/output/trinity_qmtech.bit}"

echo "=== TRINITY FPGA FLASH ==="
echo "Target: QMTECH XC7A100T-1FGG676C"
echo "Cable:  Platform Cable USB II (DLC10)"
echo "Bitstream: $BITSTREAM"
echo ""

# Check bitstream exists
if [ ! -f "$BITSTREAM" ]; then
    echo "ERROR: Bitstream not found: $BITSTREAM"
    echo "Run synthesis first on Fly.io"
    exit 1
fi

# Step 1: Load firmware if needed
echo "[1/3] Checking Platform Cable USB II firmware..."
if system_profiler SPUSBDataType 2>/dev/null | grep -q "Product ID: 0x0013"; then
    echo "  Cable PID=0x0013 (uninitialized). Loading firmware..."
    "$FXLOAD" -v -t fx2 -d 03fd:0013 -i "$FIRMWARE"
    echo "  Waiting for re-enumeration..."
    sleep 3
    if system_profiler SPUSBDataType 2>/dev/null | grep -q "Product ID: 0x0008"; then
        echo "  SUCCESS: Cable firmware loaded (PID=0x0008)"
    else
        echo "  WARNING: Cable may not have re-enumerated. Trying anyway..."
    fi
elif system_profiler SPUSBDataType 2>/dev/null | grep -q "Product ID: 0x0008"; then
    echo "  Cable PID=0x0008 (firmware loaded). Ready."
else
    echo "ERROR: Platform Cable USB II not detected!"
    echo "Check USB connection."
    exit 1
fi

# Step 2: Detect JTAG chain
echo ""
echo "[2/3] Detecting JTAG chain..."
"$DETECTCHAIN" -c xpc 2>&1 || true

# Step 3: Program FPGA
echo ""
echo "[3/3] Programming FPGA..."
"$XC3SPROG" -c xpc -v "$BITSTREAM"

echo ""
echo "=== TRINITY LIVES IN SILICON ==="
echo "phi^2 + 1/phi^2 = 3"
