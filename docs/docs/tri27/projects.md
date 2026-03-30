# 🎯 Projects 2-4: Abs, Fibonacci, Bubble Sort

> **Level**: After Project 1 (Calculator)
> **New Concepts**: Conditions, loops, arrays

---

## 📯 Table of Contents

1. [Project 2: Absolute Value (Abs)](#project-2-absolute-value-abs)
2. [Project 3: Fibonacci](#project-3-fibonacci-numbers)
3. [Project 4: Bubble Sort](#project-4-bubble-sort)

---

## Project 2: Absolute Value (Abs)

> **Goal**: Find absolute value |-7| = 7
> **New**: Conditions (CMP, JZ)

### 📐 Problem Statement

Absolute value is always positive:
- |5| = 5 (already positive)
- |-7| = 7 (flip the sign)

### 📜 Zig (what we want)

```zig
// Generated code — for understanding
fn abs(x: i32) i32 {
    if (x < 0) {
        return -x;
    }
    return x;
}

pub fn main() void {
    const result = abs(-7);  // = 7
}
```

### ⚙️ .t27 (Assembler)

```t27
; Project 2: Absolute Value
; Input: number in t0
; Output: absolute value in t0

.code
    LDI t0, -7      ; t0 = -7 (input number)

    ; Compare with zero
    CMP t0, 0       ; Compare t0 with 0, sets flags
    JGE positive    ; If t0 >= 0, jump to positive

    ; t0 < 0 — negative, flip the sign
    LDI t1, 0       ; t1 = 0
    SUB t2, t1, t0  ; t2 = 0 - (-7) = 7
    MOV t0, t2      ; t0 = 7
    JUMP done       ; Jump to done

positive:
    ; t0 >= 0 — already positive, do nothing
    NOP             ; No Operation (empty command)

done:
    ST t0, 100      ; Store result to memory
    HALT
```

### 🔄 Mapping Zig → .t27

| Zig | .t27 | Explanation |
|-----|------|-------------|
| `if (x < 0)` | `CMP t0, 0` + `JGE positive` | Comparison with conditional jump |
| `return -x` | `SUB t2, t1, t0` | Subtract from zero = flip sign |
| `return x` | (nothing) | Already in t0 |

### 🔍 Visualization

```
① Start:
t0 = -7

② After CMP t0, 0:
Flag N (Negative) = 1 (number is negative)

③ After JGE positive:
JGE doesn't trigger (number < 0), continue

④ After SUB t2, t1, t0:
t2 = 0 - (-7) = 7

⑤ After MOV t0, t2:
t0 = 7 ✅
```

### 🏆 Challenge

Modify the program for:
1. |15| = ?
2. |-3| = ?
3. |0| = ?

---

## Project 3: Fibonacci Numbers

> **Goal**: Calculate first N Fibonacci numbers
> **New**: Loops, counter, memory access

### 📐 Problem Statement

Fibonacci numbers: each next = sum of two previous
```
0, 1, 1, 2, 3, 5, 8, 13, 21, 34, ...
```

### 📜 Zig (what we want)

```zig
// Generated code
fn fibonacci(n: u32) void {
    var a: u32 = 0;
    var b: u32 = 1;
    var i: u32 = 0;

    while (i < n) : (i += 1) {
        store(a, address: 100 + i * 4);  // Save to memory
        var temp = a + b;
        a = b;
        b = temp;
    }
}
```

### ⚙️ .t27 (Assembler)

```t27
; Project 3: Fibonacci
; Calculates first 10 Fibonacci numbers
; Results saved to memory starting at address 100

.code
    ; Initialization
    LDI t0, 0       ; a = 0 (first number)
    LDI t1, 1       ; b = 1 (second number)
    LDI t2, 0       ; i = 0 (counter)
    LDI t3, 10      ; n = 10 (how many numbers)

    ; Address for saving
    LDI t4, 100     ; base_address = 100

loop:
    ; Check: i >= n?
    CMP t2, t3      ; Compare counter with limit
    JGE done        ; If i >= 10, exit

    ; Save a to memory
    ST t0, [t4]     ; memory[t4] = a

    ; Calculate next number
    MOV t5, t0      ; temp = a
    ADD t0, t1, t5  ; a = b + temp (new number)
    MOV t1, t5      ; b = temp (shift)

    ; Increment counter and address
    INC t2          ; i++
    ADDI t4, 4      ; base_address += 4

    JUMP loop       ; Repeat

done:
    HALT
```

### 🔄 Mapping Zig → .t27

| Zig | .t27 | Explanation |
|-----|------|-------------|
| `while (i < n)` | `CMP t2, t3` + `JGE done` + `JUMP loop` | Loop with condition |
| `a + b` | `ADD t0, t1, t5` | Addition |
| `i += 1` | `INC t2` | Increment |
| `store(a, addr)` | `ST t0, [t4]` | Save to memory |

### 🔍 Memory Visualization

```
Address | Value | Explanation
--------|----------|----------
100     | 0      | F(0) = 0
104     | 1      | F(1) = 1
108     | 1      | F(2) = 1
112     | 2      | F(3) = 2
116     | 3      | F(4) = 3
120     | 5      | F(5) = 5
124     | 8      | F(6) = 8
128     | 13     | F(7) = 13
132     | 21     | F(8) = 21
136     | 34     | F(9) = 34
```

### 🏆 Challenge

1. Calculate first 15 Fibonacci numbers
2. Start with F(1) = 1, F(2) = 1 (no zero)
3. Find the 50th Fibonacci number (careful, big number!)

---

## Project 4: Bubble Sort

> **Goal**: Sort an array of numbers
> **New**: Nested loops, element comparison

### 📐 Problem Statement

Sort array in ascending order:
```
Before: [5, 2, 8, 1, 9]
After:  [1, 2, 5, 8, 9]
```

### 📜 Zig (what we want)

```zig
fn bubble_sort(arr: []u32) void {
    var n = arr.len;

    var i: u32 = 0;
    while (i < n - 1) : (i += 1) {
        var j: u32 = 0;
        while (j < n - i - 1) : (j += 1) {
            if (arr[j] > arr[j + 1]) {
                // Swap values
                var temp = arr[j];
                arr[j] = arr[j + 1];
                arr[j + 1] = temp;
            }
        }
    }
}
```

### ⚙️ .t27 (Assembler)

```t27
; Project 4: Bubble Sort
; Sorts an array of 5 numbers
; Array is at address 100: [5, 2, 8, 1, 9]

.code
    ; Initialize array
    LDI t0, 5
    ST t0, 100      ; arr[0] = 5
    LDI t0, 2
    ST t0, 104      ; arr[1] = 2
    LDI t0, 8
    ST t0, 108      ; arr[2] = 8
    LDI t0, 1
    ST t0, 112      ; arr[3] = 1
    LDI t0, 9
    ST t0, 116      ; arr[4] = 9

    ; Sort parameters
    LDI t5, 5       ; n = 5 (array length)
    LDI t6, 0       ; i = 0 (outer counter)

outer_loop:
    ; Check: i >= n - 1?
    LDI t7, 4
    CMP t6, t7
    JGE sort_done

    ; Inner loop
    LDI t8, 0       ; j = 0

inner_loop:
    ; Check: j >= n - i - 1?
    MOV t9, t5      ; t9 = n
    SUB t9, t9, t6  ; t9 = n - i
    SUBI t9, 1      ; t9 = n - i - 1
    CMP t8, t9
    JGE inner_done

    ; Compare arr[j] and arr[j+1]
    LDI t10, 100
    ADD t10, t10, t8    ; address = 100 + j
    LD t11, [t10]       ; t11 = arr[j]
    LD t12, [t10 + 4]   ; t12 = arr[j+1]

    CMP t11, t12
    JLE no_swap

    ; Swap values
    ST t12, [t10]       ; arr[j] = arr[j+1]
    ST t11, [t10 + 4]   ; arr[j+1] = arr[j]

no_swap:
    INC t8              ; j++
    JUMP inner_loop

inner_done:
    INC t6              ; i++
    JUMP outer_loop

sort_done:
    HALT
```

### 🔄 Mapping Zig → .t27

| Zig | .t27 | Explanation |
|-----|------|-------------|
| `for i in 0..n` | `outer_loop` with `t6` | Outer loop |
| `for j in 0..n-i` | `inner_loop` with `t8` | Inner loop |
| `if (arr[j] > arr[j+1])` | `CMP t11, t12` + `JLE` | Compare elements |
| `swap(a, b)` | `ST t12, [t10]` + `ST t11, [t10+4]` | Swap via memory |

### 🔍 Execution Visualization

```
Initial array: [5, 2, 8, 1, 9]

i=0, j=0: Compare 5 and 2 → swap → [2, 5, 8, 1, 9]
i=0, j=1: Compare 5 and 8 → OK
i=0, j=2: Compare 8 and 1 → OK
i=1, j=3: Compare 8 and 9 → OK
i=1, j=4: Compare 2 and 5 → OK
i=1, j=5: Compare 5 and 1 → OK
i=1, j=6: Compare 1 and 9 → OK
i=1, j=7: Compare 8 and 9 → OK
i=1, j=8: Compare 9 and 1 → OK
i=1, j=9: Compare 1 and 2 → OK
...continues...

Result: [1, 2, 5, 8, 9] ✅
```

### 🏆 Challenge

1. Sort array in descending order
2. Sort an array of 10 numbers
3. Optimize: if no swaps in a pass, array is sorted!

---

## 🎓 What We Learned?

✅ **Project 2 (Abs)**:
- Conditions: `CMP`, `JZ`, `JNZ`, `JGE`, `JLE`
- Branching: `JUMP` for jumps
- Sign flip via subtract from zero

✅ **Project 3 (Fibonacci)**:
- Loops: counter + exit condition
- Memory access: `ST` for saving
- Address arithmetic: `ADDI` for address shift

✅ **Project 4 (Bubble Sort)**:
- Nested loops
- Array element access
- Value swap via temporary variable

---

## 🚀 Next Steps

- **[Full Reference](language-reference.md)** — All 36 commands
- **[Cheat Sheet](cheatsheet.md)** — One page for quick lookup

---

**Congratulations!** You've gone from a simple calculator to sorting arrays. This is the foundation of assembler! 🎉
