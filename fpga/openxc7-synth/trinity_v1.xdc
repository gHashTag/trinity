# VSA VSA TOP — Pin Constraints for QMTECH XC7A100T FGG676
# Day 3: VSA operations via UART

# Clock: 50 MHz oscillator
set_property PACKAGE_PIN U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# UART: FTDI USB-UART adapter
set_property PACKAGE_PIN H16 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]

set_property PACKAGE_PIN J16 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

# LED: Status indicator (T23 = D6)
set_property PACKAGE_PIN T23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]

# Reset: Active high (optional - tie to GND for normal operation)
set_property PACKAGE_PIN P16 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports rst]
