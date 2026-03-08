# FPGA Hardware Debug Summary

## Test Results

| Test | Config | Result | APL Range | Conclusion |
|------|--------|--------|-----------|------------|
| **Static 1** | t23=1, r23=0 | LED ON | 157-161 | **ACTIVE-HIGH confirmed** |
| **Static 2** | t23=0, r23=1 | LED ON | ~same | **ACTIVE-HIGH confirmed** |
| **blink_minimal** | Clock divider | SOLID (OFF) | 127-139 | **Clock not running** |
| **blink_working** | BUFG + counter | SOLID (OFF) | ~same | **Clock not running** |
| **blink_ring_osc** | Ring oscillator | SOLID (OFF) | 74-81 | **Counter stuck at 0** |

## Key Findings

1. **LEDs are ACTIVE-HIGH** (HARDWARE_REFERENCE.md is WRONG)
   - T23 (D6/Right LED): ON when logical 1
   - R23 (D5/Left LED): ON when logical 1

2. **Clock on U22 is NOT working**
   - All clock-based designs fail
   - Counter stays at initial value (0)
   - LEDs stay OFF (since active-high)

3. **Possible causes**:
   - U22 is NOT the 50MHz oscillator pin
   - Oscillator requires external enable
   - Oscillator is not populated on this board
   - Clock buffer not properly inferred

## Next Steps

1. **Verify clock pin** - Check QMTECH schematic for actual oscillator pin
2. **Try different clock source** - Use external signal or different pin
3. **Use internal PLL** - Generate clock from internal reference

## Evidence

Static test frames:
- led_static_frame.jpg: t23=1,r23=0 shows Left LED ON, Right LED OFF
- led_inverse_frame.jpg: t23=0,r23=1 shows Left LED OFF, Right LED ON

This proves:
- R23 controls Left LED (D5)
- T23 controls Right LED (D6)
- Both are ACTIVE-HIGH
