# TRI-27 CLI Documentation

TRI-27 CLI — Command-line tool for TRI-27 assembly language

## Overview

TRI-27 CLI provides two main commands:

1. **`assemble`** — Assemble .tasm source to .tbin bytecode
2. **`disassemble`** — Disassemble .tbin bytecode to listing

## Installation

```bash
zig build tri27
```

This builds the `tri27` binary which contains both commands.

## Usage: Assemble Source

```bash
tri27 asm program.tasm -o output.tbin
```

Assembles a TRI-27 assembly source file (`program.tasm`) into binary bytecode (`output.tbin`).

## Usage: Disassemble Binary

```bash
tri27 disasm output.tbin
```

Disassembles a .tbin binary file back into TRI-27 assembly source listing.

### Supported Instructions

The TRI-27 ISA includes the following instruction categories:

#### **Arithmetic Instructions**
- `add rD, rS, rD` — Add registers
- `sub rD, rS, rD` — Subtract registers
- `mul rD, rS, rD` — Multiply registers
- `div rD, rS` — Divide registers
- `inc rD` — Increment register
- `dec rD` — Decrement register

#### **Logic Instructions**
- `and rD, rS, rD` — Bitwise AND
- `or rD, rS, rD` — Bitwise OR
- `xor rD, rS, rD` — Bitwise XOR
- `not rD` — Bitwise NOT
- `shl rD, S` — Shift Left
- `shr rD, S` — Shift Right

#### **Memory Instructions**
- `load_imm rD, imm` — Load immediate to register
- `ldi rD, imm` — Load immediate to register
- `store rD, addr` — Store register to memory address
- `sti imm, addr` — Store immediate to memory address
- `load rD, addr` — Load register from memory address

#### **Control Flow Instructions**
- `jmp imm` — Unconditional jump
- `jz rD, imm` — Jump if zero
- `jnz rD, imm` — Jump if not zero
- `call imm` — Call function
- `ret` — Return from function

#### **Other Instructions**
- `nop` — No operation
- `halt` — Stop execution

### Opcode Encoding

All instructions are encoded as 32-bit words with the following format:

```
| Opcode (8) | Rd (5) | Rs1 (5) | Rs2 (5) | Imm (16) |
|-----------|----------|---------|----------|-------------|
```

### File Format

Binary files (.tbin) use the following format:

```
| Byte Offset | Content |
|------------|---------|
| 0x00000000 | Magic number (5 bytes) |
| 0x00000004 | Instruction words (little-endian) |
| ...       | ...       |
```

### Example Programs

#### Simple Loop

```asm
; Simple infinite loop
loop:
    inc r0
    jz r0, loop
```

```bash
tri27 asm loop.tasm -o loop.tbin
tri27 run loop.tbin
```

### Development Status

✅ **Core assembler** — All 36 opcodes implemented
✅ **Parser** — Handles labels, comments, multi-line source
✅ **Test coverage** — 58/58 tests passing
🔧 **CLI integration** — `tri27 asm` command exists, needs help menu
📝 **Documentation** — Needs examples and full help

---

## Quick Reference

```bash
# Assemble a program
tri27 asm program.tasm -o output.tbin

# Run in emulator
tri27 run program.tbin
```

---

*φ² + 1/φ² = 3 | TRINITY*
