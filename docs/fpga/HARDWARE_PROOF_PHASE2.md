# Hardware Proof Checklist — Phase 2 Patent Hardening

**Purpose:** Execute physical hardware validation for P2 patent filing
**Hardware:** QMTECH Artix-7 XC7A100T-1FGG676C
**JTAG:** Xilinx Platform Cable USB II
**Date:** 2026-03-08

---

## Pre-Flight Checklist

### Hardware Setup

- [ ] FPGA board powered and connected via USB
- [ ] JTAG cable connected to board JTAG port
- [ ] Verify USB detection:
  ```bash
  lsusb | grep Xilinx
  # Expected: Bus XXX Device XXX: ID 03fd:0013 Xilinx, Inc.
  ```

### Software Prerequisites

- [ ] fxload firmware loader available: `which fxload`
- [ ] jtag_program available: `fpga/tools/jtag_program`
- [ ] Bitstreams exist:
  - [ ] `fpga/openxc7-synth/blink.bit`
  - [ ] `fpga/openxc7-synth/counter.bit`
  - [ ] `fpga/openxc7-synth/fsm_simple.bit`

### Evidence Directory

- [ ] Create directory: `mkdir -p docs/fpga/evidence`
- [ ] Prepare for: photos, videos, logs

---

## Step 1: Load JTAG Firmware

### Command

```bash
cd /Users/playra/trinity-w1/fpga/tools
sudo ./fxload -v -t fx2 -d 03fd:0013 -i xusb_xp2.hex
```

### Expected Output

```
USB device detected
VID: 03fd, PID: 0013
Loading firmware from xusb_xp2.hex...
WROTE: 7962 bytes, 90 segments
Firmware loaded successfully
```

### Verify

```bash
lsusb | grep 03fd
# Should still show 0013 initially
```

### Action Required

**UNPLUG and REPLUG the JTAG cable now.**

PID should change from `0013` to `0008` (JTAG mode).

---

## Step 2: Verify JTAG Mode

### Command

```bash
lsusb | grep 03fd
```

### Expected Output

```
Bus XXX Device XXX: ID 03fd:0008 Xilinx, Inc.
```

**PID 0008 confirms JTAG mode is active.**

### Save Log

```bash
lsusb > docs/fpga/evidence/lsusb_after_fw.txt
```

---

## Step 3: Flash blink.bit

### Command

```bash
cd /Users/playra/trinity-w1/fpga/openxc7-synth
../tools/jtag_program blink.bit 2>&1 | tee docs/fpga/evidence/blink_flash.log
```

### Expected Output

```
IDCODE: 0x13631093 (XC7A100T)
Sending bitstream (3.6 MB)...
[████████████████████] 100%
FPGA programmed successfully
```

### Verify LED Behavior

**Expected:** LED D6 (pin R23) blinks at ~1.5 Hz

- [ ] LED is blinking
- [ ] Blink period is approximately 0.67 seconds
- [ ] Pattern repeats continuously

### Evidence to Collect

| Evidence | File | Description |
|----------|------|-------------|
| Photo | `docs/fpga/evidence/blink_photo.jpg` | Board with LED visible |
| Video | `docs/fpga/evidence/blink_video.mp4` | 10 seconds of blinking |
| Log | `docs/fpga/evidence/blink_flash.log` | Programming output |

### Photo Requirements

- Show entire FPGA board
- LED D6 must be visible (lit or mid-blink)
- Include timestamp (e.g., phone screen with time in frame)
- Good lighting (avoid glare)

### Video Requirements

- Minimum 10 seconds
- Show at least 3 blink cycles
- Steady camera (no shake)
- Include audio description: "This is Trinity FPGA blink test, [date]"

---

## Step 4: Flash counter.bit

### Command

```bash
../tools/jtag_program counter.bit 2>&1 | tee docs/fpga/evidence/counter_flash.log
```

### Expected Output

