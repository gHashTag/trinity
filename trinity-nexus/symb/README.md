# trinity-symb

**Symbolic AI Module** — Knowledge graphs, TVC, triple extraction

```
phi² + 1/phi² = 3 = TRINITY
```

---

## Overview

`trinity-symb` provides **symbolic AI capabilities**:

- **Knowledge Graphs** — Triple extraction, DHT sync, IGLA integration
- **TVC Subsystem** — Ternary Vector Computing (IR, BigInt, VSA, VM, JIT)
- **Semantic Processing** — Natural language understanding via triples

---

## Quick Start

```zig
const symb = @import("trinity-symb");

// Extract triples from text
const triples_parser = symb.triples_parser;
var result = try triples_parser.extractFromText(
    allocator,
    "Claude is an AI assistant created by Anthropic."
);
// result.triples: [.{ "Claude", "is", "AI assistant" }, ...]

// Knowledge graph sync
const kg_sync = symb.kg_sync;
try kg_sync.syncToDHT(allocator, my_kg);

// TVC operations
const tvc_vsa = symb.tvc_vsa;
var vec = try tvc_vsa.TVCVector.init(allocator, 256);
defer vec.deinit(allocator);
```

---

## Module Structure

```
trinity-nexus/symb/src/
├── root.zig                    # Module exports
│
├── Knowledge Graph & Triples
├── triples_parser.zig          # Extract RDF triples from text
├── kg_sync.zig                 # DHT-based KG sync
├── kg_pipeline.zig             # KG processing pipeline
├── igla_knowledge_graph.zig    # IGLA integration
├── kg_server.zig               # KG HTTP server
├── trinity_kg_server.zig       # Trinity KG server
│
└── TVC (Ternary Vector Computing)
    └── tvc/
        ├── tvc_ir.zig          # Intermediate representation
        ├── tvc_bigint.zig      # TVC BigInt
        ├── tvc_packed.zig      # Packed trit encoding
        ├── tvc_hybrid.zig      # Hybrid storage
        ├── tvc_vsa.zig         # VSA operations
        ├── tvc_vm.zig          # TVC Virtual Machine
        ├── tvc_parser.zig      # TVC language parser
        ├── tvc_jit.zig         # TVC JIT compiler
        └── tvc_runtime.zig     # TVC runtime
```

---

## API Reference

### Triple Extraction

```zig
pub const Triple = struct {
    subject: []const u8,
    predicate: []const u8,
    object: []const u8,
    confidence: f32,
};

pub const ExtractionResult = struct {
    triples: []Triple,
    source_text: []const u8,
    extraction_time_ms: u64,
};

pub fn extractFromText(
    allocator: Allocator,
    text: []const u8
) !ExtractionResult
```

### Knowledge Graph Sync

```zig
pub fn syncToDHT(
    allocator: Allocator,
    kg: *KnowledgeGraph
) !void

pub fn syncFromDHT(
    allocator: Allocator,
    key: []const u8
) !?KnowledgeGraph
```

### TVC VSA

```zig
pub const TVCVector = struct {
    dimension: usize,
    data: []Trit,

    pub fn init(allocator: Allocator, dim: usize) !TVCVector
    pub fn deinit(self: *TVCVector, allocator: Allocator) void
    pub fn bind(self: TVCVector, other: TVCVector) !TVCVector
    pub fn bundle(self: TVCVector, other: TVCVector) !TVCVector
    pub fn similarity(self: TVCVector, other: TVCVector) f32
};
```

---

## TVC Subsystem

TVC (Ternary Vector Computing) is a specialized vector computing system using ternary algebra.

### TVC IR

```zig
pub const TVCOp = enum {
    // Unary
    negate,
    permute,
    threshold,

    // Binary
    add,
    mul,
    bind,
    bundle,
    similarity,

    // Control
    load,
    store,
    jump,
    call,
};

pub const TVCInstruction = struct {
    op: TVCOp,
    operands: []Operand,
    result: ?Operand,
};
```

### TVC VM

```zig
pub const TVCVM = struct {
    registers: []TVCVector,
    stack: []TVCVector,
    program: []TVCInstruction,
    pc: usize,

    pub fn init(allocator: Allocator, num_registers: usize) !TVCVM
    pub fn execute(self: *TVCVM) !void
    pub fn step(self: *TVCVM) !?TVCVector
};
```

---

## Examples

### Triple Extraction

```zig
const symb = @import("trinity-symb");
const triples_parser = symb.triples_parser;

const text = \\
    Trinity is a ternary computing framework. \\
    It uses VSA for vector operations. \\
    VSA stands for Vector Symbolic Architecture.

var result = try triples_parser.extractFromText(allocator, text);
defer result.deinit(allocator);

for (result.triples) |triple| {
    std.debug.print("{s} {s} {s} (confidence: {d:.2})\n", .{
        triple.subject,
        triple.predicate,
        triple.object,
        triple.confidence,
    });
}
// Output:
// Trinity is ternary computing framework
// It uses VSA for vector operations
// VSA stands for Vector Symbolic Architecture
```

### TVC Operations

```zig
const symb = @import("trinity-symb");
const tvc_vsa = symb.tvc_vsa;

var a = try tvc_vsa.TVCVector.init(allocator, 256);
defer a.deinit(allocator);

var b = try tvc_vsa.TVCVector.init(allocator, 256);
defer b.deinit(allocator);

// Initialize with random values
try a.randomize(0.5); // 50% density
try b.randomize(0.5);

// Bind vectors
var bound = try a.bind(b);
defer bound.deinit(allocator);

// Check similarity
const sim = a.similarity(b);
std.debug.print("Similarity: {d:.3}\n", .{sim});
```

---

## Build & Test

```bash
# From workspace root
cd trinity-nexus

# Build symb library
zig build trinity-symb

# Run symb tests
zig build test-symb

# Run specific test
zig test symb/src/triples_parser.zig
```

---

## Dependencies

- **trinity-core** — VSA operations, core types
- **trinity-lang** — VIBEE compiler integration

---

## TVC vs VSA

| Feature | TVC | VSA |
|---------|-----|-----|
| Base | Ternary algebra | Bipolar vectors |
| Operations | Ternary add/mul/bind | Bind/unbind/bundle |
| Storage | Packed trits | Hypervectors |
| VM | TVC VM | Ternary VM (core) |
| JIT | TVC JIT | VSA JIT (core) |

TVC is an **extended VSA** with additional operations optimized for knowledge graph operations.

---

## Performance

| Operation | Complexity | Throughput |
|-----------|-----------|------------|
| Triple extraction | O(n²) | ~1000 triples/sec |
| TVC bind | O(d) | ~10M ops/sec |
| TVC bundle | O(d) | ~10M ops/sec |
| DHT sync | O(log n) | Network-bound |

---

## Version

```
trinity-symb v0.1.0
```

---

**φ² + 1/phi² = 3**
