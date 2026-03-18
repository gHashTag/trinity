#!/bin/bash
# ═════════════════════════════════════════════════════════════════════════
# TRINITY FPGA — Flash Arty A7 Demo
# ═════════════════════════════════════════════════════════════════════════

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          TRINITY FPGA — FLASHING ARTY A7 DEMO                ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║  Board: Digilent Arty A7 (Artix-7)                           ║"
echo "║  Bitstream: uart_demo.bit                                     ║"
echo "╚════════════════════════════════════════════════════════════════╝"

# OpenOCD configuration for Arty A7
cat > /tmp/arty_a7_openocd.cfg << 'EOCFG'
adapter driver ftdi
adapter speed 1000
transport select jtag

# Target: Xilinx Artix-7
target create xc7.tap -chain-position 0

# XC7A35T or XC7A100T depending on board variant
# For Arty A7 35T:
set XC7_CHIP  xc7a35t
# For Arty A7 100T:
# set XC7_CHIP  xc7a100t

pld device 0 \$XC7_CHIP
EOCFG

echo "INFO: Connecting to Arty A7..."
echo "INFO: Make sure the JTAG USB cable is connected!"

# Zapatwithto OpenOCD with praboutshandintoabouty
openocd -f /tmp/arty_a7_openocd.cfg \
  -c "init; \
  pld load 0 ~/Downloads/arty_a7_demo.bit; \
  exit;" 2>&1

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          FLASH COMPLETE                                      ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║  Check LEDs on your Arty A7 board!                           ║"
echo "║  They should be blinking now.                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
