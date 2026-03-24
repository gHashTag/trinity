# Wave 1: TRI-27 Reference Implementation (reticularraphe.t27)

## Step 1: reticularraphe.t27 → VM ✅ COMPLETED
- [x] Проверить что TRI-27 VM в src/temple/tri27_core.zig поддерживает все opcodes из reticular_raphe.t27
- [x] Убедиться что все opcodes реализованы в executor.zig
- [x] Создать unit тесты для новых opcodes

### Результат

✅ **Opcodes added:**
- MOV (0x1E) — move register to register
- JGT (0x44) — jump if greater than (src1 > src2)
- JLT (0x45) — jump if less than (src1 < src2)
- JUMP alias — "jump" maps to JMP

✅ **Files modified:**
- `src/tri27/emu/decoder.zig` — added opcodes to enum
- `src/tri27/emu/executor.zig` — implemented execution logic
- `src/tri27/emu/encoder_simple.zig` — added encoder functions + tests
- `src/tri27/emu/asm_parser.zig` — added JUMP alias support

✅ **Tests verified:**
- All decoder tests: ✅ PASS (5 tests)
- All executor tests: ✅ PASS (13 tests)
- All encoder tests: ✅ PASS (40 tests)
- All asm_parser tests: ✅ PASS (67 tests)

## Step 2: Coptic alphabet + 3-bank validation ✅ COMPLETED
- [x] Создать src/tri27/coptic.zig с CopticReg enum(u5)
- [x] 27 вариантов (alpha0-shmima26)
- [x] bank() → u2 method (возвращает номер банка 0-2)
- [x] Обновить asm_parser.zig для разбора Coptic регистров
- [x] Добавить unit тесты

### Результат

✅ **CopticReg implementation:**
- 27 registers across 3 banks (0-8, 9-17, 18-26)
- Bank 0 (ALU): alpha0-theta8
- Bank 1 (Sacred): iota9-rho17
- Bank 2 (Const): sigma18-shmima26
- Added shmima26 (27th Coptic letter)

✅ **Tests verified:**
- All coptic tests: ✅ PASS (2 tests)
- All asm_parser tests: ✅ PASS (67 tests)
- Coptic name parsing: case-insensitive, no allocator needed

✅ **Files modified:**
- `src/tri27/coptic.zig` — complete CopticReg enum with 27 variants
- `src/tri27/emu/asm_parser.zig` — COPTIC_NAMES array lookup, case-insensitive

### Inварианты
- L0 (Temple): ✅ GREEN
- L1 (Queens): ✅ GREEN

### Коммиты
- feat(tri27): Add MOV, JGT, JLT opcodes for reticularraphe.t27 (#411)
- fix(tri27): Fix coptic name parsing - use COPTIC_NAMES array, fix deprecated allocator (#418)

## Step 3: ADT enum + exhaustive match ✅ COMPLETED
- [x] Создать src/tri-lang/adt_enum.zig
- [x] ADT<T> type — generic algebraic data type
- [x] Variants with optional payloads (A(x) | B | C(y,z))
- [x] Exhaustive match checking at compile time
- [x] Pattern matching syntax support

### Результат

✅ **ADT Enum implementation:**
- Variant struct with name and payload_type_names
- ADT struct with name and variants list
- parseADT() — parses syntax: `type T = A(x) | B | C(y,z)`
- parseVariants() — helper for variant parsing
- isExhaustive() — compile-time exhaustive match checking

✅ **Tests verified:**
- All adt_enum tests: ✅ PASS (4 tests)

✅ **Files created:**
- `src/tri-lang/adt_enum.zig` — ADT enum with exhaustive match (~170 LOC)

### Inварианты
- L0 (Temple): ✅ GREEN
- L1 (Queens): ✅ GREEN

### Коммиты
- feat(tri27): Add MOV, JGT, JLT opcodes for reticularraphe.t27 (#411)
- fix(tri27): Fix coptic name parsing - use COPTIC_NAMES array, fix deprecated allocator (#418)
- feat(tri-lang): ADT Enum + Exhaustive Match (#414)

## Wave 1 Summary ✅ COMPLETED
All three steps of Wave 1 are now complete:
1. ✅ reticularraphe.t27 → VM (MOV, JGT, JLT, JUMP opcodes)
2. ✅ Coptic alphabet + 3-bank validation (27 registers)
3. ✅ ADT enum + exhaustive match

**Total LOC added:** ~340 LOC across tri27 and tri-lang modules
**Total tests:** 4+67+40+13+5 = 129+ tests passing
