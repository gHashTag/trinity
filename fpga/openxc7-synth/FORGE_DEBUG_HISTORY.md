# FORGE OF KOSCHEI — Debug History

## Target: quantum_blinker_top on QMTECH XC7A100T-1FGG676C
## Design: 26-bit counter, LED = ~(counter[22] ^ trit_sign), active-low

---

## PROVEN FACTS

### Board & Toolchain
- **Board**: QMTECH Artix-7 XC7A100T-1FGG676C Core Board
- **Clock**: U22 = 50 MHz (LiteX pinout, confirmed working)
- **LED D6**: T23 (active-low, confirmed working)
- **Programmer**: Platform Cable USB II, IDCODE 0x13631093
- **fasm2bit**: 100% correct — reference FASM → fasm2bit → bitstream is BIT-IDENTICAL to golden reference (0 bytes differ after sync word)
- **Reference FASM**: `blinker_t23.fasm` (635 features) — CONFIRMED BLINKING on real hardware

### Pin Mapping (CONFIRMED)
| Signal | Package Pin | Tile | IOB Y | Source |
|--------|------------|------|-------|--------|
| clk | U22 | LIOB33_X0Y25 | IOB_Y0 | trinity.xdc (LiteX) |
| led | T23 | LIOB33_X0Y51 | IOB_Y0 | trinity.xdc (LiteX) |

### XDC Files
| File | Clock | LED | Status |
|------|-------|-----|--------|
| `trinity.xdc` | U22 | T23 | **CORRECT** — matches reference |
| `qmtech_fgg676.xdc` | M22 | J19 | **WRONG** — different board revision |
| `qmtech_xc7a100t.xdc` | M22 | J19 | **WRONG** — Vivado version |

---

## VERSION HISTORY

