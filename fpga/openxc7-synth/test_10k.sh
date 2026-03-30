#!/bin/bash
# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  TRINITY VSA 10K TEST SCRIPT                                                 ║
# ║  Week 2 Day 2: Run test bench for bind+bundle                                 ║
# ║                                                                              ║
# ║  φ² + 1/φ² = 3 = TRINITY                                                    ║
# ╚════════════════════════════════════════════════════════════════════════════╝

set -e

# Check for Icarus Verilog
if ! command -v iverilog &> /dev/null; then
    echo "⚠️  iverilog not found. Installing..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install icarus-verilog
    else
        sudo apt-get install iverilog
    fi
fi

MODULE="vsa_10k_bind_bundle"
TOP="tb_vsa_10k_bind_bundle"

echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║  TRINITY VSA 10K TEST RUN                                                  ║"
echo "║  φ² + 1/φ² = 3                                                             ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Module: $MODULE"
echo "Testbench: $TOP"
echo ""

# Compile
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Compiling test bench..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

iverilog -o tb_${MODULE}.tb \
    ${MODULE}.v \
    tb/tb_${MODULE}.v \
    -g2012 \
    2>&1 | head -20

if [ -f "tb_${MODULE}.tb" ]; then
    echo "✅ Compilation successful"
    ls -lh tb_${MODULE}.tb
else
    echo "❌ Compilation failed"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Running simulation..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

vvp tb_${MODULE}.tb

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test complete. Check output above."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Cleanup (optional)
# rm -f tb_${MODULE}.tb
# rm -f tb_${MODULE}.vcd

echo ""
echo "φ² + 1/φ² = 3 = TRINITY"
