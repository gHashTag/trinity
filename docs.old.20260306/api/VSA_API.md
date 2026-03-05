# VSA API Reference

> Vector Symbolic Architecture for Balanced Ternary Computing

**Module:** `src/vsa.zig`

---

## Overview

VSA (Vector Symbolic Architecture) implements hyperdimensional computing operations using balanced ternary vectors `{-1, 0, +1}`.

### Key Features
- SIMD-accelerated operations (32 trits per cycle)
- Memory-efficient HybridBigInt backend
- Similarity measures (cosine, hamming, dot product)

---

## Core Operations

### bind(a, b) → HybridBigInt

Creates associations between two vectors via element-wise multiplication.

```zig
const result = vsa.bind(&vector_a, &vector_b);
```

**Properties:**
- `bind(a, a)` = all +1 (self-inverse)
- `bind(a, bind(a, b))` = b (unbind property)
- Preserves similarity structure

---

### unbind(bound, key) → HybridBigInt

Retrieves a vector from a binding. Same as `bind()` for balanced ternary.

```zig
const original = vsa.unbind(&bound_vector, &key);
```

---

### bundle2(a, b) → HybridBigInt

Combines two vectors via majority voting (superposition).

```zig
const combined = vsa.bundle2(&vector_a, &vector_b);
```

**Algorithm:** For each position, result = sign(a + b)
- If sum > 0 → +1
- If sum < 0 → -1
- If sum = 0 → 0

---

### bundle3(a, b, c) → HybridBigInt

Combines three vectors via majority voting.

```zig
const combined = vsa.bundle3(&a, &b, &c);
```

**Algorithm:** Result = majority(a, b, c) at each position

---

## Similarity Operations

### cosineSimilarity(a, b) → f64

Measures similarity between vectors. Returns value in [-1, 1].

```zig
const similarity = vsa.cosineSimilarity(&a, &b);
// 1.0 = identical, 0.0 = orthogonal, -1.0 = opposite
```

---

### hammingDistance(a, b) → u64

Counts differing positions between vectors.

```zig
const distance = vsa.hammingDistance(&a, &b);
```

---

### dotSimilarity(a, b) → i64

Computes inner product of two vectors.

```zig
const dot = vsa.dotSimilarity(&a, &b);
```

---

## Permutation Operations

### permute(v, count) → HybridBigInt

Cyclic right shift. Used for encoding sequences.

```zig
const shifted = vsa.permute(&vector, 3); // shift right by 3
```

---

### inversePermute(v, count) → HybridBigInt

Cyclic left shift (inverse of permute).

```zig
const restored = vsa.inversePermute(&shifted, 3);
```

---

## Usage Example

```zig
const std = @import("std");
const vsa = @import("vsa.zig");

pub fn main() !void {
    // Create random vectors
    var apple = vsa.HybridBigInt.random(1000);
    var red = vsa.HybridBigInt.random(1000);
    var fruit = vsa.HybridBigInt.random(1000);

    // Bind: apple = red + fruit
    var red_fruit = vsa.bind(&red, &fruit);
    var apple_repr = vsa.bind(&apple, &red_fruit);

    // Query: what is apple?
    var query_result = vsa.unbind(&apple_repr, &apple);

    // Check similarity
    const sim_to_red_fruit = vsa.cosineSimilarity(&query_result, &red_fruit);
    std.debug.print("Similarity: {d}\n", .{sim_to_red_fruit});
}
```

---

## Performance

| Operation | Complexity | SIMD Accelerated |
|-----------|------------|------------------|
| bind | O(n) | Yes |
| bundle2 | O(n) | Yes |
| bundle3 | O(n) | Yes |
| cosineSimilarity | O(n) | Yes |
| hammingDistance | O(n) | Yes |
| permute | O(n) | Partial |

---

## See Also

- [HYBRID_API.md](HYBRID_API.md) — HybridBigInt storage
- [VM_API.md](VM_API.md) — VM with VSA opcodes
- [Architecture](../architecture/ARCHITECTURE.md) — System design
