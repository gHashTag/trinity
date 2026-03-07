# Issue MU-3: ForgeStrategist → tri_fpga.zig Integration

**Status:** `OPEN` (deferred from v2.1)
**Priority:** P1 (non-blocking)
**Target:** Trinity v2.2

---

## Current State

**STUB IMPLEMENTATION** — `--strategy` flag exists but only prints a message.

Location: `src/tri/tri_fpga.zig:322-391`

```zig
// Flag parsing exists
} else if (std.mem.eql(u8, arg, "--strategy")) {
    use_strategist = true;
    arg_idx += 1;
}

// But strategist initialization is commented out due to circular deps
// TODO: Full integration requires resolving module dependencies
```

---

## Blocker

**Circular dependency error:**

```
error: unable to load 'unified_architecture.zig': FileNotFound
error: unable to load 'learning_loops.zig': FileNotFound
error: unable to load 'strategist.zig': FileNotFound
```

Modules exist at `/src/forge/` and `/src/consciousness/` but build.zig module registration conflicts with tri_fpga.zig location.

---

## Acceptance Criteria

- [ ] `--strategy consciousness` flag executes `ForgeStrategist.analyze()`
- [ ] Consciousness analysis displayed (IIT Φ, GWT, HOT scores)
- [ ] Strategy decision applied to synthesis parameters
- [ ] Integration uses actual module imports, not commented code
- [ ] Build passes without circular dependency errors

---

## Implementation Plan

1. **Resolve build.zig module registration** — register forge modules correctly
2. **Uncomment strategist initialization** in `tri_fpga.zig:355-391`
3. **Connect to synthesis** — pass strategy params to `runOpenxc7Synth()`
4. **Test** — `tri fpga gen specs/fpga/blink.vibee --strategy`

---

## Files

- `src/forge/strategist.zig` — ForgeStrategist implementation
- `src/forge/synthesis_types.zig` — StrategyDecision, StrategyParams
- `src/consciousness/core/unified_architecture.zig` — UnifiedConsciousness
- `src/tri/tri_fpga.zig` — Integration point

---

**Reference:** CHANGELOG_AGENT_MU.md — P1 deferred status
