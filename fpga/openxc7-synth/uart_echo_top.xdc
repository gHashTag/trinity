# ============================================================================
# UART Echo Top — Pin Constraints for QMTECH XC7A100T-1FGG676C
# ============================================================================
# Minimal: CLK + UART + LED (no reset, no debug)
# nextpnr-xilinx requires LOC syntax (not PACKAGE_PIN)
# ============================================================================

# Clock input (50 MHz oscillator)
set_property LOC U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# UART RX (from CH340 TX → FPGA)
set_property LOC L20 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]

# UART TX (from FPGA → CH340 RX)
set_property LOC K20 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

# LED (active-low, D6)
set_property LOC T23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]
