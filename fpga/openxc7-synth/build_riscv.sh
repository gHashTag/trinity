#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY OS — RISC-V Build Script
# ═══════════════════════════════════════════════════════════════════════════════
#
# Builds TRINITY V3 with RISC-V processor
# Generates bitstream for FPGA programming
#
# Usage: ./build_riscv.sh [--test|--clean|--help]
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  TRINITY V3 — RISC-V Build${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Golden Identity: φ² + 1/φ² = 3"
echo ""

#===============================================================================
# OPTION PARSING
#===============================================================================

BUILD_TEST="false"
CLEAN="false"

for arg in "$@"; do
    case $arg in
        --test)
            BUILD_TEST="true"
            ;;
        --clean)
            CLEAN="true"
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --test    Build RISC-V test program"
            echo "  --clean   Remove build artifacts"
            echo "  --help    Show this help"
            exit 0
            ;;
    esac
done

#===============================================================================
# CLEAN
#===============================================================================

if [ "$CLEAN" = "true" ]; then
    echo -e "${YELLOW}Cleaning build artifacts...${NC}"
    rm -rf build/riscv
    rm -f *.json *.fasm *.bit
    echo -e "${GREEN}Clean complete!${NC}"
    exit 0
fi

#===============================================================================
# DIRECTORIES
#===============================================================================

mkdir -p build/riscv

#===============================================================================
# STEP 1: CHECK FOR RISC-V TOOLCHAIN
#===============================================================================

echo -e "${GREEN}Step 1: Checking RISC-V toolchain...${NC}"

if command -v riscv32-unknown-elf-gcc &> /dev/null; then
    RISCV_GCC="riscv32-unknown-elf-gcc"
    echo "  Found: riscv32-unknown-elf-gcc"
elif command -v riscv64-unknown-elf-gcc &> /dev/null; then
    RISCV_GCC="riscv64-unknown-elf-gcc"
    echo "  Found: riscv64-unknown-elf-gcc (using 32-bit mode)"
else
    echo -e "${YELLOW}  RISC-V toolchain not found.${NC}"
    echo "  Install with: brew install riscv-tools"
    echo "  Or download from: https://github.com/riscv-collab/riscv-gnu-toolchain"
    echo ""
    echo "  Continuing without test program build..."
    BUILD_TEST="false"
fi

#===============================================================================
# STEP 2: BUILD TEST PROGRAM (if requested)
#===============================================================================

if [ "$BUILD_TEST" = "true" ] && [ -n "$RISCV_GCC" ]; then
    echo -e "${GREEN}Step 2: Building RISC-V test program...${NC}"

    # Build C version
    if [ -f "riscv/test_program.c" ]; then
        echo "  Compiling C test program..."
        $RISCV_GCC -march=rv32imc -mabi=ilp32 -nostdlib -Wl,-Ttext=0x0 \
            -o build/riscv/test_c.elf riscv/test_program.c

        riscv32-unknown-elf-objcopy -O binary \
            build/riscv/test_c.elf build/riscv/test_c.bin

        echo "  Output: build/riscv/test_c.bin"
    fi

    # Build Zig version (if Zig is available)
    if command -v zig &> /dev/null && [ -f "riscv/test_program.zig" ]; then
        echo "  Compiling Zig test program..."
        zig build-exe riscv/test_program.zig \
            -target riscv32-none-none \
            -mcpu=generic_rv32 \
            -fno-builtin \
            -fno-stdlib \
            -O ReleaseFast \
            --name test_zig \
            --zig-out-dir build/riscv

        echo "  Output: build/riscv/test_zig.bin"
    fi

    # Convert to hex for BRAM initialization
    if command -v srec_cat &> /dev/null; then
        srec_cat build/riscv/test_c.bin -binary -offset 0x0 \
            -o build/riscv/test_prog.hex -intel
        echo "  HEX: build/riscv/test_prog.hex"
    fi
fi

#===============================================================================
# STEP 3: CHECK FOR YOSYS
#===============================================================================

echo -e "${GREEN}Step 3: Checking synthesis tool...${NC}"

if ! command -v yosys &> /dev/null; then
    echo -e "${RED}Error: yosys not found!${NC}"
    echo "  Install with: brew install yosys"
    exit 1
fi

echo "  Yosys version: $(yosys --version 2>&1 | head -n1)"

#===============================================================================
# STEP 4: PREPARE VERILOG SOURCES
#===============================================================================

