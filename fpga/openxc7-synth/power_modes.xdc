# =============================================================================
# POWER MODES — XDC Constraints for QMTECH XC7A100T-1FGG676C
# =============================================================================
# Target: Artix-7 XC7A100T-1FGG676C on QMTECH board
# Module: power_modes.v
# φ² + 1/φ² = 3 = TRINITY
# =============================================================================

# Clock (50 MHz oscillator)
set_property PACKAGE_PIN U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# LED D6 (active-low, T23)
set_property PACKAGE_PIN T23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]

# Debug LEDs [0] and [1] — active-low
set_property PACKAGE_PIN N23 [get_ports {debug_leds[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {debug_leds[0]}]
set_property PACKAGE_PIN M22 [get_ports {debug_leds[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {debug_leds[1]}]

# UART TX (to host)
set_property PACKAGE_PIN K20 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

# DIP switch sw[0] and sw[1]
# QMTECH board: SW1 pin 1 → K21, SW1 pin 2 → J21
set_property PACKAGE_PIN K21 [get_ports {sw[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[0]}]
set_property PULLDOWN true [get_ports {sw[0]}]
set_property PACKAGE_PIN J21 [get_ports {sw[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[1]}]
set_property PULLDOWN true [get_ports {sw[1]}]

# Button (for mode-4 auto-cycle toggle)
# QMTECH on-board user button → P23
set_property PACKAGE_PIN P23 [get_ports btn]
set_property IOSTANDARD LVCMOS33 [get_ports btn]
set_property PULLDOWN true [get_ports btn]

# Timing constraint
create_clock -period 20.000 -name clk [get_ports clk]
