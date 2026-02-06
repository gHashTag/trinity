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

## Try It Live

```jsx live
function VSADemo() {
  // Ternary vectors: {-1, 0, +1}
  const vecA = [1, -1, 0, 1, -1, 1, 0, -1];
  const vecB = [-1, 1, 1, 0, -1, 1, -1, 0];

  // Bind: element-wise multiplication
  const bind = (a, b) => a.map((v, i) => v * b[i]);

  // Similarity: dot product normalized
  const similarity = (a, b) => {
    const dot = a.reduce((s, v, i) => s + v * b[i], 0);
    return (dot / a.length).toFixed(3);
  };

  // Hamming distance: count differences
  const hamming = (a, b) => a.filter((v, i) => v !== b[i]).length;

  const bound = bind(vecA, vecB);
  const selfBound = bind(vecA, vecA);

  return (
    <div style={{fontFamily: 'monospace', fontSize: '14px'}}>
      <div><b>Vector A:</b> [{vecA.join(', ')}]</div>
      <div><b>Vector B:</b> [{vecB.join(', ')}]</div>
      <hr/>
      <div><b>bind(A, B):</b> [{bound.join(', ')}]</div>
      <div><b>bind(A, A):</b> [{selfBound.join(', ')}] (all +1 = self-inverse)</div>
      <hr/>
      <div><b>similarity(A, B):</b> {similarity(vecA, vecB)}</div>
      <div><b>hamming(A, B):</b> {hamming(vecA, vecB)} differences</div>
    </div>
  );
}
```
