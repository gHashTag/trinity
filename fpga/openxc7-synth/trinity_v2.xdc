# ============================================================================
# Trinity V2 Constraints — QMTECH XC7A100T-1FGG676C
# ============================================================================
# Generated from specs/tri/trinity_v2_constraints.vibee
# Target: 50 MHz operation
# ============================================================================

# Clock — 50 MHz oscillator (U22)
set_property PACKAGE_PIN U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 20.0 [get_ports clk]

# Reset — USER RESET button (active low)
# set_property PACKAGE_PIN USER_RESET [get_ports rst_n]
# set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
# set_false_path -from [get_ports rst_n] -to [all]

# UART RX — C17
set_property PACKAGE_PIN C17 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]
set_input_delay -clock clk -max 10.0 [get_ports uart_rx]

# UART TX — D18
set_property PACKAGE_PIN D18 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]
set_output_delay -clock clk -max 10.0 [get_ports uart_tx]

# LED — T23 (D6 on board)
set_property PACKAGE_PIN T23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]
set_property SLEW SLOW [get_ports led]

# Quantum State Outputs (for debugging)
# If exposed:
# set_property PACKAGE_PIN <pin> [get_ports quantum_pos]
# set_property IOSTANDARD LVCMOS33 [get_ports quantum_pos]
# etc.
