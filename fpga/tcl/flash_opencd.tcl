#!/usr/bin/env openocd
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY FPGA — Flash Script via OpenOCD
# Target: Digilent Arty A7 with Xilinx Platform Cable USB II
# ═══════════════════════════════════════════════════════════════════════════════

# Interface - Digilent USB JTAG
adapter driver ftdi
transport select jtag
ftdi device_desc "Digilent USB Device"
ftdi vid_pid 0x0403 0x6010
ftdi channel 0

# Target - Xilinx Artix-7
set CHIP xc7a35t
set CPLD xc7a35t

# JTAG speed (kHz)
adapter speed 1000

# Initialize
init

# ═══════════════════════════════════════════════════════════════════════════════
# FLASH BITSTREAM
# ═══════════════════════════════════════════════════════════════════════════════

puts "╔════════════════════════════════════════════════════════════════╗"
puts "║          TRINITY FPGA FLASH — OMEGA PHASE                    ║"
puts "╠════════════════════════════════════════════════════════════════╣"
puts "║  Target:    Digilent Arty A7 (Artix-7)                       ║"
puts "║  Interface: FTDI JTAG                                         ║"
puts "║  Bitstream: trinity_fpga_core.bit                            ║"
puts "╚════════════════════════════════════════════════════════════════╝"

# Load bitstream to FPGA
# Note: For Artix-7, we use pld (program logic device) commands
pld load 0 vivado_build/trinity_fpga_core.bit

puts ""
puts "╔════════════════════════════════════════════════════════════════╗"
puts "║          TRINITY FPGA BOOT — COMPLETE                         ║"
puts "╠════════════════════════════════════════════════════════════════╣"
puts "║  φ² + 1/φ² = 3 = TRINITY                                       ║"
puts "║  FPGA is now running TRINITY OS                               ║"
puts "║  Check LEDs and UART for status                               ║"
puts "╚════════════════════════════════════════════════════════════════╝"

# Exit
shutdown
