# QMTECH XC7A100T-1FGG676C UART Echo Constraints
# FT232RL Connections:
#   RXD (green)  → J2 pin 5  → L20 → FPGA uart_tx
#   TXD (white)  → J2 pin 6  → K20 → FPGA uart_rx
#   GND (black) → J2 pin 1  → GND
#   LED            → T23  (D5)
#   Clock         → M22  (50 MHz)

set_property LOC M22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

set_property LOC L20 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]
set_property PULLDOWN TRUE [get_ports uart_tx]  # Pull down to idle

set_property LOC K20 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]

set_property LOC T23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]
