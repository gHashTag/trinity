# Test 09: Bank Crossing
# Bank 13: U22 (clock), G22 (LED)
# Bank 14: T23, R23 (LEDs)
# Bank 15: L22, M22, N22 (LEDs)
set_property LOC U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

set_property LOC G22 [get_ports led_bank13]  # Bank 15 actually
set_property IOSTANDARD LVCMOS33 [get_ports led_bank13]

set_property LOC T23 [get_ports led_bank14]  # Bank 14
set_property IOSTANDARD LVCMOS33 [get_ports led_bank14]

set_property LOC L22 [get_ports led_bank15]  # Bank 14
set_property IOSTANDARD LVCMOS33 [get_ports led_bank15]
