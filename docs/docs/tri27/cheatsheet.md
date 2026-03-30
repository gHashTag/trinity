# TRI-27 Assembly Cheat Sheet

> **One-page reference** for all 36 opcodes. Print this for quick lookup!

---

## 📊 Opcode Quick Reference

### 🔢 Arithmetic

| Cmd | Format | Action |
|-----|--------|--------|
| ADD | `ADD dst, src1, src2` | `dst = src1 + src2` |
| SUB | `SUB dst, src1, src2` | `dst = src1 - src2` |
| MUL | `MUL dst, src1, src2` | `dst = src1 × src2` |
| DIV | `DIV dst, src1, src2` | `dst = src1 ÷ src2` |
| INC | `INC dst` | `dst++` |
| DEC | `DEC dst` | `dst--` |

---

### 🔮 Logic (Bitwise)

| Cmd | Format | Action |
|-----|--------|--------|
| AND | `AND dst, src1, src2` | `dst = src1 & src2` |
| OR | `OR dst, src1, src2` | `dst = src1 \| src2` |
| XOR | `XOR dst, src1, src2` | `dst = src1 ^ src2` |
| NOT | `NOT dst` | `dst = ~dst` |
| SHL | `SHL dst, src1, shift` | `dst = src1 << shift` |
| SHR | `SHR dst, src1, shift` | `dst = src1 >> shift` |

---

### 🧬 Ternary/VSA

| Cmd | Format | Action |
|-----|--------|--------|
| DOT | `DOT dst, src1, src2` | Ternary dot product |
| BIND | `BIND dst, src1` | Associate two vectors |
| BUNDLE2 | `BUNDLE2 dst, src1, src2` | Majority vote (2 inputs) |
| BUNDLE3 | `BUNDLE3 dst, src1, src2, src3` | Majority vote (3 inputs) |

---

### 🌟 Sacred Constants

| Cmd | Format | Value |
|-----|--------|-------|
| PHI_CONST | `PHI_CONST dst` | φ ≈ 1.618 |
| PI_CONST | `PI_CONST dst` | π ≈ 3.141 |
| E_CONST | `E_CONST dst` | e ≈ 2.718 |
| SACR | `SACR op, dst, src` | Sacred arithmetic |

---

### 💾 Memory

| Cmd | Format | Action |
|-----|--------|--------|
| LDI | `LDI dst, imm8` | Load immediate |
| LD | `LD dst, src1` | Load from memory |
| ST | `ST dst, addr` | Store to memory |
| LDR | `LDR dst, src1` | Load register indirect |
| MOV | `MOV dst, src1` | Move register |
| LDTI | `LDTI dst, src1` | Load with type |
| STO | `STO dst, addr` | Store with offset |
| SAI | `SAI dst, imm8` | Store aligned immediate |

---

### 🚦 Control Flow

| Cmd | Format | Action |
|-----|--------|--------|
| JUMP | `JUMP offset` | Jump relative |
| JZ | `JZ dst, label` | Jump if Zero |
| JNZ | `JNZ dst, label` | Jump if Not Zero |
| JGE | `JGE dst, label` | Jump if Greater or Equal |
| JLE | `JLE dst, label` | Jump if Less or Equal |
| CALL | `CALL addr` | Call subroutine |
| RET | `RET` | Return |
| PUSH | `PUSH dst` | Push to stack |
| POP | `POP dst` | Pop from stack |
| HALT | `HALT` | Stop program |

---

## 📝 Quick Examples

### Calculator (5 + 3 = 8)
```t27
.code
    LDI t0, 5
    LDI t1, 3
    ADD t2, t0, t1
    HALT
```

### Count Down (10 → 0)
```t27
.code
    LDI t0, 10

loop:
    CMP t0, 0
    JZ done
    DEC t0
    JUMP loop

done:
    HALT
```

### Absolute Value
```t27
.code
    LDI t0, -7
    CMP t0, 0
    JZ positive
    ; t0 is negative → compute absolute value
    LDI t1, 0
    SUB t2, t1, t0  ; t2 = 0 - t0 = 7
    MOV t0, t2
    JUMP done

positive:
    ; t0 is positive or zero → keep as is
    ST t0, 100

done:
    HALT
```

### Loop with Register
```t27
.code
    LDI t0, 5       ; limit = 5
    LDI t1, 0       ; counter = 0

loop:
    CMP t1, t0       ; compare counter with limit
    JGE done        ; if counter >= limit, exit
    ; ... do something
    INC t1           ; increment counter
    JUMP loop

done:
    HALT
```

---

## 🔗 Flags After CMP

| Flag | Name | Set When... |
|-------|-------|-------------|
| Z | Zero | dst == 0 |
| N | Negative | dst < 0 |
| C | Carry | Overflow from addition |
| H | Half-carry | Ternary overflow |

---

## 🏷 Registers (t0-t26)

| Type | Range | Count |
|-------|-------|--------|
| General purpose | t0-t26 | 27 |
| Program counter | pc | 1 |
| Status | flags | 1 |

---

## 💡 Tips

1. **Always use HALT** — otherwise program continues into invalid memory
2. **Label format** — simple names like `loop`, `done`, `start`
3. **Comments use semicolon** — `; This is a comment`
4. **Ternary logic** — values are -1, 0, +1 (not 0/1/2)
5. **Stack depth** — limited by memory size

---

**Print this page → Keep it handy while coding!**

🏠 [Home](./index.md) | [Full Reference](./language-reference.md) | [Projects](./projects.md)
