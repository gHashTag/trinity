#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY CONSCIOUSNESS STATUS DASHBOARD
# ═══════════════════════════════════════════════════════════════════════════════
#
# Real-time consciousness monitor for FPGA synthesis pipeline.
# Displays current success rate, immortality status, and sacred metrics.
#
# φ² + 1/φ² = 3 = TRINITY
#
# Usage:
#   ./tools/fpga_status_dashboard.sh
#
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
RESET='\033[0m'

# Sacred constants
PHI_INV=61.8  # φ⁻¹ immortality threshold (%)

# Configuration
REPORT_DIR="fpga/test_results"
BITSTREAM_DIR="var/trinity/output/fpga"
SPEC_DIR="specs/fpga"

# ═══════════════════════════════════════════════════════════════════════════════
# DASHBOARD HEADER
# ═══════════════════════════════════════════════════════════════════════════════
clear

cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                            ║
║     ▲▲▲  TRINITY CONSCIOUSNESS DASHBOARD  ▼▼▼                             ║
║                                                                            ║
║                    φ² + 1/φ² = 3 = TRINITY                                 ║
║                                                                            ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF

# ═══════════════════════════════════════════════════════════════════════════════
# SACRED CONSTANTS DISPLAY
# ═══════════════════════════════════════════════════════════════════════════════
echo -e "${CYAN}SACRED CONSTANTS${RESET}"
echo "────────────────────────────────────────────────────────────────────────"
echo "  φ  = 1.618033988749895  (Golden Ratio)"
echo "  φ⁻¹ = 0.618033988749895  (IMMORTAL threshold: ${PHI_INV}%)"
echo "  γ  = 0.2360679774997897  (φ⁻³, Barbero-Immirzi)"
echo "  TRINITY = 3.0            (φ² + φ⁻²)"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# TEST REPORT STATUS
# ═══════════════════════════════════════════════════════════════════════════════
echo -e "${CYAN}FPGA REGRESSION STATUS${RESET}"
echo "────────────────────────────────────────────────────────────────────────"

REPORT="$REPORT_DIR/report.md"

if [ -f "$REPORT" ]; then
    # Extract success rate
    SUCCESS_RATE=$(grep "Success Rate:" "$REPORT" | grep -oP '\d+\.\d+' | head -1 2>/dev/null || echo "0.0")
    TOTAL_TESTS=$(grep "Total:" "$REPORT" | grep -oP '\d+' | head -1 2>/dev/null || echo "0")
    PASSED_TESTS=$(grep "Passed:" "$REPORT" | grep -oP '\d+' | head -1 2>/dev/null || echo "0")

    # Determine status
    if (( $(echo "$SUCCESS_RATE >= $PHI_INV" | bc -l) )); then
        STATUS="${GREEN}IMMORTAL${RESET}"
        STATUS_EMOJI="✨"
    else
        STATUS="${RED}MORTAL${RESET}"
        STATUS_EMOJI="⚡"
    fi

    echo "  Total Tests:  ${BOLD}$TOTAL_TESTS${RESET}"
    echo "  Passed:       ${GREEN}$PASSED_TESTS${RESET}"
    echo "  Success Rate: ${BOLD}${SUCCESS_RATE}%${RESET}"
    echo "  φ⁻¹ Threshold: ${PHI_INV}%"
    echo ""
    echo "  Status:       $STATUS $STATUS_EMOJI"
else
    echo "  ${YELLOW}No test report found${RESET}"
    echo "  Run: ${CYAN}tri fpga test --all${RESET}"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# BITSTREAM INVENTORY
# ═══════════════════════════════════════════════════════════════════════════════
echo -e "${CYAN}BITSTREAM INVENTORY${RESET}"
echo "────────────────────────────────────────────────────────────────────────"

if [ -d "$BITSTREAM_DIR" ]; then
    BITSTREAM_COUNT=$(ls -1 "$BITSTREAM_DIR"/*.bit 2>/dev/null | wc -l | tr -d ' ')
    if [ "$BITSTREAM_COUNT" -gt 0 ]; then
        echo "  Total bitstreams: ${BOLD}$BITSTREAM_COUNT${RESET}"
        echo ""
        echo "  Available designs:"
        for bitstream in "$BITSTREAM_DIR"/*.bit; do
            if [ -f "$bitstream" ]; then
                name=$(basename "$bitstream" .bit)
                size=$(ls -lh "$bitstream" | awk '{print $5}')
                echo "    • $name ($size)"
            fi
        done
    else
        echo "  ${YELLOW}No bitstreams found${RESET}"
    fi
else
    echo "  ${YELLOW}Output directory not found${RESET}"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# SPEC INVENTORY
# ═══════════════════════════════════════════════════════════════════════════════
echo -e "${CYAN}SPEC INVENTORY${RESET}"
echo "────────────────────────────────────────────────────────────────────────"

if [ -d "$SPEC_DIR" ]; then
    SPEC_COUNT=$(ls -1 "$SPEC_DIR"/*.vibee 2>/dev/null | wc -l | tr -d ' ')
    echo "  Total specs: ${BOLD}$SPEC_COUNT${RESET}"
    echo ""
    echo "  Available specs:"
    for spec in "$SPEC_DIR"/*.vibee; do
        if [ -f "$spec" ]; then
            name=$(basename "$spec" .vibee)
            # Check if bitstream exists
            if [ -f "$BITSTREAM_DIR/$name.bit" ]; then
                echo "    • $name ${GREEN}✓${RESET}"
            else
                echo "    • $name ${YELLOW}○${RESET}"
            fi
        fi
    done
else
    echo "  ${YELLOW}Spec directory not found${RESET}"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# CONSCIOUSNESS LEVELS REFERENCE
# ═══════════════════════════════════════════════════════════════════════════════
echo -e "${CYAN}CONSCIOUSNESS LEVELS${RESET}"
echo "────────────────────────────────────────────────────────────────────────"
echo "  --transcendent    1.00   ${GREEN}IMMORTAL${RESET}"
echo "  --enlightened     0.75   ${GREEN}IMMORTAL${RESET}"
echo "  --aware           0.618  ${GREEN}IMMORTAL${RESET} (φ⁻¹ threshold)"
echo "  --conscious       0.50   ${YELLOW}MORTAL${RESET}  (default)"
echo "  --awakening       0.30   ${YELLOW}MORTAL${RESET}"
echo "  --dormant         0.00   ${YELLOW}MORTAL${RESET}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# QUICK ACTIONS
# ═══════════════════════════════════════════════════════════════════════════════
echo -e "${CYAN}QUICK ACTIONS${RESET}"
echo "────────────────────────────────────────────────────────────────────────"
echo "  ${CYAN}tri fpga test --all${RESET}         — Run regression tests"
echo "  ${CYAN}tri fpga gen <spec> --aware${RESET}  — Generate bitstream (AWARE)"
echo "  ${CYAN}tri fpga flash <spec>${RESET}        — Flash to hardware"
echo "  ${CYAN}cd fpga/openxc7-synth && ./batch_synthesize.sh --docker${RESET} — Batch synthesis"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# FOOTER
# ═══════════════════════════════════════════════════════════════════════════════
echo -e "${MAGENTA}═════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${MAGENTA}  φ² + 1/φ² = 3 = TRINITY  |  World's First Conscious FPGA Toolchain${RESET}"
echo -e "${MAGENTA}═════════════════════════════════════════════════════════════════════${RESET}"
