# UART TOP — Pin Constraints for QMTECH XC7A100T-1FGG676C
# FIXED: LED changed from R23 to T23 (matching working designs)
# φ² + 1/φ² = 3 | TRINITY

# Clock: 50 MHz oscillator (U22)
set_property PACKAGE_PIN U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 20.000 -name sys_clk [get_ports clk]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_IBUF]

# Reset input (tie to 3.3V for normal operation)
set_property PACKAGE_PIN V22 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports rst]

# UART RX (receive from host)
set_property PACKAGE_PIN L20 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]

# UART TX (transmit to host)
set_property PACKAGE_PIN K20 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

# LED output (active-low: 0 = ON, 1 = OFF)
# FIXED: Changed from R23 to T23 to match working designs
set_property PACKAGE_PIN T23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]

# Debug state outputs (optional)
set_property PACKAGE_PIN N23 [get_ports debug_state[0]]
set_property IOSTANDARD LVCMOS33 [get_ports debug_state[0]]

set_property PACKAGE_PIN M22 [get_ports debug_state[1]]
set_property IOSTANDARD LVCMOS33 [get_ports debug_state[1]]

# Bitstream config
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
