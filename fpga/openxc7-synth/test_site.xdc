# Direct site specification
set_property BEL IOB_Y0 [get_ports {led[*]}]
set_property LOC R23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]
set_property LOC U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
