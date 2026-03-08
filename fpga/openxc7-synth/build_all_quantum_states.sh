#!/bin/bash
# build_all_quantum_states.sh — Build 4 quantum bridge bitstreams
# Each bitstream has a different quantum_state hardcoded

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

BASE="quantum_bridge"
TEMPLATE="${BASE}_template.v"

echo "════════════════════════════════════════════════════════════════"
echo " QUANTUM BRIDGE — BUILDING ALL 4 STATES"
echo " φ² + 1/φ² = 3 = TRINITY"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Check template exists
if [ ! -f "$TEMPLATE" ]; then
    echo "Error: Template file not found: $TEMPLATE"
    exit 1
fi

# Build each state
echo "[1/4] Building: SEPARABLE (state=00) ~3 Hz"
echo "-------------------------------------------"
sed "s/localparam QUANTUM_STATE = 2'b00;/localparam QUANTUM_STATE = 2'b00;/" \
    "$TEMPLATE" > "${BASE}_separable.v"
docker run --rm --platform linux/amd64 \
    -v "$SCRIPT_DIR:/work" -w /work \
    regymm/openxc7 \
    yosys -p "synth_xilinx -flatten -abc9 -nobram -arch xc7 -top quantum_bridge_top; \
              write_json ${BASE}_separable.json" \
    ${BASE}_separable.v > /dev/null 2>&1
docker run --rm --platform linux/amd64 \
    -v "$SCRIPT_DIR:/work" -w /work \
    regymm/openxc7 \
    nextpnr-xilinx \
        --chipdb /work/chipdb/xc7a100tfgg676.bin \
        --xdc /work/trinity.xdc \
        --json /work/${BASE}_separable.json \
        --write /work/${BASE}_separable_routed.json \
        --fasm /work/${BASE}_separable.fasm \
        --freq 50 --seed 1 > /dev/null 2>&1
docker run --rm --platform linux/amd64 \
    -v "$SCRIPT_DIR:/work" -w /work \
    regymm/openxc7 \
    bash -c "\
        fasm2frames \
          --db-root /nextpnr-xilinx/xilinx/external/prjxray-db/artix7 \
          --part xc7a100tfgg676-1 \
          /work/${BASE}_separable.fasm \
          /work/${BASE}_separable.frames && \
        /prjxray/build/tools/xc7frames2bit \
          --part_file /nextpnr-xilinx/xilinx/external/prjxray-db/artix7/xc7a100tfgg676-1/part.yaml \
          --part_name xc7a100tfgg676-1 \
          --frm_file /work/${BASE}_separable.frames \
          --output_file /work/${BASE}_separable.bit" > /dev/null 2>&1
SIZE=$(ls -lh "${BASE}_separable.bit" | awk '{print $5}')
echo "  ✓ ${BASE}_separable.bit created ($SIZE)"
echo ""

echo "[2/4] Building: VIOLATION (state=01) ~6 Hz"
echo "-------------------------------------------"
sed "s/localparam QUANTUM_STATE = 2'b00;/localparam QUANTUM_STATE = 2'b01;/" \
    "$TEMPLATE" > "${BASE}_violation.v"
docker run --rm --platform linux/amd64 \
    -v "$SCRIPT_DIR:/work" -w /work \
    regymm/openxc7 \
    yosys -p "synth_xilinx -flatten -abc9 -nobram -arch xc7 -top quantum_bridge_top; \
              write_json ${BASE}_violation.json" \
    ${BASE}_violation.v > /dev/null 2>&1
docker run --rm --platform linux/amd64 \
    -v "$SCRIPT_DIR:/work" -w /work \
    regymm/openxc7 \
    nextpnr-xilinx \
        --chipdb /work/chipdb/xc7a100tfgg676.bin \
        --xdc /work/trinity.xdc \
        --json /work/${BASE}_violation.json \
        --write /work/${BASE}_violation_routed.json \
        --fasm /work/${BASE}_violation.fasm \
        --freq 50 --seed 1 > /dev/null 2>&1
docker run --rm --platform linux/amd64 \
    -v "$SCRIPT_DIR:/work" -w /work \
    regymm/openxc7 \
    bash -c "\
        fasm2frames \
          --db-root /nextpnr-xilinx/xilinx/external/prjxray-db/artix7 \
          --part xc7a100tfgg676-1 \
          /work/${BASE}_violation.fasm \
          /work/${BASE}_violation.frames && \
        /prjxray/build/tools/xc7frames2bit \
          --part_file /nextpnr-xilinx/xilinx/external/prjxray-db/artix7/xc7a100tfgg676-1/part.yaml \
          --part_name xc7a100tfgg676-1 \
          --frm_file /work/${BASE}_violation.frames \
          --output_file /work/${BASE}_violation.bit" > /dev/null 2>&1
SIZE=$(ls -lh "${BASE}_violation.bit" | awk '{print $5}')
echo "  ✓ ${BASE}_violation.bit created ($SIZE)"
echo ""

