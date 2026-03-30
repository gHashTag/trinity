#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY FPGA — JTAG UART Build Script
# ═══════════════════════════════════════════════════════════════════════════════
#
# Synthesizes TRINITY V3 with JTAG UART support
#
# Usage: ./build_jtaguart.sh [--clean|--help]
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
echo -e "${BLUE}  TRINITY V3 JTAG UART Build${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Golden Identity: φ² + 1/φ² = 3"
echo ""

#===============================================================================
# OPTION PARSING
#===============================================================================

CLEAN="false"
TEST_ONLY="false"

for arg in "$@"; do
    case $arg in
        --clean)
            CLEAN="true"
            ;;
        --test)
            TEST_ONLY="true"
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --clean    Remove build artifacts"
            echo "  --test     Run tests only"
            echo "  --help     Show this help"
            exit 0
            ;;
    esac
done

#===============================================================================
# CLEAN
#===============================================================================

if [ "$CLEAN" = "true" ]; then
    echo -e "${YELLOW}Cleaning build artifacts...${NC}"
    rm -rf build/jtaguart
    echo -e "${GREEN}Clean complete!${NC}"
    exit 0
fi

#===============================================================================
# DIRECTORIES
#===============================================================================

mkdir -p build/jtaguart

#===============================================================================
# CHECK PREREQUISITES
#===============================================================================

echo -e "${GREEN}Step 1: Checking prerequisites...${NC}"

# Check Yosys
if ! command -v yosys &> /dev/null; then
    echo -e "${RED}Error: yosys not found!${NC}"
    echo "  Install with: brew install yosys"
    exit 1
fi
echo "  ✓ Yosys: $(yosys --version 2>&1 | head -n1)"

# Check OpenOCD
if ! command -v openocd &> /dev/null; then
    echo -e "${YELLOW}⚠ OpenOCD not found (optional for terminal)${NC}"
    echo "  Install with: brew install openocd"
else
    echo "  ✓ OpenOCD: $(openocd --version 2>&1 | head -n1)"
fi

echo ""

#===============================================================================
# COMPILE VERILOG FILES
#===============================================================================

echo -e "${GREEN}Step 2: Preparing Verilog sources...${NC}"

SOURCES=""
ADD_SOURCE() {
    if [ -f "$1" ]; then
        echo "  Adding: $1"
        SOURCES="$SOURCES $1"
    else
        echo -e "${YELLOW}  Warning: $1 not found, skipping...${NC}"
    fi
}

# Core JTAG UART module
ADD_SOURCE "trinity_os/jtag_uart.v"

# Top-level integration
ADD_SOURCE "trinity_v3_jtaguart.v"

# TRINITY V2 (if available)
if [ -f "trinity_v2.v" ]; then
    echo "  Adding: trinity_v2.v (VSA + TQNN)"
    SOURCES="$SOURCES trinity_v2.v"
fi

echo ""

#===============================================================================
# YOSYS SYNTHESIS
#===============================================================================

echo -e "${GREEN}Step 3: Running Yosys synthesis...${NC}"

yosys -p "
    read_verilog $SOURCES;
    synth_xilinx -flatten -abc9 -nobram -arch xc7 -top trinity_v3_jtaguart;
    write_json build/jtaguart/trinity_v3_jtaguart.json;
    opt_clean -purge;
    stat
" 2>&1 | tee build/jtaguart/synthesis.log

if [ ! -f "build/jtaguart/trinity_v3_jtaguart.json" ]; then
    echo -e "${RED}Error: Synthesis failed!${NC}"
    echo "  Check build/jtaguart/synthesis.log for details"
    exit 1
fi

echo -e "${GREEN}✓ Synthesis complete!${NC}"
echo ""

#===============================================================================
# RESOURCE REPORT
#===============================================================================

echo -e "${GREEN}Step 4: Resource usage...${NC}"

python3 - <<'PYTHON'
import json
import sys

try:
    with open('build/jtaguart/trinity_v3_jtaguart.json', 'r') as f:
        data = json.load(f)

    # Get top module
    modules = data.get('modules', {})
    top_name = 'trinity_v3_jtaguart'

    if top_name in modules:
        top = modules[top_name]
        cells = top.get('cells', {})
        total_cells = len(cells)

        # Count by type
        types = {}
        for cell_name, cell in cells.items():
            t = cell.get('type', 'unknown')
            types[t] = types.get(t, 0) + 1

        print(f"  Total cells: {total_cells}")
        print(f"  Unique types: {len(types)}")

        # Top cell types
        print("\n  Top resources:")
        for t, c in sorted(types.items(), key=lambda x: x[1], reverse=True)[:15]:
            print(f"    {t}: {c}")

    else:
        print("  Top module not found in JSON")

except Exception as e:
    print(f"  Error analyzing JSON: {e}")
PYTHON

echo ""

#===============================================================================
# TESTS
#===============================================================================

if [ "$TEST_ONLY" = "true" ]; then
    echo -e "${GREEN}Step 5: Running tests...${NC}"

    # Check JSON validity
    if python3 -c "import json; json.load(open('build/jtaguart/trinity_v3_jtaguart.json'))"; then
        echo "  ✓ JSON valid"
    else
        echo "  ✗ JSON invalid"
        exit 1
    fi

    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
fi

#===============================================================================
# SUMMARY
#===============================================================================

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Build complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Output files:"
echo "  - build/jtaguart/trinity_v3_jtaguart.json  (Yosys netlist)"
echo "  - build/jtaguart/synthesis.log            (Synthesis log)"
echo ""
echo "Next steps:"
echo ""
echo "1. Start JTAG UART terminal:"
echo "   ./tools/jtag_term.py"
echo ""
echo "2. Or use pipe wrapper:"
echo "   ./tools/jtag_pipe_wrapper.sh"
echo ""
echo "3. When JTAG cable arrives, generate bitstream:"
echo "   docker run --rm -v \"\$(pwd):/work\" -w /work \\"
echo "       regymm/openxc7 \\"
echo "       nextpnr-xilinx --chip xc7a100tfgg676-1 \\"
echo "       --json build/jtaguart/trinity_v3_jtaguart.json \\"
echo "       --fasm build/jtaguart/trinity_v3_jtaguart.fasm"
echo ""
