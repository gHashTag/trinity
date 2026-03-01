#!/bin/bash
# ═════════════════════════════════════════════════════════════════════════
# TRINITY FPGA — OpenOCD Flash Script for Digilent Arty A7 35T
# ═════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR"/.. && pwd)"
BUILD_DIR="$PROJECT_ROOT/sim/build"
BIT_FILE="$BUILD_DIR/trinity.bit"

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  TRINITY FPGA — FLASH TO ARTY A7                                    ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Check if bitstream exists
if [ ! -f "$BIT_FILE" ]; then
    echo "ERROR: Bitstream file not found: $BIT_FILE"
    echo ""
    echo "Please generate bitstream first:"
    echo "  bash fpga/generate_bitstream_vivado.sh"
    exit 1
fi

echo "Bitstream: $BIT_FILE"
echo "Size: $(ls -lh "$BIT_FILE" | awk '{print $5}')"
echo ""

# Check FPGA connection
echo "Checking FPGA connection..."
if system_profiler SPUSBDataType 2>/dev/null | grep -q "Xilinx"; then
    echo "✅ FPGA detected via USB"
else
    echo "⚠️  FPGA not detected via USB"
    echo "   Please ensure:"
    echo "   • Arty A7 is connected via USB"
    echo "   • Jumper is set to JTAG mode (not SW)"
fi
echo ""

# Create OpenOCD configuration
cat > /tmp/trinity_flash.cfg << 'EOF'
# OpenOCD configuration for Digilent Arty A7 35T
# Target: xc7a35tcsg324-1 (Artix-7 35T)

# Interface: FTDI (Digilent USB)
adapter driver ftdi
adapter speed 1000

# Target
transport select jtag
# Target Xilinx 7-series
set CHIP_FAMILY xc7
set CHIP_NAME xc7a35t
set CPLD_JTAG_CHAIN_LENGTH 4
set CABLE_BUS_WIDTH 12

# JTAG chain for Artix A7 35T:
# 0: xc7a35t (FPGA)
# 1: xc7s50 (unused)
# 2: unknown (unused)
# 3: unknown (unused)

target create xc7.chain tap -expected-id 0x0372e093

# Target settings for Xilinx 7-series
xc7.chain tap -irlen 6 -ircount 8

# FPGA device
target create xc7a35t.device testee -chain-position 0

# Initialize
init

# Program FPGA
puts "INFO: Programming FPGA with trinity.bit..."
xc7_program xc7a35t.device

# Load bitstream and program
pld load 0 trinity.bit

puts "SUCCESS: Trinity FPGA programmed!"

# Exit
shutdown
EOF

# Run OpenOCD
echo "Starting OpenOCD programming..."
echo ""

# Try to use system OpenOCD or Docker OpenOCD
if command -v openocd &>/dev/null; then
    cd "$BUILD_DIR"
    openocd -f /tmp/trinity_flash.cfg
else
    echo "Using OpenOCD from Docker..."
    docker run --rm \
        -v "$BUILD_DIR:/workspace" \
        --device-read \
        --device-write \
        f4pga-artix7:mini \
        bash -c "
            cd /workspace
            openocd -f /tmp/trinity_flash.cfg
        "
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  TRINITY FLASHED TO ARTY A7!                                       ║"
echo "║                                                                      ║
echo "║  Your Trinity design is now running on the FPGA!                    ║
echo "║                                                                      ║
echo "║  φ² + 1/φ² = 3  (Trinity Heartbeat)                                ║
echo "║                                                                      ║
echo "╚══════════════════════════════════════════════════════════════════════╝"
