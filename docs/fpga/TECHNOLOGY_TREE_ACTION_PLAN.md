# Trinity FPGA Technology Tree — Action Plan

**Date:** 2026-03-08
**Based on:** TECHNOLOGY_TREE_TOXIC_VERDICT.md

---

## Priority Matrix

| Priority | Issue | Effort | Impact | Status |
|----------|-------|--------|--------|--------|
| 🔴 HIGH | Hardware validation | 2h | Proof of execution | ⏳ Pending |
| 🔴 HIGH | VIBEE parser `values` field | 2d | Enables Tier 2 | ⏳ Pending |
| 🔴 HIGH | SSOT import generation | 1d | Eliminates duplication | ⏳ Pending |
| 🟡 MEDIUM | Verilog syntax validation | 1d | Cleaner output | ⏳ Pending |
| 🟢 LOW | counter.v spec fix | 30m | Correctness | ⏳ Pending |

---

## Phase 4: Hardware Validation (IMMEDIATE)

### Procedure

**Prerequisites:**
- QMTECH Artix-7 board connected via JTAG
- Xilinx Platform Cable USB II
- sudo access for fxload

### Step-by-Step

```bash
# 1. Navigate to tools
cd fpga/tools

# 2. Load JTAG firmware (every session!)
sudo ./fxload -v -t fx2 -d 03fd:0013 -i xusb_xp2.hex
# Expected: "WROTE: 7962 bytes, 90 segments"

# 3. Replug USB cable
# PID changes from 0013 (bootloader) to 0008 (JTAG mode)

# 4. Flash blink.bit
cd ../openxc7-synth
../tools/jtag_program blink.bit

# 5. Verify LED behavior
# Expected: D6 blinks at ~1.5 Hz (active-low)

# 6. Flash counter.bit
../tools/jtag_program counter.bit

# 7. Verify counter
# Expected: D6,D5,D4,D3 show 0-15 binary count (~1.3s per value)

# 8. Flash fsm_simple.bit
../tools/jtag_program fsm_simple.bit

# 9. Verify state machine
# Expected: D6 OFF → blinking → ON (repeating)
```

### Evidence Collection

For each design:
1. **Photo** of LED behavior
2. **Video** (10 seconds) showing pattern
3. **Log** of JTAG programming output
4. **Confirmation** of expected behavior

### Acceptance Criteria

- [ ] blink.bit: D6 blinks at ~1.5 Hz
- [ ] counter.bit: All 4 LEDs count 0-15
- [ ] fsm_simple.bit: State sequence visible
- [ ] Photos/videos saved to `docs/fpga/evidence/`

---

## Action Item 1: Fix VIBEE Parser

### File: `trinity-nexus/lang/src/vibee_parser.zig`

### Required Changes

```zig
// Add to TypeField enum
pub const TypeField = enum {
    base,
    description,
    generic,
    fields,
    enum,
    constraints,
    // NEW:
    values,      // Enum/value definitions
    encoding,    // State encoding (one_hot, binary, gray)
    width,       // Bit width

    // ... rest of implementation
};
```

### Implementation Steps

1. **Add `values` parsing**
   - Parse list of `{name, value}` pairs
   - Support for `localparam` generation

2. **Add `encoding` parsing**
   - Recognize: `one_hot`, `binary`, `gray`, `johnson`

3. **Add `width` parsing**
   - Parse integer bit width
   - Apply to signal declarations

### Testing

```yaml
# Test spec: test_values.tri
types:
  State:
    encoding: one_hot
    width: 3
    values:
      - name: IDLE
        value: 3'b001
      - name: RUNNING
        value: 3'b010
      - name: DONE
        value: 3'b100
```

Expected output:
```verilog
localparam IDLE    = 3'b001;
localparam RUNNING = 3'b010;
localparam DONE    = 3'b100;
```

---

## Action Item 2: SSOT Import Generation

### Goal: Generate `protocol_defines.v` from Zig

### Implementation

**New file:** `trinity-nexus/lang/src/protocol_defines_gen.zig`

```zig
const std = @import("std");

pub fn generateProtocolDefines(allocator: std.mem.Allocator) ![]const u8 {
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
        \\// Trit encoding (2-bit)
        `define TRIT_NEGATIVE 2'b10
        \\`define TRIT_ZERO 2'b00
        \\`define TRIT_POSITIVE 2'b01
        \\
    );

    return buffer.toOwnedSlice();
}
```

### Integration

Update `verilog_codegen.zig`:
1. Generate `protocol_defines.v` alongside Verilog output
2. Add `` `include "protocol_defines.v" `` to generated modules

### Usage in .tri spec

```yaml
imports:
  - name: protocol
    path: "src/common/protocol.zig"
    generate: "protocol_defines.v"
```

