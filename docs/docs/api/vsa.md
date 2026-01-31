---
sidebar_position: 1
---

# VSA API Reference

Core VSA operations in `trinity.vsa`.

## Vector Operations

### `bind(a, b) -> HybridBigInt`

Creates an association between two vectors.

```zig
var result = trinity.bind(&a, &b);
```

**Parameters:**
- `a`: First vector (mutable pointer)
- `b`: Second vector (mutable pointer)

**Returns:** New vector representing the binding

---

### `unbind(bound, key) -> HybridBigInt`

Recovers a vector from a binding. Same as `bind` for balanced ternary.

```zig
var original = trinity.unbind(&bound, &key);
```

---

### `bundle2(a, b) -> HybridBigInt`

Combines two vectors using majority voting.

```zig
var combined = trinity.bundle2(&a, &b);
```

---

### `bundle3(a, b, c) -> HybridBigInt`

Combines three vectors using true majority voting.

```zig
var combined = trinity.bundle3(&a, &b, &c);
```

---

### `permute(v, k) -> HybridBigInt`

Cyclically shifts vector elements right by k positions.

```zig
var shifted = trinity.permute(&v, 5);
```

**Parameters:**
- `v`: Vector to permute
- `k`: Number of positions to shift

---

### `inversePermute(v, k) -> HybridBigInt`

Cyclically shifts vector elements left by k positions.

```zig
var original = trinity.inversePermute(&shifted, 5);
```

---

## Similarity Functions

### `cosineSimilarity(a, b) -> f64`

Computes cosine similarity between two vectors.

```zig
const sim = trinity.cosineSimilarity(&a, &b);
// Returns value in [-1, 1]
```

---

### `hammingDistance(a, b) -> usize`

Counts the number of differing elements.

```zig
const dist = trinity.hammingDistance(&a, &b);
```

---

### `hammingSimilarity(a, b) -> f64`

Normalized Hamming similarity (1 - distance/length).

```zig
const sim = trinity.hammingSimilarity(&a, &b);
// Returns value in [0, 1]
```

---

### `dotSimilarity(a, b) -> f64`

Normalized dot product.

```zig
const sim = trinity.dotSimilarity(&a, &b);
```

---

## Sequence Functions

### `encodeSequence(items) -> HybridBigInt`

Encodes a sequence of vectors using permute.

```zig
var items = [_]trinity.HybridBigInt{ a, b, c };
var seq = trinity.encodeSequence(&items);
```

---

### `probeSequence(seq, candidate, position) -> f64`

Checks if a candidate is at a specific position in a sequence.

```zig
const sim = trinity.probeSequence(&seq, &word, 1);
```

---

## Utility Functions

### `randomVector(len, seed) -> HybridBigInt`

Creates a random vector with given length and seed.

```zig
var v = trinity.randomVector(256, 12345);
```

**Parameters:**
- `len`: Vector length (max 256)
- `seed`: Random seed for reproducibility
