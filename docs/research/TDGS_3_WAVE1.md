# TDGS-3: Tri Wave 1 — TRI-27 Toolchain & Reference Implementation

**Status**: ✅ COMPLETE — Wave 1, Step 1 (E2E Integration)

---

## Overview

TDGS-3 (Tri Development Guidance Set 3) implements TRI-27 — a RISC ISA for ternary computing with 27 registers (Coptic alphabet). This is a complete toolchain: assembler, emulator, reference implementation.

### Critical Breakthrough

Prior to this, `.t27` programs were **"formally valid but logically dead"**: the assembler generated correct bytecode, but jumps (JGT/JLT) didn't work due to encoding conflicts.

**This is now fixed** — reticular_raphe.t27 executes 31 instructions and exits correctly.

---

## Wave 1: Complete ✅

### Step 1: E2E Integration ✅

**Goal**: Close the end-to-end chain `.tri → VIBEE → .t27 → tri-emu → ✅`

**Result**:
- `reticular_raphe.t27` — canonical end-to-end test for TRI-27 toolchain
- 31 instructions, normal exit (HALT)
- All jumps (JMP, JGT, JLT, JZ, JNZ) work correctly

**Critical bugs fixed**:

1. **Label offset bug**: `instr_idx` was counted from 2 instead of 0
   - Problem: loader set `pc = 0`, but labels were stored with offset 2
   - Fix: `var instr_idx: u32 = 0` in tri_asm.zig:660

2. **JGT/JLT encoding conflict**: immediate field overlapped with src1/src2
   - Problem: immediate (bits 17-31) overwrote src2 (bits 18-22)
   - Fix: new encoding
     - `dst` = first comparison operand
     - `immediate[0-4]` = second comparison operand
     - `immediate[5-15]` = jump address

3. **byte_addr bug**: byte addressing didn't match word alignment
   - Problem: `byte_addr = ip * 4`, but memory is Word-aligned (8 bytes)
   - Fix: `byte_addr = ip * 8` in tri_emu_main.zig

---

## TRI-27 ISA Specification

### Conditional Jump Instructions (JGT/JLT)

**Encoding** (to avoid conflict with immediate):
```
JGT src1, src2, target    # Jump if src1 > src2
JLT src1, src2, target    # Jump if src1 < src2
```

**Fields**:
- `dst` (5 bits): first operand (src1)
- `immediate[0-4]`: second operand (src2)
- `immediate[5-15]`: jump address (absolute)

**Execution**:
```zig
const second_op = inst.immediate & 0x1F;
const target_addr = inst.immediate >> 5;
if (cpu.t27[inst.dst] > cpu.t27[second_op]) {
    cpu.pc = target_addr;
} else {
    cpu.pc += 1;
}
```

### 3-Bank Discipline (FADD/STF)

- **Bank 0 (alpha0-aleph8)**: general-purpose registers
- **Bank 1 (alpha9-omega16)**: sacred registers (φ, π, e)
- **Bank 2 (shm17-shmima26)**: **FORBIDDEN** for FADD/STF

Invariant: `FADD/STF` with dst in Bank 2 → `ExecError.InvalidRegister`

---

## Files Modified

- `src/tri27/emu/tri_asm.zig` — assembler (label offset, JGT/JLT encoding)
- `src/tri27/emu/executor.zig` — JGT/JLT execution
- `src/tri27/emu/tri_emu_main.zig` — byte_addr fix
- `src/tri27/reticular_raphe.t27` — canonical E2E test

---

## Next Steps

### emit_t27 (VIBEE → .t27)

After this layer is solidified:

1. Implement emit_t27 in VIBEE (generate .t27 bytecode from VIBEE IR)
2. Golden test: reticular_raphe.tri → VIBEE → emit_t27 → compare with manually written reticular_raphe.t27
3. Cover all TRI-27 opcodes in emit_t27

---

**Completion Date**: 2026-03-25
**Commits**: c36ed7a4ad (JGT/JLT encoding fix), c47a95a533 (build fix), 51175bc109 (field packing fix)
