# Phi-Rhythm LED Blink Constraints
# Target: XC7A100T-FGG676 (Artix-7)

# Clock: 50 MHz oscillator on U22
set_property LOC U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# LED: T23 (active-low LED on board)
set_property LOC T23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]
