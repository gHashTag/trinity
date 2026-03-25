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
- [ ] Emitter (~400 LOC) - Issue: #[TBD]
- [ ] Test coverage (15 opcodes)
- [ ] zig build emit_t27_tests

**Acceptance**: byte-exact .t27 match

#### Type System Core
- [ ] Type representation (src/tri-lang/types.zig)
- [ ] Type environment (src/tri-lang/type_env.zig)
- [ ] Unification (src/tri-lang/unify.zig)

**Estimated**: ~1000 LOC, 70 tests

- Last commit: c36ed7a4ad — Simplified JGT/JLT encoding
- Blockers: None (Zig 0.15 ArrayList API workaround needed)
- Last iteration: 2026-03-25T12:00+07
