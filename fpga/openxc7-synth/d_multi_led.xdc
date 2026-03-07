# QMTECH Artix-7 LED pins (from schematic)
set_property LOC U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# Try various LED pins
set_property LOC E21 [get_ports led0]
set_property IOSTANDARD LVCMOS33 [get_ports led0]

set_property LOC D21 [get_ports led1]
set_property IOSTANDARD LVCMOS33 [get_ports led1]

set_property LOC G21 [get_ports led2]
set_property IOSTANDARD LVCMOS33 [get_ports led2]

set_property LOC F22 [get_ports led3]
set_property IOSTANDARD LVCMOS33 [get_ports led3]

set_property LOC G22 [get_ports led4]
set_property IOSTANDARD LVCMOS33 [get_ports led4]

set_property LOC E22 [get_ports led5]
set_property IOSTANDARD LVCMOS33 [get_ports led5]
