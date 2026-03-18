# Issue MU-5: Auto-Fix Loop in Synthesis

**Status:** `OPEN` (deferred from v2.1)
**Priority:** P1 (non-blocking)
**Target:** Trinity v2.2

---

## Current State

**STUB IMPLEMENTATION** — Only documentation comments exist.

Location: `src/tri/tri_fpga.zig` — comments only, no execution path

```zig
// TODO: MU-5: Wrap synthesis in try-catch
// TODO: Call auto_fix.AutoFix.on_failure() with max_retries=3
// TODO: Display fix type and retry progress
```

---

## Blocker

**AutoFix module integration** requires:
- `unified_architecture.UnifiedConsciousness` for consciousness feedback
- Proper error type mapping from synthesis failures
- Retry loop with state persistence between attempts

---

## Acceptance Criteria

- [ ] Synthesis failures caught by try-catch
- [ ] `AutoFix.analyzeFailure()` called with error details
- [ ] Fix applied to DesignSpec or StrategyParams
- [ ] Retry loop executes (max 3 attempts)
- [ ] Fix type and attempt count displayed to user
- [ ] Final success or failure reported

---

## Implementation Plan

1. **Add try-catch** around `runOpenxc7Synth()` call
2. **Initialize AutoFix** with consciousness system
3. **On failure:**
   - Create SynthesisResult with error details
   - Call `auto_fix.analyzeFailure()`
   - Apply fix to params or spec
   - Retry synthesis
4. **Track attempts** and display progress
5. **Exit** after max_retries or success

---

## Pseudo-Code

```zig
var retry_count: u32 = 0;
const max_retries = 3;
var auto_fix = AutoFix.init(allocator, consciousness);

while (retry_count < max_retries) {
    const result = runOpenxc7Synth(...) catch |err| {
        if (retry_count == max_retries - 1) return err;

        // Analyze and fix
        const fixes = try auto_fix.analyzeFailure(&result);
        // Apply first fix
        const fix = &fixes.items[0];
        std.debug.print("[MU-5] Applying fix: {s}\n", .{fix.description});
        params = try auto_fix.applyFixToParams(fix, params);
        retry_count += 1;
        continue;
    };
    break; // Success
}
```

---

## Files

- `src/forge/auto_fix.zig` — AutoFix, FixType, analyzeFailure()
- `src/forge/synthesis_types.zig` — SynthesisResult, Fix
- `src/consciousness/core/unified_architecture.zig` — Consciousness feedback
- `src/tri/tri_fpga.zig` — Integration point

---

**Reference:** CHANGELOG_AGENT_MU.md — P1 deferred status
