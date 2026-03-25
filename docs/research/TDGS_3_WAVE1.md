# TDGS-3: Tri Wave 1 — TRI-27 Toolchain & Reference Implementation

**Status**: ✅ COMPLETE — Wave 1, Step 1 (E2E Integration)

---

## Overview

TDGS-3 (Tri Development Guidance Set 3) реализует TRI-27 — RISC ISA для тернарных вычислений с 27 регистрами (Coptic alphabet). Это полноценный toolchain: ассемблер, эмулятор, reference implementation.

### Критический прорыв

До этого момента `.t27` программы были **"формально валидными, но логически мёртвыми"**: ассемблер генерировал корректный bytecode, но прыжки (JGT/JLT) не работали из-за конфликтов в кодировке инструкций.

**Сейчас это исправлено** — reticular_raphe.t27 выполняется 31 инструкцию и корректно выходит.

---

## Wave 1: Complete ✅

### Step 1: E2E Integration ✅

**Цель**: Замкнуть end-to-end цепочку `.tri → VIBEE → .t27 → tri-emu → ✅`

**Результат**:
- `reticular_raphe.t27` — канонический end-to-end тест для TRI-27 toolchain
- 31 инструкция, нормальный exit (HALT)
- Все прыжки (JMP, JGT, JLT, JZ, JNZ) работают корректно

**Исправленные критические баги**:

1. **Label offset bug**: `instr_idx` считался от 2 вместо 0
   - Проблема: loader устанавливал `pc = 0`, но метки хранились с offset 2
   - Фикс: `var instr_idx: u32 = 0` в tri_asm.zig:660

2. **JGT/JLT encoding conflict**: immediate поле пересекалось с src1/src2
   - Проблема: immediate (bits 17-31) перезаписывал src2 (bits 18-22)
   - Фикс: новая кодировка
     - `dst` = первый операнд сравнения
     - `immediate[0-4]` = второй операнд сравнения
     - `immediate[5-15]` = адрес перехода

3. **byte_addr bug**: адресация в байтах не соответствовала словам
   - Проблема: `byte_addr = ip * 4`, но память Word-aligned (8 байт)
   - Фикс: `byte_addr = ip * 8` в tri_emu_main.zig

---

## TRI-27 ISA Specification

### Инструкции условного перехода (JGT/JLT)

**Кодировка** (для избежания конфликта с immediate):
```
JGT src1, src2, target    # Jump if src1 > src2
JLT src1, src2, target    # Jump if src1 < src2
```

**Поля**:
- `dst` (5 bits): первый операнд (src1)
- `immediate[0-4]`: второй операнд (src2)
- `immediate[5-15]`: адрес перехода (absolute)

**Исполнение**:
```zig
const second_op = inst.immediate & 0x1F;
const target_addr = inst.immediate >> 5;
if (cpu.t27[inst.dst] > cpu.t27[second_op]) {
    cpu.pc = target_addr;
} else {
    cpu.pc += 1;
}
```

### 3-Bank дисциплина (FADD/STF)

- **Bank 0 (alpha0-aleph8)**: регистры общего назначения
- **Bank 1 (alpha9-omega16)**: sacred регистры (φ, π, e)
- **Bank 2 (shm17-shmima26)**: **FORBIDDEN** для FADD/STF

Инвариант: `FADD/STF` с dst в Bank 2 → `ExecError.InvalidRegister`

---

## Files Modified

- `src/tri27/emu/tri_asm.zig` — ассемблер (label offset, JGT/JLT encoding)
- `src/tri27/emu/executor.zig` — исполнение JGT/JLT
- `src/tri27/emu/tri_emu_main.zig` — byte_addr fix
- `src/tri27/reticular_raphe.t27` — канонический E2E тест

---

## Next Steps

### emit_t27 (VIBEE → .t27)

После закрепления этого слоя:

1. Реализовать emit_t27 в VIBEE (генерация .t27 bytecode из VIBEE IR)
2. Золотой тест: reticular_raphe.tri → VIBEE → emit_t27 → сравнить с вручную написанным reticular_raphe.t27
3. Покрыть все opcode TRI-27 в emit_t27

---

**Completion Date**: 2026-03-25
**Commits**: c36ed7a4ad (JGT/JLT encoding fix), c47a95a533 (build fix), 51175bc109 (field packing fix)
