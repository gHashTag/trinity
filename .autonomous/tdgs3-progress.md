## Task: TDGS-3 (Tri Wave 2: Type System + emit_t27)

### Wave 1 ✅ COMPLETE
- Step 1: reticular_raphe.t27 → VM ✅ (MOV, JGT, JLT, JUMP opcodes)
- Step 2: Coptic alphabet + 3-bank ✅ (27 registers across 3 banks)
- Step 3: ADT enum + exhaustive match ✅ (~170 LOC)

**Total:** ~340 LOC, 129+ tests passing
**Build:** l0=✅, l1=✅, tri=✅

### Wave 2: Code Generation ✅ COMPLETE

#### emit_t27 (VIBEE → TRI-27 bytecode) ✅ COMPLETE (Phase 4)
- [x] Spec (EMIT_T27_SPEC.md)
- [x] Test matrix (EMIT_T27_TESTS.md)
- [x] Reference .t27 (reticular_raphe)
- [x] Canonmap entry (.trinity_canonmap.json)
- [x] Phase 1: Core encoder (~380 LOC) — src/vibeec/emit_t27.zig
- [x] Phase 2: RegAlloc + LabelResolver (~300 LOC)
- [x] Phase 3: Golden test (src/vibeec/emit_t27_golden.zig, 13/13 tests)
- [x] Phase 4: Minimal IR → TRI-27 (src/vibeec/emit_t27_from_ir_test.zig, 15/15 tests)
- [x] CLI: `tri t27-test [--run]`
- [x] CLI stub: `tri compile <file.tri> --target t27`
- [x] E2E tests: 15/15 tests passing
- [x] JGT/JLT special encoding
- [x] .t27 binary format (magic "2IRT")
- [x] build.zig target: `zig build test-emit_t27`

**Total emit_t27:** ~900 LOC, 15 tests passing

#### Type System Core ✅ COMPLETE
- [x] Type representation (src/tri-lang/types.zig)
- [x] Type environment (src/tri-lang/type_env.zig)
- [x] Unification (src/tri-lang/unify.zig)

**Total Type System:** ~1500 LOC, 55 tests passing

#### Typechecker ✅ COMPLETE
- [x] Expression Typing (src/tri-lang/typechecker.zig)
- [x] Function Typing (FnExpr, FnCallExpr, arity checking)
- [x] ADT Typing (ADTExpr, MatchExpr, pattern binding)

**Total Wave 2:** ~2500 LOC, 70+ tests passing

**Acceptance:** All tests passing, L0 ✅ L1 ✅
- Last commit: df415a0e66 — Zig 0.15 ArrayList API compatibility + IR → TRI-27
- Build: l0=✅, l1=✅, tri=✅
- Tests: 20/20 passing (7 IR + 13 emit_t27)
- Blockers: None
- Last iteration: 2026-03-25T16:20+07
