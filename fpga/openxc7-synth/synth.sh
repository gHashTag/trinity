#!/bin/bash
set -e

PART="xc7a100tfgg676-1"
DBPART="xc7a100tfgg676"
FAMILY="artix7"
PROJECT="trinity"
TOP="trinity_top"
XDC="trinity.xdc"

PRJXRAY_DB="/nextpnr-xilinx/xilinx/external/prjxray-db"
BBAEXPORT="/nextpnr-xilinx/xilinx/python/bbaexport.py"
CHIPDB="/workspace/chipdb"

echo "=== TRINITY OPEN-SOURCE SYNTHESIS ==="
echo "Part: $PART"
echo "Family: $FAMILY"
echo ""

# Step 1: Yosys synthesis
echo "[1/5] Yosys synthesis..."
yosys -p "synth_xilinx -flatten -abc9 -arch xc7 -top $TOP; write_json ${PROJECT}.json" ${PROJECT}.v
echo "  Netlist: ${PROJECT}.json"

# Step 2: Generate chipdb (if not cached)
if [ ! -f "${CHIPDB}/${DBPART}.bin" ]; then
    echo "[2/5] Generating chipdb for ${DBPART} (this takes a while)..."
    mkdir -p ${CHIPDB}
    pypy3 ${BBAEXPORT} --device ${PART} --bba ${DBPART}.bba || \
    python3 ${BBAEXPORT} --device ${PART} --bba ${DBPART}.bba
    bbasm -l ${DBPART}.bba ${CHIPDB}/${DBPART}.bin
    rm -f ${DBPART}.bba
    echo "  Chipdb: ${CHIPDB}/${DBPART}.bin"
else
    echo "[2/5] Chipdb cached: ${CHIPDB}/${DBPART}.bin"
fi

# Step 3: Place and route
echo "[3/5] Place and route (nextpnr-xilinx)..."
nextpnr-xilinx --chipdb ${CHIPDB}/${DBPART}.bin --xdc ${XDC} --json ${PROJECT}.json --fasm ${PROJECT}.fasm
echo "  FASM: ${PROJECT}.fasm"

# Step 4: FASM to frames
echo "[4/5] Converting FASM to frames..."
fasm2frames --part ${PART} --db-root ${PRJXRAY_DB}/${FAMILY} ${PROJECT}.fasm > ${PROJECT}.frames
echo "  Frames: ${PROJECT}.frames"

# Step 5: Generate bitstream
echo "[5/5] Generating bitstream..."
xc7frames2bit --part_file ${PRJXRAY_DB}/${FAMILY}/${PART}/part.yaml --part_name ${PART} --frm_file ${PROJECT}.frames --output_file ${PROJECT}.bit
echo "  Bitstream: ${PROJECT}.bit"

ls -lh ${PROJECT}.bit
echo ""
echo "=== SYNTHESIS COMPLETE ==="
echo "TRINITY LIVES IN SILICON. phi^2 + 1/phi^2 = 3"
