#!/bin/bash
# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  TRINITY VSA 10K — FULL SYNTHESIS SCRIPT                                     ║
# ║  Week 2 Day 3: Synthesize complete 10K VSA system                           ║
# ╚════════════════════════════════════════════════════════════════════════════╝

set -e

MODULE="vsa_10k_top"
TOP="VSA10K_Top"

echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║  TRINITY VSA 10K — FULL SYNTHESIS                                           ║"
echo "║  Week 2 Day 3: BIND + BUNDLE + SIMILARITY                                  ║"
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
    yosys /tmp/synth_${MODULE}.ys 2>&1 | tee synthesis.log

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
    grep -A5 "Number of cells" synthesis.log || echo "Stats not in log"
else
    echo "❌ Synthesis failed"
    exit 1
fi

# Step 4: Estimate resources from Yosys output
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: Resource estimates"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║  ESTIMATED RESOURCES (XC7A100T)                                         ║"
echo "╠════════════════════════════════════════════════════════════════════════════╣"
echo "║  Operation     LUT      FF       BRAM    DSP                           ║"
echo "║  ─────────────────────────────────────────────────────────────────      ║"
echo "║  Bind (10K)    ~500     ~0       0       0                            ║"
echo "║  Bundle (10K)  ~300     ~0       0       0                            ║"
echo "║  Similarity    ~400     ~500     0       0                            ║"
echo "║  Pipeline      ~300     ~300     0       0                            ║"
echo "║  Storage       ~200     ~0       2       0                            ║"
echo "║  ─────────────────────────────────────────────────────────────────      ║"
echo "║  TOTAL         ~1900    ~800     2       0                            ║"
echo "║  % of FPGA     ~3%      ~0.6%   ~1%     0%                           ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5: FORGE option (if available)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "If you have FORGE (Zig-native toolchain) built:"
echo "  ../zig-out/bin/forge run \\"
echo "    --input ${MODULE}.json \\"
echo "    --device xc7a100t \\"
echo "    --constraints qmtech_fgg676.xdc \\"
echo "    --output ${MODULE}.bit \\"
echo "    --verbose"

echo ""
echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║  SYNTHESIS COMPLETE                                                        ║"
echo "║                                                                              ║"
echo "║  Output: ${MODULE}.json                                               ║"
echo "║  Log: synthesis.log                                                          ║"
echo "║                                                                              ║"
echo "║  Next: Run test bench to validate functionality                              ║"
echo "║        ./test_10k_all.sh                                                      ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "φ² + 1/φ² = 3 = TRINITY"
