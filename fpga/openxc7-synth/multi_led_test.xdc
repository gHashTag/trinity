# QMTECH Artix-7 XC7A100T-1FGG676C
# Multi-LED test to find correct D6 pin

set_property LOC U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

set_property LOC T23 [get_ports led0]
set_property IOSTANDARD LVCMOS33 [get_ports led0]

set_property LOC R23 [get_ports led1]
set_property IOSTANDARD LVCMOS33 [get_ports led1]

set_property LOC G22 [get_ports led2]
set_property IOSTANDARD LVCMOS33 [get_ports led2]

set_property LOC D21 [get_ports led3]
set_property IOSTANDARD LVCMOS33 [get_ports led3]

set_property LOC E21 [get_ports led4]
set_property IOSTANDARD LVCMOS33 [get_ports led4]

set_property LOC F19 [get_ports led5]
set_property IOSTANDARD LVCMOS33 [get_ports led5]

set_property LOC L22 [get_ports led7]
set_property IOSTANDARD LVCMOS33 [get_ports led7]

set_property LOC M22 [get_ports led8]
set_property IOSTANDARD LVCMOS33 [get_ports led8]