echo -e "${GREEN}Step 4: Preparing Verilog sources...${NC}"

# List of source files (in dependency order)
SOURCES="
    trinity_os/vexriscv_wrapper.v
    trinity_os/trinity_os_top.v
    trinity_os/trinity_os_core.v
    trinity_os/trinity_pcb.v
    trinity_os/trinity_interrupt.v
    trinity_os/ternary_scheduler.v
    uart_command_decoder.v
    trinity_v3_riscv.v
"

# Create combined file for Yosys
cat > build/riscv/trinity_v3_combined.v <<'EOF'
// TRINITY V3 - Combined Verilog for Yosys synthesis
// Auto-generated by build_riscv.sh
EOF

for src in $SOURCES; do
    if [ -f "$src" ]; then
        echo "  Adding: $src"
        cat "$src" >> build/riscv/trinity_v3_combined.v
        echo "" >> build/riscv/trinity_v3_combined.v
    else
        echo -e "${YELLOW}  Warning: $src not found, skipping...${NC}"
    fi
done

# Include trinity_v2 modules (VSA + TQNN)
if [ -f "trinity_v2.v" ]; then
    echo "  Adding: trinity_v2.v"
    cat trinity_v2.v >> build/riscv/trinity_v3_combined.v
    echo "" >> build/riscv/trinity_v3_combined.v
fi

#===============================================================================
# STEP 5: YOSYS SYNTHESIS
#===============================================================================

echo -e "${GREEN}Step 5: Running Yosys synthesis...${NC}"

yosys -p "
    read_verilog build/riscv/trinity_v3_combined.v;
    synth_xilinx -flatten -abc9 -nobram -arch xc7 -top trinity_v3;
    write_json build/riscv/trinity_v3.json;
    opt_clean -purge;
    stat
" 2>&1 | tee build/riscv/synthesis.log

if [ ! -f "build/riscv/trinity_v3.json" ]; then
    echo -e "${RED}Error: Synthesis failed!${NC}"
    echo "  Check build/riscv/synthesis.log for details"
    exit 1
fi

echo -e "${GREEN}  Synthesis complete!${NC}"

#===============================================================================
# STEP 6: RESOURCE REPORT
#===============================================================================

echo -e "${GREEN}Step 6: Resource usage...${NC}"

# Extract cell counts from JSON
python3 - <<'PYTHON'
import json
import sys

try:
    with open('build/riscv/trinity_v3.json', 'r') as f:
        data = json.load(f)

    cells = data.get('modules', {}).get('trinity_v3', {}).get('cells', {})
    total_cells = len(cells)

    # Count by type
    types = {}
    for cell_name, cell in cells.items():
        t = cell.get('type', 'unknown')
        types[t] = types.get(t, 0) + 1

    print(f"  Total cells: {total_cells}")
    print(f"  Cell types: {len(types)}")

    # Top cell types
    print("\n  Top cell types:")
    for t, c in sorted(types.items(), key=lambda x: x[1], reverse=True)[:10]:
        print(f"    {t}: {c}")

except Exception as e:
    print(f"  Error analyzing JSON: {e}")
PYTHON

#===============================================================================
# STEP 7: NEXT STEPS
#===============================================================================

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Build complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Output files:"
echo "  - build/riscv/trinity_v3.json  (Yosys netlist)"
echo "  - build/riscv/synthesis.log    (Synthesis log)"
if [ "$BUILD_TEST" = "true" ]; then
    echo "  - build/riscv/test_c.bin       (RISC-V test program)"
fi
echo ""
echo "Next steps:"
echo "  1. Generate bitstream (when JTAG arrives):"
echo "     docker run --rm -v \"\$(pwd):/work\" -w /work \\"
echo "         regymm/openxc7 \\"
echo "         nextpnr-xilinx --chip xc7a100tfgg676-1 \\"
echo "         --json build/riscv/trinity_v3.json \\"
echo "         --fasm build/riscv/trinity_v3.fasm"
echo ""
echo "  2. Convert to bitstream:"
echo "     docker run --rm -v \"\$(pwd):/work\" -w /work \\"
echo "         regymm/openxc7 \\"
echo "         fasm2frames build/riscv/trinity_v3.fasm build/riscv/trinity_v3.frames"
echo ""
echo "  3. Program FPGA:"
echo "     fpga/tools/jtag_program build/riscv/trinity_v3.bit"
echo ""
