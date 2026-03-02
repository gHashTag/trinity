#!/bin/bash
# flash.sh — Flash FPGA via Platform Cable USB II
# Usage: ./fpga/tools/flash.sh [bitstream.bit]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BITFILE="${1:-$SCRIPT_DIR/../fly-vivado/output/trinity_qmtech.bit}"

if [ ! -f "$BITFILE" ]; then
    echo "Error: bitstream not found: $BITFILE"
    exit 1
fi

echo "Flashing: $BITFILE"
echo "sudo required for USB access..."
sudo "$SCRIPT_DIR/jtag_program" "$BITFILE"
