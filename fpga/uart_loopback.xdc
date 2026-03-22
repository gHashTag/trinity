# UART Loopback XDC Constraints
# QMTech XC7A100T FGG676 Core Board
# Bank 15 pins D26/E26

# Clock — 50 MHz system clock on M22
set_property -dict {PACKAGE_PIN M22 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 20.000 -name sys_clk [get_ports clk]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_IBUF]

# UART TX (FPGA → ESP32/Mac) - D26
set_property -dict {PACKAGE_PIN D26 IOSTANDARD LVCMOS33} [get_ports uart_tx]

# UART RX (ESP32/Mac → FPGA) - E26
set_property -dict {PACKAGE_PIN E26 IOSTANDARD LVCMOS33} [get_ports uart_rx]

# LED - J19 (active low)
set_property -dict {PACKAGE_PIN J19 IOSTANDARD LVCMOS33} [get_ports led]

# Bitstream config
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
