# Clock
set_property LOC U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# UART RX (from ESP32 TX - Pin L20)
set_property LOC L20 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]

# UART TX (to ESP32 RX - Pin K20)
set_property LOC K20 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

# Status LED
set_property LOC T23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]
