# VSA Bind 16 Constraints
# QMTECH XC7A100T-1FGG676C
# Using T23 (D5) for LED due to nextpnr R23 bug

# Clock: 50 MHz oscillator
set_property LOC U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# Reset: Button (active high) - use GPIO pin if available
# For testing without button, tie rst to GND in design

# LED: Status indicator (D5 - T23)
set_property LOC T23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]

# Debug outputs (optional) - GPIO pins
# Uncomment if you want to use debug outputs
# set_property LOC <pin> [get_ports debug[0]]
# set_property LOC <pin> [get_ports debug[1]]
# set_property LOC <pin> [get_ports debug[2]]
# set_property LOC <pin> [get_ports debug[3]]
