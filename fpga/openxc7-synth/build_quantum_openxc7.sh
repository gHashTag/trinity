#!/bin/bash
# Build quantum_bridge with OPENXC7 (working toolchain)

set -e
BASE="quantum_bridge"
WORK_DIR="/Users/playra/trinity-w1/fpga/openxc7-synth"

echo "=== OPENXC7 SYNTHESIS ==="
echo "[1/4] Yosys synthesis..."
docker run --rm --platform linux/amd64 \
  -v "$WORK_DIR:/work" -w /work \
  regymm/openxc7 \
  yosys -p "synth_xilinx -flatten -abc9 -nobram -arch xc7 -top quantum_bridge_top; write_json ${BASE}.json" \
  quantum_bridge_simple.v

echo "[2/4] nextpnr-xilinx place & route..."
docker run --rm --platform linux/amd64 \
  -v "$WORK_DIR:/work" -w /work \
  regymm/openxc7 \
  nextpnr-xilinx \
    --chipdb /work/chipdb/xc7a100tfgg676.bin \
    --xdc /work/trinity.xdc \
    --json /work/${BASE}.json \
    --write /work/${BASE}_routed.json \
    --fasm /work/${BASE}.fasm \
    --freq 50 --seed 1

echo "[3/4] FASM to frames..."
docker run --rm --platform linux/amd64 \
  -v "$WORK_DIR:/work" -w /work \
  regymm/openxc7 \
  fasm2frames \
    --db-root /nextpnr-xilinx/xilinx/external/prjxray-db/artix7 \
    --part xc7a100tfgg676-1 \
    /work/${BASE}.fasm \
    /work/${BASE}.frames

echo "[4/4] Frames to bitstream..."
docker run --rm --platform linux/amd64 \
  -v "$WORK_DIR:/work" -w /work \
  regymm/openxc7 \
  /prjxray/build/tools/xc7frames2bit \
    --part_file /nextpnr-xilinx/xilinx/external/prjxray-db/artix7/xc7a100tfgg676-1/part.yaml \
    --part_name xc7a100tfgg676-1 \
    --frm_file /work/${BASE}.frames \
    --output_file /work/${BASE}.bit

echo "=== COMPLETE: ${BASE}.bit ==="
ls -lh ${BASE}.bit
