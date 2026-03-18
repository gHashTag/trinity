# =============================================================================
# TERNARY MATVEC 243x729 — Pin Constraints for QMTECH XC7A100T-1FGG676C
# =============================================================================

# Clock input (50 MHz oscillator)
set_property LOC U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# UART RX (receive from host)
set_property LOC L20 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]

# UART TX (transmit to host)
set_property LOC K20 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

# LED output (active-low, D6 = T23, confirmed working)
set_property LOC T23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]

# Debug state outputs
set_property LOC N23 [get_ports {debug_state[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {debug_state[0]}]

set_property LOC M22 [get_ports {debug_state[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {debug_state[1]}]
