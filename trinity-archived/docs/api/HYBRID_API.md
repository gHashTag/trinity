# Hybrid API Reference

> HybridBigInt — Optimal Memory/Speed Trade-off for Ternary Vectors

**Module:** `src/hybrid.zig`

---

## Overview

HybridBigInt provides dual-mode storage for balanced ternary vectors:
- **Packed mode:** 5 trits per byte (memory efficient)
- **Unpacked mode:** 1 trit per byte (compute efficient)

Automatic conversion between modes optimizes for current operation.

---

## Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `MAX_TRITS` | 59049 (3^10) | Maximum vector dimension |
| `TRITS_PER_BYTE` | 5 | Packing density |
| `SIMD_WIDTH` | 32 | SIMD parallel trits |

---

## Types

### Trit

```zig
pub const Trit = i8;  // Values: -1, 0, +1
```

### StorageMode

```zig
pub const StorageMode = enum {
    packed_mode,    // 5 trits/byte, memory efficient
    unpacked_mode,  // 1 trit/byte, compute efficient
};
```

### HybridBigInt

```zig
pub const HybridBigInt = struct {
    mode: StorageMode,
    trit_len: usize,
    packed_data: [MAX_PACKED_BYTES]u8,
    unpacked_cache: [MAX_TRITS]Trit,
    dirty: bool,
};
```

---

## Core Functions

### zero() → HybridBigInt

Creates zero vector.

```zig
var v = HybridBigInt.zero();
```

---

### random(len) → HybridBigInt

Creates random vector of specified length.

```zig
var v = HybridBigInt.random(1000);
```

---

### fromI64(value) → HybridBigInt

Converts integer to balanced ternary.

```zig
var v = HybridBigInt.fromI64(42);
```

---

### toI64(self) → i64

Converts balanced ternary to integer.

```zig
const value = vector.toI64();
```

---

## Storage Operations

### pack(self)

Converts to packed mode (memory efficient).

```zig
vector.pack();
// Now uses 5 trits per byte
```

---

### unpack(self) / ensureUnpacked(self)

Converts to unpacked mode (compute efficient).

```zig
vector.ensureUnpacked();
// Now ready for SIMD operations
```

---

## SIMD Functions

### simdAddTrits(a, b) → {sum, carry}

Adds 32 trits in parallel with carry propagation.

```zig
const result = simdAddTrits(vec_a, vec_b);
// result.sum: normalized sum
// result.carry: overflow trits
```

---

### simdNegate(v) → Vec32i8

Negates 32 trits in parallel.

```zig
const neg = simdNegate(vec);
```

---

### simdDotProduct(a, b) → i32

Dot product of 32 trits.

```zig
const dot = simdDotProduct(vec_a, vec_b);
```

---

### simdIsZero(v) → bool

Checks if all 32 trits are zero.

```zig
if (simdIsZero(vec)) {
    // All zeros
}
```

---

## Memory Efficiency

| Mode | Storage | Speed | Use Case |
|------|---------|-------|----------|
| Packed | 1.58 bits/trit | Slower | Storage, transmission |
| Unpacked | 8 bits/trit | Fast | Computation, SIMD |

**Comparison with binary:**
- Packed ternary: 20x smaller than float32
- Information density: 1.58 bits/trit (optimal for base-3)

---

## Usage Example

```zig
const hybrid = @import("hybrid.zig");

pub fn main() !void {
    // Create vectors
    var a = hybrid.HybridBigInt.random(10000);
    var b = hybrid.HybridBigInt.random(10000);

    // Pack for storage
    a.pack();
    b.pack();

    // Memory usage: 10000 / 5 = 2000 bytes each

    // Unpack for computation
    a.ensureUnpacked();
    b.ensureUnpacked();

    // SIMD operations now available
}
```

---

## See Also

- [VSA_API.md](VSA_API.md) — High-level VSA operations
- [VM_API.md](VM_API.md) — Virtual machine
