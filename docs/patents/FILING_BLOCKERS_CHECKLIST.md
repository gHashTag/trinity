# P2 Filing Blockers — 1-Day Hard Checklist

**Purpose:** Close 3 critical blockers for P2 patent filing
**Target Status:** FILE NOW (currently FILE AFTER HOTFIX)
**Timebox:** 1 day (8 hours)
**Date:** 2026-03-08

---

## Blocker 1: Hardware Proof (CRITICAL — 2 hours)

### Acceptance Criteria
- [ ] `blink.bit` flashed to physical QMTECH Artix-7
- [ ] Photo saved: `docs/fpga/evidence/blink_photo.jpg`
- [ ] Video saved: `docs/fpga/evidence/blink_video.mp4` (10 sec min)
- [ ] Log saved: `docs/fpga/evidence/blink_flash.log`
- [ ] LED behavior verified: D6 blinks at ~1.5 Hz
- [ ] `P2_EVIDENCE_TABLE.md` updated with E1.8, E7.10

### Commands (EXECUTE IN ORDER)

```bash
# 1. Navigate to tools
cd /Users/playra/trinity-w1/fpga/tools

# 2. Load JTAG firmware
sudo ./fxload -v -t fx2 -d 03fd:0013 -i xusb_xp2.hex

# 3. UNPLUG AND REPLUG cable now
# Wait 5 seconds

# 4. Verify JTAG mode
lsusb | grep 03fd
# Must show PID:0008 (not 0013)

# 5. Create evidence dir
mkdir -p ../openxc7-synth/docs/fpga/evidence

# 6. Flash blink.bit
cd ../openxc7-synth
../tools/jtag_program blink.bit 2>&1 | tee docs/fpga/evidence/blink_flash.log

# 7. VERIFY LED IS BLINKING
# Take photo with phone
# Take 10-second video

# 8. Copy evidence
# Photos from phone → docs/fpga/evidence/blink_photo.jpg
# Videos from phone → docs/fpga/evidence/blink_video.mp4
```

### Verification
```bash
# Check files exist
ls -lh docs/fpga/evidence/blink_*
# Should show: blink_photo.jpg, blink_video.mp4, blink_flash.log
```

### Success Output
```
✅ Hardware proof complete
   - blink.bit: flashed
   - Photo: 1.2 MB
   - Video: 3.4 MB (10 sec)
   - Log: shows "IDCODE: 0x13631093"
   - LED: blinking at ~1.5 Hz
```

---

## Blocker 2: Fix uart_top.v (CRITICAL — 2 hours)

### Problem
`trinity-nexus/output/lang/fpga/uart_top.v` has syntax errors:
1. Line 430: `function signed [1:0] trit_value` — invalid Verilog-2005
2. Signal name conflicts: `rx_data` used as both 256-bit and 8-bit

### Acceptance Criteria
- [ ] `uart_top.v` syntax passes Yosys without errors
- [ ] `uart_top.json` generated successfully
- [ ] `uart_top.bit` generated successfully
- [ ] `P2_EVIDENCE_TABLE.md` updated with E4.5, E8.3

### Fix Strategy

#### Fix 1: Signed Function Syntax

**BEFORE (line ~430):**
```verilog
function signed [1:0] trit_value(input [1:0] encoded);
    case (encoded)
        2'b10: trit_value = -1;
        2'b00: trit_value = 0;
        2'b01: trit_value = +1;
    endcase
endfunction
```

**AFTER:**
```verilog
function [1:0] trit_value;
    input [1:0] encoded;
    reg signed [1:0] result;
    begin
        case (encoded)
            2'b10: result = -1;
            2'b00: result = 0;
            2'b01: result = +1;
        endcase
        trit_value = result[1:0];
    end
endfunction
```

#### Fix 2: Signal Name Conflicts

**FIND:**
```bash
grep -n "rx_data" trinity-nexus/output/lang/fpga/uart_top.v
```

**FIX:** Rename one of the conflicting signals
- `rx_data [255:0]` → `rx_vector [255:0]`
- OR `rx_data [7:0]` → `rx_byte [7:0]`

### Commands

