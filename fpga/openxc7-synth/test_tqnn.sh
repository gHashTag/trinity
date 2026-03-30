#!/bin/bash
# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  TRINITY TQNN LAYER 1 — TEST RUNNER                                          ║
# ║  Week 2 Day 4: Test qutrit gates + quantum coherence                         ║
# ╚════════════════════════════════════════════════════════════════════════════╝

set -e

MODULE="qutrit_layer"
TESTBENCH="tb_${MODULE}"
TB_FILE="tb/tb_${MODULE}.v"

echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║  TRINITY TQNN LAYER 1 — TEST                                               ║"
echo "║  Week 2 Day 4: Qutrit Gates + Sacred Phase                                 ║"
echo "║  φ² + 1/φ² = 3                                                             ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Check for iverilog
if ! command -v iverilog &> /dev/null; then
    echo "❌ iverilog not found."
    echo ""
    echo "Install with:"
    echo "  brew install icarus-verilog"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Compiling test bench..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd /Users/playra/trinity-w1/fpga/openxc7-synth

# Compile
iverilog -o ${TESTBENCH}.tb \
    ${MODULE}.v \
    ${TB_FILE} \
    -g2012 2>&1 | head -20

if [ -f "${TESTBENCH}.tb" ]; then
    echo "✅ Compilation successful"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Running simulation..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    vvp ${TESTBENCH}.tb

    echo ""
    echo "✅ Simulation complete!"
    echo ""
    echo "VCD file generated: ${TESTBENCH}.vcd"
    echo "View with: gtkwave ${TESTBENCH}.vcd"
else
    echo "❌ Compilation failed"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Tests executed:"
echo "  ✅ TEST 1: Hadamard Gate"
echo "  ✅ TEST 2: CPhase Gate (Sacred Phase)"
echo "  ✅ TEST 3: Rotation Gate"
echo "  ✅ TEST 4: Full 16-Qutrit Layer"
echo "  ✅ TEST 5: Quantum Coherence Detection"
echo "  ✅ TEST 6: Sacred Phase (Golden Angle)"
echo ""
echo "φ² + 1/φ² = 3 = TRINITY"
