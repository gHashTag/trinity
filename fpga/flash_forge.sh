#!/bin/bash
# ============================================================================
# FORGE OF KOSCHEI — Flash bitstream to Arty A7
# ============================================================================
# Usage:
#   ./fpga/flash_forge.sh                              # default bitstream
#   ./fpga/flash_forge.sh build/forge_trinity.bit      # custom bitstream
# ============================================================================

BITSTREAM="${1:-build/forge_trinity.bit}"

echo "═══════════════════════════════════════════════"
echo " FORGE OF KOSCHEI — HARDWARE FLASH"
echo " Bitstream: $BITSTREAM"
echo " Target:    XC7A35T (Arty A7)"
echo "═══════════════════════════════════════════════"

if [ ! -f "$BITSTREAM" ]; then
    echo "ERROR: Bitstream not found: $BITSTREAM"
    echo "Run first:"
    echo "  zig build forge -- run \\"
    echo "    --input fpga/sim/build/trinity.json \\"
    echo "    --device xc7a35t \\"
    echo "    --constraints fpga/fly-vivado/constraints/arty_a7.xdc \\"
    echo "    --output build/forge_trinity.bit"
    exit 1
fi

echo ""
echo "Checking USB devices..."
system_profiler SPUSBDataType 2>/dev/null | grep -A5 "Xilinx\|Digilent\|FTDI" || true
echo ""

# Method 1: openFPGALoader (requires Arty A7 connected via USB-micro)
if command -v openFPGALoader &>/dev/null; then
    echo "[1/3] Trying openFPGALoader (Arty A7 onboard USB)..."
    if openFPGALoader --board arty_a7_35t "$BITSTREAM" 2>&1; then
        echo ""
        echo "═══════════════════════════════════════════════"
        echo " FLASH COMPLETE — KOSCHEI LIVES IN SILICON"
        echo "═══════════════════════════════════════════════"
        exit 0
    fi
    echo "openFPGALoader failed (board not connected via USB-micro?)"
    echo ""
fi

# Method 2: OpenOCD (requires FTDI-based JTAG)
if command -v openocd &>/dev/null; then
    echo "[2/3] Trying OpenOCD (Digilent JTAG-SMT2)..."
    if openocd \
        -f interface/ftdi/digilent_jtag_smt2.cfg \
        -f cpld/xilinx-xc7.cfg \
        -c "adapter speed 25000" \
        -c "init" \
        -c "pld load 0 $BITSTREAM" \
        -c "shutdown" 2>&1; then
        echo ""
        echo "═══════════════════════════════════════════════"
        echo " FLASH COMPLETE — KOSCHEI LIVES IN SILICON"
        echo "═══════════════════════════════════════════════"
        exit 0
    fi
    echo "OpenOCD failed (no FTDI JTAG found)"
    echo ""
fi

# Method 3: Vivado (for Platform Cable USB II)
if command -v vivado &>/dev/null; then
    echo "[3/3] Trying Vivado Hardware Manager (Platform Cable USB II)..."
    vivado -mode batch -source fpga/fly-vivado/tcl/flash.tcl -tclargs "$BITSTREAM"
    exit $?
fi

# All methods failed
echo "═══════════════════════════════════════════════"
echo " AUTO-FLASH FAILED"
echo "═══════════════════════════════════════════════"
echo ""
echo "Your Platform Cable USB II (0x03fd:0x0013) requires Vivado."
echo ""
echo "SOLUTIONS:"
echo ""
echo "  A) Connect Arty A7 via USB-MICRO cable (onboard Digilent JTAG):"
echo "     openFPGALoader --board arty_a7_35t $BITSTREAM"
echo ""
echo "  B) Install Vivado Lab Edition (free, ~2GB):"
echo "     https://www.xilinx.com/support/download.html"
echo "     Then: vivado -mode batch -source fpga/fly-vivado/tcl/flash.tcl"
echo ""
echo "  C) Use Docker with Vivado (from existing setup):"
echo "     docker build -t trinity-vivado fpga/fly-vivado/"
echo "     docker run --privileged -v /dev/bus/usb:/dev/bus/usb \\"
echo "       -v \$(pwd)/build:/build trinity-vivado \\"
echo "       vivado -mode batch -source /tcl/flash.tcl -tclargs /build/forge_trinity.bit"
echo ""
exit 1