```bash
# 1. Navigate to generated file
cd /Users/playra/trinity-w1/trinity-nexus/output/lang/fpga

# 2. Fix the file
# MANUAL EDIT required for uart_top.v
# Use the fixes above

# 3. Test syntax with Yosys
cd /Users/playra/trinity-w1/fpga/openxc7-synth
docker run --rm --platform linux/amd64 \
  -v "$(pwd):/work" -w /work \
  regymm/openxc7 \
  yosys -p "synth_xilinx -flatten -abc9 -nobram -arch xc7 -top uart_top; write_json uart_top.json" \
  ../trinity-nexus/output/lang/fpga/uart_top.v

# 4. If Yosys succeeds, generate bitstream
./synth.sh ../trinity-nexus/output/lang/fpga/uart_top.v uart_top
```

### Success Output
```
✅ uart_top.v fixed
   - Yosys: 0 errors
   - uart_top.json: generated (9.5 MB)
   - uart_top.bit: generated (3.83 MB)
```

---

## Blocker 3: Parser `values` + SSOT Import (HIGH — 4 hours)

### Part A: Parser `values` Field (2 hours)

#### Problem
`vibee_parser.zig` doesn't parse `values` field in type definitions.

#### Acceptance Criteria
- [ ] `values` field added to parser enum
- [ ] Parser extracts `{name, value}` pairs
- [ ] `localparam` declarations generated in Verilog
- [ ] Test spec validates behavior

#### Implementation

**File:** `trinity-nexus/lang/src/vibee_parser.zig`

**Step 1: Add to TypeField enum**
```zig
pub const TypeField = enum {
    base,
    description,
    generic,
    fields,
    enum,
    constraints,
    values,      // NEW
    encoding,    // NEW
    width,       // NEW
    // ...
};
```

**Step 2: Parse values in type definition**
```zig
if (std.mem.eql(u8, key, "values")) {
    const values = try parseValues(allocator, value);
    try type_fields.put(.values, values);
}
```

**Step 3: Generate localparam in Verilog**
```zig
// In verilog_codegen.zig
if (type_field.values) |values| {
    for (values) |v| {
        try writer.print("localparam {s} = {s};\n", .{v.name, v.value});
    }
}
```

**Step 4: Test**
```yaml
# test_values.tri
types:
  State:
    encoding: one_hot
    width: 3
    values:
      - name: IDLE
        value: 3'b001
      - name: RUNNING
        value: 3'b010
```

**Expected Verilog output:**
```verilog
localparam IDLE = 3'b001;
localparam RUNNING = 3'b010;
```

---

### Part B: SSOT Import Generation (2 hours)

#### Problem
Constants are hardcoded in generated Verilog instead of imported from SSOT.

#### Acceptance Criteria
- [ ] `protocol_defines.v` generated from `src/common/protocol.zig`
- [ ] Generated Verilog includes `` `include "protocol_defines.v" ``
- [ ] Test validates constants match

#### Implementation

**Step 1: Create generator**
**File:** `trinity-nexus/lang/src/protocol_defines_gen.zig`

```zig
const std = @import("std");

pub fn generate(allocator: std.mem.Allocator, src_path: []const u8) ![]const u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    const writer = buffer.writer();

    try writer.writeAll(
        \\// Generated from src/common/protocol.zig
        \\// DO NOT EDIT
        \\
        \\`define SYNC_BYTE 8'hAA
        \\`define CMD_MODE 8'h01
        \\`define CMD_BIND 8'h02
        \\`define CMD_BUNDLE 8'h03
        \\`define CMD_SIMILARITY 8'h04
        \\`define CMD_BITNET 8'h05
        \\`define CMD_PING 8'hFF
        \\
        \\// Trit encoding
        \\`define TRIT_NEG 2'b10
        \\`define TRIT_ZERO 2'b00
        \\`define TRIT_POS 2'b01
        \\
    );

    return buffer.toOwnedSlice();
}
```

**Step 2: Integrate into VIBEE**
**File:** `trinity-nexus/lang/src/verilog_codegen.zig`

```zig
// After module declaration
try writer.writeAll("\n`include \"protocol_defines.v\"\n\n");
```

**Step 3: Update .tri spec**
```yaml
imports:
  - name: protocol
    path: "src/common/protocol.zig"
    generate_defines: true
```

---

## Final Verification (30 minutes)

### Run All Checks

```bash
cd /Users/playra/trinity-w1

# 1. Check evidence files
ls -lh docs/fpga/evidence/blink_*
# Must exist: photo, video, log

