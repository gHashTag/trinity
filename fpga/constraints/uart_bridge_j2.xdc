# ============================================================================
# UART Bridge Constraints — J2 Header (FT232RL connection)
# QMTECH XC7A100T-1FGG676C
# ============================================================================
# Source: Schematic U2 (HDR_32x2), Bank 15
#
# FT232RL Wiring:
#   🟢 RXD (green)  → J2 pin 5  → FPGA D26 (uart_tx from FPGA)
#   ⬜ TXD (white)  → J2 pin 6  → FPGA E26 (uart_rx to FPGA)
#   ⬛ GND (black)  → J2 pin 1  → GND
#
# ⚠️ LEGACY WARNING: K20/L20 were INCORRECT pins (pre-Iteration 7)
#    Always use D26/E26 for J2 UART per schematic U2
# ============================================================================

# Clock: 50 MHz oscillator (M22)
set_property -dict {PACKAGE_PIN M22 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 20.000 -name sys_clk [get_ports clk]

# UART TX (FPGA → FT232RL RXD → J2 pin 5 → BANK15_D26)
set_property -dict {PACKAGE_PIN D26 IOSTANDARD LVCMOS33} [get_ports uart_tx]

# UART RX (FT232RL TXD → J2 pin 6 → BANK15_E26)
set_property -dict {PACKAGE_PIN E26 IOSTANDARD LVCMOS33 PULLDOWN true} [get_ports uart_rx]

# LED (T23 - active-low)
set_property -dict {PACKAGE_PIN T23 IOSTANDARD LVCMOS33} [get_ports led]
