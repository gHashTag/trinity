# Test D5 on J19 (active-low), Clock M22
set_property LOC M22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

set_property LOC J19 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]
