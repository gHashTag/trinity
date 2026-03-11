# =============================================================================
# Artix-7 XC7A200T Constraints (adjust for your board)
# =============================================================================
# Placeholder: update LOC pins for your specific 200T board
# These are typical Nexys A7-200T pins

set_property LOC E3 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

set_property LOC H17 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]

# UART (adjust for your board's USB-UART bridge)
set_property LOC C4 [get_ports {uart_rx}]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_rx}]

set_property LOC D4 [get_ports {uart_tx}]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_tx}]

# Debug
set_property LOC J15 [get_ports {debug_state[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {debug_state[0]}]

set_property LOC J13 [get_ports {debug_state[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {debug_state[1]}]
