#!/bin/bash
# Flash quantum bridge bitstream with auto-initialization

BITSTREAM="${1:-/Users/playra/trinity-w1/fpga/openxc7-synth/quantum_bridge_violation.bit}"
FXLOAD="/Users/playra/trinity-w1/fpga/tools/fxload"
FIRMWARE="/Users/playra/trinity-w1/fpga/tools/xusb_xp2.hex"
JTAG_PROG="/Users/playra/trinity-w1/fpga/tools/jtag_program"

echo "🔌 Initializing JTAG cable..."
sudo "$FXLOAD" -t fx2 -d 03fd:0013 -i "$FIRMWARE" 2>/dev/null

echo "⚡ Flashing: $BITSTREAM"
sudo "$JTAG_PROG" "$BITSTREAM"

echo "✅ Done!"
