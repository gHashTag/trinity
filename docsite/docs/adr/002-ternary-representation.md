# ADR 002: Ternary Representation with Packed Trits

**Date:** 2025-02-02
**Status:** Accepted
**Deciders:** @gHashTag
**Related:** [ADR-001](./001-vibee-compiler.md)

---

## Context

Trinity implements ternary computing {-1, 0, +1} (balanced ternary).

**Problems with naive approaches:**
1. **Array of i8:** Wastes 8x memory (1 trit = 1 byte)
2. **Enum of {-1,0,1}:** No SIMD support, cache-inefficient
3. **Float32 approximation:** Loses exact trit values, 32x memory overhead

**Requirements:**
- Memory efficiency: ~1.58 bits/trit (theoretical minimum)
- Fast packed ↔ unpacked conversion
- SIMD-compatible operations
- Exact trit preservation (no floating-point)

---

## Decision

**Adopt packed trit encoding with HybridBigInt pattern.**

### Encoding Scheme

| Trit | Binary | Description |
|------|--------|-------------|
| -1   | 00     | Negative |
| 0    | 01     | Zero |
| +1   | 10     | Positive |
| ?    | 11     | Reserved (future) |

**Density:** 2 bits/trit = 1.27x theoretical minimum (acceptable trade-off for SIMD)

### Implementation

```zig
// src/packed_trit.zig
pub const PackedTrits = struct {
    data: []u8,        // Packed storage
    length: usize,     // Number of trits
    cache: ?[]i8       // Unpacked cache (lazy)
};
```

### Operations

| Operation | Complexity | Notes |
|-----------|------------|-------|
| pack | O(n) | One-time |
| unpack | O(n) with cache O(1) | Lazy cache |
| bind | O(n) | Element-wise XOR |
| bundle | O(n) | Majority vote |
| similarity | O(n) | Cosine |

---

## Consequences

### Positive

✅ **20x memory savings** vs float32
✅ **SIMD-compatible** — u8 arrays work with AVX2/NEON
✅ **Fast conversion** — Lazy unpacking cache
✅ **Exact representation** — No floating-point errors
✅ **FPGA-friendly** — Maps directly to 2-bit registers

### Negative

⚠️ **Bit manipulation overhead** — Pack/unpack required
⚠️ **No native CPU support** — x86/ARM are binary-only
⚠️ **Cache complexity** — Need to manage packed/unpacked states

### Neutral

- Packed format for storage/transmission
- Unpacked format for computation
- HybridBigInt provides transparent switching

---

## References

- [Packed Trit Implementation](https://github.com/gHashTag/trinity/blob/main/src/packed_trit.zig)
- [HybridBigInt](https://github.com/gHashTag/trinity/blob/main/src/hybrid.zig)
- [Balanced Ternary Wikipedia](https://en.wikipedia.org/wiki/Balanced_ternary)

---

**φ² + 1/φ² = 3 = TRINITY**
