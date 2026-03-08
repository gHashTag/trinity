# Hardware Debug Report — QMTECH Artix-7 XC7A100T LED Issues

**Date:** 2026-03-08
**Board:** QMTECH Artix-7 XC7A100T-1FGG676C
**Issue:** LEDs not blinking on hardware despite successful bitstream generation

---

## Executive Summary

Multiple bitstreams were synthesized and flashed, but LEDs did not blink as expected. Analysis revealed:
1. **Pin confusion** between T23 and R23
2. **Inconsistent polarity handling** (active-high vs active-low)
3. **No definitive diagnostic** to identify which pin/polarity works

A `definitive_diagnostic.bit` has been created to systematically identify the correct configuration.

---

## Root Cause Analysis

### Issue 1: Pin Mismatch

| File | LED Pin | Notes |
|------|---------|-------|
| `blink.v` | R23 | Uses R23, not T23 |
| `led_diagnostic.v` | T23, R23 | Tests both pins |
| `d6_blink.v` | T23 | Specifically targets D6 LED |

**Problem:** Different test files target different pins without documentation of which LED corresponds to which pin on the QMTECH board.

### Issue 2: Polarity Inconsistency

| File | Inversion | Comment |
|------|-----------|---------|
| `blink.v` | `~counter[25]` | Assumes active-low |
| `led_diagnostic.v` | `counter[22]`, `counter[24]` | No inversion (active-high) |
| `d6_blink.v` | Various | Mixed polarity |

**Problem:** Without knowing whether the QMTECH LEDs are active-high or active-low, some designs invert when they shouldn't (or vice versa).

### Issue 3: Clock/Constraints Verification

All designs use:
- **Clock:** U22 (50 MHz oscillator) ✓
- **IO Standard:** LVCMOS33 ✓
- **Timing:** PASS (nextpnr reports >200 MHz)

The synthesis and P&R are working correctly. The issue is at the pin/polarity level.

---

## Solution: Definitive Diagnostic

A new diagnostic design has been created: `definitive_diagnostic.bit`

### Design Specifications

```verilog
module definitive_diagnostic_top (
    input  wire clk,    // 50 MHz on U22
    output wire t23,    // T23 (D6?) - FAST blink ~6 Hz
    output wire r23     // R23 (D5?) - SLOW blink ~1.5 Hz
);
```

**Blink Rates:**
- **T23:** `counter[22]` → 50MHz / 2^23 = **~5.96 Hz** (FAST)
- **R23:** `counter[24]` → 50MHz / 2^25 = **~1.49 Hz** (SLOW)

**Polarity:** Active-high (no inversion)

### Expected Behavior

| Observation | Interpretation |
|-------------|----------------|
| T23 blinks FAST, R23 blinks SLOW | Both pins work, LEDs are active-high |
| Both LEDs solid ON | LEDs are active-low (need inversion) |
| Both LEDs solid OFF | Wrong pins or no clock |
| Only T23 blinks | R23 pin incorrect or LED broken |
| Only R23 blinks | T23 pin incorrect or LED broken |

---

## Synthesis Results

```
✓ Yosys synthesis: PASSED
✓ nextpnr-xilinx: PASSED
  - Max frequency: 239.46 MHz (target: 50 MHz)
  - Timing slack: PASS
✓ fasm2frames: PASSED
✓ xc7frames2bit: PASSED
```

**Output:** `definitive_diagnostic.bit` (3.8 MB)

---

## Next Steps

### Step 1: Flash Diagnostic

```bash
# Load JTAG firmware (if not already loaded)
sudo fpga/tools/fxload -v -t fx2 -d 03fd:0013 -i fpga/tools/xusb_xp2.hex

# Replug cable, then flash
fpga/tools/jtag_program definitive_diagnostic.bit
```

### Step 2: Observe and Document

| What to Observe | How to Identify |
|-----------------|-----------------|
| Which LEDs blink? | D6 (top) vs D5 (below) |
| Blink rates? | Fast (~6/sec) vs Slow (~1.5/sec) |
| Solid states? | Always ON or always OFF |

### Step 3: Apply Fix

Once the correct pin and polarity are identified:

1. **If active-low needed:** Add inversion to diagnostic
2. **If wrong pin:** Update blink.v to use correct pin
3. **Create minimal_blink.v** with confirmed working configuration
4. **Flash and verify** with `tri fpga verify`

---

## Files Generated

| File | Purpose |
|------|---------|
| `definitive_diagnostic.v` | Source Verilog |
| `definitive_diagnostic.xdc` | Constraints |
| `definitive_diagnostic.json` | Yosys output |
| `definitive_diagnostic.fasm` | FPGA assembly |
| `definitive_diagnostic.frames` | Frame data |
| `definitive_diagnostic.bit` | **Bitstream to flash** |

---

## QMTECH Artix-7 LED Pin Reference (To Be Verified)

```
D6 LED (top)    → T23? (to be confirmed)
D5 LED (below)  → R23? (to be confirmed)
```

**Note:** The actual pin-to-LED mapping will be determined by flashing `definitive_diagnostic.bit` and observing which LEDs blink.

---

## Status

- [x] Root cause analysis complete
- [x] Definitive diagnostic synthesized
- [ ] **Flash to hardware** ← NEXT STEP
- [ ] Observe and document LED behavior
- [ ] Apply fix based on observations
- [ ] Create working minimal_blink.v
- [ ] Verify with `tri fpga verify`

---

**φ² + 1/φ² = 3 | TRINITY v2.2.0**
