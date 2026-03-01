# Trinity FPGA Flash — QMTECH XC7A100T via Platform Cable USB II
# Programs FPGA via JTAG (volatile — lost on power cycle)

puts "INFO: Opening hardware manager..."
open_hw_manager

puts "INFO: Connecting to Platform Cable USB II..."
connect_hw_server -allow_non_jtag

puts "INFO: Opening hardware target..."
open_hw_target

# Get the first device on the JTAG chain
set device [lindex [get_hw_devices] 0]
puts "INFO: Found device: $device"

# Set the bitstream file
set_property PROGRAM.FILE {/workspace/output/trinity_qmtech.bit} $device

# Program
puts "INFO: Programming FPGA..."
program_hw_devices $device

puts "SUCCESS: FPGA programmed! LED should be blinking."
puts "TRINITY LIVES IN SILICON. phi^2 + 1/phi^2 = 3"

close_hw_manager
exit
