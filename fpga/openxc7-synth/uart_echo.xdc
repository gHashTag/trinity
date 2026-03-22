# UART Echo Constraints for QMTech XC7A100T FGG676C
# Board: QMTech XC7A100T-1FGG676C
# J2 Connector pins: M22(clk), K20(RX), L20(TX), T23(LED)

# Clock — 50 MHz system clock on M22
set_property -dict {PACKAGE_PIN M22 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 20.000 -name sys_clk [get_ports clk]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_IBUF]

# UART TX (FPGA → ESP32/Mac) - L20 on J2 connector
set_property -dict {PACKAGE_PIN L20 IOSTANDARD LVCMOS33} [get_ports uart_tx]

# UART RX (ESP32/Mac → FPGA) - K20 on J2 connector
set_property -dict {PACKAGE_PIN K20 IOSTANDARD LVCMOS33} [get_ports uart_rx]

# Activity LED - T23 on J2 connector
set_property -dict {PACKAGE_PIN T23 IOSTANDARD LVCMOS33} [get_ports led]

# Bitstream configuration
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
