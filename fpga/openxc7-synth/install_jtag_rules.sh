#!/bin/bash
# Installing udev rules for JTAG without sudo

set -e

RULES_FILE="/Users/playra/trinity-w1/fpga/openxc7-synth/99-xilinx-ftdi.rules"
TARGET_DIR="/etc/udev/rules.d"

echo "📋 Copying JTAG rules to $TARGET_DIR..."
sudo cp "$RULES_FILE" "$TARGET_DIR/99-xilinx-ftdi.rules"

echo "🔄 Reloading udev..."
sudo udevadm control --reload-rules
sudo udevadm trigger

echo ""
echo "✅ Rules installed!"
echo ""
echo "🔌 Now disconnect and reconnect JTAG cable"
echo "   After that check: lsusb | grep 03fd"
echo ""
echo "📝 Flashing without sudo:"
echo "   openFPGALoader --board qmtech_xc7a100t --bitstream temporal_heartbeat.bit"
