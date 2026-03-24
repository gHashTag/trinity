# ═══════════════════════════════════════════════════════════════════════════════
# UART Bridge Constraints — J2 Header (FT232RL connection)
# QMTech XC7A100T-1FGG676C
# ═══════════════════════════════════════════════════════════════════════════════
#
# FT232RL Wiring:
#   🟢 RXD (green)  → J2 pin 5  → FPGA K20 (uart_tx from FPGA)
#   ⬜ TXD (white)  → J2 pin 6  → FPGA L20 (uart_rx to FPGA)
#   ⬛ GND (black)  → J2 pin 1  → GND
#
# φ² + 1/φ² = 3 = TRINITY
# ═══════════════════════════════════════════════════════════════════════════════

# Clock: 50 MHz oscillator (M22)
set_property -dict {PACKAGE_PIN M22 IOSTANDARD LVCMOS33} [get_ports clk]

# UART TX (FPGA → FT232RL RXD → J2 pin 5)
set_property -dict {PACKAGE_PIN K20 IOSTANDARD LVCMOS33} [get_ports uart_tx]

# UART RX (FT232RL TXD → J2 pin 6 → FPGA)
set_property -dict {PACKAGE_PIN L20 IOSTANDARD LVCMOS33 PULLDOWN true} [get_ports uart_rx]

# LED (T23 - active-low)
set_property -dict {PACKAGE_PIN T23 IOSTANDARD LVCMOS33} [get_ports led]
