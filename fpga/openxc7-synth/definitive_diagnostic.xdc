# ============================================================================
# DEFINITIVE LED DIAGNOSTIC Constraints
# QMTECH Artix-7 XC7A100T-1FGG676C
# ============================================================================

# Clock: 50 MHz oscillator
set_property PACKAGE_PIN U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# T23: D6 LED (green) - FAST blink (~6 Hz)
set_property PACKAGE_PIN T23 [get_ports t23]
set_property IOSTANDARD LVCMOS33 [get_ports t23]

# R23: D5 LED (green) - SLOW blink (~1.5 Hz)
set_property PACKAGE_PIN R23 [get_ports r23]
set_property IOSTANDARD LVCMOS33 [get_ports r23]
