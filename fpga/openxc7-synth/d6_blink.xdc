# LED D6 (R23) + Clock (M22) constraints for QMTECH xc7a100t
set_property LOC M22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

set_property LOC R23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]
