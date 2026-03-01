# =====================================================================
# QMTECH Artix-7 XC7A100T-1FGG676C Core Board — Trinity FPGA
# Clock: 50 MHz onboard crystal
# LED: J19 (active-low, accent LED D5)
# Button: H19 (active-low, user key SW1)
# =====================================================================

# =====================================================================
# CLOCK — 50 MHz system clock (M22 = IO_L15N_T2_DQS_MRCC)
# Note: M22 is N-side of MRCC pair. Needs CLOCK_DEDICATED_ROUTE FALSE.
# =====================================================================
set_property -dict {PACKAGE_PIN M22 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 20.000 -name sys_clk [get_ports clk]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_IBUF]

# =====================================================================
# LED — Active-low user LED D5
# =====================================================================
set_property -dict {PACKAGE_PIN J19 IOSTANDARD LVCMOS33} [get_ports led]

# =====================================================================
# ACTIVE SIGNALS (directly mapped, active-low button)
# =====================================================================
set_property -dict {PACKAGE_PIN H19 IOSTANDARD LVCMOS33} [get_ports rst_n]

# =====================================================================
# BITSTREAM CONFIG
# =====================================================================
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
