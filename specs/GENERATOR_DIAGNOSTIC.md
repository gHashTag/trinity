# Generator Diagnostic Report — Issue #70

**Branch:** `fix/pipeline-generator`
**Date:** 2026-03-10
**Commits:** `1f5ff4f2f` (Round 1), `1f5d2ae93` (Round 2)

---

## Full Batch Results

| Metric | Baseline | Round 1 | Round 2 (Final) |
|--------|----------|---------|-----------------|
| Sample test | 2/10 (20%) | 7/10 (70%) | 13/19 (68%) |
| **Full batch (371 Zig specs)** | ~15% est. | — | **310/359 (86%)** |

**Breakdown of 371 total specs:**
- 2 Python → excluded
- 10 Verilog (`language: varlog`) → excluded from Zig ast-check
- **359 Zig specs → 310 PASS, 49 FAIL, 0 CRASH**

---

## Failure Categories (49 failures)

| Category | Count | % of Fails | Example | Generator Fix? |
|----------|-------|------------|---------|----------------|
| **Undeclared identifier** | 28 | 57% | `Config`, `Allocator`, `CodeBuilder`, `Array` | Partial — type mapping |
| **Expected comma after field** | 6 | 12% | `List TheoryState` → `[]const TheoryState` | YES — `List T` space syntax |
| **Other syntax** | 8 | 16% | `pub` inside fn, `align`, string literal | Mixed |
| **Duplicate struct member** | 3 | 6% | `init`, `ELASTIC_WEIGHT_DECAY` | YES — dedup needed |
| **Unused function parameter** | 3 | 6% | spec body doesn't use declared params | SPEC_QUALITY |
| **Undeclared fn/const** | 1 | 2% | `recordLifecycleEvent` | SPEC_QUALITY |

### Subcategory: Undeclared Identifiers (28)

| Identifier | Count | Root Cause | Fix |
|------------|-------|------------|-----|
| `Config` | 6 | Spec impl references external `Config` type | SPEC_QUALITY |
| `Allocator` | 4 | Missing `std.mem.Allocator` import | Generator: add import |
| `CodeBuilder` | 3 | Spec impl references internal type | SPEC_QUALITY |
| `Array` | 2 | `Array` not mapped → should be `[]T` | TYPE_MAPPING |
| `Self` | 1 | Missing struct self-reference | Generator: emit `const Self = @This()` |
| `String` | 1 | `String` not mapped → `[]const u8` | TYPE_MAPPING |
| Other | 11 | Various domain-specific types | SPEC_QUALITY |

---

## Per-Spec Results (original 20-spec test)

| # | Spec | Size | R1 | R2 | Error Category |
|---|------|------|----|----|----------------|
| 1 | dynamic_memory | S | PASS | **PASS** | — |
| 2 | tri_search_commands | S | PASS | **PASS** | — |
| 3 | chemistry_cli | M | PASS | **PASS** | — |
| 4 | math_compute | M | PASS | **PASS** | — |
| 5 | evolving_dark_energy | L | PASS | **PASS** | — |
| 6 | holy_core_parser_phase1 | L | PASS | **PASS** | — |
| 7 | holy_core_type_resolver | L | PASS | **PASS** | — |
| 8 | spec_lint | M | FAIL | **PASS** | Fixed: enum escaping |
| 9 | tri_devutil_commands | M | FAIL | **PASS** | Fixed: Option[T], dedup |
| 10 | autonomous_lifecycle | M | FAIL | **PASS** | Fixed: const error |
| 11 | add_hello_command | S | — | **PASS** | — |
| 12 | sacred_constants | S | — | **PASS** | — |
| 13 | pipeline_executor | S | — | **PASS** | — |
| 14 | holy_core_emitter_phase1 | XL | FAIL | FAIL | D: duplicate `init` member |
| 15 | swarm_agents | XXL | FAIL | FAIL | D: unused params |
| 16 | swarm_coordinator | XXL | FAIL | FAIL | D: unused params |
| 17 | vm_integration_v7 | L | FAIL | FAIL | D: undeclared `VSARegisters` |
| 18 | governance_agent | L | FAIL | FAIL | D: undeclared `distribution` |
| 19 | qrl_agent | M | — | SKIP | Python spec |
| 20 | autonomous_lifecycle | M | — | FAIL | D: undeclared fn |

---

## Fixes Applied

### Round 1 (commit `1f5ff4f2f`) — 5 fixes

| Fix | File | Impact |
|-----|------|--------|
| YAML list-format fields | `parser_sections.zig` | math_compute, evolving_dark_energy |
| `List[T]` bracket type mapping | `utils.zig` | tri_search_commands, chemistry_cli |
| Behavior body sanitization | `emitter.zig` | # comments, .error escaping, pseudocode detection |
| Test generation safety | `tests_gen.zig` | dynamic_memory |
| Constants & enum safety | `trinity-nexus/.../emitter.zig` | evolving_dark_energy |

### Round 2 (commit `1f5d2ae93`) — 4 fixes

| Fix | File | Impact |
|-----|------|--------|
| Enum variant escaping (vibeec) | `emitter.zig` | spec_lint (`error,` variant) |
| `Option[T]` bracket notation | `utils.zig` | tri_devutil_commands |
| `const error` → `const err` | `emitter.zig` | autonomous_lifecycle |
| Struct field deduplication | `emitter.zig` | tri_devutil_commands (dup `zig_files`) |

---

## Next Steps (TIER 2 fixes for 86% → 95%)

### P0: `List T` space-separated type (6 fails)
**File:** `src/vibeec/codegen/utils.zig`
`List TheoryState` → `[]const TheoryState`. The mapper handles `List<T>` and `List[T]` but not `List T`.

### P1: Missing standard imports (4 fails)
**File:** `src/vibeec/codegen/emitter.zig`
Add `const Allocator = std.mem.Allocator;` when implementation references `Allocator`.

### P2: `Array<T>` / `Array` type mapping (2 fails)
**File:** `src/vibeec/codegen/utils.zig`
Map `Array` → `[]T` (or `std.ArrayList(T)`).

### P3: `String` type mapping (1 fail)
**File:** `src/vibeec/codegen/utils.zig`
Map bare `String` → `[]const u8` (may already exist but not matching).

### P4: Self reference in structs (1 fail)
**File:** `src/vibeec/codegen/emitter.zig`
Emit `const Self = @This();` at top of struct when `Self` is used.

---

## Files Modified

| File | Changes |
|------|---------|
| `src/vibeec/parser_sections.zig` | parseFields() + parseConstants() YAML list-format |
| `src/vibeec/codegen/utils.zig` | mapType() — List[T], list<T>, Option[T], aliases |
| `src/vibeec/codegen/emitter.zig` | sanitizeImplementation, containsNonZigContent, enum escaping, struct dedup, behavior dedup |
| `src/vibeec/codegen/tests_gen.zig` | Safe compile-time test for similarity behaviors |
| `trinity-nexus/lang/src/codegen/emitter.zig` | Same sanitization + isValidZigIdentifier + enum escaping |
| `trinity-nexus/lang/src/spec_compiler.zig` | mapType() — same additions as utils.zig |
| `trinity-nexus/lang/src/vibee_parser.zig` | parseFields/parseConstants (secondary code path) |
