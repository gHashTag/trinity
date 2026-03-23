# ADR 003: Sacred Constants Unification

**Date:** 2025-03-04
**Status:** Accepted
**Deciders:** @gHashTag
**Related:** [ADR-001](./001-vibee-compiler.md), [Audit Report](https://github.com/gHashTag/trinity/blob/main/docsite/docs/research/idempotency-audit.md)

---

## Context

**Audit Discovery:** Sacred constants (φ, π, e, TRINITY, PHOENIX) were duplicated across 500+ files.

**Problems:**
1. **Violation of DRY** — Same constant defined in multiple locations
2. **Inconsistency risk** — Values drift between files
3. **Golden Identity violations** — φ² + 1/φ² ≠ 3 in some modules
4. **Maintenance nightmare** — Updates require global search-and-replace

**Golden Identity (Theorem):**
```
φ² + 1/φ² = 3 = TRINITY
where φ = (1 + √5) / 2 ≈ 1.618033988749895
```

This is a mathematical truth that MUST hold across all computations.

---

## Decision

**Create single source of truth: `src/sacred/constants.zig`**

### Implementation

```zig
// src/sacred/constants.zig
pub const SacredConstants = struct {
    /// Golden Ratio - φ = (1 + √5) / 2
    pub const PHI: f64 = 1.618033988749895;

    /// Golden Ratio Inverse - 1/φ = φ - 1
    pub const PHI_INVERSE: f64 = 0.618033988749895;

    /// TRINITY - The sacred number 3
    pub const TRINITY: f64 = 3.0;

    /// Square Root of 5
    pub const SQRT5: f64 = 2.2360679774997896;

    /// Pi
    pub const PI: f64 = 3.141592653589793;

    /// Euler's Number
    pub const E: f64 = 2.718281828459045;

    /// PHOENIX - The immortal number
    pub const PHOENIX: i64 = 999;

    // COMPILE-TIME VERIFICATION
    comptime {
        const identity = PHI * PHI + 1.0 / (PHI * PHI);
        if (@abs(identity - TRINITY) > 1e-10) {
            @compileError("GOLDEN IDENTITY VIOLATED: φ² + 1/φ² ≠ 3");
        }
    }
};
```

### Usage Pattern

```zig
// Import in any module
const SacredConstants = @import("sacred_constants").SacredConstants;

// Use constants
const result = SacredConstants.PHI * x;
```

---

## Consequences

### Positive

✅ **Single source of truth** — One file defines all sacred constants
✅ **Compile-time verification** — Golden Identity verified at build
✅ **Idempotency guarantee** — Values NEVER change between builds
✅ **Type safety** — PHOENIX as i64, others as f64
✅ **Zero runtime overhead** — All comptime

### Negative

⚠️ **Migration required** — 500+ files need import updates
⚠️ **Build dependency** — All modules depend on sacred_constants

### Mitigation

- Backward compatibility: Export constants as `pub const PHI = SacredConstants.PHI;`
- Automated migration: Script to replace inline constants with imports

---

## Migration Status

| Category | Files | Status |
|----------|-------|--------|
| Core library (src/) | 50 | ✅ Migrated |
| VIBEE codegen (trinity-nexus/) | 20 | ✅ Migrated |
| Generated code (var/trinity/output/) | 400 | ✅ Regenerated |
| Tools (tools/) | 10 | ⏳ Pending |
| MCP servers (tools/mcp/) | 15 | ⏳ Pending |

---

## Verification Command

```bash
tri research idempotency
```

Runs 100-cycle idempotency test, verifying:
- Sacred constants consistency
- Golden Identity holds
- No code duplication

---

## References

- [Sacred Constants Source](https://github.com/gHashTag/trinity/blob/main/src/sacred/constants.zig)
- [Idempotency Audit](https://github.com/gHashTag/trinity/blob/main/docsite/docs/research/idempotency-audit.md)
- [Golden Identity Proof](https://github.com/gHashTag/trinity/blob/main/docsite/docs/math-foundations/golden-identity.md)

---

**φ² + 1/φ² = 3 = TRINITY**
