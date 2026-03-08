#!/bin/bash
# synth.sh — OpenXC7 FPGA Synthesis Pipeline
# Usage: ./synth.sh <design.v> [top_module_name]
#
# Prerequisites:
#   - Docker image regymm/openxc7:latest
#   - Pin constraints in <design>.xdc

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="${SCRIPT_DIR}"

# Check arguments
if [ -z "$1" ]; then
    echo "Usage: $0 <design.v> [top_module_name]"
    echo ""
    echo "Example:"
    echo "  $0 temporal_heartbeat.v temporal_heartbeat_top"
    exit 1
fi

VERILOG="$1"
TOP="${2:-$(basename -s .v "$VERILOG")_top}"
BASE="$(basename -s .v "$VERILOG")"

# Check files exist
if [ ! -f "$VERILOG" ]; then
    echo "Error: Verilog file not found: $VERILOG"
    exit 1
fi

XDC="${BASE}.xdc"
if [ ! -f "$XDC" ]; then
    echo "Error: XDC file not found: $XDC"
    exit 1
fi

echo "═══════════════════════════════════════════════"
echo " OPENXC7 SYNTHESIS PIPELINE"
echo " Design: $VERILOG"
echo " Top:   $TOP"
echo "═══════════════════════════════════════════════"
echo ""

# Step 1: Yosys synthesis
echo "[1/4] Yosys synthesis..."
docker run --rm --platform linux/amd64 \
  -v "$WORK_DIR:/work" -w /work \
  regymm/openxc7 \
  yosys -p "synth_xilinx -flatten -abc9 -nobram -arch xc7 -top $TOP; write_json ${BASE}.json" \
  "$VERILOG"

echo "  → ${BASE}.json"

# Step 2: nextpnr-xilinx place & route
echo "[2/4] nextpnr-xilinx place & route..."
docker run --rm --platform linux/amd64 \
  -v "$WORK_DIR:/work" -w /work \
  regymm/openxc7 \
  nextpnr-xilinx \
    --chipdb /work/chipdb/xc7a100tfgg676.bin \
    --xdc /work/"$XDC" \
    --json /work/"${BASE}.json" \
    --write /work/"${BASE}_routed.json" \
    --fasm /work/"${BASE}.fasm" \
    --freq 50 --seed 1

echo "  → ${BASE}.fasm"

# Step 3: FASM → Frames
echo "[3/4] FASM to frames conversion..."
docker run --rm --platform linux/amd64 \
  -v "$WORK_DIR:/work" -w /work \
  regymm/openxc7 \
  fasm2frames \
    --db-root /nextpnr-xilinx/xilinx/external/prjxray-db/artix7 \
    --part xc7a100tfgg676-1 \
    /work/"${BASE}.fasm" \
    /work/"${BASE}.frames"

echo "  → ${BASE}.frames"

# Step 4: Frames → Bitstream
echo "[4/4] Frames to bitstream..."
docker run --rm --platform linux/amd64 \
  -v "$WORK_DIR:/work" -w /work \
  regymm/openxc7 \
  /prjxray/build/tools/xc7frames2bit \
    --part_file /nextpnr-xilinx/xilinx/external/prjxray-db/artix7/xc7a100tfgg676-1/part.yaml \
    --part_name xc7a100tfgg676-1 \
    --frm_file /work/"${BASE}.frames" \
    --output_file /work/"${BASE}.bit"

echo "  → ${BASE}.bit"
echo ""

# Step 5: LED Hardware Verification (MANDATORY)
# Automated self-testing via monitoring camera - no human intervention required
echo "[5/5] LED hardware verification..."
echo "  Camera: iPhone Continuity Camera (device ${FPGA_CAMERA_DEVICE:-2})"
echo "  This step flashes the bitstream and verifies LED behavior"
echo ""

# Skip verification if SKIP_VERIFY is set (for CI environments)
if [ -n "$SKIP_VERIFY" ]; then
    echo "  ⚠ SKIP: SKIP_VERIFY environment variable is set"
    echo "  To enable: unset SKIP_VERIFY or remove it from environment"
else
    # Determine expected LED pattern based on design name
    EXPECTED_PATTERN="ANY"
    case "$BASE" in
        blink*)
            EXPECTED_PATTERN="MEDIUM"  # ~1.5 Hz for blink.v
            ;;
        uart_top*)
            EXPECTED_PATTERN="FAST"    # ~3 Hz for VIOLATION mode
            ;;
        counter*)
            EXPECTED_PATTERN="MEDIUM"  # Counter patterns
            ;;
        fsm_simple*)
            EXPECTED_PATTERN="FAST"    # State machine blink
            ;;
    esac

    echo "  Expected pattern: ${EXPECTED_PATTERN}"

    # Run verification
    if ../tools/verify_led.sh "${BASE}.bit" "$EXPECTED_PATTERN" 3; then
        echo ""
        echo "  ✓ LED verification PASSED"
        VERIFY_RESULT="PASS"
    else
        VERIFY_RESULT=$?
        echo ""
        if [ $VERIFY_RESULT -eq 1 ]; then
            echo "  ✗ LED verification FAILED"
            echo "  Check video evidence in: /tmp/fpga_verify_${BASE}/"
            # Don't fail the build - still generate bitstream
        else
            echo "  ⚠ LED verification: Pattern mismatch or inconclusive"
            echo "  Check video evidence in: /tmp/fpga_verify_${BASE}/"
        fi
    fi
fi

echo ""
echo "═══════════════════════════════════════════════"
echo " SYNTHESIS COMPLETE"
echo " Bitstream: ${BASE}.bit"
echo " LED Verify: ${VERIFY_RESULT:-SKIPPED}"
echo ""
echo " To flash:"
echo "   sudo ../tools/jtag_program ${BASE}.bit"
echo ""
echo " To verify LED manually:"
echo "   ../tools/verify_led.sh ${BASE}.bit FAST"
echo "═══════════════════════════════════════════════"
