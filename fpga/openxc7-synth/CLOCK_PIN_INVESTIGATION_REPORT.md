# Clock Pin Investigation Report

**Date:** 2026-03-08
**Status:** CLOCK SOURCE NOT IDENTIFIED

---

## Summary

After testing **three different clock pins** (U22, M22, M21), **NONE provide a working clock signal**.

All tests use the same design with only the clock pin changed.

---

## Test Results

| Clock Pin | Source | Result | APL Range | Conclusion |
|-----------|--------|--------|-----------|------------|
| **U22** | Core board spec | SOLID OFF | 65-89 | No clock signal |
| **M22** | Wukong V1/V2 N-side | SOLID OFF | 68-70 | No clock signal |
| **M21** | Wukong V3 P-side | SOLID OFF | 61-79 | No clock signal |

**All show identical behavior:**
- Counter stuck at 0
- LED output stuck at 0
- Active-high LED: 0 = OFF → SOLID OFF state

---

## Key Findings

### 1. LEDs Work Correctly ✅

Static tests confirmed:
- T23 (D6/Right) = ACTIVE-HIGH
- R23 (D5/Left) = ACTIVE-HIGH
- Logic 1 = LED ON, Logic 0 = LED OFF

### 2. Clock Does NOT Reach Counter ❌

All clock-based designs fail regardless of pin used.

### 3. Possible Causes

1. **Wrong board identification**
   - May not be QMTECH Wukong board
   - Could be different variant
   - Oscillator may be on different pin

2. **Oscillator not enabled**
   - May require external enable signal
   - Power sequencing issue

3. **Oscillator not populated**
   - Board variant without 50MHz oscillator
   - Would need external clock source

4. **Dedicated clock routing issue**
   - M22 (N-side) requires CLOCK_DEDICATED_ROUTE FALSE
   - nextpnr-xilinx doesn't support this constraint
   - May need Vivado toolchain

---

## Recommended Next Steps

### Option 1: Identify Board Variant

Check board markings:
```
QMTech / XC7A100T / ???
Wukong V1 / V2 / V3 / ???
Core Board (not Wukong)
```

### Option 2: Try Ethernet PHY Clock

Use 125MHz clock from RTL8211EG (if populated):

```verilog
MMCME2_BASE #(
    .CLKFBOUT_MULT_F(8.0),    // 125 * 8 = 1000 MHz VCO
    .CLKOUT0_DIVIDE_F(20.0),  // 1000 / 20 = 50 MHz
    .CLKIN1_PERIOD(8.0)        // 125 MHz = 8ns
) mmcm_inst (
    .CLKIN1(eth_clk_125m),    // Input from Ethernet PHY
    .CLKOUT0(clk_50m),         // Output 50MHz
    ...
);
```

### Option 3: Use External Clock

Provide clock from:
- Function generator
- Another FPGA board
- Arduino with clock output

### Option 4: Try Vivado Toolchain

Vivado supports CLOCK_DEDICATED_ROUTE FALSE for N-side pins.

---

## Files Created

- `blink_fixed.v` - Design with explicit BUFG
- `blink_fixed.xdc` - XDC with M21 clock pin
- `HARDWARE_DEBUG_SUMMARY.md` - Static test results
- `COMPREHENSIVE_DEBUG_REPORT.md` - Full analysis
- `CLOCK_PIN_INVESTIGATION_REPORT.md` - This file

---

## Conclusion

**Root cause NOT yet identified.**

The clock oscillator is not providing a signal on any of the expected pins (U22, M22, M21).

**RECOMMENDATION:** Check physical board markings and identify actual board variant before proceeding.

**φ² + 1/φ² = 3 = TRINITY**