```
IDCODE: 0x13631093 (XC7A100T)
Sending bitstream (3.6 MB)...
[████████████████████] 100%
FPGA programmed successfully
```

### Verify LED Behavior

**Expected:** 4 LEDs show binary count 0-15

| LED | Pin | Bit |
|-----|-----|-----|
| D6 | R23 | 0 (LSB) |
| D5 | T23 | 1 |
| D4 | R24 | 2 |
| D3 | P24 | 3 (MSB) |

- [ ] LEDs count from 0 to 15 repeatedly
- [ ] Each value displays for ~1.3 seconds
- [ ] Pattern is binary (0000 → 0001 → 0010 → ... → 1111 → 0000)

### Evidence to Collect

| Evidence | File | Description |
|----------|------|-------------|
| Photo | `docs/fpga/evidence/counter_photo.jpg` | Board showing count value |
| Video | `docs/fpga/evidence/counter_video.mp4` | 20 seconds (full cycle) |
| Log | `docs/fpga/evidence/counter_flash.log` | Programming output |

### Photo Requirements

- Capture at least 3 different count values
- Label each photo (e.g., "counter_value_5.jpg")

---

## Step 5: Flash fsm_simple.bit

### Command

```bash
../tools/jtag_program fsm_simple.bit 2>&1 | tee docs/fpga/evidence/fsm_flash.log
```

### Expected Output

```
IDCODE: 0x13631093 (XC7A100T)
Sending bitstream (3.6 MB)...
[████████████████████] 100%
FPGA programmed successfully
```

### Verify LED Behavior

**Expected:** 3-state traffic light sequence

| State | LED D6 | Duration |
|-------|--------|----------|
| RED | OFF (lit board, LED dark) | ~1 second |
| GREEN | Blinking (~0.5 Hz) | ~1 second |
| YELLOW | ON (LED lit continuously) | ~1 second |

- [ ] State sequence: RED → GREEN → YELLOW → RED (repeating)
- [ ] Each state lasts ~1 second
- [ ] GREEN state blinks

### Evidence to Collect

| Evidence | File | Description |
|----------|------|-------------|
| Photo | `docs/fpga/evidence/fsm_photo.jpg` | Board in one state |
| Video | `docs/fpga/evidence/fsm_video.mp4` | 15 seconds (all states) |
| Log | `docs/fpga/evidence/fsm_flash.log` | Programming output |

---

## Step 6: Collect System Information

### Git Commit

```bash
cd /Users/playra/trinity-w1
git log -1 --format="%H %s" > docs/fpga/evidence/git_commit.txt
git diff HEAD~1 --stat >> docs/fpga/evidence/git_commit.txt
```

### Synthesis Logs

```bash
cp fpga/openxc7-synth/blink.json docs/fpga/evidence/
cp fpga/openxc7-synth/counter.json docs/fpga/evidence/
cp fpga/openxc7-synth/fsm_simple.json docs/fpga/evidence/
```

### Yosys Statistics

Extract cell counts from synthesis logs:

```bash
echo "=== blink.v ===" > docs/fpga/evidence/synthesis_stats.txt
grep "Number of cells" -A 20 fpga/openxc7-synth/blink.json >> docs/fpga/evidence/synthesis_stats.txt

echo "=== counter.v ===" >> docs/fpga/evidence/synthesis_stats.txt
grep "Number of cells" -A 20 fpga/openxc7-synth/counter.json >> docs/fpga/evidence/synthesis_stats.txt

echo "=== fsm_simple.v ===" >> docs/fpga/evidence/synthesis_stats.txt
grep "Number of cells" -A 20 fpga/openxc7-synth/fsm_simple.json >> docs/fpga/evidence/synthesis_stats.txt
```

---

## Step 7: Create Evidence Manifest

### Generate Manifest

