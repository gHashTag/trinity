---
sidebar_position: 4
---

# Memory Efficiency

Trinity achieves up to 20x memory savings compared to float32 representations through a combination of packed ternary encoding, lazy conversion strategies, and sparse vector formats. This page explains each memory optimization technique and when to use it.

## Ternary Information Density

Each ternary value (trit) can be one of three states: \{-1, 0, +1\}. This carries log2(3) = 1.58 bits of information. In contrast, a float32 value uses 32 bits, and even a single byte (int8) uses 8 bits. The theoretical minimum storage for a trit is 1.58 bits, and Trinity's packed format approaches this limit.

## HybridBigInt: Dual Representation

The `HybridBigInt` type (defined in the core library) provides a hybrid storage strategy with two internal representations:

- **Packed format**: Trits are stored at approximately 1.58 bits per trit using a custom encoding scheme. This is the memory-efficient representation used for storage and transmission.
- **Unpacked format**: Each trit occupies a full integer slot in a fixed-size array (`[MAX_TRITS]Trit`). This is the compute-friendly representation used during arithmetic operations.

Conversion between formats is lazy -- the system only unpacks when an operation requires element-level access, and only packs when storage efficiency is needed. This avoids redundant conversions in operation chains. The `ensureUnpacked()` method is called before JIT-compiled operations to guarantee direct memory access to the trit array.

## Packed Trit Encoding

At the lowest level, Trinity encodes trits using 2 bits per trit in packed byte arrays. The encoding maps:

| Trit Value | 2-bit Encoding |
|------------|---------------|
| -1 | 0b10 |
| 0 | 0b00 |
| +1 | 0b01 |

Four trits fit in a single byte. For a 10,000-dimensional vector:

| Format | Size | Calculation |
|--------|------|-------------|
| float32 | 40,000 bytes (40 KB) | 10,000 x 4 bytes |
| int8 | 10,000 bytes (10 KB) | 10,000 x 1 byte |
| Packed 2-bit | 2,500 bytes (2.5 KB) | 10,000 x 2 bits / 8 |
| Theoretical (1.58-bit) | 1,981 bytes (~2 KB) | 10,000 x 1.58 bits / 8 |

The packed 2-bit format achieves a 16x reduction compared to float32. With the higher-density 1.58 bits/trit packing used by HybridBigInt, the compression approaches 20x.

## Sparse Vector Representation

For vectors where a large proportion of trits are zero (sparsity > 50%), Trinity provides a `SparseVector` type that uses the Coordinate List (COO) format. Instead of storing every element, it stores only the indices and values of non-zero elements:

```
SparseVector {
    indices: [u32]    -- sorted positions of non-zero trits
    values:  [Trit]   -- trit values at those positions (-1 or +1)
    dimension: u32    -- total vector length
}
```

Memory usage scales with the number of non-zero elements (nnz) rather than the total dimension:

| Sparsity | 10,000-dim Dense (packed) | 10,000-dim Sparse (COO) | Savings |
|----------|--------------------------|------------------------|---------|
| 50% zeros | 2,500 bytes | ~25,000 bytes | None (sparse is worse) |
| 90% zeros | 2,500 bytes | ~5,000 bytes | None (sparse is worse) |
| 99% zeros | 2,500 bytes | ~500 bytes | 5x |
| 99.9% zeros | 2,500 bytes | ~50 bytes | 50x |

The sparse format becomes advantageous at very high sparsity levels (above ~95% zeros), which occurs in certain VSA encoding patterns and after thresholding operations. The `SparseVector` provides a `sparsity()` method to measure the zero ratio and a `memorySavings()` method to compare against the equivalent dense representation.

## Choosing the Right Format

| Use Case | Recommended Format | Reason |
|----------|-------------------|--------|
| General VSA operations | HybridBigInt (packed) | Good balance of memory and speed |
| JIT-compiled hot paths | HybridBigInt (unpacked) | Direct memory access for native code |
| Storage and serialization | Packed trit arrays | Minimum size for dense vectors |
| Very sparse data (>95% zeros) | SparseVector (COO) | Memory proportional to non-zero count |
| BitNet model weights | Packed ternary | 20x compression vs float32 |

## Impact on Inference

For BitNet b1.58 language models, the memory savings from ternary weights are substantial. A 7B parameter model in float32 requires approximately 28 GB of memory for weights alone. With ternary packing at 1.58 bits per weight, the same model fits in roughly 1.4 GB -- small enough to run on a single consumer GPU or even in system RAM on a laptop.
