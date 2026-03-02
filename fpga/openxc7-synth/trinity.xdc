# QMTECH Artix-7 XC7A100T-1FGG676C Core Board — Trinity FPGA
# Correct pins from LiteX platform (qmtech_artix7_fgg676.py)
# Clock: 50 MHz (U22), LED0: T23, LED1: R23

set_property LOC U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

set_property LOC T23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]
