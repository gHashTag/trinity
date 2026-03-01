#!/bin/bash
# ═════════════════════════════════════════════════════════════════════════
# TRINITY FPGA — Flash Script for Digilent Arty A7 35T
# ═════════════════════════════════════════════════════════════════════════
# Uses openFPGALoader (handles macOS USB drivers properly)
# Falls back to OpenOCD if openFPGALoader is not available
#
# Usage:  sudo bash fpga/flash_arty_vivado.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIT_FILE="$SCRIPT_DIR/fly-vivado/output/trinity.bit"

echo ""
echo "  TRINITY FPGA — FLASH TO ARTY A7 35T"
echo "  ====================================="
echo ""

# Check root
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Must run as root."
    echo "  sudo bash $0"
    exit 1
fi

# Check bitstream
if [ ! -f "$BIT_FILE" ]; then
    echo "ERROR: Bitstream not found: $BIT_FILE"
    exit 1
fi

echo "  Bitstream: $BIT_FILE"
echo "  Size:      $(ls -lh "$BIT_FILE" | awk '{print $5}')"
echo ""

# macOS: unload Apple FTDI kext if loaded
if [ "$(uname)" = "Darwin" ]; then
    echo "  macOS: unloading Apple FTDI driver..."
    kextunload -b com.apple.driver.AppleUSBFTDI 2>/dev/null || true
    kextunload -b com.apple.driver.usb.serial 2>/dev/null || true
    sleep 1
fi

# Check connection
echo "  Checking FPGA connection..."
if system_profiler SPUSBDataType 2>/dev/null | grep -q "0x03fd"; then
    echo "  FPGA detected (Xilinx VID 0x03fd)"
elif system_profiler SPUSBDataType 2>/dev/null | grep -q "Digilent"; then
    echo "  FPGA detected (Digilent)"
else
    echo "  WARNING: FPGA may not be connected."
    echo "  Continuing anyway..."
fi
echo ""

# Method 1: openFPGALoader (preferred — handles macOS USB natively)
if command -v openFPGALoader >/dev/null 2>&1; then
    echo "  Using openFPGALoader (native FPGA programmer)..."
    echo "  Board: arty_a7_35t (xc7a35tcsg324)"
    echo ""

    # Try with Xilinx VID first (0x03fd:0x0013), then default
    if openFPGALoader -b arty_a7_35t --vid 0x03fd --pid 0x0013 "$BIT_FILE" 2>&1; then
        echo ""
        echo "  ================================================"
        echo "  TRINITY FLASHED TO ARTY A7!"
        echo "  PHI=0x19E38  PHI_SQ=0x29E1F  TRINITY=0x30000"
        echo "  ================================================"
        echo ""
        exit 0
    fi

    echo ""
    echo "  Xilinx VID failed. Trying with digilent cable..."
    if openFPGALoader -b arty_a7_35t -c digilent "$BIT_FILE" 2>&1; then
        echo ""
        echo "  ================================================"
        echo "  TRINITY FLASHED TO ARTY A7!"
        echo "  PHI=0x19E38  PHI_SQ=0x29E1F  TRINITY=0x30000"
        echo "  ================================================"
        echo ""
        exit 0
    fi

    echo ""
    echo "  Trying ft2232 cable with Xilinx VID..."
    if openFPGALoader -b arty_a7_35t -c ft2232 --vid 0x03fd --pid 0x0013 "$BIT_FILE" 2>&1; then
        echo ""
        echo "  ================================================"
        echo "  TRINITY FLASHED TO ARTY A7!"
        echo "  PHI=0x19E38  PHI_SQ=0x29E1F  TRINITY=0x30000"
        echo "  ================================================"
        echo ""
        exit 0
    fi

    echo ""
    echo "  Trying digilent_hs2 cable with Xilinx VID..."
    if openFPGALoader -b arty_a7_35t -c digilent_hs2 --vid 0x03fd --pid 0x0013 "$BIT_FILE" 2>&1; then
        echo ""
        echo "  ================================================"
        echo "  TRINITY FLASHED TO ARTY A7!"
        echo "  PHI=0x19E38  PHI_SQ=0x29E1F  TRINITY=0x30000"
        echo "  ================================================"
        echo ""
        exit 0
    fi

    echo ""
    echo "  All openFPGALoader methods failed."
fi

# Method 2: OpenOCD fallback
if command -v openocd >/dev/null 2>&1; then
    echo "  openFPGALoader not found. Falling back to OpenOCD..."
    echo ""

    cat > /tmp/trinity_flash.cfg << OPENOCD_EOF
adapter driver ftdi
ftdi vid_pid 0x03fd 0x0013 0x0403 0x6010 0x0403 0x6014
ftdi channel 0
ftdi layout_init 0x00e8 0x60eb
reset_config none

adapter speed 10000
transport select jtag

source [find cpld/xilinx-xc7.cfg]

init

puts "Programming FPGA with trinity.bit..."
pld load 0 ${BIT_FILE}
puts ""
puts "SUCCESS: Trinity FPGA programmed!"
puts "PHI=0x19E38 | PHI_SQ=0x29E1F | TRINITY=0x30000"

shutdown
OPENOCD_EOF

    openocd -f /tmp/trinity_flash.cfg

    echo ""
    echo "  ================================================"
    echo "  TRINITY FLASHED TO ARTY A7!"
    echo "  PHI=0x19E38  PHI_SQ=0x29E1F  TRINITY=0x30000"
    echo "  ================================================"
    echo ""
    exit 0
fi

echo "ERROR: No FPGA programmer found."
echo "  Install: brew install openfpgaloader"
echo "  Or:      brew install openocd"
exit 1
