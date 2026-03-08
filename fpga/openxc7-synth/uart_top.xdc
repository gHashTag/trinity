# ═══════════════════════════════════════════════════════════════════════════════
# UART TOP — Pin Constraints for QMTECH XC7A100T-1FGG676C
# ═══════════════════════════════════════════════════════════════════════════════
#
# Generated from: specs/fpga/uart_top.tri
# Target:         QMTECH Artix-7 XC7A100T-1FGG676C
# Frequency:      50 MHz
#
# φ² + 1/φ² = 3 = TRINITY
# ═══════════════════════════════════════════════════════════════════════════════

# Clock input (50 MHz oscillator)
set_property PACKAGE_PIN U22 [get_ports {clk}]
set_property IOSTANDARD LVCMOS33 [get_ports {clk}]

# Reset input (tie to 3.3V for normal operation)
set_property PACKAGE_PIN V22 [get_ports {rst}]
set_property IOSTANDARD LVCMOS33 [get_ports {rst}]

# UART RX (receive from host)
set_property PACKAGE_PIN L20 [get_ports {uart_rx}]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_rx}]

# UART TX (transmit to host)
set_property PACKAGE_PIN K20 [get_ports {uart_tx}]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_tx}]

# LED output (active-low: 0 = ON, 1 = OFF)
set_property PACKAGE_PIN R23 [get_ports {led}]
set_property IOSTANDARD LVCMOS33 [get_ports {led}]

# Debug state outputs (optional - using minimal pins)
set_property PACKAGE_PIN N23 [get_ports {debug_state[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {debug_state[0]}]

set_property PACKAGE_PIN M22 [get_ports {debug_state[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {debug_state[1]}]

# ═══════════════════════════════════════════════════════════════════════════════
