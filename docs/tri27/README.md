# TRI‑27 — Ternary Computing ISA

> **Trinity S³AI DNA**: φ² + 1/φ² = 3

**Strand III** — Language & Hardware Bridge

---

## Overview

TRI‑27 — тритный (ternary) RISC процессор с 27 тритами и уникальным управлением.

### Architecture

```
.tri spec (Single Source of Truth)
    ↓
TRI-27 language (Ternary types, AST)
    ↓              ↓
    Zig Backend (CPU)          Verilog Backend (FPGA)
```

### Word Layout

| Bit | Регистр | Размер | Назначение |
|-----|--------|------|------------------|
| r0-r25 | 25 трит | 6.25K | Глобальный накопитель |
| r0-r20 | 20 трит | 5 бит | r1-r24 | Локальный накопитель |
| r0-r17 | 17 трит | 4.25 бита | r1-r16 | Обычные регистры |
| r0-r15 | 15 трит | 4 бита | r1-r14 | r2-r12 | Служебные регистры |
| r0-r13 | 13 трит | 4 бита | r2-r10 | r2-r8  | 32‑битные регистры |

### Float Registers

| Регистр | Размер | Назначение |
|-----|--------|------|------------------|
| f0    | 32 бита | Точность (0.5, 1.0) |
| f1    | 32 бита | Точность (1.0, 1.0) |
| v0    | 32 бита | GF16 формат |
| v1    | 32 бита | GF8 формат |

### Vector Registers

| Регистр | Размер | Назначение |
|-----|--------|------|------------------|
| vec0-r7 | 7×16 бит | v1-r6 128 бита | Vectors (512×8 бит) |
| vec0-r5 | 6×16 бит | v1-r4 128 бита | Vectors (1024×8 бит) |

### Instructions

27 опкодов для вычислений, загрузки, ветвления и управления:

**Арифметика (15 инструкций)**
- LDI/ST  — загрузка в R0 через src1
- LDI/ST  — загрузка в R0 через dst1
- LDR   — загрузка в R0 через dst2
- MOV   — перемещение между регистрами (R→R)
- ST    — запись в память (R0 ← R)
- LD    — загрузка из памяти в R0 (R0 ← [src])
- ST   — сохранение R0 в [src]
- LDI   — загрузка из памяти в R0 (R0 ← [dst])
- SAI   — сохранение R0 в [dst]
- SAI   — сохранение R0 в [dst, src]

**Ветвления (11 инструкций)**
- JUMP   — безусловный переход (PC ← PC + offset)
- CALL   — вызов функции по адресу (R0 ← addr)
- RET   — возврат из функции (PC ← [R0])
- HALT   — остановка VM (временно)
- NOP   — нет операции

**Управление памятью (2 инструкций)**
- LDTI/LDI  — загрузка из памяти
- STO/LO — сохранение в память

**Системные (5 инструкций)**
- PUSH   — сохранение PC, увеличение
- POP   — восстановление PC, уменьшение
- PUSH/R0 — сохранение R0, затем R0
- POP/R1 — сохранение R1, затем R1
- JZ   — переход на R0
- JZ/INC — сравнение, переход на результат

---

## Experience Tracking

**Модуль**: `src/tri27/tri27_experience.zig`

**Тип операции**:
- `assemble` — компиляция .tri → .tbin
- `disassemble` — декомпиляция .tbin → листинг
- `run` — исполнение .tbin в VM
- `validate` — проверка .tri спецификации

**События** — `Tri27Event`:
- timestamp, operation, input_file, output_file, status, cycles, instructions, error_msg

**Circular буфер** — 32 последних события

**CLI команды**:
```bash
# Инициализация лога
tri27 experience init          # Инициализировать event log

# Логирование операции
tri27 experience log <file> [ASM|DISASM|RUN|VAL]  # Логировать TRI-27 операцию

# Просмотр истории
tri27 experience status         # Показать последние события

# Сохранение эпизода
tri27 experience record <issue>  # Сохранить эпизод из последнего события в опыта

# Показать справку
tri27 experience                # Показать справку по командам
```

## Examples

### Hello World (asm)

```asm
# Hello World .tri
    msg: const r0, "Hello, World!"
    const r1: const r1, "World"
    ldi r0, r0           # загрузка строки
    ldi r1, r0, r0         # загрузка "World!"
    ldi r1, r0, r0         # копирование r1 в r0
    halt                     # остановка VM
```

### Команда `run` для выполнения

```bash
# Запуск VM
tri27 run program.tbin 1000    # Выполнить 1000 инструкций
```

---

**Интеграция**: `src/tri27/tri27_experience.zig` ↔ `src/tri/tri27_cli.zig`
- Автоматическая запись эпизодов после операций assemble/run/validate/disassemble
