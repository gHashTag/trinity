# emit_t27 Test Matrix

**Status**: TDGS-3 Wave 2 — Ready to implement

---

## Opcode Coverage (13 minimal subset)

| Opcode | VIBEE Source | Test File | Status |
|--------|--------------|-----------|--------|
| MOV | `x := y` | emit_mov.zig | ⏳ |
| LDI | `x := 42` | emit_ldi.zig | ⏳ |
| ADD | `x := a + b` | emit_add.zig | ⏳ |
| SUB | `x := a - b` | emit_sub.zig | ⏳ |
| MUL | `x := a * b` | emit_mul.zig | ⏳ |
| SHR | `x := a >> n` | emit_shr.zig | ⏳ |
| INC | `x++` | emit_inc.zig | ⏳ |
| LD | `x := [addr]` | emit_ld.zig | ⏳ |
| CMP | `if a < b` | emit_cmp.zig | ⏳ |
| JLT | `if a < b { label }` | emit_jlt.zig | ⏳ |
| JGT | `if a > b { label }` | emit_jgt.zig | ⏳ |
| JZ | `if a == 0 { label }` | emit_jz.zig | ⏳ |
| JNZ | `if a != 0 { label }` | emit_jnz.zig | ⏳ |
| JMP | `goto label` | emit_jmp.zig | ⏳ |
| HALT | `end` | emit_halt.zig | ⏳ |

---

## E2E Tests

| Case | Input | Expected | Status |
|------|-------|----------|--------|
| reticular_raphe | .tri file | byte-exact .t27 | ⏳ |
| single-op | tiny program | 1 instruction | ⏳ |
| branch | VIBEE labels | correct targets | ⏳ |
| call/ret | function | stack correct | ⏳ |

---

## Status Legend
- ⏳ TODO
- 🚧 WIP
- ✅ PASS
- ❌ FAIL

---

## Test Directory Structure

```
tests/tri27/emit/
├── emit_mov.zig        # MOV opcode tests
├── emit_ldi.zig        # LDI opcode tests
├── emit_add.zig        # ADD opcode tests
├── emit_jlt.zig        # JLT opcode tests
├── emit_jgt.zig        # JGT opcode tests
├── emit_jmp.zig        # JMP opcode tests
├── emit_halt.zig       # HALT opcode tests
├── reticular_raphe.zig # E2E: .tri → .t27 roundtrip
└── test_helpers.zig    # Shared test utilities
```

---

## Validation Strategy

### Phase 1: Opcode Unit Tests
Each opcode gets isolated tests:
- Correct encoding (byte-by-byte)
- Register field mapping
- Immediate value handling
- Edge cases (max imm, register boundaries)

### Phase 2: Integration Tests
Multi-opcode programs:
- reticular_raphe (canonical, 40 instructions)
- Simple arithmetic sequence
- Conditional branching
- Loop constructs

### Phase 3: VM Roundtrip
- emit_t27 → .t27 → tri-emu → state dump
- Compare with hand-written .t27 execution
- Verify identical CPU state (registers, memory, PC)

---

## Acceptance Criteria

1. ✅ All 15 opcode unit tests pass
2. ✅ reticular_raphe.tri → byte-exact .t27 match
3. ✅ VM execution produces identical state
4. ✅ `zig build emit_t27_tests` works
5. ✅ 0 regressions in tri-emu

---

## References

- Spec: `docs/research/EMIT_T27_SPEC.md`
- ISA: `docs/research/TDGS_3_WAVE1.md`
- Reference: `tests/tri27/reticular_raphe/expected.t27`
- VM: `src/tri27/emu/*.zig`
