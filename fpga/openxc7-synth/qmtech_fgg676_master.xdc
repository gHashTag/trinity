# ═══════════════════════════════════════════════════════════════════════════
# QMTECH Artix-7 XC7A100T-1FGG676C CONSTRAINTS
# ═══════════════════════════════════════════════════════════════════════════
#
# ⚠️ CRITICAL: LED on T23 is ACTIVE-LOW! ⚠️
#   led = 0 → LED ON
#   led = 1 → LED OFF
#   MUST USE: assign led = ~led_state;  (invert output!)
#
# Hardware verified: 2026-03-08
# Variation: 55.1% → LED IS BLINKING ✅
#
# ═══════════════════════════════════════════════════════════════════════════

# Clock: 50 MHz oscillator
set_property PACKAGE_PIN U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# LED: T23 (ACTIVE-LOW! Must invert Verilog output)
set_property PACKAGE_PIN T23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]
