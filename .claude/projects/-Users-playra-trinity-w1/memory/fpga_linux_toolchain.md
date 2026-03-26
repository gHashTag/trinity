# FPGA Toolchain — Linux Build Environment (Iteration 7)

## Target: QMTECH XC7A100T-1FGG676C (Artix-7)

### Quick Install (Ubuntu 22.04 / Debian 12)

```bash
# 1. Base dependencies
sudo apt-get update
sudo apt-get install -y \
    git build-essential cmake python3 python3-pip \
    bison flex gawk libboost-dev libboost-all-dev \
    libreadline-dev libeigen3-dev zlib1g-dev

# 2. Clone and build SymbiFlow/openXC7 components
mkdir -p ~/fpga-toolchain
cd ~/fpga-toolchain

# Yosys
git clone https://github.com/YosysHQ/yosys.git
cd yosys
git checkout v0.38  # stable release
make -j$(nproc)
sudo make install
cd ..

# nextpnr-xilinx
git clone https://github.com/SymbiFlow/nextpnr-xilinx.git
cd nextpnr-xilinx
mkdir build && cd build
cmake .. -DCHIPDB=../xilinx-chipdb
make -j$(nproc)
sudo make install
cd ..

# xilinx-chipdb (for XC7A100T)
git clone https://github.com/SymbiFlow/xilinx-chipdb.git
cd xilinx-chipdb
make xc7a100tfgg676  # Build chipdb for QMTECH board
cd ..

# prjxray (artix7 database)
git clone https://github.com/SymbiFlow/prjxray-db.git
cd prjxray-db
git submodule update --init --recursive
cd ..
```

### Chipdb Path Verification

```bash
# Verify chipdb exists
ls -la ~/fpga-toolchain/xilinx-chipdb/xilinx/xc7a100tfgg676.bin

# Path for nextpnr
export CHIPDB_PATH=~/fpga-toolchain/xilinx-chipdb/xilinx/xc7a100tfgg676.bin
```

### prjxray Database Path

```bash
export PRJXRAY_DB_ROOT=~/fpga-toolchain/prjxray-db/database/artix7
export FASM2FRAMES=~/fpga-toolchain/prjxray-db/utils/fasm2frames.py
export XC7FRAMES2BIT=~/fpga-toolchain/prjxray-db/utils/xc7frames2bit.py
```

### Build Script for uart_bridge_j2

```bash
#!/usr/bin/env bash
set -euo pipefail

TRINITY_ROOT=~/trinity  # Adjust to your Trinity clone path
cd "$TRINITY_ROOT/fpga/openxc7-synth"

OUTDIR=./build_uart_j2
RTL=../rtl/uart_bridge_j2.v
XDC=../constraints/uart_bridge_j2.xdc

mkdir -p "$OUTDIR"

# Step 1: Synthesis (Yosys)
yosys -p "
  read_verilog $RTL;
  synth_xilinx -family xc7 -top uart_bridge_top -json $OUTDIR/uart_bridge_j2.json;
  json2json $OUTDIR/uart_bridge_j2.json;  # Human-readable version (optional)
"

# Step 2: Place & Route (nextpnr-xilinx)
nextpnr-xilinx \
  --chipdb "$CHIPDB_PATH" \
  --xdc "$XDC" \
  --json "$OUTDIR/uart_bridge_j2.json" \
  --fasm "$OUTDIR/uart_bridge_j2.fasm" \
  --freq 50

# Step 3: FASM to Frames (prjxray)
python3 "$FASM2FRAMES" \
  --part xc7a100tfgg676 \
  --db-root "$PRJXRAY_DB_ROOT" \
  "$OUTDIR/uart_bridge_j2.fasm" \
  > "$OUTDIR/uart_bridge_j2.frames"

# Step 4: Frames to Bitstream (prjxray)
python3 "$XC7FRAMES2BIT" \
  --part-file "$PRJXRAY_DB_ROOT/xc7a100tfgg676/part.yaml" \
  --part-name xc7a100tfgg676 \
  --frm-file "$OUTDIR/uart_bridge_j2.frames" \
  --output-file "$OUTDIR/uart_bridge_j2.bit"

echo "SUCCESS: $OUTDIR/uart_bridge_j2.bit created"
ls -lh "$OUTDIR/uart_bridge_j2.bit"
```

### Expected Output

```
SUCCESS: ./build_uart_j2/uart_bridge_j2.bit created
-rw-r--r-- 1 user user 1.2M Mar 24 10:00 uart_bridge_j2.bit
```

Size should be ~1.2MB for XC7A100T bitstream.

---

## Troubleshooting

| Symptom | Fix |
|----------|-----|
| `--chipdb: No such file or directory` | Verify `xc7a100tfgg676.bin` exists in xilinx-chipdb |
| `--xdc: Cannot open file` | Path to XDC is wrong — use `../constraints/uart_bridge_j2.xdc` |
| `part xc7a100tfgg676 not found` | `prjxray-db` incomplete — check `submodule update --init --recursive` |
| `ERROR: route failed` | Reduce frequency or check pin conflicts in XDC |

---

## Transfer to Mac

```bash
# From Linux box
scp ~/trinity/fpga/openxc7-synth/build_uart_j2/uart_bridge_j2.bit \
    mac-user:/Users/playra/trinity-w1/fpga/openxc7-synth/

# Or via Git (add to .gitignore large files temporarily)
```

---

## Verification Commands (on Mac)

```bash
cd /Users/playra/trinity-w1

# Verify bitstream exists
ls -lh fpga/openxc7-synth/uart_bridge_j2.bit

# Flash to FPGA
tri fpga flash-uart

# Test UART
tri fpga uart-test
```