```bash
cat > docs/fpga/evidence/MANIFEST.txt << 'EOF'
Trinity FPGA Technology Tree - Hardware Evidence
Date: $(date)
Commit: $(git log -1 --format="%H")
Operator: [YOUR NAME]

=== Bitstreams Tested ===
1. blink.bit - LED blink test
2. counter.bit - 4-bit binary counter
3. fsm_simple.bit - 3-state traffic light

=== Evidence Files ===
Photos: blink_photo.jpg, counter_photo_*.jpg, fsm_photo.jpg
Videos: blink_video.mp4, counter_video.mp4, fsm_video.mp4
Logs: *_flash.log, lsusb_after_fw.txt, synthesis_stats.txt
Synthesis: *.json

=== Test Results ===
[ ] blink.v: PASSED - LED blinks at ~1.5 Hz
[ ] counter.v: PASSED - 4 LEDs count 0-15
[ ] fsm_simple.v: PASSED - 3-state sequence observed

=== Hardware ===
FPGA: QMTECH Artix-7 XC7A100T-1FGG676C
JTAG: Xilinx Platform Cable USB II
Setup: [Description of test setup]

=== Certification ===
I certify that the above evidence was collected on [DATE]
from physical Trinity FPGA hardware.
Signature: __________________
EOF
```

---

## Step 8: Update Evidence Table

### Update P2_EVIDENCE_TABLE.md

Add hardware evidence entries:

```markdown
| E1.8 | HW | docs/fpga/evidence/blink_photo.jpg | Blink test photo | 2026-03-08 | ✅ |
| E1.9 | HW | docs/fpga/evidence/blink_video.mp4 | Blink test video | 2026-03-08 | ✅ |
| E7.10 | HW | docs/fpga/evidence/counter_photo.jpg | Counter test photo | 2026-03-08 | ✅ |
| E7.11 | HW | docs/fpga/evidence/lsusb_after_fw.txt | JTAG detection | 2026-03-08 | ✅ |
```

---

## Troubleshooting

### Issue: "No USB probe found"

**Cause:** JTAG firmware not loaded or cable not replugged

**Solution:**
1. Re-run fxload command
2. Unplug and replug cable
3. Verify with lsusb (PID should be 0008)

### Issue: "IDCODE mismatch"

**Cause:** Wrong FPGA or cable issue

**Solution:**
1. Verify FPGA model: `cat fpga/TECH_TREE.md | grep FPGA`
2. Check cable connections
3. Try different USB port

### Issue: LED doesn't blink

**Cause:** Bitstream incorrect or pin constraint wrong

**Solution:**
1. Verify blink.xdc has correct pin (R23)
2. Check if LED is active-low design
3. Resynthesize if needed

---

## Success Criteria

Hardware proof is COMPLETE when:

- [ ] All 3 bitstreams programmed successfully
- [ ] All LED behaviors verified
- [ ] At least 3 photos collected (one per design)
- [ ] At least 3 videos collected (one per design)
- [ ] All programming logs saved
- [ ] Evidence manifest created
- [ ] P2_EVIDENCE_TABLE.md updated

---

## Post-Execution

### Update Patent Docs

1. Update `docs/patents/P2_CLAIM_CHART.md`:
   - Change Claim 1 status to ✅ COMPLETE
   - Change Claim 7 status to ✅ COMPLETE

2. Update `docs/patents/P2_EVIDENCE_TABLE.md`:
   - Add all new evidence entries
   - Update statistics

3. Create filing decision:
   - If all hardware tests pass: **FILE NOW**
   - If issues: document and retry

---

## Time Estimate

| Step | Time |
|------|------|
| Setup (firmware, cable) | 10 min |
| blink.bit flash + verify | 15 min |
| counter.bit flash + verify | 15 min |
| fsm_simple.bit flash + verify | 15 min |
| Evidence collection | 10 min |
| Documentation update | 15 min |
| **Total** | **~80 minutes** |

---

φ² + 1/φ² = 3 = TRINITY

**Seeing is believing. Hardware proof is truth.**
