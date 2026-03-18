# QMTECH Artix-7 XC7A100T-1FGG676C Core Board
# Correct pins from LiteX platform (qmtech_artix7_fgg676.py)
# Clock: U22 (50 MHz), LED0: T23 (D5), LED1: R23 (D6)

set_property LOC U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# D6 is R23 - using this instead of T23 (D5)
set_property LOC R23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]
