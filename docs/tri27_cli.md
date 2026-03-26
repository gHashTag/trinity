# TRI-27 CLI Documentation

TRI-27 CLI — Command-line tool for TRI-27 ternary computing ISA

## Overview

TRI-27 CLI provides comprehensive toolchain for TRI-27 assembly language:

| Command | Aliases | Description |
|--------|---------|-------------|
| `assemble` | `asm` | Assemble .tri → .tbin |
| `disassemble` | `disasm` | Disassemble .tbin → listing |
| `run` | - | Execute .tbin in VM |
| `validate` | - | Validate .tri specification |
| `experience` | `exp` | Experience logging |
| `isa` | - | Show ISA reference |
| `help` | `--help`, `-h` | Show help |

## Installation

```bash
zig build tri27
```

This builds `tri27` binary which contains all commands.

## Commands

### Assemble Source

```bash
tri tri27 assemble <input.tri> -o <output.tbin>
```

Assembles a TRI-27 assembly source file (`program.tri`) into binary bytecode (`output.tbin`).

**Example:**
```bash
tri tri27 assemble counter.tri -o counter.tbin
```

### Disassemble Binary

```bash
tri tri27 disassemble <input.tbin>
```

Disassembles a .tbin binary file back into TRI-27 assembly listing.

**Example:**
```bash
tri tri27 disassemble counter.tbin
```

### Run Program

```bash
tri tri27 run <program.tbin>
```

Executes a .tbin bytecode file in the TRI-27 virtual machine.

**Example:**
```bash
tri tri27 run counter.tbin
```

### Validate Specification

```bash
tri tri27 validate <source.tri>
```

Validates a .tri specification file.

**Note:** Full validation not yet implemented.

### Experience Tracking

```bash
# Initialize experience log
tri tri27 experience init

# Log an operation
tri tri27 experience log <file> [ASM|DISASM|RUN|VAL]

# Show event history
tri tri27 experience status

# Record episode to GitHub issue
tri tri27 experience record <issue>
```

### ISA Reference

```bash
tri tri27 isa
```

Displays the complete TRI-27 instruction set architecture reference.

## Instruction Set

The TRI-27 ISA includes the following instruction categories:

### Arithmetic Instructions (0x10-0x17)

| Mnemonic | Hex | Format | Description |
|----------|-----|--------|-------------|
| ADD | 0x10 | `dst, src1, src2` | `dst = src1 + src2` |
| SUB | 0x11 | `dst, src1, src2` | `dst = src1 - src2` |
| MUL | 0x12 | `dst, src1, src2` | `dst = src1 * src2` |
| DIV | 0x13 | `dst, src1, src2` | `dst = src1 / src2` |
| INC | 0x14 | `dst` | `dst++` |
| DEC | 0x15 | `dst` | `dst--` |

### Logic Instructions (0x18-0x1D)

| Mnemonic | Hex | Format | Description |
|----------|-----|--------|-------------|
| AND | 0x18 | `dst, src1, src2` | `dst = src1 & src2` |
| OR | 0x19 | `dst, src1, src2` | `dst = src1 | src2` |
| XOR | 0x1A | `dst, src1, src2` | `dst = src1 ^ src2` |
| NOT | 0x1B | `dst` | `dst = ~dst` |
| SHL | 0x1C | `dst, src1, shift` | `dst = src1 << shift` |
| SHR | 0x1D | `dst, src1, shift` | `dst = src1 >> shift` |

### Memory Instructions (0x02-0x05)

| Mnemonic | Hex | Format | Description |
|----------|-----|--------|-------------|
| LD | 0x02 | `dst, addr` | Load register from memory |
| ST | 0x03 | `dst, addr` | Store register to memory |
| LDI | 0x04 | `dst, imm` | Load immediate to register |
| STI | 0x05 | `imm, addr` | Store immediate to memory |

### Control Flow Instructions (0x40-0x4F)

| Mnemonic | Hex | Format | Description |
|----------|-----|--------|-------------|
| JMP | 0x40 | `imm` | Unconditional jump |
| JZ | 0x41 | `dst, imm` | Jump if zero |
| JNZ | 0x42 | `dst, imm` | Jump if not zero |
| CALL | 0x43 | `imm` | Call function |
| RET | 0x4B | - | Return from function |
| HALT | 0x4D | - | Stop execution |

### Ternary Instructions (0x60-0x6D)

| Mnemonic | Hex | Format | Description |
|----------|-----|--------|-------------|
| DOT | 0x60 | `dst, v1, v2` | Ternary dot product |
| BIND | 0x61 | `dst, v1, v2` | VSA bind operation |
| BUNDLE2 | 0x62 | `dst, v1, v2` | Majority vote (2 vectors) |
| BUNDLE3 | 0x63 | `dst, v1, v2, v3` | Majority vote (3 vectors) |

### Sacred Constant Instructions (0x80-0x92)

