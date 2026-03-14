# ============================================================================
# JTAG Echo — Minimal constraints (CLK + 2 LEDs only)
# No UART pins needed — communication via BSCANE2/JTAG
# ============================================================================

# Clock: 50 MHz oscillator
set_property LOC U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# LED D5 — Heartbeat (active-low)
set_property LOC T23 [get_ports led_d5]
set_property IOSTANDARD LVCMOS33 [get_ports led_d5]

# LED D6 — RX activity (active-low)
set_property LOC R23 [get_ports led_d6]
set_property IOSTANDARD LVCMOS33 [get_ports led_d6]