---

## Action Item 3: Verilog Syntax Validation

### Issue: `function signed` invalid in Verilog-2005

### Fix Pattern

**Before (incorrect):**
```verilog
function signed [1:0] trit_value(input [1:0] encoded);
    case (encoded)
        2'b10: trit_value = -1;
        2'b00: trit_value = 0;
        2'b01: trit_value = +1;
    endcase
endfunction
```

**After (correct):**
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
        trit_value = result;
    end
endfunction
```

### Implementation

Add validation in `verilog_codegen.zig`:
1. Check for `function signed` pattern
2. Rewrite using intermediate `reg signed`
3. Warn if generate blocks used (not Verilog-2005)

---

## Action Item 4: Fix counter.tri Spec

### Issue: Spec declares 4 signals but codegen only created 2

### Fix

Update `specs/fpga/counter.tri`:

```yaml
signals:
  - name: clk
    type: input
    width: 1
    pin: U22
    iostandard: LVCMOS33

  - name: led0
    type: output
    width: 1
    pin: R23
    iostandard: LVCMOS33

  - name: led1
    type: output
    width: 1
    pin: T23
    iostandard: LVCMOS33

  - name: led2
    type: output
    width: 1
    pin: R24
    iostandard: LVCMOS33

  - name: led3
    type: output
    width: 1
    pin: P24
    iostandard: LVCMOS33
```

Then regenerate:
```bash
zig build vibee -- gen specs/fpga/counter.tri
```

---

## Action Item 5: uart_top.v Syntax Fix

### Issues Identified

1. **Signed function syntax** (line 430)
2. **Signal name conflicts** (rx_data used as both 256-bit and 8-bit)
3. **Missing wire/reg declarations**

### Fix Strategy

1. Run Yosys on generated `uart_top.v`:
   ```bash
   yosys -p "synth_xilinx -top uart_top" uart_top.v
   ```

2. Fix each error in `uart_top.tri` spec:
   - Add explicit wire/reg declarations
   - Rename conflicting signals
   - Use proper Verilog-2005 syntax

3. Regenerate and re-test

---

## Tier 2 Preparation

### VSA Coprocessor Spec Outline

```yaml
name: vsa_coprocessor
version: "1.0.0"
language: varlog
fpga_target: xilinx
target_frequency: 50

imports:
  - name: protocol
    path: "src/common/protocol.zig"

types:
  TritVector:
    width: 10000  # 10k trits = ~16KB packed
    encoding: packed  # 2 bits per trit

behaviors:
  - name: bind
    given: Two trit vectors A and B
    when: BIND command received via UART
    then: Return A ⊛ B (permuted binding)

  - name: bundle3
    given: Three trit vectors A, B, C
    when: BUNDLE command received
    then: Return majority vote (A ⊕ B ⊕ C)

  - name: similarity
    given: Two trit vectors A and B
    when: SIMILARITY command received
    then: Return cosine similarity [-1, 1]
```

---

## Timeline

### Week 1 (Current)
- [x] Phase 0-3: Spec to bitstream
- [ ] Phase 4: Hardware validation
- [ ] Phase 5: Git sync

### Week 2
- [ ] Fix VIBEE parser (values, encoding, width)
- [ ] Implement SSOT import generation
- [ ] Add Verilog syntax validation

### Week 3
- [ ] Fix uart_top.v issues
- [ ] Regenerate all Tier 1 from fixed VIBEE
- [ ] Re-synthesize and verify

### Week 4
- [ ] Start Tier 2: VSA coprocessor spec
- [ ] File P2 patent (supplement later)

---

## Success Criteria

### Phase 4 Completion
- [ ] All 3 bitstreams flashed to hardware
- [ ] LED behavior verified
- [ ] Evidence documented

### Week 2-3 Completion
- [ ] VIBEE parser handles all type fields
- [ ] SSOT import working
- [ ] No manual edits required after generation

### Tier 2 Readiness
- [ ] VSA coprocessor spec complete
- [ ] Code generates without errors
- [ ] Synthesis succeeds

---

## Resource Allocation

| Task | Owner | Estimate | Dependencies |
|------|-------|----------|--------------|
| Hardware validation | User | 2h | JTAG cable |
| VIBEE parser fix | Dev | 2d | None |
| SSOT import | Dev | 1d | Parser fix |
| Syntax validation | Dev | 1d | None |
| uart_top fix | Dev | 1d | Validation |
| Tier 2 spec | Dev | 3d | All above |

**Total:** ~8 days of development work

---

φ² + 1/φ² = 3 = TRINITY

**Plan is useless. Planning is essential.**
**Execute. Verify. Adapt.**
