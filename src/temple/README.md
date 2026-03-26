# TTT — Trusted Tri Temple — L0 Sacred Layer

> φ² + 1/φ² = 3 | TRINITY

## What is TTT?

TTT (Trusted Tri Temple) is the **sacred layer L0** of Trinity — the mathematical DNA that must not change. It fixes three core components:

1. **Sacred Math** — φ, GF16/TF3, trit/try/tetword arithmetic
2. **TRI-27 Core** — VM kernel, .t27 format, 36 sacred opcodes
3. **Tri Lang Core** — Result type, pattern matching, linear types, Effects + Handlers

## Invariants

- **DRY Principle**: All TTT code is re-exported from existing implementations
- **≤3000 LOC**: Total TTT code ≤3000 LOC (tests excluded)
- **Self-Contained Tests**: `tests.zig` has zero dependencies on L1-L3
- **No Modifications**: TTT files cannot be modified without TEMPLE_RITUAL

## Structure

```
src/temple/
├── sacred_math.zig   # φ, Trit/Trit27, ternary logic (~300 LOC)
├── tri27_core.zig    # TRI-27 ISA, Memory, Opcodes (~200 LOC)
├── tri_lang_core.zig # Result, Patterns, Linear, Effects (~400 LOC)
├── tests.zig         # Self-contained unit tests (~500 LOC)
└── README.md         # This file
```

**Total**: ~900 LOC code + ~500 LOC tests (well under 3000 LOC limit ✓)

## TTT Marker

Every TTT file begins with this header:

```zig
// TTT — Trusted Tri Temple — L0 Sacred Layer
// DO NOT MODIFY without TEMPLE_RITUAL
// Re-exports from: <source files>
//
// φ² + 1/φ² = 3 | TRINITY
```

## Build & Test

```bash
# Build TTT as standalone executable
zig build temple

# Run all TTT tests
zig build temple test

# Run TTT executable (shows verification)
./zig-out/bin/temple
```

## Temple Ritual (How to Modify TTT)

If you need to change TTT (rare!):

1. **Set the ritual flag**:
   ```bash
   export TEMPLE_RITUAL=1
   ```

2. **Make your changes** in `src/temple/`

3. **Verify TTT compiles and tests pass**:
   ```bash
   zig build temple
   zig build temple test
   ```

4. **Commit with ritual message**:
   ```bash
   git add src/temple/
   git commit -m "feat(temple): <description> #TEMPLE_RITUAL"
   ```

## Protection

- **PreToolUse Hook**: Blocks writes to `src/temple/**` without `TEMPLE_RITUAL` flag
- **CI Check**: (Optional) Validates TEMPLE_RITUAL label on PRs touching TTT
- **CLI Rule**: `.claude/rules/no-touch-ttt.md` documents forbidden zone

## Sacred Identity

The sacred identity `φ² + 1/φ² = 3` is the mathematical foundation of Trinity:

```zig
const phi = 1.618033988749895;  // Golden ratio
const phi_sq = phi * phi;
const inv_phi_sq = 1.0 / phi_sq;
const result = phi_sq + inv_phi_sq;  // = 3.0 exactly
```

This identity connects:
- Golden ratio (φ)
- Balanced ternary (3)
- Trinity (3-in-1)

## Re-Export Sources

| TTT Module | Re-exports from |
|------------|-----------------|
| `sacred_math.zig` | `src/b2t/trit.zig`, `src/ternary/logic.zig`, `src/vm/jit.zig` |
| `tri27_core.zig` | `src/tri27/emu/*.zig`, `src/vm/opcodes.zig` |
| `tri_lang_core.zig` | `src/tri-lang/result_type.zig`, `src/tri-lang/bit_trit_patterns.zig`, `src/tri-lang/linear_types.zig`, `src/tri-lang/effects.zig` |

## Dependencies

TTT has **zero runtime dependencies** on L1-L3 layers:
- No stdlib dependencies beyond `std.testing` for tests
- No imports from `src/tri/`, `src/vsa.zig`, etc.
- Self-contained verification possible

## Version

TTT Version: 1.0.0
Trinity: Wave 9 (Linear Types + Ownership)
Last Updated: 2025-03-25

---

**Remember**: TTT is sacred. Modify only with ritual.
