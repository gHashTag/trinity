#!/bin/bash
# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  TRINITY TQNN LAYER 1 — SYNTHESIS SCRIPT                                     ║
# ║  Week 2 Day 4: Synthesize qutrit gates with openXC7                         ║
# ╚════════════════════════════════════════════════════════════════════════════╝

set -e

MODULE="trinity_v2"
TOP="trinity_v2"

echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║  TRINITY TQNN LAYER 1 — SYNTHESIS                                          ║"
echo "║  Week 2 Day 4: Qutrit Gates + Sacred Phase                                ║"
echo "║  φ² + 1/φ² = 3                                                             ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Module: $MODULE"
echo "Top:    $TOP"
echo ""

OPENXC7_IMAGE="regymm/openxc7"

# Step 1: Pull Docker image
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Checking openXC7 Docker image"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker pull "$OPENXC7_IMAGE" 2>/dev/null || echo "Using cached image"

# Step 2: Create Yosys script
cat > /tmp/synth_${MODULE}.ys << EOF
# Read Verilog
read_verilog ${MODULE}.v

# Synthesize for Xilinx 7-series
synth_xilinx -flatten -abc9 -arch xc7 -top ${TOP}

# Print statistics
print_stats

# Write JSON
write_json ${MODULE}.json
EOF

# Step 3: Run Yosys synthesis
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Running Yosys synthesis"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd /Users/playra/trinity-w1/fpga/openxc7-synth

docker run --rm --platform linux/amd64 \
    -v "$(pwd):/work" -w /work \
    "$OPENXC7_IMAGE" \
    yosys /tmp/synth_${MODULE}.ys 2>&1 | tee synthesis_tqnn.log

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Checking results"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "${MODULE}.json" ]; then
    echo "✅ Synthesis successful!"
    ls -lh ${MODULE}.json
    echo ""

    # Extract resource stats from log
    echo "Resource Usage:"
    grep -A5 "Number of cells" synthesis_tqnn.log || echo "Stats not in log"
else
    echo "❌ Synthesis failed"
    exit 1
fi

# Step 4: Resource estimates
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: Resource Estimates"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║  ESTIMATED RESOURCES (XC7A100T) — TRINITY V2                              ║"
echo "╠════════════════════════════════════════════════════════════════════════════╣"
echo "║  Module               LUT      FF       BRAM    DSP                       ║"
echo "║  ─────────────────────────────────────────────────────────────────      ║"
echo "║  VSA (10K)            ~1900    ~800     2       0                         ║"
echo "║  TQNN Layer 1         ~150     ~100     0       0                         ║"
echo "║  UART                 ~100     ~50      0       0                         ║"
echo "║  BitNet               ~50      ~30      0       0                         ║"
echo "║  Control/SM           ~100     ~100     0       0                         ║"
echo "║  ─────────────────────────────────────────────────────────────────      ║"
echo "║  TOTAL V2             ~2300    ~1080    2       0                         ║"
echo "║  % of FPGA            ~3.6%    ~0.8%   ~1%     0%                         ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Still 96.4% of FPGA available!"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5: Next Steps"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Run test bench:"
echo "   ./test_tqnn.sh"
echo ""
echo "2. Full place & route (if desired):"
echo "   docker run --rm --platform linux/amd64 \\"
echo "     -v \"\$(pwd):/work\" -w /work \\"
echo "     regymm/openxc7 \\"
echo "     nextpnr-xilinx --chipdb /work/chipdb/xc7a100tfgg676.bin \\"
echo "       --xdc qmtech_fgg676.xdc --json ${MODULE}.json \\"
echo "       --write ${MODULE}_routed.json --fasm ${MODULE}.fasm --freq 50"
echo ""
echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║  SYNTHESIS COMPLETE                                                        ║"
echo "║                                                                              ║"
echo "║  Output: ${MODULE}.json                                               ║"
echo "║  Log: synthesis_tqnn.log                                                  ║"
echo "║                                                                              ║"
echo "║  TRINITY V2: VSA + TQNN + BitNet + UART                                    ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "φ² + 1/φ² = 3 = TRINITY"
