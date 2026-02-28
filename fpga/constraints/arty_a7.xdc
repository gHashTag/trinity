# ═══════════════════════════════════════════════════════════════════════════════
# Digilent Arty A7 Constraints File
# FPGA: Xilinx Artix-7 XC7A35T or XC7A100T
# ═══════════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════════
# CLOCK
# ═══════════════════════════════════════════════════════════════════════════════

# 100 MHz system clock (E3/E19)
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports clk]
create_generated_clock -name clk_100MHz -source [get_ports clk] [get_pins */clk]

# ═══════════════════════════════════════════════════════════════════════════════
# RESET
# ═══════════════════════════════════════════════════════════════════════════════

# Reset button (C12 - active low)
set_property -dict {PACKAGE_PIN C12 IOSTANDARD LVCMOS33} [get_ports rst_n]

# ═══════════════════════════════════════════════════════════════════════════════
# LEDS - Status Indicators
# ═══════════════════════════════════════════════════════════════════════════════

# 4 LEDs (R5, T5, T8, T9 - active low)
set_property -dict {PACKAGE_PIN R5 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN T5 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN T8 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN T9 IOSTANDARD LVCMOS33} [get_ports {led[3]}]

# ═══════════════════════════════════════════════════════════════════════════════
# SWITCHES - Input
# ═══════════════════════════════════════════════════════════════════════════════

# 4 switches (A15, C16, C15, P15)
set_property -dict {PACKAGE_PIN A15 IOSTANDARD LVCMOS33} [get_ports {switch[0]}]
set_property -dict {PACKAGE_PIN C16 IOSTANDARD LVCMOS33} [get_ports {switch[1]}]
set_property -dict {PACKAGE_PIN C15 IOSTANDARD LVCMOS33} [get_ports {switch[2]}]
set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports {switch[3]}]

# ═══════════════════════════════════════════════════════════════════════════════
# BUTTONS
# ═══════════════════════════════════════════════════════════════════════════════

# 4 buttons (D9, C9, B9, B8 - active low)
set_property -dict {PACKAGE_PIN D9 IOSTANDARD LVCMOS33} [get_ports {btn[0]}]
set_property -dict {PACKAGE_PIN C9 IOSTANDARD LVCMOS33} [get_ports {btn[1]}]
set_property -dict {PACKAGE_PIN B9 IOSTANDARD LVCMOS33} [get_ports {btn[2]}]
set_property -dict {PACKAGE_PIN B8 IOSTANDARD LVCMOS33} [get_ports {btn[3]}]

# ═══════════════════════════════════════════════════════════════════════════════
# UART - Communication with Host
# ═══════════════════════════════════════════════════════════════════════════════

# UART (TX=A9, RX=C9 - at 115200 baud)
set_property -dict {PACKAGE_PIN A9 IOSTANDARD LVCMOS33} [get_ports uart_tx]
set_property -dict {PACKAGE_PIN C9 IOSTANDARD LVCMOS33} [get_ports uart_rx]

# ═══════════════════════════════════════════════════════════════════════════════
# GPIO - Pmod ports (optional)
# ═══════════════════════════════════════════════════════════════════════════════

# Pmod JA (J1, L1, M1, N1 - top row)
# set_property -dict {PACKAGE_PIN J1 IOSTANDARD LVCMOS33} [get_ports {gpio[0]}]
# set_property -dict {PACKAGE_PIN L1 IOSTANDARD LVCMOS33} [get_ports {gpio[1]}]
# set_property -dict {PACKAGE_PIN M1 IOSTANDARD LVCMOS33} [get_ports {gpio[2]}]
# set_property -dict {PACKAGE_PIN N1 IOSTANDARD LVCMOS33} [get_ports {gpio[3]}]

# ═══════════════════════════════════════════════════════════════════════════════
# JTAG - Programming Interface (automatic)
# ═══════════════════════════════════════════════════════════════════════════════
# JTAG pins are automatically configured for programming
