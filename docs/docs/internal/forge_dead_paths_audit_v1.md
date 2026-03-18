# FORGE Dead Paths Audit — Trinity v2.2.0

**Date:** 2026-03-08
**Purpose:** Identify unused/dead code paths in FORGE synthesis
**Status:** DRAFT — TODO 7 SA-5

---

## Executive Summary

The FORGE Zig toolchain contains several dead or unused code paths:

1. **FORGE main.zig entry point** — Not integrated with CLI
2. **Strategy pattern** — Partially implemented, not used
3. **Multiple placement strategies** — Only simulated annealing works
4. **Alternative toolchain support** — Only openXC7 is functional

---

## Dead Path 1: FORGE Binary Entry Point

**Location:** `src/forge/main.zig`

**Status:** ❌ DEAD — No binary integration

**Description:**
- Contains a `pub fn main()` that could compile to a standalone FORGE binary
- Not called by `tri fpga build` or any other Trinity command
- Superseded by synth.sh → openXC7 Docker flow

**Decision:** **DEPRECATE**
- Keep for potential future native toolchain use
- Add documentation that it's not currently used
- TODO 8+: Re-enable after OLOGIC bugs fixed

---

## Dead Path 2: Strategist Pattern

**Location:** `src/forge/strategist.zig`

**Status:** ⚠️ PARTIAL — Only placement strategy works

**Description:**
- Defines `PlacementStrategy` enum with options: SimulatedAnnealing, Genetic, ForceDirected
- Only SimulatedAnnealing is implemented in placer.zig
- Other strategies are stubs or incomplete

**Decision:** **SIMPLIFY**
- Remove unused strategy enums
- Keep only SimulatedAnnealing
- Document as single supported strategy

---

## Dead Path 3: Alternative Toolchain Support

**Location:** `src/forge/main.zig`, `synth.sh` variants

**Status:** ❌ UNUSED — Only openXC7 works

**Description:**
- Code references to "FORGE native" toolchain
- synth_10k.sh, synth_tqnn.sh imply other targets
- Only xc7a100t with openXC7 Docker is verified

**Decision:** **REMOVE SPECIALIZED SCRIPTS**
- synth_10k.sh, synth_10k_all.sh, synth_tqnn.sh: Mark as deprecated
- synth_conscious.sh: DELETE (unknown if ever worked)
- Keep only synth.sh and synth_batch.sh active

---

## Dead Path 4: Direct Yosys/nextpnr Calls

**Location:** Documentation mentions direct toolchain invocation

**Status:** ⚠️ REFERENCE ONLY — Not recommended

**Description:**
- Some docs show direct Docker commands for Yosys, nextpnr
- These bypass synth.sh wrapper
- Not integrated with CLI

**Decision:** **DOCUMENT AS REFERENCE**
- Keep for advanced users
- Clearly label as "manual" vs "recommended" path
- Primary path should always be `tri fpga build`

---

## Unused Functions

| File | Function | Status | Action |
|------|----------|--------|--------|
| `src/forge/strategist.zig` | `selectGeneticStrategy()` | ❌ Stub | Remove |
| `src/forge/strategist.zig` | `selectForceDirectedStrategy()` | ❌ Stub | Remove |
| `src/forge/strategist.zig` | `learn()` | ⚠️ Empty | Document as TODO |
| `src/forge/interfaces.zig` | `ITriParser.parse()` | ✅ Used | Keep |
| `src/forge/interfaces.zig` | `IAutoFixEngine.analyzeFailure()` | ✅ Used | Keep |
| `src/forge/interfaces.zig` | `IAutoFixEngine.autoFix()` | ✅ Used | Keep |

---

## Unused Specialized Synth Scripts

| Script | Purpose | Status | Action |
|---------|---------|--------|--------|
| `synth_10k.sh` | xc7a35t target | ⚠️ Untested | Deprecate |
| `synth_10k_all.sh` | Batch for 10K | ⚠️ Untested | Deprecate |
| `synth_tqnn.sh` | TQNN-specific | ⚠️ Unknown | Deprecate |
| `synth_conscious.sh` | Consciousness | ❌ Unknown | DELETE |

---

## Memory-Efficient FORGE Binary

**Location:** `src/forge/main.zig`

**Status:** ❌ NOT INTEGRATED

**Description:**
- FORGE main.zig can compile to standalone binary
- Takes JSON input from Yosys
- Outputs bitstream directly
- Not integrated with tri CLI

**Action:** **DOCUMENT**
- Keep as potential future option
- Add README explaining how to use standalone
- Note that it's not the primary path

---

## Recommendations

### Immediate (TODO 7)
1. Add deprecation header to synth.sh
2. Delete synth_conscious.sh (never worked)
3. Document FORGE main.zig as "standalone only"
4. Remove unused strategy enums

### Post-GA (TODO 8+)
1. Fix FORGE OLOGIC bugs
2. Re-enable native toolchain as option
3. Add `--toolchain forge` flag
4. Implement genetic strategy if needed

---

## Files to Delete

```
fpga/openxc7-synth/synth_conscious.sh    # Never worked
```

## Files to Deprecate

```
fpga/openxc7-synth/synth_10k.sh         # Untested target
fpga/openxc7-synth/synth_10k_all.sh     # Untested target
fpga/openxc7-synth/synth_tqnn.sh        # Unknown purpose
```

## Files to Keep Active

```
fpga/openxc7-synth/synth.sh              # Main synthesis (deprecated but working)
fpga/openxc7-synth/synth_batch.sh        # Batch synthesis
src/forge/*.zig                           # Keep for future native toolchain
```

---

φ² + 1/φ² = 3 | TODO 7 SA-5: DEAD CODE AUDIT
