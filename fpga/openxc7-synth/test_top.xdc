# QMTECH Artix-7 XC7A100T-1FGG676C Pin Constraints
# φ-Arithmetic LED Blink Demo
#
# ⚠️ CRITICAL: LED on T23 is ACTIVE-LOW! ⚠️
#   led = 0 → LED ON  |  led = 1 → LED OFF
#   Verilog: assign led = ~led_state;
#   Verified: 2026-03-08 (55.1% variation ✅)

# Clock: 50 MHz oscillator (U22)
set_property PACKAGE_PIN U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# LED: T23 (ACTIVE-LOW!)
set_property PACKAGE_PIN T23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]
