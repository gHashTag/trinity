# QMTECH Artix-7 XC7A100T-1FGG676C Core Board — Trinity FPGA
# Correct pins from LiteX platform (qmtech_artix7_fgg676.py)
# Clock: 50 MHz (U22), LED0: T23, LED1: R23

set_property LOC U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

set_property LOC T23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]

# UART pins (directly accessible on J2 header)
set_property LOC L20 [get_ports {uart_rx}]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_rx}]

set_property LOC K20 [get_ports {uart_tx}]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_tx}]

# Debug outputs (optional, accent J2 header)
set_property LOC N23 [get_ports {debug_state[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {debug_state[0]}]

set_property LOC M22 [get_ports {debug_state[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {debug_state[1]}]

# SPI Flash (directly wired on QMTECH board to W25Q128)
# These use CCLK/DIN/DOUT which are special on Artix-7
# For user SPI access, use STARTUPE2 primitive or dedicated pins
# set_property LOC C11 [get_ports {spi_cs_n}]
# set_property IOSTANDARD LVCMOS33 [get_ports {spi_cs_n}]
