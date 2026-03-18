# ═══════════════════════════════════════════════════════════════════════════════
# COUNTER — Pin Constraints for QMTECH XC7A100T-1FGG676C
# ═══════════════════════════════════════════════════════════════════════════════
#
# Generated from: specs/fpga/counter.tri
# Target:         QMTECH Artix-7 XC7A100T-1FGG676C
# Frequency:      50 MHz
#
# Pin Map:
#   U22 = 50 MHz oscillator
#   R23 = LED D6 (PRIMARY)
#   T23 = LED D5
#   R24 = LED D4
#   P24 = LED D3
#
# φ² + 1/φ² = 3 = TRINITY
# ═══════════════════════════════════════════════════════════════════════════════

# Clock input (50 MHz oscillator)
set_property PACKAGE_PIN U22 [get_ports {clk}]
set_property IOSTANDARD LVCMOS33 [get_ports {clk}]

# LED outputs (active-low: 0 = ON, 1 = OFF)
# Bit 0 (LSB) - LED D6 PRIMARY
set_property PACKAGE_PIN R23 [get_ports {led0}]
set_property IOSTANDARD LVCMOS33 [get_ports {led0}]

# Bit 1 - LED D5
set_property PACKAGE_PIN T23 [get_ports {led1}]
set_property IOSTANDARD LVCMOS33 [get_ports {led1}]

# Bit 2 - LED D4
set_property PACKAGE_PIN R24 [get_ports {led2}]
set_property IOSTANDARD LVCMOS33 [get_ports {led2}]

# Bit 3 (MSB) - LED D3
set_property PACKAGE_PIN P24 [get_ports {led3}]
set_property IOSTANDARD LVCMOS33 [get_ports {led3}]

# ═══════════════════════════════════════════════════════════════════════════════
