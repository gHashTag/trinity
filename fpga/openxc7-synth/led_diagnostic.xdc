# LED Diagnostic — Dual LED test
# QMTECH Artix-7 XC7A100T-1FGG676C

# Clock: 50 MHz (U22)
set_property LOC U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# LED0: T23 (fast blink)
set_property LOC T23 [get_ports led0]
set_property IOSTANDARD LVCMOS33 [get_ports led0]

# LED1: R23 (slow blink)
set_property LOC R23 [get_ports led1]
set_property IOSTANDARD LVCMOS33 [get_ports led1]
