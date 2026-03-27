# Tri Language Roadmap

## Overview

Tri Language is a domain-specific language for Trinity S³AI. Single entry point for generating Zig and Verilog code from .tri specifications.

**Goal**: Single Source of Truth for CPU and FPGA backends.

---

## Status

| Component | Status | File |
|-----------|--------|------|
| Grammar | 🔄 In Progress | `specs/tri/grammar.tri` |
| Lexer | 🔄 In Progress | `src/tri-lang/lexer.zig` |
| Parser | ⏳ Planned | `src/tri-lang/parser.zig` |
| emit_zig | 🔄 In Progress | `src/tri-lang/emit_zig.zig` |
| emit_verilog | ⏳ Planned | `src/tri-lang/emit_verilog.zig` |

---

## Grammar

### Tokens

```
// Keywords
fn, return, if, else, while, for, struct, enum, ternary, sacred

// Types
i8, i16, i32, i64, trit, trit3, trit9, trit27, gf16, tf3

// Literals
42           // integer
3.14         // float
"Ternary"    // string
'tr'         // ternary literal

// Operators
+, -, *, /, %      // arithmetic
&, |, ^, ~, <<, >> // logic
@, ., ->, =>       // special
```

### Types

```tri
// Ternary types (native)
trit        // {-1, 0, +1}
trit3       // 3 trits packed
trit9       // 9 trits packed
trit27      // 27 trits packed

// Sacred types
gf16        // Golden Format 16 (exp=6, mant=9)
tf3         // Ternary Folding 3 (9 params)

// Composite
struct Vec3 {
    x: gf16,
    y: gf16,
    z: gf16,
}

enum Quality {
    good,
    unstable,
    bad,
    unknown,
}
```

### Functions

```tri
// Dot-product (ternary)
fn dot_product(a: []trit, b: []trit) i32 {
    var acc: i32 = 0;
    for (i in 0..a.len) {
        const w = a[i];
        acc += (w == 1) ? b[i] : (w == -1) ? -b[i] : 0;
    }
    return acc;
}

// Sacred multiplication (GF16)
fn sacred_mul(a: gf16, b: gf16, limit: gf16) gf16 {
    const prod = a * b;
    return clamp(prod, -limit, limit);
}
```

---

## Compiler

### Architecture

```
.tri spec (Single Source of Truth)
    ↓
Lexer (tokens)
    ↓
Parser (AST)
    ↓
Type Checker
    ↓              ↓
emit_zig        emit_verilog
    ↓              ↓
Zig backend    Verilog backend
    ↓              ↓
CPU code       FPGA bitstream
```

### Lexer

**File**: `src/tri-lang/lexer.zig`

**Purpose**:
- Tokenization of .tri source files
- Recognition of keywords, identifiers, literals
- Generation of Token stream

**Token type**:
```zig
pub const Token = union(enum) {
    keyword: Keyword,
    identifier: []const u8,
    literal: Literal,
    operator: Operator,
    eof,
};
```

### Parser

**File**: `src/tri-lang/parser.zig` (planned)

**Purpose**:
- Construction of AST from Token stream
- Syntax checking
- Generation of Error on invalid syntax

**AST node**:
```zig
pub const Node = union(enum) {
    function: Function,
    struct_def: StructDef,
    enum_def: EnumDef,
    statement: Statement,
    expression: Expression,
};
```

### Type Checker

**File**: `src/tri-lang/type_checker.zig` (planned)

**Purpose**:
- Type inference
- Type compatibility checking
- Generation of Type errors

**Type rules**:
- `trit ⊆ i32` — ternary can be used as integer
- `gf16 ↔ f16` — conversion without precision loss
- `tf3 → [8]trit` — unpacking

---

## Code Generation

### emit_zig

**File**: `src/tri-lang/emit_zig.zig`

**Purpose**:
- Generation of Zig code from AST
- Mapping Tri types → Zig types
- Generation of stdlib calls

**Type mapping**:
| Tri type | Zig type |
|----------|-----------|
| trit | i8 (values: -1, 0, 1) |
| trit3 | i8 (packed) |
| gf16 | f16 (via @bitCast) |
| tf3 | struct TF3 { scale: f16, weights: u16 } |

**Example**:
```tri
// Tri source
fn add(a: trit, b: trit) trit {
    return a + b;
}
```

```zig
// Generated Zig
fn add(a: i8, b: i8) i8 {
    const result = a + b;
    if (result > 1) return 1;
    if (result < -1) return -1;
    return result;
}
```

### emit_verilog

**File**: `src/tri-lang/emit_verilog.zig` (planned)

**Purpose**:
- Generation of Verilog code from AST
- Mapping Tri types → Verilog types
- Generation of module definitions

**Type mapping**:
| Tri type | Verilog type |
|----------|--------------|
| trit | `signed [1:0]` (00=0, 01=+1, 11=-1) |
| trit3 | `signed [5:0]` (6 trits) |
| gf16 | `signed [15:0]` (Q8.8 fixed-point) |
| tf3 | `struct { scaled signed [15:0]; weights [15:0]; }` |

**Example**:
```tri
// Tri source
fn mac(a: trit, w: trit, acc: i32) i32 {
    return acc + (w * a);
}
```

```verilog
// Generated Verilog
module mac (
    input wire signed [1:0] a,
    input wire signed [1:0] w,
    input wire signed [31:0] acc,
    output reg signed [31:0] result
);
    wire signed [2:0] mac_val =
        (w == 2'b01) ? {a[1], a} :
        (w == 2'b11) ? -{a[1], a} :
                       3'b0;
    always @(*) begin
        result = acc + {{29{mac_val[2]}}, mac_val};
    end
endmodule
```

