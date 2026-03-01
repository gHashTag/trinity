# ============================================================================
# FORGE OF KOSCHEI — Flash bitstream to Arty A7 via Vivado Hardware Manager
# Target: XC7A35T via Platform Cable USB II (JTAG)
# ============================================================================
# Usage:
#   vivado -mode batch -source fpga/fly-vivado/tcl/flash.tcl
#   vivado -mode batch -source fpga/fly-vivado/tcl/flash.tcl -tclargs <bitstream.bit>
# ============================================================================

# Get bitstream path from args or use default
if {$argc > 0} {
    set bitstream_path [lindex $argv 0]
} else {
    set bitstream_path "build/forge_trinity.bit"
}

puts "============================================="
puts "FORGE OF KOSCHEI — HARDWARE FLASH"
puts "Bitstream: $bitstream_path"
puts "Target:    XC7A35T (Arty A7)"
puts "Cable:     Platform Cable USB II"
puts "============================================="

# Check bitstream exists
if {![file exists $bitstream_path]} {
    puts "ERROR: Bitstream not found: $bitstream_path"
    puts "Run: zig build forge -- run --input fpga/sim/build/trinity.json --device xc7a35t --constraints fpga/fly-vivado/constraints/arty_a7.xdc --output build/forge_trinity.bit"
    exit 1
}

# Open hardware manager
open_hw_manager

# Connect to hardware server
connect_hw_server -allow_non_jtag

# Open hardware target (auto-detect)
open_hw_target

# Get the first device (XC7A35T)
set hw_device [lindex [get_hw_devices] 0]
puts "Device found: $hw_device"

# Set programming file
set_property PROGRAM.FILE $bitstream_path $hw_device

# Program the device
puts "Programming FPGA..."
program_hw_devices $hw_device

puts "============================================="
puts "FLASH COMPLETE — KOSCHEI LIVES IN SILICON"
puts "============================================="

# Clean up
close_hw_target
disconnect_hw_server
close_hw_manager
