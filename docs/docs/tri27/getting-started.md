# 🎯 Project 1: Calculator

> **Goal**: Add two numbers (5 + 3 = 8) and save result
> **Architecture**: VIBEE (.tri) → Zig → .t27

---

## 🏗️ Trinity Architecture: 3 Levels of Languages

```
┌─────────────────────────────────────────────────┐
│ Level 1: .tri (VIBEE)   │  Specification (source of truth) │
│ One formula → generates Zig + .t27                 │
├─────────────────────────────────────────────────┤
│ Level 2: .zig            │  System code           │
│ Bootstrap, files, network, OS                          │
├─────────────────────────────────────────────────┤
│ Level 3: .t27            │  TRI-27 Assembler      │
│ Executes on processor / FPGA                    │
└─────────────────────────────────────────────────┘
           φ² + 1/φ² = 3 ← Three levels in one!
```

**Why 3 levels?**

| Level | Why needed? |
|-------|----------------|
| **.tri (VIBEE)** | One formula → generates entire Zig + .t27 code. Source of truth. |
| **Zig** | System things: files, network, JSON, HTTP |
| **.t27** | Runs on TRI-27 processor / FPGA directly |

---

## 📐 Level 1: .tri (VIBEE Specification)

```tri
# calculator.tri — VIBEE specification
# One formula → generates Zig + .t27

@def calculate_sum(a: u32, b: u32) -> u32 {
    return a + b
}

# Entry point
@entry main() {
    result = calculate_sum(5, 3)
    store(result, address: 100)
}
```

**What happens here:**
- `@def` — defines a function (like Python/JS)
- `a + b` — formula that's understandable to humans
- `@entry` — program entry point
- `store()` — save result

---

## 📜 Level 2: Zig (Generated)

```zig
// Generated from calculator.tri
// tri vibee gen calculator.tri

pub fn calculateSum(a: u32, b: u32) u32 {
    return a + b;
}

pub fn main() void {
    const result = calculateSum(5, 3);
    // System code for saving to memory
    @setRuntimeSafety(false);
    asm volatile (
        \\ ST t0, 100
        : [result] "{t0}" (result)
    );
}
```

**What happens here:**
- Function `calculateSum` generated from `@def`
- Types `u32` added automatically
- Inline assembler for system operations

---

## ⚙️ Level 3: .t27 (Generated Assembler)

```t27
; Generated from calculator.tri
; tri vibee gen calculator.tri --target tri27

.code
    LDI t0, 5      ; Load a = 5 into box t0
    LDI t1, 3      ; Load b = 3 into box t1
    ADD t2, t0, t1 ; Add: t2 = t0 + t1
    ST t2, 100     ; Store result in memory address 100
    HALT           ; Stop!
```

**What happens here:**
- Each line of `.tri` → one or more `.t27` commands
- Registers `t0, t1, t2` — "boxes" for numbers
- `HALT` — end of program (added automatically)

---

## 🔄 Mapping: .tri → Zig → .t27

| .tri Line | Zig Code | .t27 Command | What Happens |
|-----------|-----------|--------------|----------------|
| `a: u32 = 5` | `const a: u32 = 5` | `LDI t0, 5` | Put 5 into box t0 |
| `b: u32 = 3` | `const b: u32 = 3` | `LDI t1, 3` | Put 3 into box t1 |
| `a + b` | `return a + b` | `ADD t2, t0, t1` | Add t0 + t1 → into t2 |
| (no direct analog) | `store(result, 100)` | `ST t2, 100` | Store t2 into memory |

---

## 🔍 Visualizing Registers

```
Before execution:
┌─────┬─────┬─────┬─────┬─────┐
│ t0  │ t1  │ t2  │ ... │
│  ?  │  ?  │  ?  │     │
└─────┴─────┴─────┴─────┴─────┘

After LDI t0, 5:
┌─────┬─────┬─────┬─────┬─────┐
│ t0  │ t1  │ t2  │ ... │
│  5  │  ?  │  ?  │     │
└─────┴─────┴─────┴─────┴─────┘

After LDI t1, 3:
┌─────┬─────┬─────┬─────┬─────┐
│ t0  │ t1  │ t2  │ ... │
│  5  │  3  │  ?  │     │
└─────┴─────┴─────┴─────┴─────┘

After ADD t2, t0, t1:
┌─────┬─────┬─────┬─────┬─────┐
│ t0  │ t1  │ t2  │ ... │
│  5  │  3  │  8  │     │
└─────┴─────┴─────┴─────┴─────┘
        │   │    │
        └───┴─────┘
          5 + 3 = 8 ✅
```

---

## 🧪 Run (Full Pipeline)

> ⚠️ **Note**: `tri vibee gen` is planned for Phase 2.
> Currently, write .t27 files manually. The examples below show the full pipeline as it will work once VIBEE code generation is implemented.

```bash
# For now, write .t27 directly:
cat > calculator.t27 << 'EOF'
.code
    LDI t0, 5      ; Load 5 into t0
    LDI t1, 3      ; Load 3 into t1
    ADD t2, t0, t1 ; Add t0 + t1, result in t2
    ST t2, 100     ; Store result to memory address 100
    HALT           ; Stop!
EOF

# Assemble .t27 → .tbin
tri tri27 assemble calculator.t27 -o calculator.tbin

# Run on TRI-27
tri tri27 run calculator.tbin

# Check result (value 8 at memory address 100)
```

---

## 📖 New Commands (.t27)

| Command | Format | Description |
|---------|--------|----------|
| **LDI** | `LDI reg, imm` | Load Immediate — load number `imm` into register `reg` |
| **ADD** | `ADD dst, src1, src2` | Add `src1 + src2`, result in `dst` |
| **ST** | `ST reg, addr` | Store — save register value to memory address |
| **HALT** | `HALT` | Halt — stop program execution |

---

## 🏆 Challenges

Modify the program to calculate:

1. **7 + 9** = ? (hint: change numbers in LDI)
2. **10 + 15** = ?
3. **(5 + 3) × 2** = ?
4. **5 + 3 + 2** = ?

<details>
<summary>📝 Challenge Solutions</summary>

```t27
; 1. 7 + 9 = 16
.code
    LDI t0, 7
    LDI t1, 9
    ADD t2, t0, t1
    HALT

; 2. 10 + 15 = 25
.code
    LDI t0, 10
    LDI t1, 15
    ADD t2, t0, t1
    HALT

; 3. (5 + 3) × 2 = 16
.code
    LDI t0, 5
    LDI t1, 3
    ADD t2, t0, t1   ; t2 = 8
    LDI t3, 2
    ADD t4, t2, t3   ; t4 = 10
    HALT

; 4. 5 + 3 + 2 = 10
.code
    LDI t0, 5
    LDI t1, 3
    ADD t2, t0, t1   ; t2 = 8
    LDI t3, 2
    ADD t4, t2, t3   ; t4 = 10
    HALT
```
</details>

---

## 🎓 What We Learned?

✅ **Registers** — Boxes for numbers (t0, t1, t2...)
✅ **LDI** — Put number into a box
✅ **ADD** — Add two numbers from boxes
✅ **ST** — Move from a box to the shelf (memory)
✅ **HALT** — Stop!
✅ **Pipeline** — `.tri → vibee gen → .t27 → assemble → run`

---

**Next**: [Project 2: Abs (Absolute Value)](projects.md) →
