#!/bin/bash
# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  TRINITY VSA 10K SYNTHESIS SCRIPT                                              ║
# ║  Week 2 Day 2: Synthesize 10K bind+bundle with openXC7                          ║
# ║                                                                              ║
# ║  φ² + 1/φ² = 3 = TRINITY                                                    ║
# ╚════════════════════════════════════════════════════════════════════════════╝

set -e

MODULE="${1:-vsa_10k_bind_bundle}"
TOP="${2:-VSA10K_BindBundle_Top}"

echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║  TRINITY VSA 10K SYNTHESIS                                                 ║"
echo "║  φ² + 1/φ² = 3                                                             ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Module: $MODULE"
echo "Top:    $TOP"
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker for openXC7 synthesis."
    echo "   Alternatively, use FORGE (Zig) with: zig build forge"
    exit 1
fi

OPENXC7_IMAGE="regymm/openxc7"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Pulling openXC7 Docker image (if not cached)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker pull "$OPENXC7_IMAGE" || echo "Image already cached or pull failed"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Running Yosys synthesis"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > /tmp/synth_$MODULE.ys << 'EOF'
# Read Verilog
read_verilog ${MODULE}.v

# Synthesize for Xilinx 7-series
synth_xilinx -flatten -abc9 -arch xc7 -top ${TOP}

# Write JSON
write_json ${MODULE}.json

# Print stats
print_stats

EOF

# Run Yosys in Docker
docker run --rm --platform linux/amd64 \
    -v "$(pwd):/work" -w /work \
    "$OPENXC7_IMAGE" \
    yosys /tmp/synth_${MODULE}.ys

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Checking resource usage from Yosys"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "${MODULE}.json" ]; then
    echo "✅ Synthesis complete: ${MODULE}.json"
    ls -lh "${MODULE}.json"
else
    echo "❌ Synthesis failed: ${MODULE}.json not found"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: FORGE alternative (Zig-native)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "If you have FORGE built, run:"
echo "  ../zig-out/bin/forge run \\"
echo "    --input ${MODULE}.json \\"
echo "    --device xc7a100t \\"
echo "    --constraints qmtech_fgg676.xdc \\"
echo "    --output ${MODULE}.bit \\"
echo "    --verbose"

echo ""
echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║  SYNTHESIS COMPLETE                                                        ║"
echo "║  Output: ${MODULE}.json                                              ║"
echo "║                                                                              ║"
echo "║  Next steps:                                                                ║"
echo "║  1. Review resource usage in Yosys output                                 ║"
echo "║  2. Run FORGE to generate bitstream (if available)                         ║"
echo "║  3. Flash to FPGA with jtag_program                                     ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "φ² + 1/φ² = 3 = TRINITY"
