# .t27 Assembly Format Specification

## Overview

`.t27` is a text-based assembly format for the TRI-27 RISC processor. Human-readable, easily parsed, with sections for constants, data, and code.

**Mathematical foundation**: φ² + 1/φ² = 3 = TRINITY

---

## File Structure

```
.const      # Constants (optional)
.data       # Data initialization (optional)
.code       # Program code (required)
```

### Section Order

1. `.const` — processed first if present
2. `.data` — processed second if present
3. `.code` — always processed, contains instructions

All sections mandatory? No. Can have only `.code` or only `.const + .code`.

---

## Syntax

### General Format

```
<section>
    <directive> <operand1> <operand2> ... <operandN>
    <directive> <operand1> <operand2> ... <operandN>
    ...
```

- One instruction per line
- Comment starts with `#`
- Empty lines ignored
- Whitespace between tokens optional for readability

---

## Constants (.const)

### Syntax

```
.const
    <name> = <value>
    <name> = <value>
```

### Example

```
.const
    PHI = 1.618
    MAX_INT = 32767
    NEG_ONE = -1
```

### Usage

Constants can be used as operands in any instruction:

```
LDI t0, PHI         # t0 = 1.618
LDI t1, MAX_INT     # t1 = 32767
```

---

## Data (.data)

### Syntax

```
.data
    .<bytes> <value> <value2> ... <valueN>
```

### Supported Sizes

| Directive | Description |
|-----------|-------------|
| `.byte` | 8-bit unsigned |
| `.word` | 16-bit unsigned |
| `.dword` | 32-bit unsigned |
| `.trit` | 2-bit ternary {00=0, 01=+1, 11=-1} |
| `.trit3` | 6-bit ternary (3 trits) |
| `.trit9` | 18-bit ternary (9 trits) |
| `.trit27` | 54-bit ternary (27 trits) |

### Example

```
.data
    .byte 0x42 0x13 0xFF
    .word 0x1234 0xABCD
    .dword 0xDEADBEEF
    .trit 0b11 0b01 0b00
```

### Usage

`.data` data is loaded into memory starting at address 0x0000, in order.

---

## Code (.code)

### Registers

| Register | Size | Purpose |
|----------|------|---------|
| t0-t26 | 32-bit | Trit registers (t0 = default accumulator) |
| pc | 32-bit | Program Counter (only for JUMP/JZ/JNZ) |
| sp | 32-bit | Stack Pointer (for PUSH/POP/CALL/RET) |

### Instruction Format

```
<opcode> <dst> <src1> [src2] [imm8]
```

- `<dst>` — destination register (t0-t26)
- `<src1>` — first source operand
- `<src2>` — second source operand (optional for some opcodes)
- `<imm8>` — 8-bit immediate value (optional)

### Register Convention

For opcodes using two registers: src1, src2 order corresponds to reading from memory/registers, dst for writing.

---

## Opcodes by Category

### Arithmetic (0x60-0x65)

| Opcode | Mnemonic | Format | Description |
|--------|----------|---------|-------------|
| 0x60 | ADD | ADD dst, src1, src2 | dst = src1 + src2 |
| 0x61 | SUB | SUB dst, src1, src2 | dst = src1 - src2 |
| 0x62 | MUL | MUL dst, src1, src2 | dst = src1 × src2 |
| 0x63 | DIV | DIV dst, src1, src2 | dst = src1 ÷ src2 |
| 0x64 | INC | INC dst | dst++ |
| 0x65 | DEC | DEC dst | dst-- |

### Logic (0x18-0x1D)

| Opcode | Mnemonic | Format | Description |
|--------|----------|---------|-------------|
| 0x18 | AND | AND dst, src1, src2 | dst = src1 & src2 |
| 0x19 | OR | OR dst, src1, src2 | dst = src1 \| src2 |
| 0x1A | XOR | XOR dst, src1, src2 | dst = src1 ^ src2 |
| 0x1B | NOT | NOT dst | dst = ~dst |
| 0x1C | SHL | SHL dst, src1, src2 | dst = src1 << src2 |
| 0x1D | SHR | SHR dst, src1, src2 | dst = src1 >> src2 |

### Ternary/VSA (0x6A-0x6C)

| Opcode | Mnemonic | Format | Description |
|--------|----------|---------|-------------|
| 0x60 | DOT | DOT dst, src1, src2 | ternary dot product (note: overlaps with ADD in current spec) |
| 0x6A | BIND | BIND dst, src1, src2 | VSA bind operation |
| 0x6B | BUNDLE2 | BUNDLE2 dst, src1, src2 | majority vote (2 inputs) |
| 0x6C | BUNDLE3 | BUNDLE3 dst, src1, src2 | majority vote (3 inputs) |

### Sacred (0x80-0x82, 0x92)

| Opcode | Mnemonic | Format | Description |
|--------|----------|---------|-------------|
| 0x80 | PHI_CONST | PHI_CONST dst | dst = φ ≈ 1.61803398875 |
| 0x81 | PI_CONST | PI_CONST dst | dst = π ≈ 3.14159265359 |
| 0x82 | E_CONST | E_CONST dst | dst = e ≈ 2.71828182846 |
| 0x92 | SACR | SACR op, dst, src | sacred arithmetic (op encoded in op) |

