#!/bin/bash
# synth_batch.sh — OpenXC7 Batch Synthesis Pipeline
# Usage: ./synth_batch.sh <designs_list.txt>
#
# Processes multiple FPGA designs in a single Docker container session.
# Each line in designs_list.txt: <design.v> <top_module>
#
# Performance: 100+ designs without Docker container restart overhead.
#
# φ² + 1/φ² = 3 | TRINITY v2.1

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="${SCRIPT_DIR}"

# Check arguments
if [ -z "$1" ]; then
    echo "Usage: $0 <designs_list.txt>"
    echo ""
    echo "designs_list.txt format (one per line):"
    echo "  design1.v top1"
    echo "  design2.v top2"
    echo "  ..."
    exit 1
fi

DESIGNS_LIST="$1"

if [ ! -f "$DESIGNS_LIST" ]; then
    echo "Error: Designs list file not found: $DESIGNS_LIST"
    exit 1
fi

# Count total designs
TOTAL_DESIGNS=$(grep -c '.' "$DESIGNS_LIST" || echo 0)

if [ "$TOTAL_DESIGNS" -eq 0 ]; then
    echo "Error: No designs found in $DESIGNS_LIST"
    exit 1
fi

echo "═══════════════════════════════════════════════"
echo " OPENXC7 BATCH SYNTHESIS"
echo " Designs: $TOTAL_DESIGNS"
echo "═══════════════════════════════════════════════"
echo ""

# Results tracking
PASS_COUNT=0
FAIL_COUNT=0
START_TIME=$(date +%s)

# Process each design
DESIGN_NUM=0
while IFS=' ' read -r VERILOG TOP || [ -n "$VERILOG" ]; do
    # Skip empty lines and comments
    [[ -z "$VERILOG" || "$VERILOG" == \#* ]] && continue

    DESIGN_NUM=$((DESIGN_NUM + 1))
    BASE="$(basename -s .v "$VERILOG")"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "[$DESIGN_NUM/$TOTAL_DESIGNS] $BASE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Check files exist
    if [ ! -f "$VERILOG" ]; then
        echo "  ✗ FAIL: Verilog file not found: $VERILOG"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        continue
    fi

    XDC="${BASE}.xdc"
    if [ ! -f "$XDC" ]; then
        echo "  ✗ FAIL: XDC file not found: $XDC"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        continue
    fi

    # Run synthesis (Docker starts per step, but container reuse is automatic)
    if /bin/bash "$SCRIPT_DIR/synth.sh" "$VERILOG" "$TOP" > "${BASE}.log" 2>&1; then
        echo "  ✓ PASS: ${BASE}.bit"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  ✗ FAIL: See ${BASE}.log"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi

    echo ""
done < "$DESIGNS_LIST"

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

# Summary
echo "═══════════════════════════════════════════════"
echo " BATCH SYNTHESIS COMPLETE"
echo "═══════════════════════════════════════════════"
echo " Total:    $TOTAL_DESIGNS"
echo " Passed:   $PASS_COUNT"
echo " Failed:   $FAIL_COUNT"
echo " Time:     ${ELAPSED}s"
echo " Avg:      $((ELAPSED / TOTAL_DESIGNS))s/design"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo "✓ ALL DESIGNS PASSED"
    exit 0
else
    echo "✗ SOME DESIGNS FAILED"
    exit 1
fi