echo "[3/4] Building: ZERO (state=10) ~0.4 Hz"
echo "-------------------------------------------"
sed "s/localparam QUANTUM_STATE = 2'b00;/localparam QUANTUM_STATE = 2'b10;/" \
    "$TEMPLATE" > "${BASE}_zero.v"
docker run --rm --platform linux/amd64 \
    -v "$SCRIPT_DIR:/work" -w /work \
    regymm/openxc7 \
    yosys -p "synth_xilinx -flatten -abc9 -nobram -arch xc7 -top quantum_bridge_top; \
              write_json ${BASE}_zero.json" \
    ${BASE}_zero.v > /dev/null 2>&1
docker run --rm --platform linux/amd64 \
    -v "$SCRIPT_DIR:/work" -w /work \
    regymm/openxc7 \
    nextpnr-xilinx \
        --chipdb /work/chipdb/xc7a100tfgg676.bin \
        --xdc /work/trinity.xdc \
        --json /work/${BASE}_zero.json \
        --write /work/${BASE}_zero_routed.json \
        --fasm /work/${BASE}_zero.fasm \
        --freq 50 --seed 1 > /dev/null 2>&1
docker run --rm --platform linux/amd64 \
    -v "$SCRIPT_DIR:/work" -w /work \
    regymm/openxc7 \
    bash -c "\
        fasm2frames \
          --db-root /nextpnr-xilinx/xilinx/external/prjxray-db/artix7 \
          --part xc7a100tfgg676-1 \
          /work/${BASE}_zero.fasm \
          /work/${BASE}_zero.frames && \
        /prjxray/build/tools/xc7frames2bit \
          --part_file /nextpnr-xilinx/xilinx/external/prjxray-db/artix7/xc7a100tfgg676-1/part.yaml \
          --part_name xc7a100tfgg676-1 \
          --frm_file /work/${BASE}_zero.frames \
          --output_file /work/${BASE}_zero.bit" > /dev/null 2>&1
SIZE=$(ls -lh "${BASE}_zero.bit" | awk '{print $5}')
echo "  ✓ ${BASE}_zero.bit created ($SIZE)"
echo ""

echo "[4/4] Building: NEGATIVE (state=11) steady ON"
echo "-------------------------------------------"
sed "s/localparam QUANTUM_STATE = 2'b00;/localparam QUANTUM_STATE = 2'b11;/" \
    "$TEMPLATE" > "${BASE}_negative.v"
docker run --rm --platform linux/amd64 \
    -v "$SCRIPT_DIR:/work" -w /work \
    regymm/openxc7 \
    yosys -p "synth_xilinx -flatten -abc9 -nobram -arch xc7 -top quantum_bridge_top; \
              write_json ${BASE}_negative.json" \
    ${BASE}_negative.v > /dev/null 2>&1
docker run --rm --platform linux/amd64 \
    -v "$SCRIPT_DIR:/work" -w /work \
    regymm/openxc7 \
    nextpnr-xilinx \
        --chipdb /work/chipdb/xc7a100tfgg676.bin \
        --xdc /work/trinity.xdc \
        --json /work/${BASE}_negative.json \
        --write /work/${BASE}_negative_routed.json \
        --fasm /work/${BASE}_negative.fasm \
        --freq 50 --seed 1 > /dev/null 2>&1
docker run --rm --platform linux/amd64 \
    -v "$SCRIPT_DIR:/work" -w /work \
    regymm/openxc7 \
    bash -c "\
        fasm2frames \
          --db-root /nextpnr-xilinx/xilinx/external/prjxray-db/artix7 \
          --part xc7a100tfgg676-1 \
          /work/${BASE}_negative.fasm \
          /work/${BASE}_negative.frames && \
        /prjxray/build/tools/xc7frames2bit \
          --part_file /nextpnr-xilinx/xilinx/external/prjxray-db/artix7/xc7a100tfgg676-1/part.yaml \
          --part_name xc7a100tfgg676-1 \
          --frm_file /work/${BASE}_negative.frames \
          --output_file /work/${BASE}_negative.bit" > /dev/null 2>&1
SIZE=$(ls -lh "${BASE}_negative.bit" | awk '{print $5}')
echo "  ✓ ${BASE}_negative.bit created ($SIZE)"
echo ""

echo "════════════════════════════════════════════════════════════════"
echo " ALL BITSTREAMS READY"
echo "════════════════════════════════════════════════════════════════"
echo ""

ls -lh ${BASE}_*.bit | awk '{print "  " $9 " (" $5 ")"}'
echo ""
echo "Usage:"
echo "  sudo /Users/playra/trinity-w1/fpga/tools/jtag_program ${BASE}_separable.bit"
echo "  sudo /Users/playra/trinity-w1/fpga/tools/jtag_program ${BASE}_violation.bit"
echo "  sudo /Users/playra/trinity-w1/fpga/tools/jtag_program ${BASE}_zero.bit"
echo "  sudo /Users/playra/trinity-w1/fpga/tools/jtag_program ${BASE}_negative.bit"
echo ""
echo "Or run: zig run src/tri/quantum_bridge_runner.zig"
