# ============================================================================
# TRINITY V3 JTAG UART — QMTECH XC7A100T-1FGG676C Constraints
# ============================================================================
# Clock: U22 (50 MHz), LED D5: R20, LED D6: T23
# ============================================================================

# Clock — 50 MHz oscillator (U22)
set_property PACKAGE_PIN U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 20.0 [get_ports clk]

# Reset — active high, can be tied low if unused
set_property PACKAGE_PIN P16 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports rst]
set_false_path -from [get_ports rst] -to [all]

# LED D5 — JTAG active (R20)
set_property PACKAGE_PIN R20 [get_ports led_d5]
set_property IOSTANDARD LVCMOS33 [get_ports led_d5]
set_property SLEW SLOW [get_ports led_d5]
set_property DRIVE 8 [get_ports led_d5]

# LED D6 — TX/RX activity (T23)
set_property PACKAGE_PIN T23 [get_ports led_d6]
set_property IOSTANDARD LVCMOS33 [get_ports led_d6]
set_property SLEW SLOW [get_ports led_d6]
set_property DRIVE 8 [get_ports led_d6]

# LED D7 — Fault/Error (H17 - confirmed GPIO)
set_property PACKAGE_PIN H17 [get_ports led_d7]
set_property IOSTANDARD LVCMOS33 [get_ports led_d7]
set_property SLEW SLOW [get_ports led_d7]
set_property DRIVE 8 [get_ports led_d7]
