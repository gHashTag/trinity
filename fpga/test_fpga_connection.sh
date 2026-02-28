#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# TRINITY FPGA — Test Connection via OpenOCD
# ═══════════════════════════════════════════════════════════════════════════

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          TRINITY FPGA CONNECTION TEST                          ║"
echo "╠════════════════════════════════════════════════════════════════╣"

# Detect USB devices
echo "║  USB DEVICES:                                                  ║"
usb_devices=$(system_profiler SPUSBDataType 2>/dev/null | grep -A5 "Xilinx")
if [ -n "$usb_devices" ]; then
    echo "$usb_devices" | sed 's/^/║  /'
else
    echo "║  ❌ Xilinx device not found via USB                           ║"
fi

echo "║                                                                ║"
echo "║  OPENOCD VERSION:                                              ║"
openocd --version | head -1 | sed 's/^/║  /'

echo "║                                                                ║"
echo "║  TESTING JTAG CONNECTION...                                    ║"

# Test OpenOCD connection
openocd -f interface/ftdi/digilent-hs1.cfg \
        -f target/xilinx/artix7.cfg \
        -c "init; scan_chain; exit" 2>&1 | sed 's/^/║  /'

echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
