# GF16 FPGA Synthesis Constraints — BENCH-005
# QMTECH XC7A100T-FGG676 (Artix-7)
# Native openXC7 toolchain (Yosys + nextpnr-xilinx)

# =============================================================================
# CLOCK — 50 MHz oscillator (U22 → LIOB33_X0Y25)
# =============================================================================
set_property LOC U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# =============================================================================
# LED — T23 (active-low, D6) for status indication
# =============================================================================
set_property LOC T23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]

# LED behavior (in Verilog):
# - Solid ON = computation complete (result valid)
# - OFF = reset state
# - Can be used for simple status check

# =============================================================================
# UART (optional, for later verification)
# =============================================================================
# Uncomment when UART verification is needed:
# set_property LOC L20 [get_ports uart_rx]
# set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]
# set_property LOC K20 [get_ports uart_tx]
# set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]
