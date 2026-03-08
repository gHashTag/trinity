# ============================================================================
# VSA UART φ-TOP — Pin Constraints for QMTECH XC7A100T-1FGG676C
# ============================================================================
#
# Demonstrates 0 DSP48 VSA coprocessor with φ-arithmetic
#
# Pin Assignments:
#   Clock:  U22 (50 MHz oscillator)
#   Reset:  V22 (tie to 3.3V for normal operation)
#   UART:   L20 (RX), K20 (TX) — 115200 baud 8N1
#   LED:    T23 (D6, ACTIVE-LOW: 0 = ON, 1 = OFF)
#   Debug:  N23, M22 (optional status outputs)
#
# φ² + 1/φ² = 3 = TRINITY
#
# ============================================================================

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

# LED output (ACTIVE-LOW: 0 = ON, 1 = OFF)
# Using T23 (D6, right LED) as confirmed working in phi_arithmetic_top
set_property PACKAGE_PIN T23 [get_ports {led}]
set_property IOSTANDARD LVCMOS33 [get_ports {led}]

# Debug state outputs (optional)
set_property PACKAGE_PIN N23 [get_ports {debug_state[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {debug_state[0]}]

set_property PACKAGE_PIN M22 [get_ports {debug_state[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {debug_state[1]}]

# ============================================================================
