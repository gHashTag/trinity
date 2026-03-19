#!/bin/bash
# Sacred ALU Yosys Synthesis — Phase 6.4
# Quick resource estimation for GF16/TF3 operations
#
# Target: Digilent Arty A7-100T (XC7A100T-CSG324)
# Clock: 100 MHz onboard oscillator
# φ² + 1/φ² = 3
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SYNTH_DIR="$PROJECT_ROOT/fpga/openxc7-synth"
OUT_DIR="$PROJECT_ROOT/fpga/openxc7-synth/synth-yosys"

mkdir -p "$OUT_DIR"

# Check for yosys
if ! command -v yosys &> /dev/null; then
    echo "ERROR: yosys not found. Please install YosysHQ:"
    echo "  brew tap yosys-hq/yosys"
    exit 1
fi

echo "=== Sacred ALU Yosys Synthesis ==="
echo "Target: XC7A100T-CSG324 (Arty A7-100T)"
echo "Clock: 100 MHz"
echo ""

# Modules to synthesize
MODULES=(
    "gf16_add.v"
    "gf16_alu.v"
    "gf16_mul.v"
    "tf3_add.v"
    "tf3_dot.v"
    "sacred_alu.v"
    "sacred_constants_unit.v"
    "cordic_sacred.v"
)

# Run synthesis for each module
for module in "${MODULES[@]}"; do
    module_name="${module%.v}"
    echo "Synthesizing: $module"

    yosys \
        -d xc7a100tcsg324 \
        -p "xc7a100tcsg324-1+speed+grade" \
        -t "$SYNTH_DIR/$module" \
        -o "$OUT_DIR/${module_name%.v}_yosys.edif" \
        > "$OUT_DIR/${module_name%.v}_yosys.log" 2>&1

    if [ $? -eq 0 ]; then
        # Extract resource usage from log
        luts=$(grep -o "Number of 4-LUTs:" "$OUT_DIR/${module_name%.v}_yosys.log" | awk '{print $4}')
        dffs=$(grep -o "Number of DFFs:" "$OUT_DIR/${module_name%.v}_yosys.log" | awk '{print $4}')
        bram=$(grep -o "Number of RAMB36E1:" "$OUT_DIR/${module_name%.v}_yosys.log" | awk '{print $4}')

        printf "  %-20s LUTs:%-5s DFFs:%-5s BRAM:%-5s\n" "$module_name" "$luts" "$dffs" "$bram"
    else
        printf "  %-20s FAILED\n" "$module_name"
    fi
done

echo ""
echo "=== Resource Summary ==="
echo "Log files: $OUT_DIR"
echo ""
