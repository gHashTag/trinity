#!/bin/bash
# Trinity FPGA UART Echo Synthesis — Docker Full Pipeline
# ================================================
# Usage: bash fpga/docker_uart_synth.sh [uart_echo_top.bit output path]
# Requires: Docker, fpga-synth image (ghcr.io/symbiflow/prjxray:latest)
# ================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$SCRIPT_DIR/openxc7-synth"
BITSTREAM="${1:-$WORK_DIR/uart_echo_top.bit}"

echo "═════════════════════════════════════════════"
echo "  TRINITY UART ECHO SYNTHESIS"
echo "═══════════════════════════════════════════"
echo ""
echo "Target:  Xilinx XC7A100T-1FGG676C"
echo "Design:  UART Echo + Ping/Pong"
echo ""

# Check fpga-synth container (image name may vary)
if ! docker ps --format '{{.Image}}' 2>/dev/null | grep -q 'fpga-synth\|prjxray\|symbiflow'; then
    echo "❌ fpga-synth container not running!"
    echo "   Start with: docker run -d --name fpga-synth --platform linux/amd64 -v \"$PWD:/work\" fpga-synth:latest sleep inf"
    exit 1
fi

echo "✅ fpga-synth container detected"

# Check inputs
if [ ! -f "$WORK_DIR/uart_echo_top.v" ]; then
    echo "❌ uart_echo_top.v not found!"
    exit 1
fi

if [ ! -f "$WORK_DIR/uart_echo_top.xdc" ]; then
    echo "❌ uart_echo_top.xdc not found!"
    exit 1
fi

# Run synthesis inside container
echo "[1/5] Yosys synthesis..."
docker exec fpga-synth bash -lc "
    set -e
    cd /work
    yosys -p 'read_verilog uart_echo_top.v; synth_xilinx -family xc7 -top uart_echo_top -blif uart_echo_top.blif'
    echo \"\$?\"
"

if [ $? -ne 0 ]; then
    echo "❌ Yosys synthesis failed"
    exit 1
fi

echo "✅ Yosys synthesis complete"

# Place and route
echo "[2/5] Nextpnr placement & routing..."
docker exec fpga-synth bash -lc "
    set -e
    cd /work
    nextpnr-xilinx --chipdb /opt/nextpnr-xilinx/xc7a100t.bin \
        --xdc uart_echo_top.xdc \
        --json uart_echo_top.json \
        --fasm uart_echo_top.fasm \
        --top uart_echo_top \
        uart_echo_top.blif
    echo \"\$?\"
"

if [ $? -ne 0 ]; then
    echo "❌ Nextpnr failed"
    exit 1
fi

echo "✅ Placement & routing complete"

# Generate bitstream
echo "[3/5] Fasm2frames + XC7frames2bit → bitstream..."
docker exec fpga-synth bash -lc "
    set -e
    cd /work
    fasm2frames --part xc7a100t-fgg484-1 uart_echo_top.fasm uart_echo_top.frames
    echo \"\$?\"
"

if [ $? -ne 0 ]; then
    echo "❌ Fasm2frames failed"
    exit 1
fi

docker exec fpga-synth bash -lc "
    set -e
    cd /work
    xc7frames2bit --part xc7a100t-fgg484-1 uart_echo_top.frames uart_echo_top.bit
    echo \"\$?\"
"

if [ $? -ne 0 ]; then
    echo "❌ XC7frames2bit failed"
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════"
echo "  BITSTREAM GENERATED"
echo "═════════════════════════════════════════════"
echo ""
echo "Output: $BITSTREAM"
ls -lh "$BITSTREAM" 2>/dev/null
echo ""
echo "Next step: flash with openFPGALoader"
echo "  openFPGALoader -c xpc $BITSTREAM"
