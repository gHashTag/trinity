#!/bin/bash
# finish_bitstream.sh — Convert FASM to bitstream and flash
# Usage: ./finish_bitstream.sh <design_name>
#
# Expects <design_name>.fasm to already exist (from nextpnr)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE="${1:-vsa_coproc}"

echo "═══════════════════════════════════════════════"
echo " FASM → BITSTREAM → FLASH"
echo " Design: ${BASE}"
echo "═══════════════════════════════════════════════"

if [ ! -f "${SCRIPT_DIR}/${BASE}.fasm" ]; then
    echo "ERROR: ${BASE}.fasm not found! Run nextpnr first."
    exit 1
fi

# Step 1: FASM → Frames
echo "[1/3] FASM → Frames..."
docker run --rm --platform linux/amd64 \
    -v "${SCRIPT_DIR}:/work" -w /work \
    regymm/openxc7 \
    fasm2frames \
        --db-root /nextpnr-xilinx/xilinx/external/prjxray-db/artix7 \
        --part xc7a100tfgg676-1 \
        /work/"${BASE}.fasm" \
        /work/"${BASE}.frames"

echo "  → ${BASE}.frames"

# Step 2: Frames → Bitstream
echo "[2/3] Frames → Bitstream..."
docker run --rm --platform linux/amd64 \
    -v "${SCRIPT_DIR}:/work" -w /work \
    regymm/openxc7 \
    /prjxray/build/tools/xc7frames2bit \
        --part_file /nextpnr-xilinx/xilinx/external/prjxray-db/artix7/xc7a100tfgg676-1/part.yaml \
        --part_name xc7a100tfgg676-1 \
        --frm_file /work/"${BASE}.frames" \
        --output_file /work/"${BASE}.bit"

echo "  → ${BASE}.bit ($(du -h "${SCRIPT_DIR}/${BASE}.bit" | cut -f1))"

# Step 3: Flash
echo "[3/3] Flashing to FPGA..."
JTAG="${SCRIPT_DIR}/../tools/jtag_program"
if [ -x "$JTAG" ]; then
    "$JTAG" "${SCRIPT_DIR}/${BASE}.bit"
    echo ""
    echo "═══════════════════════════════════════════════"
    echo " FLASH COMPLETE!"
    echo " Watch LED D6 for VSA coprocessor result"
    echo "═══════════════════════════════════════════════"
else
    echo ""
    echo "═══════════════════════════════════════════════"
    echo " BITSTREAM READY: ${BASE}.bit"
    echo " Flash manually:"
    echo "   ${JTAG} ${SCRIPT_DIR}/${BASE}.bit"
    echo "═══════════════════════════════════════════════"
fi
