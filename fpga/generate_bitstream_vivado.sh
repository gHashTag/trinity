#!/bin/bash
# ═════════════════════════════════════════════════════════════════════════
# TRINITY FPGA — Vivado Bitstream Generation Script
# ═════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR"/.. && pwd)"
SIM_DIR="$PROJECT_ROOT/sim"
BUILD_DIR="$SIM_DIR/build"
VERILOG_FILE="$SIM_DIR/trinity_simple.v"

mkdir -p "$BUILD_DIR"

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  TRINITY FPGA — VIVADO BITSTREAM GENERATION                        ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Detect Vivado installation
VIVADO_DIR=""
if [ -d "/Applications/Xilinx/Vivado/2024.2" ]; then
    VIVADO_DIR="/Applications/Xilinx/Vivado/2024.2"
elif [ -d "/Applications/Xilinx/Vivado/2025.1" ]; then
    VIVADO_DIR="/Applications/Xilinx/Vivado/2025.1"
elif [ -d "/tools/Xilinx" ]; then
    VIVADO_DIR="/tools/Xilinx"
else
    # Try to find in PATH
    VIVADO_DIR="$(dirname "$(dirname "$(which vivado 2>/dev/null || echo "")")")"
fi

if [ -z "$VIVADO_DIR" ] || [ ! -d "$VIVADO_DIR" ]; then
    echo "ERROR: Vivado not found!"
    echo ""
    echo "Please install Vivado WebPACK:"
    echo "  1. Download from: https://www.xilinx.com/member/forms/download/xef-vivado.html"
    echo "  2. Choose: Vivado ML Standard -> WebPACK Edition"
    echo "  3. After installation, run this script again"
    exit 1
fi

VIVADO_BIN="$VIVADO_DIR/bin"
echo "Found Vivado at: $VIVADO_BIN"
echo ""

# Create TCL synthesis script
cat > "$BUILD_DIR/synth.tcl" << 'VIVADO_EOF'
# Vivado synthesis script for Trinity FPGA
# Target: Digilent Arty A7 35T (xc7a35tcsg324-1)

# Set project parameters
set project_dir [file dirname [info script]]
set top_module trinity_top
set part_name xc7a35tcsg324-1

# Create project
create_project trinity_proj $project_dir/build/vivado_proj -part $part_name -force

# Add source files
add_files -norecurse $project_dir/../trinity_simple.v

# Set top module
set_property top $top_module [current_fileset]

# Read design
update_compile_order -fileset sources_1

# Synthesize design
puts "INFO: Starting synthesis..."
synth_design -top $top_module -part $part_name

# Optimize design
opt_design

# Place design
puts "INFO: Starting placement..."
place_design

# Route design
puts "INFO: Starting routing..."
route_design

# Write bitstream
puts "INFO: Generating bitstream..."
write_bitstream -force $project_dir/build/trinity.bit

puts "SUCCESS: Bitstream generated at $project_dir/build/trinity.bit"

# Close project
close_project

exit
VIVADO_EOF

# Run Vivado in batch mode
echo "Starting Vivado synthesis..."
echo ""

$VIVADO_BIN/vivado -mode batch -source "$BUILD_DIR/synth.tcl"

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  BITSTREAM GENERATED                                                   ║"
echo "║                                                                      ║"
echo "║  File: $BUILD_DIR/trinity.bit"
echo "║  Size: $(ls -lh "$BUILD_DIR/trinity.bit" 2>/dev/null | awk '{print $5}')"
echo "║                                                                      ║
echo "║  Next: Flash to Arty A7 with:                                      ║
echo "║  bash fpga/flash_arty_vivado.sh                                       ║
echo "║                                                                      ║
echo "╚══════════════════════════════════════════════════════════════════════╝"
