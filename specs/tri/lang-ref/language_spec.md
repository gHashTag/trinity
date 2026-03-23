# Tri Language Specification

> **Tri is a purely functional, non-OOP, ternary programming language**
> Sacred Formula: `φ² + 1/φ² = 3` — connects all layers of Trinity S³AI

---

## Paradigm & Philosophy

Tri is designed for **neuromorphic hardware acceleration** with sacred mathematics at its core:
- **Purely functional**: No objects, classes, methods, or inheritance
- **Ternary by design**: {-1, 0, +1} values enable 20x memory efficiency
- **Structured by φ**: All proportions follow the golden ratio ≈ 1.618
- **Explicit mutation**: No hidden state; all changes are explicit via function parameters

---

## 🚫 FORBIDDEN CONSTRUCTS

The following constructs are **STRICTLY FORBIDDEN** in any `.tri` source file:

### 1. OOP Keywords
```
❌ class, object, this, super, interface, extends, implements
❌ virtual, override, abstract (as class modifiers)
❌ public, private, protected (as access modifiers)
```

### 2. OOP Methods
```
❌ Any function attached to a type (e.g., `foo.bar()` as method)
❌ Getter/setter pairs as methods
❌ Method overloading
```

### 3. Inheritance & Polymorphism
```
❌ Type inheritance hierarchies
❌ Virtual method tables
❌ Abstract base classes
❌ Mixins
```

### 4. Exceptions
```
❌ throw, try, catch, finally, error handling via exceptions
```

### 5. Hidden State
```
❌ Global mutable variables (static state that changes invisibly)
❌ Objects with hidden mutable internal fields
❌ Implicit context (this, self)
```

### 6. Reflection & RTTI
```
❌ Dynamic type inspection
❌ Runtime type casting (except explicit ternary/int conversions)
❌ Reflection APIs
```

### 7. Implicit Dependencies
```
❌ Side-effectful expressions (implicit reads/writes)
❌ Implicit imports or require statements
```

---

## ✅ REQUIRED PATTERN

### 1. Top-Level Functions Only
All logic MUST be expressed as top-level functions:
```tri
// ✅ GOOD: Top-level function
fn compute(a: Ternary, b: Ternary) Ternary {
    return ternary_add(a, b);
}

// ❌ BAD: Function as method attached to struct
struct Math {
    fn add(self: Math, a: Ternary, b: Ternary) Ternary { // OOP-style!
        return ternary_add(a, b);
    }
}
```

### 2. Struct as Record Types ONLY
Data structures MUST be simple `struct` products:
```tri
// ✅ GOOD: Pure record type
pub const Vector = struct {
    data: [1024]Trit,
    dimensions: u32,
};

// ❌ BAD: Function-typed struct emulating methods
pub struct Vector {
    pub fn dot(self: Vector, other: Vector) f64 { ... } // OOP-style!
}
```

### 3. Enum as Sum Types (ADT)
Variants MUST use `enum` with pattern matching:
```tri
// ✅ GOOD: ADT with match
pub const Value = enum {
    int: i64,
    float: f64,
    trit: Trit,
    nil,
};

fn process(val: Value) i64 {
    return match val {
        .int => |n| n,
        .float => |f| @floatFromInt(f),
        .trit => |t| @as(i64, t),
        .nil => 0,
    };
}

// ❌ BAD: Interface + polymorphism
interface Value { fn toNumber() i64; }
```

### 4. Match for All Branching
All variant selection MUST use `match`:
```tri
// ✅ GOOD: Explicit pattern matching
fn evaluate(expr: Expr) Ternary {
    return switch (expr) {
        .literal => |n| n,
        .add => |e| ternary_add(e.left, e.right),
        .mul => |e| ternary_mul(e.operand, e.value),
        else => unreachable,
    };
}

// ❌ BAD: Virtual method dispatch or if-else chains on type
```

### 5. Immutable Values by Default
All values are immutable by default. Mutation is EXPLICIT:
```tri
// ✅ GOOD: Explicit function parameter
fn process(input: [Ternary]) [Ternary] {
    // input is NOT modified here
    return transform(input);
}

// ❌ BAD: Implicit mutation through pointer
fn process_bad(input: *[Ternary]) [Ternary] {
    input[0] = ternary_negate(input[0]); // Hidden mutation!
}
```

### 6. Module Organization
Modules are organized by FILE, not by class:
```tri
// ✅ GOOD: Module-based organization
// file: tri/sacred_alu.tri — Sacred ALU operations
// file: tri/vsa_ops.tri — VSA operations
// file: tri/memory.tri — Memory operations

// ❌ BAD: Class-based organization
class SACRED_ALU { ... }  // OOP-style!
```

---

## Type System

### Primitives
| Type | Description |
|-------|-------------|
| **Trit** | Ternary value: {-1, 0, +1} |
| **Ternary** | 64-bit packed ternary (2 trits per byte) |
| **GF16** | 16-bit IEEE 754 format (for hardware) |
| **TF3** | 3-bit packed ternary (9 trits per byte) |

### Composite Types
All composite types use ADT (Algebraic Data Types):
```tri
pub const Value = enum {
    trit: Trit,
    ternary: Ternary,
    gf16: GF16,
    tf3: TF3,
    string: []const u8,
    nil,
};
```

---

## Standard Library

Tri includes standard functions organized by module:

| Module | Functions |
|---------|-----------|
| **sacred_alu** | φ-constants, sacred geometry, φ-powers |
| **vsa_ops** | bind, unbind, bundle, permute, similarity |
| **memory** | allocate, free, load, store (ternary-aware) |
| **control** | conditional jumps, loop constructs |
| **fpga** | direct hardware operations, TMU integration |

---

## Grammar Summary

```
file        := module EOF
module        := identifier (import) | (module identifier)
declaration  := fn | const | type

fn           := 'fn' identifier parameter_list? type_expr
type_expr     := identifier | primitive_type | composite_type | fn_type
```

---

## Enforcement

### Parser Level (tric)
Any `.tri` file containing forbidden constructs MUST result in `ParseError`:
```
ParseError {
    OOP_NOT_SUPPORTED,
    CLASS_SYNTAX_DETECTED,
    METHOD_SYNTAX_DETECTED,
    HIDDEN_STATE_DETECTED,
}
```

### Linter Level (tri-lsp)
The linter MUST reject patterns resembling OOP:
- Detect `class`, `object`, `this` usage
- Flag function fields that look like methods
- Warn on implicit mutation patterns

### Tool Level (tri-fmt, tric, tri-lsp)
Formatter MUST reject:
- Auto-generate functional style, not preserve OOP patterns
- Convert any detected OOP to functional equivalent
- Flag files that repeatedly violate the paradigm

---

## Implementation Targets

### tri-emu (Software)
```zig
// ✅ Allowed: Pure Zig functions, no classes
// ✅ Allowed: Struct-based VM state
// ✅ Allowed: Match-based dispatch
```

### tri-hw (FPGA)
```verilog
// ✅ Allowed: Pure combinatorial logic
// ✅ Allowed: Sacred ALU modules
// ❌ Forbidden: Verilog tasks (sequential, behavioral)
```

---

## Versioning

Current version: **Tri v1.0 — Functional Foundation**

Version increments:
- **MAJOR**: New architectural features (e.g., new opcode category)
- **MINOR**: New standard library functions
- **PATCH**: Bug fixes, optimizations

---

## References

- [Trinity S³AI Architecture](../trinity_s3ai_architecture.md)
- [φ-Structure](../sacred/CHARTER.md)
- [VSA module](../../src/vsa/README.md)
