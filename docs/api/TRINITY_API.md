# Trinity API Reference

## Core Types

### Trit
```zig
pub const Trit = enum(i2) {
    neg = -1,
    zero = 0,
    pos = 1,
};
```

### TritVector
```zig
pub const TritVector = struct {
    data: []Trit,
    dimension: usize,
    
    pub fn init(allocator: Allocator, dim: usize) !TritVector;
    pub fn deinit(self: *TritVector, allocator: Allocator) void;
    pub fn clone(self: *const TritVector, allocator: Allocator) !TritVector;
};
```

### PackedTritVector
Memory-efficient storage using 2 bits per trit.
```zig
pub const PackedTritVector = struct {
    data: []u8,
    dimension: usize,
    
    pub fn get(self: *const PackedTritVector, index: usize) Trit;
    pub fn set(self: *PackedTritVector, index: usize, value: Trit) void;
};
```

---

## Core Operations

### bind
Creates association between two vectors (element-wise multiplication).
```zig
pub fn bind(a: *const TritVector, b: *const TritVector) TritVector
```
- Commutative: `bind(a, b) = bind(b, a)`
- Self-inverse: `bind(bind(a, b), b) = a`

### bundle
Combines multiple vectors (element-wise majority vote).
```zig
pub fn bundle(vectors: []*const TritVector) TritVector
```

### permute
Rotates vector elements for sequence encoding.
```zig
pub fn permute(v: *const TritVector, shift: i32) TritVector
```

### similarity
Computes cosine similarity between vectors.
```zig
pub fn cosineSimilarity(a: *const TritVector, b: *const TritVector) f64
```
Returns value in [-1.0, 1.0].

### dotProduct
Computes dot product.
```zig
pub fn dotProduct(a: *const TritVector, b: *const TritVector) i64
```
Performance: 8.9 B trits/sec with SIMD.

### randomVector
Generates random ternary vector.
```zig
pub fn randomVector(dimension: usize, seed: u64) TritVector
```

---

## Knowledge Graph API

```zig
pub const KnowledgeGraph = struct {
    pub fn init(allocator: Allocator) KnowledgeGraph;
    pub fn deinit(self: *KnowledgeGraph) void;
    
    pub fn addTriple(self: *KnowledgeGraph, subject: []const u8, predicate: []const u8, object: []const u8) !void;
    pub fn query(self: *KnowledgeGraph, subject: ?[]const u8, predicate: ?[]const u8, object: ?[]const u8) ![]Triple;
    pub fn similarEntities(self: *KnowledgeGraph, entity: []const u8, k: usize) ![]SimilarEntity;
};
```

---

## VM Instructions

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x01 | BIND | Bind top two vectors |
| 0x02 | BUNDLE | Bundle n vectors |
| 0x03 | PERMUTE | Permute by n positions |
| 0x04 | SIMILARITY | Compute similarity |
| 0x05 | THRESHOLD | Apply threshold |
| 0x10 | LOAD | Load from memory |
| 0x11 | STORE | Store to memory |
| 0xFF | HALT | Stop execution |

---

## CLI Commands

### vibee gen
```bash
./bin/vibee gen <spec.vibee> [--output dir] [--language zig|varlog]
```

### vibee run
```bash
./bin/vibee run <program.999> [--debug] [--trace]
```

### vibee koschei
```bash
./bin/vibee koschei [chain|status]
```
