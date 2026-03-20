# ═════════════════════════════════════════════════════════════════════════════
# SACRED ALU TOP — XDC Constraints for QMTECH XC7A100T-1FGG676C
# ═════════════════════════════════════════════════════════════════════════════
#
# Clock: U22 (50 MHz onboard crystal)
# LED: T23 (active-low, D5 on board)
#
# φ² + 1/φ² = 3 | TRINITY
# ═════════════════════════════════════════════════════════════════════════════

# =============================================================================
# CLOCK — 50 MHz system clock (U22)
# =============================================================================
set_property -dict {PACKAGE_PIN U22 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 20.000 -name sys_clk [get_ports clk]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_IBUF]

# =============================================================================
# LED — Active-low user LED D5 (T23)
# =============================================================================
set_property -dict {PACKAGE_PIN T23 IOSTANDARD LVCMOS33} [get_ports led]

# =============================================================================
# BITSTREAM CONFIG
# =============================================================================
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
