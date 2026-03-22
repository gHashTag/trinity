# ============================================================================
# UART Echo Top — Pin Constraints for QMTECH XC7A100T-1FGG676C
# ============================================================================
# Minimal: CLK + UART + LED (no reset, no debug)
# nextpnr-xilinx requires LOC syntax (not PACKAGE_PIN)
# ============================================================================

# Clock input (50 MHz oscillator) — M22
set_property LOC M22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 20.000 -name sys_clk [get_ports clk]

# UART RX (from FT232RL TX → FPGA) — E26 (J2 pin 6)
set_property LOC E26 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]

# UART TX (from FPGA → FT232RL RX) — D26 (J2 pin 5)
set_property LOC D26 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

# LED (active-low, D5) — J19
set_property LOC J19 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]

# Bitstream config
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
