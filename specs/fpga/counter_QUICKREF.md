# Counter Enhancement Quick Reference
**Spec:** specs/fpga/counter.tri
**Status:** ✅ VALIDATED AND ENHANCED

---

## What Changed

### Before (counter.vibee)
```yaml
signals:
  - clk (input)
  - led0 (output)  # Only 2 LEDs!
  - led1 (output)

constraints:
  - clk → U22
  - led0 → R23
  - led1 → T23
  # Missing led2, led3!
```

### After (counter.tri)
```yaml
signals:
  - clk (input)
  - led0 (output)  # Now all 4 LEDs!
  - led1 (output)
  - led2 (output)  # NEW
  - led3 (output)  # NEW

constants:
  - PHI = 1.618...      # NEW
  - TRINITY = 3.0       # NEW
  - TIMER_BITS = 26     # NEW
  - COUNT_BITS = 4      # NEW

constraints:
  - clk → U22
  - led0 → R23
  - led1 → T23
  - led2 → R24    # NEW
  - led3 → P24    # NEW

test_cases: 5 comprehensive scenarios  # NEW
```

---

## Pin Map (QMTECH XC7A100T FGG676)

| Port | Pin | LED | Bit |
|------|-----|-----|-----|
| clk | U22 | - | - |
| led0 | R23 | D6 | 0 (LSB) |
| led1 | T23 | D5 | 1 |
| led2 | R24 | D4 | 2 |
| led3 | P24 | D3 | 3 (MSB) |

---

## Quick Commands

### Generate Verilog from Spec
```bash
zig build vibee -- gen specs/fpga/counter.tri
# Output: trinity/output/fpga/counter.v
```

### Synthesize with Yosys
```bash
cd fpga/openxc7-synth
yosys -p "synth_xilinx -flatten -abc9 -arch xc7 -top counter; \
          write_json counter.json" counter.v
```

### Full Synth Pipeline
```bash
cd fpga/openxc7-synth
./synth.sh counter.v counter
```

---

## Validation Checklist

- [x] 4 LED signals defined (was 2)
- [x] Pin constraints complete
- [x] Sacred constants added
- [x] Protocol import documented
- [x] Test cases comprehensive
- [x] XDC file updated
- [ ] Reference Verilog updated (TODO)
- [ ] Synthesis tested (TODO)

---

## Files

| File | Status |
|------|--------|
| `specs/fpga/counter.tri` | ✅ Created (enhanced) |
| `specs/fpga/counter.vibee` | ⚠️ Original (2 LEDs only) |
| `specs/fpga/COUNTER_VALIDATION_REPORT.md` | ✅ Created |
| `specs/fpga/COUNTER_ENHANCEMENT_SUMMARY.md` | ✅ Created |
| `fpga/openxc7-synth/counter.xdc` | ✅ Updated (4 LEDs) |
| `fpga/openxc7-synth/counter.v` | ⚠️ Needs update (2 LEDs only) |

---

**φ² + 1/φ² = 3**
