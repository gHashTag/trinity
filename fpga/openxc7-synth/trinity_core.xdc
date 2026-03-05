# QMTECH Artix-7 XC7A100T-1FGG676C constraints
# TRINITY CORE V2 - RISC-V Processor with UART

# Clock input (50 MHz oscillator @ U22)
set_property LOC U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# LED output D5 (T23) - active LOW
set_property LOC T23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]

# V2: UART TX/RX pins (Bank 15, 3.3V)
# Using R23/P23 from expansion header
set_property LOC R23 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

set_property LOC P23 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]