| Mnemonic | Hex | Format | Description |
|----------|-----|--------|-------------|
| PHI_CONST | 0x80 | `dst` | `dst = φ` (golden ratio) |
| PI_CONST | 0x81 | `dst` | `dst = π` |
| E_CONST | 0x82 | `dst` | `dst = e` |
| SACR | 0x83 | `op, dst, src` | Sacred arithmetic |

### Additional Instructions

| Mnemonic | Hex | Description |
|----------|-----|-------------|
| NOP | 0x00 | No operation |

## Opcode Encoding

All instructions are encoded as 32-bit words with the following format:

```
┌─────────────────────────────────────────────────────────┐
│ 31  17│ 16  13│ 12   8│ 7    0 │
├─────────┼─────────┼─────────┼─────────┤
│ Imm(15) │ Rs2(5)  │ Rs1(5)  │ Rd(5)  │ Opcode(8)│
└─────────┴─────────┴─────────┴─────────┘
```

| Bit Range | Field | Description |
|----------|--------|-------------|
| [7:0] | Opcode (8) | Operation code |
| [12:8] | Rd (5) | Destination register |
| [17:13] | Rs1 (5) | Source register 1 |
| [22:18] | Rs2 (5) | Source register 2 |
| [31:17] | Imm (15) | Immediate value (signed) |

**Note:** The immediate field is 15-bit signed, range: -16384 to 16383.

## File Format

Binary files (.tbin) contain raw instruction words (little-endian):

- No header or magic number
- Each instruction is exactly 4 bytes (32 bits)
- Program starts at byte 0
- Instructions are read sequentially

## Registers

TRI-27 has 27 ternary registers:

- **Primary naming:** `t0` through `t26`
- **Alternative naming:** `r0` through `r26` (accepted by assembler)
- **Register 0:** Acts as accumulator-like register
- **Disassembly output:** Uses `tN` format

All register fields in instructions are 5 bits, allowing values 0-26.

## Example Programs

### Simple Counter

```asm
; Simple counter
loop:
    inc t0          ; Increment t0
    jz t0, loop      ; Jump back if t0 == 0 (never, for demo)
    halt
```

```bash
tri tri27 assemble counter.tri -o counter.tbin
tri tri27 run counter.tbin
```

### Add Two Numbers

```asm
; Add two numbers and store result
    ldi t0, 10       ; Load 10 into t0
    ldi t1, 20       ; Load 20 into t1
    add t2, t0, t1   ; t2 = t0 + t1
    halt
```

### Conditional Jump

```asm
; Loop until t0 reaches 5
    ldi t0, 0        ; Initialize counter
loop:
    inc t0          ; Increment
    ldi t1, 5        ; Compare value
    sub t2, t1, t0   ; 5 - t0
    jnz t2, loop      ; Jump if not zero
    halt
```

## Complete Opcode Reference

| Mnemonic | Hex | Category |
|----------|-----|----------|
| NOP | 0x00 | Control |
| LD | 0x02 | Memory |
| ST | 0x03 | Memory |
| LDI | 0x04 | Memory |
| STI | 0x05 | Memory |
| ADD | 0x10 | Arithmetic |
| SUB | 0x11 | Arithmetic |
| MUL | 0x12 | Arithmetic |
| DIV | 0x13 | Arithmetic |
| INC | 0x14 | Arithmetic |
| DEC | 0x15 | Arithmetic |
| AND | 0x18 | Logic |
| OR | 0x19 | Logic |
| XOR | 0x1A | Logic |
| NOT | 0x1B | Logic |
| SHL | 0x1C | Logic |
| SHR | 0x1D | Logic |
| JMP | 0x40 | Control |
| JZ | 0x41 | Control |
| JNZ | 0x42 | Control |
| CALL | 0x43 | Control |
| RET | 0x4B | Control |
| HALT | 0x4D | Control |
| DOT | 0x60 | Ternary |
| BIND | 0x61 | Ternary |
| BUNDLE2 | 0x62 | Ternary |
| BUNDLE3 | 0x63 | Ternary |
| PHI_CONST | 0x80 | Sacred |
| PI_CONST | 0x81 | Sacred |
| E_CONST | 0x82 | Sacred |
| SACR | 0x83 | Sacred |

## Development Status

✅ **Core assembler** — 35+ opcodes implemented
✅ **Parser** — Handles labels, comments, multi-line source
✅ **Test coverage** — 19/19 golden tests passing
✅ **CLI integration** — Full help menu, 9 commands
✅ **Experience tracking** — Episode logging to JSONL

## Quick Reference

```bash
# Assemble a program
tri tri27 assemble program.tri -o output.tbin

# Disassemble binary
tri tri27 disassemble output.tbin

# Run in emulator
tri tri27 run program.tbin

# Show ISA reference
tri tri27 isa

# Help
tri tri27 help
```

---

*φ² + 1/φ² = 3 | TRINITY*
