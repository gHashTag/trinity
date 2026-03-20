# Phi-Rhythm LED Blink Constraints
# Target: XC7A100T-FTG256 (Artix-7 on DLC10 clone)

# Clock: 50 MHz oscillator
set_property -dict {PACKAGE_PIN U22 IOSTANDARD LVCMOS33} [get_ports clk]

# LED: Active-low LED
set_property -dict {PACKAGE_PIN T23 IOSTANDARD LVCMOS33} [get_ports led]

# Bitstream configuration
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
