# VSA UART Top Constraints
# QMTECH XC7A100T-1FGG676C

# Clock: 50 MHz oscillator
set_property LOC U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# LED: Status indicator (D5 - T23)
set_property LOC T23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]

# Reset: Tie to GND internally via unused pin
set_property LOC M15 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports rst]

# UART (connect to USB-UART adapter)
# Using pins from Bank 15
set_property LOC H16 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]
set_property LOC J16 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]
