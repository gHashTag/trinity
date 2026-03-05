# QMTECH Artix-7 XC7A100T-1FGG676C Core Board
# Week 5: VSA Quantum Top with UART

# Clock: 50 MHz oscillator
set_property LOC U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# Reset: Tie to GND for normal operation
set_property LOC M15 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports rst]

# LED: Status indicator (D6 - T23)
set_property LOC T23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]

# UART (connect to USB-UART adapter)
set_property LOC H16 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]
set_property LOC J16 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]
