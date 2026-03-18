# FPGA LED PIN MEMORY — DON'T FORGET!

## Board: QMTECH Artix-7 XC7A100T-1FGG676C

### LEDs (from board markings):
- **D1** — pin unknown
- **D4** — pin unknown
- **D5** — pin unknown (maybe NOT T23!)
- **D6** — pin unknown (maybe T23?)

### Working Configurations:

| Bitstream | Pin (XDC) | LED Status | Notes |
|-----------|-----------|------------|-------|
| temporal_heartbeat.bit | T23 | ✅ BLINKING (D6?) | CONFIRMED WORKING! |
| quantum_bridge_separable.bit | T23 | ❌ NOT blinking | Just tested |
| quantum_bridge_violation.bit | T23 | ❓ | |

### Critical Facts:
1. **temporal_heartbeat.bit with T23 works** — LED was blinking
2. **quantum_bridge_separable.bit with T23 doesn't work** — LED not blinking
3. **Same pin T23, different result**

### Possible Issues:
- Different LEDs on board (D1, D4, D5, D6 = different pins!)
- T23 might be connected to a DIFFERENT LED than D5
- Board silkscreen labels might be wrong

### Actions Needed:
- [ ] Test which physical LED corresponds to T23
- [ ] Document all LED pins properly
- [ ] Try different pins (R23, etc.) for quantum_bridge

### Files to Check:
- Board schematic — shows LED pin mapping
- Board physical inspection — count LEDs, note positions

### Actions Needed:
- [x] Test which physical LED corresponds to T23
- [x] Create diagnostic bitstream with both T23 and R23
- [ ] Flash led_diagnostic.bit and observe results
- [ ] Document all LED pins properly

### NEW: LED Diagnostic Bitstream

**File:** `led_diagnostic.bit` (created 2026-03-03 19:44)

**What it does:**
- **led0 (T23)**: Fast blink (~6 Hz) — counter[22]
- **led1 (R23)**: Slow blink (~1.5 Hz) — counter[24]

**How to use:**
```bash
# Initialize cable
sudo /Users/playra/trinity-w1/fpga/tools/fxload -t fx2 -d 03fd:0013 -i /Users/playra/trinity-w1/fpga/tools/xusb_xp2.hex

# Flash diagnostic
sudo /Users/playra/trinity-w1/fpga/tools/jtag_program /Users/playra/trinity-w1/fpga/openxc7-synth/led_diagnostic.bit
```

**Expected results:**
- If you see FAST blinking → that LED is T23
- If you see SLOW blinking → that LED is R23
- Both LEDs should blink (but at different rates)

**Physical LEDs on board:** D1, D4, D5, D6 — need to identify which is which!

## DON'T FORGET:
- temporal_heartbeat.bit WORKS with T23
- quantum_bridge SEPARABLE doesn't work with T23
- **NEW: led_diagnostic.bit will identify T23 vs R23 LEDs!**
- Need to find WHICH LED is T23!

**Last updated: 2026-03-03 19:44**
**φ² + 1/φ² = 3 = TRINITY**
