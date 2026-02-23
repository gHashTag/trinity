# trinity-core

**Foundation Module** — VSA operations, Ternary VM, JIT acceleration

```
phi² + 1/phi² = 3 = TRINITY
```

---

## Overview

`trinity-core` is the **foundation module** with **zero dependencies**. It provides:

- **VSA Operations** — Vector Symbolic Architecture primitives
- **Ternary VM** — Stack-based bytecode interpreter
- **HybridBigInt** — Ternary big integer arithmetic
- **JIT Compilation** — Just-in-time acceleration (x86_64, ARM64)
- **Packed Trit Encoding** — 1.58 bits/trit storage
- **High-level SDK** — Easy-to-use API

---

## Quick Start

```zig
const core = @import("trinity-core");

// VSA Operations
const vsa = core.vsa;
var a = try Hypervector.init(allocator, 1024);
var b = try Hypervector.init(allocator, 1024);
var bound = try vsa.bind(allocator, a, b);

// Ternary VM
const vm = core.vm;
var interpreter = try vm.Interpreter.init(allocator);
defer interpreter.deinit(allocator);

// SDK
const sdk = core.sdk;
var hv = try sdk.Hypervector.init(allocator, 1024);
defer hv.deinit(allocator);
```

---

## Module Structure

```
trinity-nexus/core/src/
├── root.zig              # Module exports
├── bigint.zig            # BigInt operations
├── packed_trit.zig       # Packed ternary encoding
├── hybrid.zig            # HybridBigInt (1.58 bits/trit)
├── vsa.zig               # VSA operations facade
├── vm.zig                # Ternary Virtual Machine
├── sdk.zig               # High-level SDK
├── jit.zig               # JIT compiler facade
├── jit_x86_64.zig        # x86_64 JIT backend
├── jit_arm64.zig         # ARM64 JIT backend
├── jit_unified.zig       # Unified JIT interface
├── vsa_jit.zig           # VSA-accelerated JIT
├── ternary_matmul.zig    # Ternary matrix multiply
├── vsa/                  # VSA subsystem
│   ├── bind.zig
│   ├── unbind.zig
│   ├── bundle.zig
│   ├── similarity.zig
│   └── ...
└── ml/                   # ML primitives
    ├── matmul.zig
    └── ...
```

---

## API Reference

### VSA Operations

```zig
// Bind two vectors (association)
pub fn bind(allocator: Allocator, a: Hypervector, b: Hypervector) !Hypervector

// Unbind to retrieve vector
pub fn unbind(allocator: Allocator, bound: Hypervector, key: Hypervector) !Hypervector

// Bundle (majority vote)
pub fn bundle2(allocator: Allocator, a: Hypervector, b: Hypervector) !Hypervector
pub fn bundle3(allocator: Allocator, a: Hypervector, b: Hypervector, c: Hypervector) !Hypervector

// Similarity
pub fn cosineSimilarity(a: Hypervector, b: Hypervector) f32
pub fn hammingDistance(a: Hypervector, b: Hypervector) usize

// Permutation
pub fn permute(v: Hypervector, count: usize) Hypervector
```

### Trit Type

```zig
pub const Trit = enum(i8) {
    negative = -1,  // FALSE
    zero = 0,       // UNKNOWN
    positive = 1,   // TRUE
};
```

### HybridBigInt

```zig
pub const HybridBigInt = struct {
    // Packed representation (1.58 bits/trit)
    packed: []u8,

    // Unpacked cache (for active operations)
    cache: []Trit,

    pub fn init(allocator: Allocator, max_trits: usize) !HybridBigInt
    pub fn deinit(self: *HybridBigInt, allocator: Allocator) void
    pub fn add(self: *HybridBigInt, other: HybridBigInt) !void
    pub fn mul(self: *HybridBigInt, other: HybridBigInt) !void
};
```

### Ternary VM

```zig
pub const Interpreter = struct {
    stack: []TernaryValue,
    bytecode: []BytecodeOp,

    pub fn init(allocator: Allocator) !Interpreter
    pub fn deinit(self: *Interpreter, allocator: Allocator) void
    pub fn execute(self: *Interpreter) !TernaryValue
};

pub const BytecodeOp = enum(u8) {
    push_pos, push_neg, push_zero,
    add, sub, mul, div,
    bind, unbind, bundle,
    jump, jump_if, call, ret,
};
```

---

## Constants

```zig
pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 0.618033988749895;
pub const PHI_SQ: f64 = 2.618033988749895;
pub const TRINITY: f64 = 3.0;
pub const SQRT5: f64 = 2.2360679774997896;
```

---

## Build & Test

```bash
# From workspace root
cd trinity-nexus

# Build core library
zig build trinity-core

# Run core tests
zig build test-core

# Run specific test
zig test core/src/vsa.zig
```

---

## Performance Characteristics

| Operation | Complexity | Notes |
|-----------|-----------|-------|
| bind/unbind | O(n) | n = hypervector dimension |
| bundle | O(n) | Majority vote across trits |
| similarity | O(n) | Cosine similarity |
| permute | O(1) | Cyclic rotation |
| JIT compile | O(p) | p = program size |

**Memory**: Hypervectors use 1 byte/trit (unpacked) or 1.58 bits/trit (packed).

---

## Examples

### Associative Memory

```zig
const core = @import("trinity-core");
const vsa = core.vsa;

// Create symbol vectors
var cat = try Hypervector.random(allocator, 1024);
var dog = try Hypervector.random(allocator, 1024);
var animal = try Hypervector.random(allocator, 1024);

// Create associations: cat ↔ animal, dog ↔ animal
var cat_animal = try vsa.bind(allocator, cat, animal);
var dog_animal = try vsa.bind(allocator, dog, animal);

// Bundle associations
var knowledge = try vsa.bundle2(allocator, cat_animal, dog_animal);

// Query: what is cat related to?
var query = try vsa.unbind(allocator, knowledge, cat);
var similarity = vsa.cosineSimilarity(query, animal);
// similarity ≈ 0.8 (high match)
```

### Ternary VM

```zig
const core = @import("trinity-core");
const vm = core.vm;

// bytecode: [push_pos, push_pos, add, ret]
var program = [_]vm.BytecodeOp{
    .push_pos, .push_pos, .add, .ret
};

var interpreter = try vm.Interpreter.init(allocator);
defer interpreter.deinit(allocator);

try interpreter.loadProgram(&program);
const result = try interpreter.execute();
// result = .positive (1 + 1 = 2, clamped to +1 in ternary)
```

---

## Dependencies

**None** — This is the foundation module.

---

## Version

```
trinity-core v0.1.0
```

---

**φ² + 1/φ² = 3**