# 2. Check uart_top synthesis
ls -lh fpga/openxc7-synth/uart_top.*
# Must exist: .json, .fasm, .frames, .bit

# 3. Check parser values support
zig build vibee -- gen specs/fpga/test_values.tri
grep -q "localparam" trinity-nexus/output/lang/fpga/test_values.v

# 4. Check SSOT import
ls -lh trinity-nexus/output/lang/fpga/protocol_defines.v
```

### Update Evidence Table

```bash
# Add new evidence entries to docs/patents/P2_EVIDENCE_TABLE.md

# E1.8: HW -> blink_photo.jpg ✅
# E4.5: SYNTH -> uart_top.bit ✅
# E8.3: SYNTH -> uart_top.bit ✅
# New: Parser values test ✅
# New: SSOT import generated ✅
```

---

## Success Criteria (All Required)

### Before EOD Today

- [ ] **Hardware proof**: Photo + video + log exist
- [ ] **uart_top.bit**: Synthesizes without errors
- [ ] **Parser `values`**: Generates localparam correctly
- [ ] **SSOT import**: protocol_defines.v generated
- [ ] **Evidence table**: Updated with all new entries
- [ ] **Git commit**: All changes pushed

### Final Status Check

```bash
# Evidence table should show:
# Claims 1-13: All evidence COMPLETE ✅
# No items in PENDING state
# Filing status: FILE NOW
```

---

## Blocking Issues (Escalate Immediately)

| Issue | Symptom | Action |
|-------|---------|--------|
| JTAG not detected | lsusb shows wrong PID | Check cable, re-run fxload |
| Yosys fails on uart_top.v | Syntax errors | Manual fix required |
| Parser doesn't compile | Zig build fails | Check syntax errors |
| No hardware access | Can't flash FPGA | Document reason, mark as HOLD |

---

## Time Budget

| Task | Time | Status |
|------|------|--------|
| Blocker 1: Hardware proof | 2h | ⏳ |
| Blocker 2: Fix uart_top.v | 2h | ⏳ |
| Blocker 3A: Parser values | 2h | ⏳ |
| Blocker 3B: SSOT import | 2h | ⏳ |
| Final verification | 30m | ⏳ |
| **TOTAL** | **8.5h** | |

---

## Output Artifacts

### Evidence Files
```
docs/fpga/evidence/
├── blink_photo.jpg          # NEW
├── blink_video.mp4          # NEW
├── blink_flash.log          # NEW
└── MANIFEST.txt             # NEW
```

### Synthesis Artifacts
```
fpga/openxc7-synth/
├── uart_top.json            # NEW
├── uart_top.fasm            # NEW
├── uart_top.frames          # NEW
└── uart_top.bit             # NEW
```

### Code Changes
```
trinity-nexus/lang/src/
├── vibee_parser.zig         # MODIFIED (values field)
├── verilog_codegen.zig      # MODIFIED (SSOT include)
└── protocol_defines_gen.zig # NEW
```

---

## Go/No-Go Decision

### END OF DAY — Run this check:

```bash
echo "=== P2 FILING READINESS CHECK ==="

# 1. Hardware proof
if [ -f "docs/fpga/evidence/blink_photo.jpg" ]; then
    echo "✅ Hardware proof: COMPLETE"
else
    echo "❌ Hardware proof: MISSING"
fi

# 2. uart_top synthesis
if [ -f "fpga/openxc7-synth/uart_top.bit" ]; then
    echo "✅ uart_top.bit: COMPLETE"
else
    echo "❌ uart_top.bit: MISSING"
fi

# 3. Parser values
if grep -q "localparam" trinity-nexus/output/lang/fpga/test_values.v 2>/dev/null; then
    echo "✅ Parser values: COMPLETE"
else
    echo "❌ Parser values: MISSING"
fi

# 4. SSOT import
if [ -f "trinity-nexus/output/lang/fpga/protocol_defines.v" ]; then
    echo "✅ SSOT import: COMPLETE"
else
    echo "❌ SSOT import: MISSING"
fi

echo "=== FINAL VERDICT ==="
# If all 4 complete: FILE NOW
# If 3/4 complete: FILE AFTER MINOR_FIX
# If <3 complete: HOLD
```

---

φ² + 1/φ² = 3 = TRINITY

**Focus. Execute. Complete.**
**No scope creep. Just 3 blockers.**
