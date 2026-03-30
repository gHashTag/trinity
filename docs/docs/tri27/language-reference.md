# TRI-27 Language Reference

> **Complete reference** for all 36 TRI-27 opcodes.

---

## 📖 Table of Contents

- [Arithmetic (6 opcodes)](#arithmetic)
- [Logic (6 opcodes)](#logic)
- [Ternary/VSA (4 opcodes)](#ternaryvsa)
- [Sacred (4 opcodes)](#sacred)
- [Memory (8 opcodes)](#memory)
- [Control Flow (8 opcodes)](#control-flow)
- [Register Names](#register-names)

---

## 🔢 Arithmetic (6)

| Opcode | Mnemonic | Format | Description | Example |
|--------|----------|--------|-------------|---------|
| 0x60 | ADD | `ADD dst, src1, src2` | `dst = src1 + src2` | `ADD t2, t0, t1` |
| 0x61 | SUB | `SUB dst, src1, src2` | `dst = src1 - src2` | `SUB t2, t0, t1` |
| 0x62 | MUL | `MUL dst, src1, src2` | `dst = src1 × src2` | `MUL t2, t0, t1` |
| 0x63 | DIV | `DIV dst, src1, src2` | `dst = src1 ÷ src2` | `DIV t2, t0, t1` |
| 0x64 | INC | `INC dst` | `dst++` | `INC t0` |
| 0x65 | DEC | `DEC dst` | `dst--` | `DEC t0` |

### Examples

```t27
; Addition: 5 + 3 = 8
.code
    LDI t0, 5      ; t0 = 5
    LDI t1, 3      ; t1 = 3
    ADD t2, t0, t1 ; t2 = t0 + t1 = 8
    HALT

; Subtraction: 10 - 4 = 6
.code
    LDI t0, 10
    LDI t1, 4
    SUB t2, t0, t1 ; t2 = t0 - t1 = 6
    HALT

; Multiplication: 4 × 7 = 28
.code
    LDI t0, 4
    LDI t1, 7
    MUL t2, t0, t1 ; t2 = t0 × t1 = 28
    HALT
```

---

## 🔮 Logic (6)

| Opcode | Mnemonic | Format | Description | Example |
|--------|----------|--------|-------------|---------|
| 0x18 | AND | `AND dst, src1, src2` | `dst = src1 & src2` | `AND t2, t0, t1` |
| 0x19 | OR | `OR dst, src1, src2` | `dst = src1 \| src2` | `OR t2, t0, t1` |
| 0x1A | XOR | `XOR dst, src1, src2` | `dst = src1 ^ src2` | `XOR t2, t0, t1` |
| 0x1B | NOT | `NOT dst` | `dst = ~dst` | `NOT t2` |
| 0x1C | SHL | `SHL dst, src1, shift` | `dst = src1 << shift` | `SHL t2, t0, t1` |
| 0x1D | SHR | `SHR dst, src1, shift` | `dst = src1 >> shift` | `SHR t2, t0, t1` |

### Bitwise Operations Explained

| Operation | What it does |
|-----------|-------------|
| **AND** | Bitwise AND — result bit is 1 only if both inputs have 1 |
| **OR** | Bitwise OR — result bit is 1 if either input has 1 |
| **XOR** | Bitwise XOR — result bit is 1 if inputs differ |
| **NOT** | Bitwise NOT — flip all bits |
| **SHL** | Shift Left — move bits left (multiply by powers of 2) |
| **SHR** | Shift Right — move bits right (divide by powers of 2) |

### Example

```t27
; Check if number is odd (bit 0 is set)
.code
    LDI t0, 7        ; t0 = 7
    LDI t1, 1        ; t1 = 1 (binary: 0001)
    AND t2, t0, t1 ; t2 = 7 & 1 = 1 (odd!)
    HALT
```

---

## 🧬 Ternary/VSA (4)

> **Advanced**: These operations work with ternary values and Vector Symbolic Architecture.

| Opcode | Mnemonic | Format | Description | Example |
|--------|----------|--------|-------------|---------|
| 0x60 | DOT | `DOT dst, src1, src2` | Ternary dot product | `DOT t2, t0, t1` |
| 0x6A | BIND | `BIND dst, src1` | Associate two vectors | `BIND t2, t0` |
| 0x6B | BUNDLE2 | `BUNDLE2 dst, src1, src2` | Majority vote (2 inputs) | `BUNDLE2 t2, t0, t1` |
| 0x6C | BUNDLE3 | `BUNDLE3 dst, src1, src2, src3` | Majority vote (3 inputs) | `BUNDLE3 t2, t0, t1, src3` |

### What is BUNDLE?

**Majority Vote** — pick the value that appears most:
- If 2 inputs: `BUNDLE2(a, b)` → if one is -1 and other is +1, result is -1
- If 3 inputs: `BUNDLE3(a, b, c)` → at least 2 must agree

---

## 🌟 Sacred (4)

> **Sacred Constants**: φ (golden ratio), π (pi), e (Euler's number)

| Opcode | Mnemonic | Format | Description | Value |
|--------|----------|--------|-------------|-------|
| 0x80 | PHI_CONST | `PHI_CONST dst` | `dst = φ ≈ 1.618` |
| 0x81 | PI_CONST | `PI_CONST dst` | `dst = π ≈ 3.141` |
| 0x82 | E_CONST | `E_CONST dst` | `dst = e ≈ 2.718` |
| 0x92 | SACR | `SACR op, dst, src` | Sacred arithmetic | — |

### Example

```t27
.code
    PHI_CONST t0    ; t0 = φ (golden ratio)
    PI_CONST t1     ; t1 = π (pi)
    E_CONST t2      ; t2 = e (Euler's number)
    HALT
```

---

## 💾 Memory (8)

| Opcode | Mnemonic | Format | Description | Example |
|--------|----------|--------|-------------|---------|
| 0x01 | LDI | `LDI dst, imm8` | Load immediate into register | `LDI t0, 42` |
| 0x02 | LD | `LD dst, src1` | Load from memory | `LD t0, t1` |
| 0x03 | ST | `ST dst, addr` | Store to memory | `ST t0, 100` |
| 0x04 | LDR | `LDR dst, src1` | Load register indirect | `LDR t0, t1` |
| 0x05 | MOV | `MOV dst, src1` | Move register to register | `MOV t0, t1` |
| 0x06 | LDTI | `LDTI dst, src1` | Load with type | `LDTI t0, t1` |
| 0x07 | STO | `STO dst, addr` | Store with offset | `STO t0, 100` |
| 0x08 | SAI | `SAI dst, imm8` | Store aligned immediate | `SAI t0, 100` |

### Memory Analogy

```
┌───────────────────────┬─────┬─────┐
│  CPU (Processor)     │   │     │
│                     │   │     │
└───────────────────────┴─────┴─────┘
    Registers (boxes)        Memory (shelf)
```

- **LDI** — Put number directly into a box
- **LD** — Get number from shelf into a box
- **ST** — Put number from a box onto the shelf
- **MOV** — Copy number from one box to another

### Example

```t27
; Store and retrieve a value
.code
    LDI t0, 42      ; Put 42 into box t0
    ST t0, 100      ; Put t0 onto shelf at address 100
    LD t1, 100      ; Get from shelf address 100 into box t1
    HALT              ; t1 = 42 ✅
```

---

## 🚦 Control Flow (8)

| Opcode | Mnemonic | Format | Description | Example |
|--------|----------|--------|-------------|---------|
| 0x10 | JUMP | `JUMP offset` | Jump relative | `JUMP -5` |
| 0x11 | JZ | `JZ dst, label` | Jump if Zero | `JZ t0, done` |
| 0x12 | JNZ | `JNZ dst, label` | Jump if Not Zero | `JNZ t0, loop` |
| 0x13 | JGE | `JGE dst, label` | Jump if Greater or Equal | `JGE t0, done` |
| 0x14 | JLE | `JLE dst, label` | Jump if Less or Equal | `JLE t0, done` |
| 0x15 | CALL | `CALL addr` | Call subroutine | `CALL start` |
| 0x16 | RET | `RET` | Return from subroutine | `RET` |
| 0x17 | HALT | `HALT` | Stop execution | `HALT` |

| Opcode | Mnemonic | Format | Description | Example |
|--------|----------|--------|-------------|---------|
| 0x15 | PUSH | `PUSH dst` | Push to stack | `PUSH t0` |
| 0x16 | POP | `POP dst` | Pop from stack | `POP t1` |

### How Jumps Work

**Absolute vs Relative**:
- **JUMP** is relative — jump forward/back by offset from current position
- **CALL** is absolute — jump to specific address (using stack to return)

### Conditional Jumps

```t27
; Loop: print numbers 0, 1, 2
.code
    LDI t0, 3        ; Counter = 3

loop:
    ; Print t0 (would need I/O)
    CMP t0, 0        ; Check if t0 == 0
    JZ done          ; If zero, exit loop
    INC t0           ; Increment counter
    JUMP loop        ; Repeat

done:
    HALT
```

### Stack Analogy

```
Before PUSH:
    ┌───┬───┬───┬───┬───┐  ← Registers (boxes)
    │ t2│ t1│ t0│ ... │
    └───┴───┴───┴───┴───┘

After PUSH(t0):
    ┌───┬───┬───┬───┬───┬───┐  ← Stack (plates)
    │ t2│ t1│ t0│ ... │ t0│  ← Top
    └───┴───┴───┴───┴───┴───┘
      └───┴───┴─┴───┴─┘

Before POP:
    ┌───┬───┬───┬───┬───┬───┐  ← Stack
    │ t2│ t1│ t0│ ... │    │
    └───┴───┴───┴───┴───┘
          └───┴───┴───┴─┘  ← Top removed!

After POP(t1):
    ┌───┬───┬───┬───┬───┬───┐  ← Registers
    │ t2│ t0│ ... │ t0│
    └───┴───┴───┴───┴───┘
      └───┴───┴───┴─┘  ← New value!
```

---

## 🏷 Register Names

TRI-27 uses 27 registers divided into 3 banks:

| Bank | Registers | Purpose |
|-------|-----------|---------|
| Bank 0 | t0, t1, t2, t3, t4, t5, t6, t7, t8 | General purpose |
| Bank 1 | t9, t10, t11, t12, t13, t14, t15, t16, t17 | General purpose |
| Bank 2 | t18, t19, t20, t21, t22, t23, t24, t25, t26 | General purpose |

**t0 is the accumulator** — often used for results.

**Special Registers**:
- `pc` — Program Counter (points to current instruction)
- `flags` — Status flags (Z, N, C, H, O...)

### Flags After CMP

| Flag | Name | Set When... |
|-------|-------|-------------|
| Z | Zero | dst == 0 |
| N | Negative | dst < 0 |
| C | Carry | Overflow from addition |
| H | Half-carry | Ternary overflow |

---

## 📖 Quick Examples

### Calculator
```t27
.code
    LDI t0, 5
    LDI t1, 3
    ADD t2, t0, t1
    ST t2, 100
    HALT
```

### Loop Counter
```t27
.code
    LDI t0, 10     ; Count from 10 down

loop:
    CMP t0, 0        ; Check if zero
    JZ done
    DEC t0           ; Decrement
    JUMP loop

done:
    HALT
```

### Conditional Jump
```t27
.code
    LDI t0, 5

    CMP t0, 10
    JGE greater_or_eq ; Jump if >= 10
    ; Code if < 10 here
    HALT

greater_or_eq:
    ; Code if >= 10 here
    HALT
```

---

## 🎯 Practice

Try writing programs that:
- Add numbers 1-10 and store results
- Count down from 10 to 0
- Find if a number is even (use AND with 1)
- Implement simple multiplication without MUL (use repeated ADD)

---

**🏠 Home**: [Back to Top](#-tri-27-language-reference)
