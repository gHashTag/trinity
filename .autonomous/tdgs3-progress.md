## Task: TDGS-3 (Tri Wave 1: reticularraphe + Coptic)

### Wave 1 ✅ COMPLETE
- Step 1: reticular_raphe.t27 → VM ✅ (MOV, JGT, JLT, JUMP opcodes)
- Step 2: Coptic alphabet + 3-bank ✅ (27 registers across 3 banks)
- Step 3: ADT enum + exhaustive match ✅ (~170 LOC)

**Total:** ~340 LOC, 129+ tests passing
**Build:** l0=✅, l1=✅, tri=✅

### Wave 2: Code Generation

#### emit_t27 (VIBEE → TRI-27 bytecode)
- [x] Spec (EMIT_T27_SPEC.md)
- [x] Test matrix (EMIT_T27_TESTS.md)
- [x] Reference .t27 (reticular_raphe)
- [x] Canonmap entry (.trinity_canonmap.json)
- [x] Phase 1: Core encoder (~380 LOC) — src/vibeec/emit_t27.zig
- [x] Phase 2: RegAlloc + LabelResolver (~300 LOC additional)
- [x] Phase 3: Golden test (src/vibeec/emit_t27_golden.zig, 13/13 tests passing)
- [x] E2E tests: 13/13 tests passing
- [x] JGT/JLT special encoding (src2 in imm[11-15], target in imm[0-10])
- [x] .t27 binary format (magic "2IRT" + header + code section)
- [x] build.zig target: `zig build test-emit_t27`

**Acceptance**: 13/13 tests passing

#### Type System Core
- [ ] Type representation (src/tri-lang/types.zig)
- [ ] Type environment (src/tri-lang/type_env.zig)
- [ ] Unification (src/tri-lang/unify.zig)

**Estimated**: ~1000 LOC, 70 tests

- Last commit: (uncommitted) — Phase 3 golden test complete
- Blockers: None
- Last iteration: 2026-03-25T14:30+07
