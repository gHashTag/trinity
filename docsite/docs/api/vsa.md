---
sidebar_position: 2
---

# VSA API

Vector Symbolic Architecture for Balanced Ternary Computing.

**Module:** `src/vsa.zig`

## Core Operations

### bind(a, b) → HybridBigInt

Creates associations via element-wise multiplication.

```zig
const result = vsa.bind(&vector_a, &vector_b);
```

**Properties:**
- `bind(a, a)` = all +1 (self-inverse)
- `bind(a, bind(a, b))` = b (unbind)

### unbind(bound, key) → HybridBigInt

Retrieves a vector from a binding.

```zig
const original = vsa.unbind(&bound_vector, &key);
```

### bundle2(a, b) → HybridBigInt

Combines two vectors via majority voting.

```zig
const combined = vsa.bundle2(&vector_a, &vector_b);
```

### bundle3(a, b, c) → HybridBigInt

Combines three vectors via majority voting.

```zig
const combined = vsa.bundle3(&a, &b, &c);
```

## Similarity Operations

### cosineSimilarity(a, b) → f64

Returns similarity in [-1, 1].

```zig
const similarity = vsa.cosineSimilarity(&a, &b);
```

### hammingDistance(a, b) → u64

Counts differing positions.

```zig
const distance = vsa.hammingDistance(&a, &b);
```

### dotSimilarity(a, b) → i64

Computes inner product.

```zig
const dot = vsa.dotSimilarity(&a, &b);
```

## Permutation

### permute(v, count) → HybridBigInt

Cyclic right shift for sequence encoding.

```zig
const shifted = vsa.permute(&vector, 3);
```
