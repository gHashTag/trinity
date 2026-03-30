# TRI-27 Assembly Guide

TRI-27 is a ternary RISC processor with 27 registers and 36 instructions. This guide will help you understand how computers work at the lowest level.

---

## What is t27?

**t27** is an assembler for the TRI-27 processor. An assembler is a language the processor understands directly.

Think of a computer as a machine that only understands simple commands:
- "Get a number"
- "Add two numbers"
- "Store result to memory"

t27 is how you write these commands for TRI-27.

---

## Why "Ternary"?

Regular computers use **binary** logic: 0 or 1.

```
Binary: 🔴 OFF  |  🟢 ON
```

TRI-27 uses **ternary** logic: -1, 0, +1.

```
Ternary: 🔴 Minus  |  🟡 Zero  |  🟢 Plus
```

**Traffic Light Analogy**:
- 🔴 Red — Stop (-1)
- 🟡 Yellow — Wait (0)
- 🟢 Green — Go (+1)

Three states instead of two — more information in the same space!

---

## 27 Registers = 3 × 9

**Registers** are storage locations inside the processor where you can put numbers.

TRI-27 has **27 registers** (t0, t1, t2, ... t26).

Why 27? It's based on φ (golden ratio):

```
φ² + 1/φ² = 3
3³ = 27
```

27 registers = 3 banks of 9 registers each:
```
Bank 0: t0  t1  t2  t3  t4  t5  t6  t7  t8
Bank 1: t9  t10 t11 t12 t13 t14 t15 t16 t17
Bank 2: t18 t19 t20 t21 t22 t23 t24 t25 t26
```

**Analogy**: 27 boxes on a desk, each can hold a number from 0 to 4,294,967,295.

---

## Key Concepts

| Concept | Analogy |
|---------|----------|
| **Registers** | 27 boxes that hold numbers |
| **Memory** | A shelf with millions of cells — for long-term storage |
| **Opcodes** | 36 commands the processor understands |
| **LDI** | Put a number into a register |
| **ADD** | Add two numbers from two registers |
| **ST** | Move from a register to memory |
| **JUMP** | Jump to another line of code |
| **Stack** | A stack of plates: last one placed — first one removed |
| **HALT** | Stop! End of program |

---

## 4 Projects: From Simple to Complex

| Project | New Concepts | Lines of Code |
|--------|-----------------|------------|
| 1. Calculator | LDI, ADD, HALT | ~5 |
| 2. Abs | CMP, JZ (conditions) | ~15 |
| 3. Fibonacci | Loops, counter | ~25 |
| 4. Bubble Sort | Arrays, nested loops | ~40 |

Each project shows:
- 📜 **Zig code** — High-level code (readable)
- ⚙️ **.t27 code** — Same algorithm in assembler — line by line
- 🔄 **Mapping** — Which Zig line = which .t27 command
- 🔍 **Visualization** — How registers change step by step

---

## Quick Start

### Installation

```bash
git clone https://github.com/gHashTag/trinity.git
cd trinity
zig build
```

### Your First Program

Create `hello.t27`:

```t27
.code
    LDI t0, 42      ; Put 42 into register t0
    ST t0, 100      ; Store to memory address 100
    HALT            ; Stop!
```

Assemble and run:

```bash
tri tri27 assemble hello.t27 -o hello.tbin
tri tri27 run hello.tbin
```

---

## Next Steps

- **[Project 1: Calculator](getting-started.md)** — Add 5 + 3
- **[Projects 2-4](projects.md)** — Abs, Fibonacci, Bubble Sort
- **[Reference](language-reference.md)** — All 36 commands
- **[Cheat Sheet](cheatsheet.md)** — One page reference

---

## Why Learn Assembly?

Assembly teaches:
- How processors execute commands
- How memory works
- Why loops are expensive
- How to optimize code

These skills apply to any programming language.

---

## Useful Links

- [Trinity GitHub](https://github.com/gHashTag/trinity)
- [Balanced Ternary](../concepts/balanced-ternary.md)

---

**Next**: [Project 1: Calculator](getting-started.md) →
