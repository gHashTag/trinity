# Tri Language v1.0 Specification

**Status**: STABLE ✅
**Date**: 2026-03-25
**Version**: 1.0.0

> The Tri Language is a ternary-first, effect-handling, linear-typed functional language designed for dual-target compilation (CPU/FPGA/VM) via TRI-27 bytecode.

---

## Table of Contents

1. [Overview](#overview)
2. [Wave 1: Syntax & Control](#wave-1-syntax--control)
3. [Wave 2: Types & Memory](#wave-2-types--memory)
4. [Wave 3: Effects & Handlers](#wave-3-effects--handlers)
5. [Wave 4: Combinators & Platform](#wave-4-combinators--platform)
6. [Grammar](#grammar)
7. [TRI-27 Opcodes](#tri-27-opcodes)

---

## Overview

Tri Language combines:
- **Ternary logic**: Native trit types (`trit`, `trit3`, `trit9`, `trit27`)
- **Algebraic Data Types**: Enums with data-carrying variants
- **Exhaustive pattern matching**: `match` with guards
- **Linear types**: `linear T` for consume-once semantics
- **Banked values**: `Banked<T, BankN>` for Coptic register safety
- **Algebraic effects**: `perform`, `handle`, `try ... with`
- **Array combinators**: `map`, `reduce`, `scan`, `filter`, `flatMap`, `zip`
- **Platform targets**: `CPU`, `FPGA`, `VM`, `Auto`

---

## Wave 1: Syntax & Control

### ADT Enums

```tri
enum Option {
    None,
    Some(T),
}
```

### Pattern Matching

```tri
match value {
    None => 0,
    Some(x) | x > 0 => x,
    Some(x) => 0,
}
```

### Pipe Operator

```tri
result = source |> stage1 |> stage2 |> stage3
```

### Coptic Registers (27 registers, 3 banks)

| Bank | Registers | Purpose |
|------|-----------|---------|
| Bank 0 (ALU) | t0-t8 (Ⲁ-Ⲑ) | General computation |
| Bank 1 (Sacred) | t9-t17 (Ⲓ-Ⲣ) | Accumulators |
| Bank 2 (Constant) | t18-t26 (Ⲥ-Ϥ) | Immutable constants |

---

## Wave 2: Types & Memory

### Result Type (No Exceptions)

```tri
let divide: (i32, i32) -> Result(i32, Error) = fn(a, b) {
    if b == 0 { return Err(DivisionByZero) }
    return Ok(a / b)
}
```

### Linear Types

```tri
linear File

let readFile: (File) -> String = fn(f) {
    let content = f.read()
    consume f  // Must use exactly once
    return content
}
```

### Banked Types

```tri
let x: Banked<i32, Bank0> = 42  // ALU register
let y: Banked<gf16, Bank1> = phi // Sacred accumulator
```

### Fixed-Size Arrays

```tri
let arr: [8]trit = [1, 0, -1, 1, 0, 0, -1, 1]
```

### Ownership Modes

```tri
let x = ...        // Immutable, can read multiple times
inout y = ...      // Mutable reference
sink z = ...       // Must consume exactly once
set w = ...        // Mutable owned value
```

---

## Wave 3: Effects & Handlers

### Effect Declaration

```tri
effect State {
    get,
    set(T),
}
```

### Perform and Handle

```tri
handle State {
    get => currentState,
    set(x) => { currentState = x }
}

let result = perform State.set(42)
```

### Try-With

```tri
try {
    let x = perform State.get()
    let y = perform State.set(x * 2)
    return y
} with {
    State.get(x) => x,
    State.set(x) => { /* update state */ }
}
```

### Built-in Effects

| Effect | Operations | Purpose |
|--------|-----------|---------|
| `IO` | read, write | Console/file I/O |
| `State` | get, set | Mutable state |
| `Error` | fail | Error handling |
| `Async` | await | Async operations |
| `PlatformCPU` | compile | Force CPU target |
| `PlatformFPGA` | synthesize | Force FPGA target |
| `PlatformVM` | interpret | Force VM target |

---

## Wave 4: Combinators & Platform

### Array Combinators (Futhark-style)

```tri
let doubled = map(arr, fn(x) { x * 2 })
let sum = reduce(arr, 0, +)
let scanned = scan(arr, 0, +, Inclusive)
let filtered = filter(arr, fn(x) { x > 0 })
let flattened = flatMap(arr, fn(x) { [x, x * 2] })
let paired = zip(arr1, arr2)
```

### Scan Types

| Type | Description |
|------|-------------|
| `Prefix` | Standard prefix scan |
| `Inclusive` | Include current element |
| `Exclusive` | Exclude current element |

### Platform Targets

```tri
// Type-level platform specification
let kernel: FPGA = fn(x: i32) -> i32 { ... }

// Effect-based platform selection
perform PlatformCPU.compile()
perform PlatformFPGA.synthesize()
perform PlatformVM.interpret()
```

| Target | Backend | Use Case |
|--------|---------|----------|
| `CPU` | Zig native | High-performance CPU |
| `FPGA` | Verilog | Hardware acceleration |
| `VM` | TRI-27 bytecode | Portable execution |
| `Auto` | Compiler choice | Automatic selection |

---

## Grammar

See `specs/tri_grammar.ebnf` for complete EBNF grammar.

### Core Expression Syntax

```
expr     ::= pipe_expr
pipe_expr ::= unary_expr ('|>' unary_expr)*
unary_expr ::= ('-' | '~')* primary_expr
primary_expr ::= literal
              | identifier
              | '(' expr ')'
              | '[' expr* ']'
              | array_combinator
              | match_expr

array_combinator ::= 'map' '(' expr ',' expr ')'
                  | 'reduce' '(' expr ',' expr ',' operator ')'
                  | 'scan' '(' expr ',' expr ',' expr ',' scan_type? ')'
                  | 'filter' '(' expr ',' expr ')'
                  | 'flatMap' '(' expr ',' expr ')'
                  | 'zip' '(' expr ',' expr ')'

match_expr ::= 'match' expr '{' match_arm* '}'
match_arm ::= pattern '=>' expr
pattern ::= '_' | literal | identifier | Variant '(' pattern ')'
```

---

## TRI-27 Opcodes

### Base Opcodes (0x00-0x7F)

| Opcode | Hex | Description |
|--------|-----|-------------|
| NOP | 0x00 | No operation |
| PUSH | 0x01 | Push to stack |
| POP | 0x02 | Pop from stack |
| LOADI | 0x10 | Load integer literal |
| LOADB | 0x11 | Load boolean literal |
| MOV | 0x20 | Move register |
| ADD/SUB/MUL/DIV | 0x30-0x33 | Arithmetic |
| EQ/NE/LT/GT | 0x40-0x44 | Comparison |
| JUMP/JZ | 0x50-0x51 | Control flow |
| CALL/RET | 0x60-0x61 | Function calls |

### ADT Opcodes (0x70-0x73)

| Opcode | Hex | Description |
|--------|-----|-------------|
| ADTN | 0x70 | Construct nullary ADT |
| ADTD | 0x71 | Construct data-carrying ADT |
| RESULT_OK | 0x72 | Construct Ok(value) |
| RESULT_ERR | 0x73 | Construct Err(error) |

### Linear Type Opcodes (0x74-0x76)

| Opcode | Hex | Description |
|--------|-----|-------------|
| LINEAR_CONSUME | 0x74 | Mark linear value as consumed |
| LINEAR_BORROW | 0x75 | Shared borrow |
| LINEAR_MOVE | 0x76 | Transfer ownership |

### Array Opcodes (0x77-0x79, 0x80-0x85)

| Opcode | Hex | Description |
|--------|-----|-------------|
| ARRAY_GET | 0x77 | Bounds-checked get |
| ARRAY_LEN | 0x78 | Get compile-time length |
| ARRAY_SET | 0x79 | Bounds-checked set |
| **ARRAY_MAP** | **0x80** | **Map function over array** |
| **ARRAY_REDUCE** | **0x81** | **Fold with binary op** |
| **ARRAY_SCAN** | **0x82** | **Prefix scan** |
| **ARRAY_FILTER** | **0x83** | **Filter by predicate** |
| **ARRAY_FLATMAP** | **0x84** | **Map and concatenate** |
| **ARRAY_ZIP** | **0x85** | **Pair two arrays** |

### Effect Opcodes (0x7A-0x7C)

| Opcode | Hex | Description |
|--------|-----|-------------|
| EFFECT_PERFORM | 0x7A | Perform effect operation |
| EFFECT_HANDLE | 0x7B | Handle effect |
| EFFECT_RESUME | 0x7C | Resume from handler |

---

## Implementation Status

| Component | File | Status |
|-----------|------|--------|
| Lexer | `src/tri-lang/lexer.zig` | ✅ |
| Parser | `src/tri-lang/parser.zig` | ✅ |
| Typechecker | `src/tri-lang/typechecker.zig` | ✅ |
| Codegen (TRI-27) | `src/tri-lang/emit_t27.zig` | ✅ |
| AST | `src/tri-lang/ast.zig` | ✅ |
| Grammar | `specs/tri_grammar.ebnf` | ✅ |
| Examples | `specs/tri_examples.tri` | ✅ |

---

## Next Steps (Post-v1.0)

These are **NOT** part of v1.0 core:

1. **Auto-parallelism**: DAG extraction from effect handlers
2. **Content-addressed functions**: Memoization via hashing
3. **Deep verification**: Lean integration for proofs
4. **Optimizer**: Algebraic simplification, fusion
5. **REPL**: Interactive development environment
6. **FFI**: Foreign function interface

---

## License

Part of the Trinity project. See LICENSE file for details.

---

**Tri Language v1.0 — STABLE**
*From sacred math to silicon, one trit at a time.*
