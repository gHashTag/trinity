---
sidebar_position: 3
---

# Types Reference

Core data types in Trinity.

## HybridBigInt

The main vector type with hybrid storage.

### Creation

```zig
// Zero vector
var v = trinity.HybridBigInt.zero();

// From integer
var v = trinity.HybridBigInt.fromI64(12345);

// Random vector
var v = trinity.randomVector(256, seed);
```

### Properties

```zig
v.trit_len      // Number of trits
v.mode          // .packed_mode or .unpacked_mode
v.dirty         // Needs re-packing
```

### Methods

```zig
// Convert to/from i64
const val = v.toI64();
var v = trinity.HybridBigInt.fromI64(val);

// Arithmetic
var sum = a.add(&b);
var diff = a.sub(&b);
var prod = a.mul(&b);

// Dot product
const dot = a.dotProduct(&b);

// Memory management
v.pack();           // Compress to packed format
v.ensureUnpacked(); // Decompress for computation
const bytes = v.memoryUsage();  // Packed size
```

---

## Trit

Single balanced ternary digit.

```zig
pub const Trit = i8;  // Values: -1, 0, +1
```

---

## BigInt

Arbitrary precision balanced ternary integer.

```zig
const trinity = @import("trinity");
const BigInt = trinity.BigInt;

var a = BigInt.fromI64(12345);
var b = BigInt.fromI64(67890);
var sum = a.addScalar(&b);
```

### Methods

- `fromI64(val)` - Create from i64
- `toI64()` - Convert to i64
- `addScalar(other)` - Addition
- `subScalar(other)` - Subtraction
- `mulScalar(other)` - Multiplication
- `divScalar(other)` - Division

---

## PackedBigInt

Memory-efficient storage (5 trits per byte).

```zig
const PackedBigInt = trinity.PackedBigInt;

var packed = PackedBigInt.fromI64(12345);
const bytes = packed.memoryUsage();  // ~4 bytes for small numbers
```

---

## Constants

```zig
trinity.MAX_TRITS       // 256 - Maximum vector dimension
trinity.TRITS_PER_BYTE  // 5 - Packing ratio
trinity.version         // "0.1.0"
```

---

## Storage Modes

```zig
pub const StorageMode = enum {
    packed_mode,    // 5 trits per byte, memory efficient
    unpacked_mode,  // 1 trit per byte, compute efficient
};
```

HybridBigInt automatically switches between modes:
- Stores in `packed_mode` (4.9x smaller)
- Computes in `unpacked_mode` (faster)
- Lazy unpacking on first access