### v13-v16: All LEDs glow, D6 does NOT blink
- **Symptom**: FPGA configures OK, D1/D4/D5 glow, D6 glows steady (no blink)
- **XDC used**: `qmtech_fgg676.xdc` (WRONG — M22/J19 pins)
- **Root causes found**:
  1. Wrong XDC file (M22/J19 instead of U22/T23)
  2. 20 IMUX conflicts (duplicate PIPs targeting same IMUX pin)
  3. Various FASM generation bugs (fixes #1-#11)

### v17: Same as v16 (deconflict not applied)
- **Symptom**: Identical to v16
- **Root cause**: `zig build forge` runs binary from cache; debug prints went to stderr but `deconflictInfraImux()` WAS being called, output just not visible in terminal
- **Fix**: Run binary directly from `.zig-cache/o/*/forge` to see stderr

### v18: D6 completely OFF (worse than before)
- **Symptom**: D1/D4/D5 glow, D6 completely dark
- **XDC used**: `trinity.xdc` (CORRECT — U22/T23)
- **Deconflict**: Working — removed 21 conflicting PIPs
- **IO features**: 100% match with reference (16/16 features identical)
- **Clock distribution**: 100% match with reference (44/44 features identical)
- **BUFG slot**: BUFGCTRL_X0Y15 — same as reference
- **Analysis**: D6 OFF means output=1 (active-low), which means counter=0 (clock not reaching FFs), or routing broken
- **Bit-level comparison**: 1424 bit differences in 34 frames (out of 51840 frames)
- **Status**: FAILED — routing differences prevent counter from working

### Reference via fasm2bit: D6 BLINKS!
- **File**: `/tmp/blinker_reference_via_forge.bit`
- **Method**: Reference FASM → FORGE fasm2bit → bitstream
- **Result**: D6 blinks at ~3 Hz — CONFIRMED WORKING
- **Conclusion**: fasm2bit is 100% correct, problem is in FORGE's FASM generation

### v19: Diagonal routing + priority dedup + OBUF dest fix
- **Fixes applied**: #14 (dedup PIPs), #15 (priority dedup), #16 (diagonal SW6 routing), #17 (OBUF INT Y+1)
- **LED output path**: 100% MATCHES REFERENCE (3/3 PIPs identical)
  - `INT_L_X2Y55.SW6BEG1.LOGIC_OUTS_L19`
  - `INT_L_X0Y51.NL1BEG1.SW6END1`
  - `INT_L_X0Y52.IMUX_L34.NL1END1`
- **FASM duplicates**: 0 (all eliminated)
- **Dedup**: 19 conflicting PIPs removed (signals win over infra)
- **IO features**: 100% match reference
- **Clock distribution**: 100% match reference
- **Bit-level comparison**: 1570 bit diffs in 29 frames (807 ref-only, 763 v19-only)
- **Remaining diffs**: CLB routing strategy (FFMUX, OUTMUX), infrastructure tieoffs
- **Status**: READY TO TEST

---

## FIXES APPLIED (Cumulative)

### Fix #1-#11: FASM Generation Bugs
- LUT INIT encoding (individual bits format)
- CARRY4 CY0 features
- FFSYNC feature
- FF ZINI/ZRST features
- NOCLKINV feature
- CLB infrastructure routing (VCC_WIRE tieoffs, GFAN0 ties)
- Clock distribution (HCLK_CMT, CLK_HROW, HCLK_R, CLK_BUFG_REBUF)
- IO interconnect (LIOI3 features)
- CARRY4 feedback routes (__carry_feedback__ net)

### Fix #12: IMUX Deconfliction (router.zig:1018)
- **Problem**: 20 duplicate IMUX PIPs across Y63-Y69 tiles
- **Types**: VCC_WIRE vs signal, signal vs carry feedback, duplicate feedback
- **Fix**: Rewrote `deconflictInfraImux()` with 3-phase priority system:
  - Phase 1: Collect carry feedback IMUX claims (highest priority)
  - Phase 2: Collect signal net IMUX claims (medium priority)
  - Phase 3: Remove conflicting PIPs (infra loses to all; signal loses to feedback)
- **Result**: 21 conflicting PIPs removed, 0 IMUX conflicts remaining

### Fix #13: Wrong XDC File
- **Problem**: Used `qmtech_fgg676.xdc` (M22/J19) instead of `trinity.xdc` (U22/T23)
- **Fix**: Switch to `trinity.xdc` for all FORGE runs
- **Result**: IO and clock features now 100% match reference

### Fix #14: Global Routing PIP Deduplication (router.zig)
- **Problem**: Multiple nets generating PIPs with same (tile, wire_to) → ORed config bits
- **Fix**: Added `deduplicateRoutingPips()` after all routing completes
- **Result**: 20 duplicate PIPs removed, 0 MUX conflicts in FASM output

### Fix #15: Priority-Based Dedup (router.zig)
- **Problem**: Dedup removed signal net PIPs when infra had claimed the resource first
- **Fix**: Two-pass dedup — signal nets claim first (pass 1), infra keeps unclaimed only (pass 2)
- **Result**: LED output route no longer removed by infra tieoffs

### Fix #16: Diagonal Routing (SW6/NE6) for Cross-Column Routes (router.zig)
- **Problem**: L-shaped routes used vertical+horizontal hops, conflicting with carry chain at shared tiles
- **Fix**: Added `emitDiagonalRoute()` using SW6BEG/SW6END for south-west, NL1BEG bridge to IMUX
- **Result**: LED output path now 100% matches reference (SW6BEG1 → NL1BEG1 → IMUX_L34)

### Fix #17: OBUF Destination Tile Adjustment (router.zig)
- **Problem**: Signal routing targeted OBUF's IOB tile (Y=51) instead of INT tile (Y=52)
- **Fix**: When sink is OBUF, route to (tile_x, tile_y+1) with IMUX_L34 as destination
- **Result**: Signal correctly reaches IOI_IMUX34_1 which feeds OLOGIC0_D1

### Fix #18: FASM Deduplication (fasm_gen.zig)
- **Problem**: CLB features emitted twice from different generators (LUT + CARRY4)
- **Fix**: Added string dedup in `writeFasm()` using hash set
- **Result**: 0 duplicate FASM features in output

---

## REMAINING ISSUES (v19)

### Issue A: Different CLB Routing Strategy (may be OK)
- **Reference**: Uses mix of `FFMUX.AX/BX/CX/DX` (bypass) and `FFMUX.XOR` (carry)
- **FORGE v18**: Uses `FFMUX.XOR` for ALL 26 FFs
- **Note**: `FFMUX.XOR` IS architecturally valid for counter — XOR output = sum bit
- **Impact**: Unknown — may or may not be causing failure

### Issue B: 4 Duplicate FASM Features
```
[2x] CLBLL_L_X2Y55.SLICEL_X1.NOCLKINV       (harmless — idempotent)
[2x] INT_L_X2Y55.NN6BEG2.LOGIC_OUTS_L16      (DANGEROUS — MUX conflict)
[2x] INT_L_X2Y55.SL1BEG0.SS6END0             (DANGEROUS — MUX conflict)
[2x] INT_L_X2Y63.NL1BEG1.NN6END2             (DANGEROUS — MUX conflict)
```
- Routing MUX duplicates can OR config bits → illegal mux state
- All in critical tiles: Y55 (output LUT), Y63 (first CARRY4)

### Issue C: Missing OUTMUX Features
- Reference has `AOUTMUX.XOR`, `BOUTMUX.XOR`, `COUTMUX.XOR`, `DOUTMUX.XOR`
  for carry positions that feed routing to other tiles
- V18 has fewer OUTMUX features — may cause carry chain outputs to not reach next tile

### Issue D: Reference Uses X1 Slice FFs
- Reference places some FFs in X1 slice (with `FFMUX.BX/CX/DX` bypass)
- V18 places ALL 26 FFs in X0 slice only
- This is a placer decision, not necessarily wrong

### Issue E: 1424 Bit Differences
- 696 bits set in ref but not v18 (missing)
- 728 bits set in v18 but not ref (extra)
- All in INT_L tiles (interconnect routing)
- 34 frames affected out of 51840

---

## PPIPS (No Config Bits — Can Ignore)

These features appear in FASM but have NO config bits in the bitstream:
- `CLBLL_LL_*` (CLB site routing: CLBLL_LL_A1, CLBLL_LL_B2, etc.)
- `CLBLL_LOGIC_OUTS*` (CLB output routing)
- `CLBLL_L_CLK.CLBLL_CLK0` (CLB clock routing)
- `CLBLL_L_CE.CLBLL_FAN6` (CLB CE routing)
- `CLBLL_L_SR.CLBLL_CTRL0` (CLB SR routing)
- `CLBLL_L_AX.CLBLL_BYP*` (CLB bypass routing)
- `CLBLL_LL_COUT_N.CLBLL_LL_COUT` (CARRY4 chain output)
- `INT_R.GCLK_B0_WEST.GCLK_B0` (always ppip)
- `INT_R.IMUX*.VCC_WIRE` (default ppip for BUFG site)
- `FAN_ALT*.VCC_WIRE` / `FAN_L*.FAN_ALT*` (fanout ppips)
- `BYP_L*.BYP_ALT*` (bypass ppips)

---

## KEY FILES

| File | Description |
|------|-------------|
| `fpga/openxc7-synth/quantum_blinker.v` | Verilog source |
| `fpga/openxc7-synth/quantum_blinker.json` | Yosys JSON netlist (234K lines, 433 modules) |
| `fpga/openxc7-synth/trinity.xdc` | CORRECT XDC (U22/T23) |
| `fpga/openxc7-synth/blinker_t23.fasm` | GOLDEN REFERENCE FASM (635 features, CONFIRMED WORKING) |
| `src/forge/router.zig` | Routing engine (~1125 lines) |
| `src/forge/fasm_gen.zig` | FASM generation |
| `src/forge/placer.zig` | Placement engine |
| `src/forge/tech_map.zig` | Technology mapping |
| `src/forge/segbits.zig` | Segbits database lookup |
| `src/forge/segbits_data.zig` | Compiled prjxray segbits |
| `/tmp/quantum_blinker_v18.fasm` | Latest FORGE output (1374 features, FAILED) |
| `/tmp/quantum_blinker_v18.bit` | Latest FORGE bitstream (FAILED) |
| `/tmp/blinker_reference_via_forge.bit` | Reference via fasm2bit (CONFIRMED WORKING) |

---

## FORGE RUN COMMAND (CORRECT)

```bash
zig build forge -- run \
    --input /Users/playra/trinity-w1/fpga/openxc7-synth/quantum_blinker.json \
    --device xc7a100t \
    --constraints /Users/playra/trinity-w1/fpga/openxc7-synth/trinity.xdc \
    --output /tmp/quantum_blinker_vNN.bit \
    --fasm /tmp/quantum_blinker_vNN.fasm 2>&1
```

## FLASH COMMAND

```bash
bash fpga/tools/flash.sh /tmp/quantum_blinker_vNN.bit
```

## REFERENCE FASM2BIT COMMAND (for board testing)

```bash
zig build forge -- fasm2bit \
    --input /Users/playra/trinity-w1/fpga/openxc7-synth/blinker_t23.fasm \
    --device xc7a100t \
    --output /tmp/blinker_reference_via_forge.bit
```

---

## NEXT STEPS

1. Fix duplicate routing PIPs (Issue B) — most likely cause of failure
2. Verify OUTMUX features are correct (Issue C)
3. Consider: should we match reference routing strategy exactly?
   - Option A: Fix FORGE router to produce valid alternative routing
   - Option B: Match reference FASM exactly (would prove correctness but limit flexibility)
4. After fixing, compare bit-level differences again (target: 0 critical diffs)
5. Flash and test

---

## LESSONS LEARNED

1. **Always use absolute paths** with `zig build forge --` (runs from cache dir)
2. **`zig build forge`** = build + RUN (not just build). Use `-- args` to pass args
3. **std.debug.print** goes to stderr; grep stdout won't catch it
4. **XDC pin mapping is board-specific** — LiteX vs Vivado have different pins for same board
5. **fasm2bit verification**: Convert reference FASM through our fasm2bit, flash it, verify it works. If it blinks, our bitstream assembly is correct.
6. **IMUX conflicts**: Multiple PIPs targeting same IMUX pin = ORed config bits = broken mux
7. **ppips have no config bits** — differences in ppip features are irrelevant to bitstream
8. **Port names**: Yosys renames top-level ports to IBUF/OBUF pin names in some cases. FORGE's tech_map renames them back using port declarations from the actual module.
9. **Duplicate PIPs** are as dangerous as IMUX conflicts — any MUX-based routing resource with duplicate features will have ORed config bits
