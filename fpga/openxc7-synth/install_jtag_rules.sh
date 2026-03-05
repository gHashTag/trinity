#!/bin/bash
# Установка udev правил для JTAG без sudo

set -e

RULES_FILE="/Users/playra/trinity-w1/fpga/openxc7-synth/99-xilinx-ftdi.rules"
TARGET_DIR="/etc/udev/rules.d"

echo "📋 Копирую правила JTAG в $TARGET_DIR..."
sudo cp "$RULES_FILE" "$TARGET_DIR/99-xilinx-ftdi.rules"

echo "🔄 Перезагружаю udev..."
sudo udevadm control --reload-rules
sudo udevadm trigger

echo ""
echo "✅ Правила установлены!"
echo ""
echo "🔌 Теперь отключи и включи JTAG кабель"
echo "   После этого проверь: lsusb | grep 03fd"
echo ""
echo "📝 Прошивка без sudo:"
echo "   openFPGALoader --board qmtech_xc7a100t --bitstream temporal_heartbeat.bit"
