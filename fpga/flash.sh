#!/bin/bash
# Trinity FPGA Flash Script — QMTECH XC7A100T/200T via Platform Cable USB II
# Usage: sudo bash fpga/flash.sh [bitstream.bit]
#
# Requires sudo for USB access (libusb on macOS).
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

# Default: use openxc7-synth bitstream (XC7A100T), fall back to vivado output
if [ -n "$1" ]; then
    BITSTREAM="$1"
elif [ -f "$SCRIPT_DIR/openxc7-synth/trinity.bit" ]; then
    BITSTREAM="$SCRIPT_DIR/openxc7-synth/trinity.bit"
elif [ -f "$SCRIPT_DIR/fly-vivado/output/trinity.bit" ]; then
    BITSTREAM="$SCRIPT_DIR/fly-vivado/output/trinity.bit"
else
    echo "ERROR: No bitstream found. Run synthesis first:"
    echo "  cd fpga/openxc7-synth && make"
    exit 1
fi

echo "═══════════════════════════════════════════════"
echo " TRINITY FPGA FLASH"
echo " Target:    QMTECH XC7A100T/200T Core Board"
echo " Cable:     Platform Cable USB II (DLC10)"
echo " Bitstream: $BITSTREAM"
echo "═══════════════════════════════════════════════"
echo ""

# Check sudo (needed for fxload firmware upload)
NEED_FXLOAD=false
if system_profiler SPUSBDataType 2>/dev/null | grep -q "Product ID: 0x0013"; then
    NEED_FXLOAD=true
    if [ "$(id -u)" -ne 0 ]; then
        echo "ERROR: Cable needs firmware upload, which requires sudo."
        echo "Run: sudo bash $0 $*"
        exit 1
    fi
fi

# Check bitstream exists
if [ ! -f "$BITSTREAM" ]; then
    echo "ERROR: Bitstream not found: $BITSTREAM"
    exit 1
fi

# Check tools exist
for tool in "$FXLOAD" "$XC3SPROG" "$DETECTCHAIN" "$FIRMWARE"; do
    if [ ! -f "$tool" ]; then
        echo "ERROR: Missing tool: $tool"
        exit 1
    fi
done

# Step 1: Load firmware if needed
echo "[1/3] Checking Platform Cable USB II firmware..."

if [ "$NEED_FXLOAD" = "true" ]; then
    echo "  Cable PID=0x0013 (uninitialized). Loading firmware..."
    if ! "$FXLOAD" -v -t fx2 -d 03fd:0013 -i "$FIRMWARE" 2>&1; then
        echo "  ERROR: fxload failed. Check USB connection and try again."
        exit 1
    fi
    echo "  Waiting for re-enumeration..."
    for i in 1 2 3 4 5 6 7 8 9 10; do
        sleep 1
        if system_profiler SPUSBDataType 2>/dev/null | grep -q "Product ID: 0x0008"; then
            echo "  SUCCESS: Cable firmware loaded (PID=0x0008) after ${i}s"
            break
        fi
        if [ "$i" = "10" ]; then
            echo "  WARNING: PID=0x0008 not yet detected after 10s. Trying anyway..."
        fi
    done
elif system_profiler SPUSBDataType 2>/dev/null | grep -q "Product ID: 0x0008"; then
    echo "  Cable PID=0x0008 (firmware already loaded). Ready."
else
    echo "ERROR: Platform Cable USB II not detected!"
    echo ""
    echo "Check:"
    echo "  1. Cable is connected via USB"
    echo "  2. Cable LED is on (green or amber)"
    echo "  3. Run: system_profiler SPUSBDataType | grep -A3 '0x03fd'"
    exit 1
fi

# Step 2: Detect JTAG chain
echo ""
echo "[2/3] Detecting JTAG chain..."
if "$DETECTCHAIN" -c xpc 2>&1; then
    echo "  JTAG chain detected."
else
    echo "  WARNING: detectchain returned error (may still work)."
fi

# Step 3: Program FPGA
echo ""
echo "[3/3] Programming FPGA..."
if "$XC3SPROG" -c xpc -v "$BITSTREAM" 2>&1; then
    echo ""
    echo "═══════════════════════════════════════════════"
    echo " FLASH COMPLETE — TRINITY LIVES IN SILICON"
    echo " phi^2 + 1/phi^2 = 3"
    echo "═══════════════════════════════════════════════"
else
    echo ""
    echo "═══════════════════════════════════════════════"
    echo " FLASH FAILED"
    echo "═══════════════════════════════════════════════"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Unplug and replug the Platform Cable USB II"
    echo "  2. Ensure JTAG ribbon cable connects to board's JTAG header"
    echo "  3. Check board power (separate power supply, not from cable)"
    echo "  4. Try: sudo $TOOLS/xc3sprog -c xpc -v $BITSTREAM"
    exit 1
fi
