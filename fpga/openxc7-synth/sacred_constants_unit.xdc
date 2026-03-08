# ============================================================================
# SACRED_CONSTANTS_UNIT — Pin Constraints for QMTECH Artix-7
# ============================================================================
#
# Target: QMTECH Artix-7 XC7A100T-1FGG676C
# Clock: 50MHz oscillator (correct pin TBD - investigation in progress)
#
# LEDs for status display:
#   T23 (D6/Right) = ACTIVE-HIGH
#   R23 (D5/Left) = ACTIVE-HIGH
#
# ============================================================================

# ============================================================================
# CLOCK INPUT
# ============================================================================
# NOTE: Clock pin currently under investigation
# The board appears to differ from documented specifications
# For now, using T23 as clock input for testing (can be changed)

#set_property PACKAGE_PIN M21 [get_ports clk]  # Wukong V3 (P-side)
#set_property PACKAGE_PIN M22 [get_ports clk]  # Wukong V1/V2 (N-side)
#set_property PACKAGE_PIN U22 [get_ports clk]  # Core board (NOT WORKING)

# Temporary: Use R23 as clock for testing (verify with oscilloscope)
set_property PACKAGE_PIN R23 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# ============================================================================
# STATUS LEDs
# ============================================================================
# T23 shows operation status (blink = active, solid = idle)

set_property PACKAGE_PIN T23 [get_ports status_led]
set_property IOSTANDARD LVCMOS33 [get_ports status_led]

# ============================================================================
# DATA INTERFACE (for testing, would use PMOD connectors)
# ============================================================================
# These can be connected to external logic analyzer or scope
# for verification of sacred constant computation

# PMOD A (JA connector)
#set_property PACKAGE_PIN AA14 [get_ports data_out_0]
#set_property IOSTANDARD LVCMOS33 [get_ports data_out_0]

# Add more pins as needed for full interface
