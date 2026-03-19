# ═════════════════════════════════════════════════════════════════════════════
# SACRED ALU — XDC Constraints for XC7A100T (Artix-7)
# ═════════════════════════════════════════════════════════════════════════════
#
# Trinity Sacred Formats on FPGA Level 6 (RTL)
#
# GF16 (Golden Float 16): exp:mant = 6:9 = 0.667, φ-distance = 0.049
# TF3-9 (Ternary Float 9): exp:mant = 3:5 = 0.6, φ-distance = 0.018
#
# φ² + 1/φ² = 3 = TRINITY
# ═════════════════════════════════════════════════════════════════════════════

# =============================================================================
# PRIMARY CLOCK — 100 MHz target for XC7A100T (Artix-7)
# =============================================================================

set_property -dict DONT_TOUCH true [get_nets -hierarchical -filter {name =~ "*clk*"}]

# Clock period = 10ns (100 MHz) — target for XC7A100T
create_clock -period 10.000 -waveform {0.000 5.000} [get_ports clk*]

# =============================================================================
# I/O STANDARD — LVDS for differential if needed, default LVCMOS33
# =============================================================================

set_property IOSTANDARD LVCMOS33 [get_ports -filter {direction == out}]

# =============================================================================
# PLACEMENT FLOORS — No placement constraints (let router optimize)
# =============================================================================

# No specific placement needed — let auto-place optimize for best routing

# ═════════════════════════════════════════════════════════════════════════════
# END OF CONSTRAINTS
# ═════════════════════════════════════════════════════════════════════════════
