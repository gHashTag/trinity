# emit_t27: TRI-27 Code Generator from VIBEE IR

**Task**: Implement code generation backend for TRI-27 ISA in VIBEE compiler

**Status**: Phase 4 COMPLETE ✅

**Phase 1 Complete** (2026-03-25):
- ✅ src/vibeec/emit_t27.zig (~380 LOC) - Core encoder
- ✅ src/vibeec/emit_t27_test.zig (~260 LOC) - 7 tests passing
- ✅ JGT/JLT special encoding implemented
- ✅ .t27 binary format (magic "2IRT" + header)

**Phase 2 Complete** (2026-03-25):
- ✅ RegAlloc: Deterministic register allocator (t0..t3 = state, t4..t7 = loop, t8..t26 = GP)
- ✅ LabelResolver: Two-pass label resolution for jump instructions
- ✅ E2E tests: 3 tests for reticular_raphe bytecode format
- ✅ 11/11 tests passing

**Phase 3 Complete** (2026-03-25):
- ✅ Golden test: src/vibeec/emit_t27_golden.zig (IR → emit_t27 → .t27)
- ✅ SimpleIR struct matching reticular_raphe.t27 structure
- ✅ Structural comparison tests (decodeTri27Word validation)
- ✅ 13/13 tests passing
- ✅ build.zig target: `zig build test-emit_t27`

**Phase 4 Complete** (2026-03-25):
- ✅ Minimal IR → TRI-27 converter (src/vibeec/emit_t27_from_ir_test.zig)
- ✅ MinimalIRToTri27 struct with full opcode mapping
- ✅ 4 new tests (LDI+HALT, ADD+labels, JNZ, reticular_raphe subset)
- ✅ 15/15 tests passing (4 new + 11 existing)
- ✅ CLI command: `tri t27-test [--run]`
- ✅ CLI stub: `tri compile <file.tri> --target t27` (TODO: tri_lang integration)

**Remaining (Phase 5+)**:
- [ ] Full VIBEE IR → emit_t27 integration (ir.zig compatibility with Zig 0.15)
- [ ] .tri parser → IR generation
- [ ] Byte-exact comparison with canonical reticular_raphe.t27

---

## Minimal Viable Opcode Subset (v1)

Based on analysis of `reticular_raphe.t27` (canonical E2E test), emit_t27 v1 MUST support:

| Opcode | Description | Operands | Usage in reticular_raphe |
|--------|-------------|----------|-------------------------|
| `LDI` | Load Immediate | dst, imm | 13× |
| `MOV` | Move register | dst, src | 5× |
| `ADD` | Add | dst, src1, src2 | 4× |
| `MUL` | Multiply | dst, src1, src2 | 4× |
| `SHR` | Shift Right | dst, src, imm | 1× |
| `INC` | Increment | dst | 1× |
| `LD` | Load from memory | dst, addr | 1× |
| `JLT` | Jump if Less Than | src1, src2, target | 2× |
| `JGT` | Jump if Greater Than | src1, src2, target | 1× |
| `JZ` | Jump if Zero | src, target | 2× |
| `JNZ` | Jump if Not Zero | src, target | 2× |
| `JMP` | Unconditional Jump | target | 4× |
| `HALT` | Halt execution | — | 1× |

**Total**: 13 opcodes, 40 instruction instances

---

## Encoding Contract

### Register Encoding
- Coptic alphabet: `alpha0..shmima26` (27 registers, bank 0)
- Assembly syntax: `t0..t26` maps to registers 0-26

### Instruction Encoding (from TDGS_3_WAVE1.md)

**JGT/JLT** (special encoding to avoid field conflict):
```
JGT src1, src2, target    # dst=src1, imm[0-4]=src2, imm[5-15]=target
JLT src1, src2, target    # same encoding
```

**Standard format**:
```
LDI dst, imm              # Load immediate to register
MOV dst, src              # Copy register to register
ADD dst, src1, src2       # dst = src1 + src2
MUL dst, src1, src2       # dst = src1 * src2
SHR dst, src, imm         # dst = src >> imm (arithmetic shift right)
INC dst                   # dst++
LD dst, addr              # dst = mem[addr]
JZ src, target            # if src == 0, jump to target
JNZ src, target           # if src != 0, jump to target
JMP target                # jump to target
HALT                      # stop execution
```

---

## Acceptance Criteria

### Phase 1: Code Generation

1. **Add emit_t27 backend to VIBEE**
   - Location: `src/vibee/emit_t27.zig` (new file)
   - Function signature: `pub fn emitT27(allocator: Allocator, ir: []const IR.Instruction) ![]u8`

2. **Implement opcode subset**
   - All 13 opcodes from table above
   - Correct encoding per TDGS_3_WAVE1.md spec
   - Register allocation: use t0..t26 as allocated

3. **Output format**
   - .t27 binary format (as defined in loader.zig)
   - Header: "2IRT" magic + version + section count
   - Code section with encoded instructions

### Phase 2: E2E Validation

1. **Create test framework**
   - Location: `tests/tri27/reticular_raphe/`
   - Files:
     - `expected.t27` — canonical hand-written bytecode
     - `generated.t27` — output from emit_t27
     - `test_emit_t27.zig` — validation test

2. **Validation test**
   ```zig
   // 1. Assemble expected.t27
   // 2. Run emit_t27 on VIBEE IR → generated.t27
   // 3. Compare byte-by-byte (or instruction-by-instruction)
   // 4. Run both through tri-emu, compare final state
   ```

3. **Success criteria**
   - `generated.t27` == `expected.t27` (byte-identical OR instruction-equivalent)
   - Both produce identical CPU state after execution
   - Test passes reproducibly

---

## Files to Create/Modify

### New Files
- `src/vibee/emit_t27.zig` — code generator
- `tests/tri27/reticular_raphe/expected.t27` — canonical bytecode
- `tests/tri27/reticular_raphe/test_emit_t27.zig` — validation test

### Modify
- `src/vibee/vibee_parser.zig` — add emit_t27 option
- `src/vibee/vibee_compiler.zig` — wire up backend
- `build.zig` — add test target

---

## Out of Scope (v2+)

- VSA operations (DOT, BIND, BUNDLE2/3)
- Sacred constants (PHI_CONST, PI_CONST, E_CONST)
- FADD/STF (bank-restricted operations)
- CALL/RET (subroutine calls)
- Complex addressing modes

These can be added incrementally after v1 validation passes.

---

## Dependencies

- ✅ `tri-emu` — working TRI-27 emulator
- ✅ `reticular_raphe.t27` — canonical test case
- ✅ `TDGS_3_WAVE1.md` — ISA specification
- ✅ VIBEE IR — already defined in src/vibee/

---

**Estimated Complexity**: ~500 LOC (emit_t27) + ~200 LOC (tests)
**Estimated Time**: 2-4 hours for MVP
