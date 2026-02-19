# Golden Chain Enforcement Rules

**Version:** 1.0.0
**Date:** 2026-02-07
**Status:** MANDATORY

---

## Core Rule

> **ALL CODE MUST COME FROM .vibee SPEC → `tri gen` → .zig**
>
> **NO DIRECT ZIG WRITING. EVER.**

---

## The 16 Links (No Skipping)

| Link | Name | Action | Output |
|------|------|--------|--------|
| 1 | BASELINE | Analyze v(n-1) | Understanding |
| 2 | METRICS | Collect metrics | metrics/v(n-1).json |
| 3 | PAS_ANALYZE | Research patterns | Analysis notes |
| 4 | TECH_TREE | Design architecture | Tech tree diagram |
| 5 | **SPEC_CREATE** | **Create .vibee** | **specs/tri/feature.vibee** |
| 6 | **CODE_GENERATE** | **`tri gen`** | **generated/feature.zig** |
| 7 | TEST_RUN | `zig build test` | Test results |
| 8 | BENCHMARK_PREV | vs v(n-1) | Comparison |
| 9 | BENCHMARK_EXT | vs llama.cpp | Comparison |
| 10 | BENCHMARK_THEORY | vs optimal | Gap analysis |
| 11 | DELTA_REPORT | Improvement | Report |
| 12 | OPTIMIZE | Fix issues | Patches |
| 13 | DOCS | Documentation | Updated docs |
| 14 | TOXIC_VERDICT | Self-criticism | Verdict |
| 15 | GIT | Commit | Git log |
| 16 | LOOP | Decide next | IMMORTAL/MORTAL |

---

## Critical Links (Fail-Fast)

These MUST pass or pipeline ABORTS:
- **Link 7**: TEST_RUN - All tests must pass
- **Link 8**: BENCHMARK_PREV - No regression allowed

---

## Link 5: SPEC_CREATE (The ONLY Source of Truth)

### What to do:
```bash
# Create specification
vim specs/tri/feature_name.vibee
```

### Required sections in .vibee:
```yaml
name: feature_name
version: "1.0.0"
language: zig
module: feature_name

description: |
  What this feature does.

constants:
  # Define any constants

types:
  TypeName:
    description: "What this type represents"
    fields:
      field1: Type

behaviors:
  - name: function_name
    given: Precondition
    when: Action
    then: Result

test_cases:
  - name: test_name
    input: "..."
    expected: "..."
```

### DO NOT:
- Write any Zig code directly
- Create .zig files manually
- Skip this link

---

## Link 6: CODE_GENERATE (Generated Code Only)

### What to do:
```bash
# Generate code from spec
tri gen specs/tri/feature_name.vibee
# Output: generated/feature_name.zig
```

### Verify:
```bash
# Check generated file exists
ls generated/feature_name.zig
```

### DO NOT:
- Edit generated/feature_name.zig manually
- Write additional .zig files
- Add code not in spec

---

## Integration (After Link 6)

If you need to integrate generated code into src/tri/:

1. **Copy generated to src/tri/**:
```bash
cp generated/feature_name.zig src/tri/
```

2. **Add import to main.zig** (minimal change):
```zig
const feature = @import("feature_name.zig");
```

3. **Add command handler** (use generated types/functions only)

**NO NEW LOGIC in main.zig** - all logic must be in the generated module.

---

## Verification Checklist

Before committing, verify:

- [ ] .vibee spec exists in specs/tri/
- [ ] `tri gen` was run on the spec
- [ ] generated/*.zig exists
- [ ] NO direct Zig code written (except imports)
- [ ] All 16 links executed
- [ ] Tests pass
- [ ] No regression in benchmarks

---

## Prohibited Actions

| Action | Status |
|--------|--------|
| Write .zig without .vibee | **FORBIDDEN** |
| Skip Link 5 (SPEC_CREATE) | **FORBIDDEN** |
| Skip Link 6 (CODE_GENERATE) | **FORBIDDEN** |
| Edit generated/*.zig | **FORBIDDEN** |
| Skip tests | **FORBIDDEN** |
| Commit with regression | **FORBIDDEN** |

---

## Why This Matters

### Without Enforcement:
- Duplicate logic (spec + manual code)
- Bugs from inconsistency
- No improvement loop
- Chaos

### With Enforcement:
- Single source of truth (.vibee)
- Auto-generated code
- Verified improvement (Needle)
- Self-optimizing system

---

## Example: Correct Workflow

```bash
# Link 1-4: Analysis and planning
tri decompose "add progress bar"
tri plan

# Link 5: Create spec (THE ONLY PLACE TO WRITE LOGIC)
vim specs/tri/progress_bar.vibee

# Link 6: Generate code (NO MANUAL ZIG)
tri gen specs/tri/progress_bar.vibee

# Link 7: Test
zig build test

# Link 8-16: Benchmark, report, commit
tri verify
tri verdict
git add . && git commit
```

---

## Penalty for Violation

If direct Zig is written without .vibee:
1. Revert changes
2. Create proper .vibee spec
3. Re-run pipeline from Link 5
4. Document violation in TOXIC_VERDICT

---

**GOLDEN CHAIN IS LAW | NO SHORTCUTS | φ² + 1/φ² = 3**
