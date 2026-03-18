# Issue MU-4: .tri Parser → FPGA Pipeline Integration

**Status:** `OPEN` (deferred from v2.1)
**Priority:** P1 (non-blocking)
**Target:** Trinity v2.2

---

## Current State

**STUB IMPLEMENTATION** — File extension detection exists but doesn't parse.

Location: `src/tri/tri_fpga.zig:393-399`

```zig
// Detection works
const spec_ext = std.fs.path.extension(spec_path.?);
const is_tri_file = std.mem.eql(u8, spec_ext, ".tri");

if (is_tri_file) {
    std.debug.print("[MU-4] Detected .tri file, using TriParser...\n");
}
// But then falls through to VIBEE anyway — no actual parsing
```

---

## Blocker

**Missing execution path:** TriParser requires DesignSpec from synthesis_types, which has build integration issues.

```zig
// This code exists but is commented out
var parser = tri_parser_mod.TriParser.init(allocator);
const design_spec = try parser.parse(spec_abs);
try parser.generateVerilog(&design_spec, verilog_file.writer());
```

---

## Acceptance Criteria

- [ ] `.tri` files detected and routed to TriParser (not VIBEE)
- [ ] TriParser successfully parses `@module`, `@ports`, `@constraints`
- [ ] Verilog generated directly from .tri spec
- [ ] XDC generated from .tri constraints
- [ ] Full pipeline works: `.tri` → Verilog + XDC → synthesis → bitstream

---

## Implementation Plan

1. **Resolve synthesis_types import** — fix build.zig module path
2. **Add .tri parsing branch** in `runFpgaGen()` after file detection
3. **Generate Verilog** directly from TriParser output
4. **Skip VIBEE** for .tri files
5. **Test** — create test.tri spec, verify full pipeline

---

## Files

- `src/forge/tri_parser.zig` — TriParser implementation
- `src/forge/synthesis_types.zig` — DesignSpec, Port, Constraints
- `src/tri/tri_fpga.zig` — Integration point

---

## Test Spec Example

```tri
@module blink_test
@device xc7a100t
@consciousness true

@ports
  input clk: clock @freq 50MHz
  output led: signal @loc R23 @iostandard LVCMOS33

@constraints
  timing: target_frequency=50MHz
```

---

**Reference:** CHANGELOG_AGENT_MU.md — P1 deferred status