### Memory (0x01-0x08)

| Opcode | Mnemonic | Format | Description |
|--------|----------|---------|-------------|
| 0x01 | LDI | LDI dst, imm8 | dst = imm8 (zero-extend) |
| 0x02 | LD | LD dst, src1 | dst = [src1] |
| 0x03 | ST | ST dst, src1 | [dst] = src1 |
| 0x04 | LDR | LDR dst, src1 | dst = [[src1]] |
| 0x05 | MOV | MOV dst, src1 | dst = src1 |
| 0x06 | LDTI | LDTI dst, src1, imm8 | load with type (type in imm8) |
| 0x07 | STO | STO dst, src1, src2 | [dst + src2] = src1 |
| 0x08 | SAI | SAI dst, imm8 | [dst] = imm8 (aligned store) |

### Control Flow (0x10-0x17)

| Opcode | Mnemonic | Format | Description |
|--------|----------|---------|-------------|
| 0x10 | JUMP | JUMP imm8 | PC = PC + sign_extend(imm8) |
| 0x11 | JZ | JZ dst, imm8 | if dst == 0: PC = PC + imm8 |
| 0x12 | JNZ | JNZ dst, imm8 | if dst != 0: PC = PC + imm8 |
| 0x13 | CALL | CALL imm8 | push PC; PC = PC + imm8 |
| 0x14 | RET | RET | pop PC |
| 0x15 | PUSH | PUSH src1 | push src1 to stack |
| 0x16 | POP | POP dst | pop from stack to dst |
| 0x17 | HALT | HALT | stop execution |

---

## Complete Example Programs

### Example 1: Fibonacci

```
.const
    ONE = 1

.data
    .word 0 0 0 0 0 0 0 0

.code
    # t0 = n, t1 = prev, t2 = current, t3 = index
    LDI t0, 10         # n = 10

    # Loop start
loop:
    # t2 = Fibonacci(t1, t0), t3++
    LDI t2, t1         # current = prev
    ADD t2, t1         # current = prev + prev
    MOV t1, t2         # prev = current

    DEC t0              # n--
    JZ t0, done        # if n == 0, jump to done
    JUMP loop            # continue loop

done:
    HALT
```

### Example 2: Dot Product

```
.data
    # Vector A: [1, 2, 3, 4]
    .word 1 2 3 4
    # Vector B: [5, 6, 7, 8]
    .word 5 6 7 8
    # Accumulator
    .dword 0

.code
    # t0 = address A, t1 = address B, t2 = accumulator
    LDI t0, 0          # &A
    LDI t1, 4          # &B

    # Initialize accumulator
    LDI t2, 0

    # Loop: 4 elements
    LDI t3, 4

dot_loop:
    # Load A[i] and B[i]
    LD t4, t0          # A[i]
    LD t5, t1          # B[i]

    # Multiply and accumulate: t2 += t4 * t5
    MUL t6, t4, t5     # t6 = A[i] * B[i]
    ADD t2, t2, t6     # t2 = acc + product

    # Increment pointers
    INC t0              # &A++
    INC t1              # &B++

    # Decrement counter
    DEC t3

    # Continue if counter > 0
    JNZ t3, dot_loop

    # Result in t2
    HALT
```

### Example 3: Sacred Constants

```
.const
    PHI = 16180  # Q16 fixed-point: φ ≈ 1.618
    PI = 10243   # Q16 fixed-point: π ≈ 3.14159

.code
    PHI_CONST t0        # t0 = φ
    PI_CONST t1         # t1 = π
    MUL t2, t0, t1     # t2 = φ × π
    HALT
```

---

## Notes

### Status Flags

Flags are set automatically:
- **Z** (Zero): last arithmetic operation result equals 0
- **N** (Negative): result is negative
- **C** (Carry): overflow in addition/subtraction
- **H** (Half): mid-point overflow for 16-bit operations

### Assembler Errors

| Error | Description |
|--------|-------------|
| `Unknown opcode: 0xXX` | Unknown opcode |
| `Invalid register: t27` | Register outside t0-t26 range |
| `Immediate out of range: 256` | imm8 > 255 or < -128 |
| `Missing operand for: XXX` | Instruction requires operand |

### Binary Format (.tbin)

Binary word (32 bits):
```
[31:26] | [25:20] | [19:14] | [13:8]  | [7:0]
opcode   | dst       | src1      | src2/shift | imm8
```

Conversion: `.t27 → .tbin` via assembler (`tri tri27 assemble`).

---

## TRI-27 Integration

| Component | File | Interface |
|-----------|------|-----------|
| CPU Emulator | `src/tri27/emu/executor.zig` | Execute .tbin |
| Assembler | `src/tri27/emu/asm_parser.zig` | .t27 → .tbin |
| Decoder | `src/tri27/emu/decoder.zig` | Opcode decoder |
| Queen | `src/tri/queen/self_learning.zig` | Experience logging |

---

**φ² + 1/φ² = 3 | TRINITY**
