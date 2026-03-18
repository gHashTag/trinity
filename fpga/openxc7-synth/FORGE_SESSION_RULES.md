# FORGE SESSION RULES — Lessons From v18-v23 Failures

## RULE 1: NEVER route CARRY4.O/CO -> FF.D through INT tiles
- CARRY4 outputs feed FFs via internal FFMUX.XOR path
- No INT tile PIP needed for same-tile CARRY4.O -> FF.D
- Routing through INT creates LOGIC_OUTS_L20 -> IMUX_L{4,12} PIPs
- These OVERRIDE VCC_WIRE tieoffs on I6 pins (IMUX_L{4,12,35,43})
- LUT truth tables depend on I6=VCC (upper 32 bits of INIT)
- **FIX**: Skip routing when src=CARRY4 pin=O/CO, dst pin=D, same tile

## RULE 2: NEVER route CARRY4.CO -> CARRY4.CI through INT tiles
- Carry chain uses dedicated COUT/CIN vertical path (ppip, no config bits)
- **FIX**: Skip routing when src=CARRY4 pin=CO, dst=CARRY4 pin=CI

## RULE 3: OBUF destination is INT tile at (tile_x, tile_y + 1)
- IOB_Y0 at Y=51 has its INT tile at Y=52
- Signal must reach INT tile, not IOB tile
- Use IMUX_L34 -> IOI_IMUX34_1 -> OLOGIC0_D1

## RULE 4: VCC IMUX pins are SACRED — never route signals through them
- Left tiles: IMUX_L{4,12,35,43} = A6/B6/C6/D6 VCC pins
- These must ALWAYS be VCC_WIRE (infrastructure tieoffs)
- findCompatibleImux() can accidentally select these
- Dedup removes infra VCC_WIRE when signal claims same IMUX

## RULE 5: ppips have NO config bits — ignore them
- CLBLL_LL_xx.CLBLL_IMUXnn features = ppips
- INT_R.GCLK_B0_WEST.GCLK_B0 = ppip
- FAN_ALT*.VCC_WIRE, BYP_L*.BYP_ALT* = ppips
- They appear in FASM but produce ZERO bitstream differences

## RULE 6: CARRY4 S inputs need carry feedback routing
- FF.Q -> LUT input (via IMUX_L{1,18,29,38})
- LUT computes O6 = f(input), O6 feeds CARRY4.S
- carry_fb_imux = {1, 18, 29, 38} — compatible with LOGIC_OUTS_L{4,5,6,7}

## RULE 7: Always verify with reference FASM before flashing
- Reference: fpga/openxc7-synth/blinker_t23.fasm (635 features, CONFIRMED WORKING)
- Compare: CARRY4 (35 features), Clock (44 features), IO (16 features)
- Check: No LOGIC_OUTS_L20 on VCC IMUX pins
- Check: No duplicate PIPs (same tile+wire_to, different wire_from)

## RULE 8: XDC = trinity.xdc (U22=clk, T23=led)
- NEVER use qmtech_fgg676.xdc or qmtech_xc7a100t.xdc (wrong pins)

## FAILURE HISTORY
| Version | Result | Root Cause |
|---------|--------|------------|
| v18 | D6 OFF | Wrong XDC + IMUX conflicts |
| v19 | Not tested | Diagonal routing + priority dedup |
| v22 | No blink | CARRY4.O->FF.D routed through INT, overriding VCC |
| v23 | No blink | Same fix applied but 1142 bit diffs remain |

## REMAINING SUSPECTS (v23 still fails)
1. LUT INIT truth tables differ from reference (biggest bit diff source)
2. FFMUX strategy: FORGE uses XOR everywhere, ref uses mix of XOR + AX/BX/CX/DX
3. OUTMUX features may be missing
4. Routing PIPs in INT tiles still differ (different routing strategy)
