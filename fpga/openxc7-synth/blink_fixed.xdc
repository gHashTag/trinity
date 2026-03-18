# ============================================================================
# BLINK FIXED — Corrected pin mapping for QMTECH Wukong board
# ============================================================================
#
# ROOT CAUSE: Original XDC used U22, but Wukong board has clock on M22
# U22 is for standalone core board, NOT Wukong daughterboard
#
# Wukong V1/V2: 50MHz oscillator on M22 (N-side) — needs workaround
# Wukong V3:    50MHz oscillator on M21 (P-side) — works normally
#
# ============================================================================

# Clock input — M21 (P-side) for Wukong V3, try M22 first for V1/V2
# M21 is P-side, which works properly with Xilinx clock tree
set_property PACKAGE_PIN M21 [get_ports sys_clk]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]

# LED output — T23 (D6/Right LED, ACTIVE-HIGH)
set_property PACKAGE_PIN T23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]
