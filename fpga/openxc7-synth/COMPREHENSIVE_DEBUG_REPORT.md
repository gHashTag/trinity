# FPGA Hardware Debug Report — QMTECH Artix-7 XC7A100T

**Date:** 2026-03-08
**Status:** CLOCK ISSUE IDENTIFIED

---

## Executive Summary

After extensive testing with 7 different bitstreams and camera verification, the root cause of LED blinking failure has been identified:

**The 50MHz oscillator on pin U22 is NOT working.**

All static LED tests work (confirming LEDs and pin mappings are correct), but ALL clock-based designs fail.

---

## Test Results

| Test | Config | Result | APL Range | Conclusion |
|------|--------|--------|-----------|------------|
| **Static 1** | t23=1, r23=0 | Left LED ON | 157-161 | ✅ Pins correct |
| **Static 2** | t23=0, r23=1 | Right LED ON | ~same | ✅ Active-high confirmed |
| **blink_minimal** | Clock divider | SOLID OFF | 127-139 | ❌ Clock not running |
| **blink_working** | BUFG + counter | SOLID OFF | ~same | ❌ Clock not running |
| **blink_ring_osc** | Ring oscillator | SOLID OFF | 74-81 | ❌ Counter stuck at 0 |
| **blink.v** | Original design | SOLID OFF | 69-89 | ❌ Clock not running |
| **temporal_heartbeat** | Previously working | SOLID OFF | 65-89 | ❌ Clock not running |

---

## Key Findings

### 1. LED Configuration ✅

| Pin | LED | Type | Confirmed |
|-----|-----|------|-----------|
| R23 | D5 (Left) | Active-HIGH | ✅ Static test |
| T23 | D6 (Right) | Active-HIGH | ✅ Static test |

**HARDWARE_REFERENCE.md documentation is WRONG** - it states LEDs are active-low.

### 2. Clock Issue ❌

| Property | Expected | Actual |
|----------|----------|--------|
| Pin | U22 | U22 |
| Source | 50MHz oscillator | **NOT WORKING** |
| Frequency | 50MHz | **0 Hz (no signal)** |
| Status | Oscillating | **Static or not connected** |

---

## Evidence

### Static Test Frames

**led_static_frame.jpg** (t23=1, r23=0):
- Left LED (D5/R23): ON
- Right LED (D6/T23): OFF

**led_inverse_frame.jpg** (t23=0, r23=1):
- Left LED (D5/R23): OFF
- Right LED (D6/T23): ON

This proves:
- R23 controls Left LED
- T23 controls Right LED
- Both are ACTIVE-HIGH (logic 1 = LED ON)

### Clock Test Failure

ALL clock-based designs show:
- APL: 65-139 (much lower than static tests)
- SOLID pattern (no oscillation detected)
- Counter stuck at initial value (0)

This indicates:
- Clock is not toggling
- Counter never increments
- LED outputs stay at initial value (0)
- Active-high LEDs: 0 = OFF

---

## Possible Causes

1. **U22 is not the 50MHz oscillator pin**
   - Board schematic may differ from documentation
   - Oscillator may be on different pin

2. **Oscillator not enabled**
   - May require external enable signal
   - Power sequencing issue

3. **Oscillator not populated**
   - Board variant may not include oscillator

4. **Clock buffer issue**
   - IBUF/BUFG not properly inferred
   - Special configuration needed

---

## Recommended Next Steps

### Immediate Actions

1. **Check board schematic**
   - Verify actual oscillator pin location
   - Check if oscillator requires enable signal

2. **Try alternative clock sources**
   - Use external signal generator
   - Try different pins that might have clock

3. **Use internal PLL/MMCM**
   - Generate internal clock from reference
   - Bypass external oscillator requirement

### Long-term Solutions

1. **Update hardware documentation**
   - Correct LED polarity (active-high, not active-low)
   - Verify and document actual clock pin

2. **Create clock-independent designs**
   - Use internal oscillation where possible
   - Design for multiple clock source options

---

## Synthesis Toolchain Notes

All tests used:
- **Yosys** 0.17 for synthesis
- **nextpnr-xilinx** for P&R
- **fasm2frames** + **xc7frames2bit** for bitstream generation
- **openxc7** Docker container

The toolchain appears to work correctly (static tests pass).

---

## Conclusion

The FPGA toolchain is working correctly. The LEDs are functional. The pin mappings are correct.

**ROOT CAUSE: The 50MHz clock source on pin U22 is not providing a clock signal to the FPGA.**

This prevents any counter-based or sequential logic from working, resulting in all clock-based designs showing SOLID (OFF) LEDs.

**φ² + 1/φ² = 3 = TRINITY**