---

## Component Integration

### HSLM code → Tri → CPU/FPGA

```
HSLM training (src/hslm/*.zig)
    ↓
Extract core algorithms
    ↓
Tri spec (specs/tri/hslm_ops.tri)
    ↓
tri build --target zig    → Zig code → CPU inference
tri build --target verilog → Verilog → FPGA bitstream
```

**Example**:
```tri
// specs/tri/ternary_mac.tri
struct TernaryMAC {
    fn forward(x: []gf16, w: []tf3, out: []gf16) void {
        for (i in 0..w.len) {
            const tw = unpack(w[i]);  // unpack 8 trits
            var acc: gf16 = 0;
            for (j in 0..8) {
                acc += (tw[j] == 1) ? x[j] : (tw[j] == -1) ? -x[j] : 0;
            }
            out[i] = acc;
        }
    }
}
```

### TRI-27 ISA → native ternary ops

```tri
// TRI-27 instructions in Tri
asm DOT dst, src1, src2 {
    // dst = dot_product(src1, src2)
    const result = dot_product(
        read_reg(src1),
        read_reg(src2)
    );
    write_reg(dst, result);
}
```

### Sacred ALU → dot-product, ternary arithmetic

```tri
// Sacred ALU operations
fn sacred_dot(a: []gf16, b: []gf16) gf16 {
    var acc: gf16 = 0;
    for (i in 0..a.len) {
        acc += sacred_mul(a[i], b[i], MAX_GF16);
    }
    return acc;
}
```

---

## Scientific Questions

### Q1: Influence of Ternary Types on Expressiveness
**Hypothesis**: Ternary types (trit, trit3, trit9) enable more compact expression of algorithms vs binary types.

**Metrics**:
- LOC for typical algorithms (dot-product, matmul)
- Cyclomatic complexity
- Type safety (compile-time errors)

**Experiment**:
```bash
# Write benchmark in Tri and Zig
tri bench compare --spec ternary_mac.tri --impl zig/ternary_mac.zig
```

### Q2: Dot Operator Optimization
**Hypothesis**: Dot operator (`a . b`) in Tri generates more efficient code vs loop.

**Metrics**:
- Instruction count
- Cycle count (CPU)
- LUT utilisation (FPGA)

**Experiment**:
```bash
# Compare dot vs loop
tri bench dot_vs_loop --size 1000 --backend zig,verilog
```

### Q3: Dual-Target Compilation Fidelity
**Hypothesis**: Zig and Verilog backends generate semantically equivalent code.

**Metrics**:
- Numerical results (identical within 1e-6)
- Behaviour corner cases (overflow, NaN)
- Performance parity (within 2×)

**Experiment**:
```bash
# Generate both backends
tri build --target zig,verilog --spec ternary_ops.tri

# Test on unified inputs
tri test compare --zig out/zig --verilog out/verilog --inputs test_vectors.json
```

---

## CLI

```bash
# Compile Tri spec to Zig
tri build --input specs/tri/hslm_ops.tri --target zig --output src/hslm/ops_gen.zig

# Compile Tri spec to Verilog
tri build --input specs/tri/hslm_ops.tri --target verilog --output fpga/hslm_ops.v

# Validate Tri spec
tri validate specs/tri/hslm_ops.tri

# Show AST (debug)
tri ast specs/tri/hslm_ops.tri --format json

# Type check
tri typecheck specs/tri/hslm_ops.tri
```

---

## Roadmap

### Phase 1: Grammar + Lexer (Q2 2026)
- [x] Define grammar in BNF
- [ ] Implement lexer
- [ ] Token stream tests

### Phase 2: Parser + AST (Q3 2026)
- [ ] Implement parser
- [ ] AST node definitions
- [ ] Parse tests

### Phase 3: Type Checker (Q3 2026)
- [ ] Type inference
- [ ] Type compatibility rules
- [ ] Type error messages

### Phase 4: emit_zig (Q4 2026)
- [ ] Zig code generation
- [ ] stdlib mapping
- [ ] Zig backend tests

### Phase 5: emit_verilog (Q1 2027)
- [ ] Verilog code generation
- [ ] Module generation
- [ ] Verilog backend tests

### Phase 6: Toolchain integration (Q2 2027)
- [ ] CLI (`tri build`)
- [ ] Error reporting
- [ ] Documentation

---

## File Structure

```
specs/tri/
├── grammar.tri           # Grammar definition
├── hslm_ops.tri          # HSLM operations
├── ternary_mac.tri       # Ternary MAC
└── sacred_alu.tri        # Sacred ALU operations

src/tri-lang/
├── lexer.zig             # Lexer implementation
├── parser.zig            # Parser implementation
├── type_checker.zig      # Type checker
├── ast.zig               # AST node definitions
├── emit_zig.zig          # Zig backend
├── emit_verilog.zig      # Verilog backend
└── cli.zig               # CLI entrypoint
```

---

## Status

🔄 Grammar defined
🔄 Lexer in progress
⏳ Parser planned
⏳ Type checker planned
🔄 emit_zig in progress
⏳ emit_verilog planned

---

## Integration with Other Components

| Component | Interface | File |
|-----------|-----------|------|
| HSLM | Algorithm specs | `specs/tri/hslm_ops.tri` |
| TRI-27 | ISA instructions | `specs/tri/tri27_ops.tri` |
| FPGA | Verilog generation | `src/tri-lang/emit_verilog.zig` |

---

**φ² + 1/φ² = 3 | TRINITY**
