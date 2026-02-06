---
sidebar_position: 10
---

# Sparse Vector API

When most elements in your vector are zero, storing all of them wastes memory. `SparseVector` stores only the non-zero elements with their positions. For a 10,000-element vector with 90% zeros, this saves 10x memory and makes operations 10x faster.

Trinity uses [ternary vectors](/docs/concepts/glossary) (\{-1, 0, +1\}). Many operations -- masking, gating, thresholding -- produce vectors dominated by zeros. `SparseVector` exploits this by keeping two sorted arrays: indices (where non-zero elements live) and values (what those elements are). All lookups use binary search. All VSA operations use merge-join algorithms that skip zeros entirely.

**Source:** `src/sparse.zig`

## When to Use Sparse vs Dense

:::tip Rule of thumb
Use `SparseVector` when more than half your elements are zero. Below 50% zeros, the index overhead negates the memory savings.
:::

| Density | Memory (10K dim) | bind speed | Recommendation |
|---------|-----------------|------------|----------------|
| 5% non-zero | Sparse: ~2.5KB vs Dense: ~10KB | Sparse ~20x faster | Use Sparse |
| 33% non-zero | Sparse: ~16KB vs Dense: ~10KB | Similar | Use Dense |
| 66% non-zero | Sparse: ~33KB vs Dense: ~10KB | Dense ~2x faster | Use Dense |

:::warning
JIT operations require dense vectors. Convert with `toDense()` before passing to `JitVSAEngine`. See the [JIT API](./jit.md) for details.
:::

## Density After Operations

Different VSA operations change the density of your vectors. Plan accordingly:

| Operation | Output density | Explanation |
|-----------|---------------|-------------|
| **bind** | density_a x density_b | Only positions where *both* inputs are non-zero survive. Output is always sparser. |
| **bundle** | density_a + density_b - overlap | Positions from *either* input survive. Output is usually denser. |
| **permute** | Same as input | Elements just move to new positions. No zeros are created or removed. |

For example, binding two 10%-dense vectors produces roughly 1%-dense output (0.1 x 0.1 = 0.01). Bundling two 10%-dense vectors produces roughly 19%-dense output (0.1 + 0.1 - 0.01 = 0.19).

## SparseVector

### Construction

#### `init(allocator: Allocator, dimension: u32) SparseVector`

Creates an empty sparse vector with the given total dimension. No memory is allocated until elements are added.

```zig
const sparse = @import("sparse");

var vec = sparse.SparseVector.init(allocator, 10000);
defer vec.deinit();
```

#### `deinit(self: *SparseVector) void`

Frees the internal index and value arrays.

#### `random(allocator: Allocator, dimension: u32, density: f64, seed: u64) !SparseVector`

Creates a random sparse vector with the specified density (fraction of non-zero elements). Non-zero values are uniformly chosen as +1 or -1.

```zig
// 10% density: ~1000 non-zero elements in a 10000-dim vector
var vec = try sparse.SparseVector.random(allocator, 10000, 0.10, 42);
defer vec.deinit();
// vec.nnz() = ~1000
```

#### `fromDense(allocator: Allocator, dense: *HybridBigInt) !SparseVector`

Converts a dense `HybridBigInt` to sparse representation. Iterates over all elements and stores only non-zero trits.

```zig
var dense_vec = vsa.randomVector(1000, 42);
var sparse_vec = try sparse.SparseVector.fromDense(allocator, &dense_vec);
defer sparse_vec.deinit();
// sparse_vec.nnz() = ~667 (random ternary vectors are ~66% non-zero)
```

#### `toDense(self: *const SparseVector) HybridBigInt`

Converts back to a dense `HybridBigInt`. Initializes all positions to zero, then sets non-zero values from the sparse representation. Returns a stack-allocated `HybridBigInt`.

```zig
const dense = sparse_vec.toDense();
// dense is a full HybridBigInt with all dimensions filled in
```

#### `clone(self: *const SparseVector) !SparseVector`

Creates an independent copy of the sparse vector.

```zig
var copy = try vec.clone();
defer copy.deinit();
```

### Element Access

#### `set(self: *SparseVector, index: u32, value: Trit) !void`

Sets the value at the given index. Uses binary search to find the insertion point.

- If the value is non-zero and the index is new, inserts in sorted order.
- If the value is non-zero and the index exists, updates in place.
- If the value is zero and the index exists, removes the element (maintains sparsity).
- If the index is out of bounds (at or above `dimension`), the operation is silently ignored.

```zig
try vec.set(42, 1);    // Set position 42 to +1
try vec.set(100, -1);  // Set position 100 to -1
try vec.set(42, 0);    // Remove position 42 (now zero)
```

#### `get(self: *const SparseVector, index: u32) Trit`

Returns the trit value at the given index. Uses binary search. Returns `0` for positions not in the sparse representation or for out-of-bounds indices.

```zig
const val = vec.get(42);  // Returns -1, 0, or +1
```

### Properties

#### `nnz(self: *const SparseVector) usize`

Returns the number of non-zero elements.

```zig
const count = vec.nnz();
// count = 1000 (for a 10%-dense, 10000-dim vector)
```

#### `sparsity(self: *const SparseVector) f64`

Returns the sparsity ratio: `1.0 - nnz/dimension`. A value of 0.0 means all elements are non-zero; 1.0 means all elements are zero.

```zig
const s = vec.sparsity();
// s = 0.90 (90% of elements are zero)
```

#### `memoryBytes(self: *const SparseVector) usize`

Returns current memory usage in bytes, including struct overhead and the index/value arrays.

#### `memorySavings(self: *const SparseVector) f64`

Returns the memory savings ratio compared to a dense representation: `1.0 - sparse_bytes/dense_bytes`. A value of 0.8 means the sparse representation uses 80% less memory.

```zig
const savings = vec.memorySavings();
// savings = 0.80 (80% less memory than dense)
```

## VSA Operations

All VSA operations allocate and return a new `SparseVector`. The caller owns the result and must call `deinit` when done.

### `bind(allocator: Allocator, a: *const SparseVector, b: *const SparseVector) !SparseVector`

Element-wise ternary multiplication using a merge-join on sorted indices. The result contains elements only at positions where **both** inputs have non-zero values. The result is always at least as sparse as the sparser input.

```zig
var bound = try sparse.SparseVector.bind(allocator, &vec_a, &vec_b);
defer bound.deinit();
// bound.nnz() = ~100 (for two 10%-dense inputs: 0.1 * 0.1 * 10000)
```

### `unbind(allocator: Allocator, a: *const SparseVector, b: *const SparseVector) !SparseVector`

Identical to `bind` for balanced ternary. Multiplying by the inverse is the same as multiplying by the value itself when values come from \{-1, 0, +1\}.

### `bundle(allocator: Allocator, a: *const SparseVector, b: *const SparseVector) !SparseVector`

Element-wise sum with ternary threshold. Unlike bind, the result may be **denser** than the inputs because positions where only one input is non-zero survive. At positions where both inputs are non-zero, the sum is thresholded: positive becomes +1, negative becomes -1, zero is omitted.

```zig
var bundled = try sparse.SparseVector.bundle(allocator, &vec_a, &vec_b);
defer bundled.deinit();
// bundled.nnz() = ~1900 (denser than either input)
```

### `permute(allocator: Allocator, v: *const SparseVector, k: u32) !SparseVector`

Cyclic shift of all indices by `k` positions: `new_index = (old_index + k) % dimension`. Values are unchanged. The result is re-sorted by index after shifting.

```zig
var shifted = try sparse.SparseVector.permute(allocator, &vec, 5);
defer shifted.deinit();
// shifted.nnz() == vec.nnz() (same density, different positions)
```

## Similarity

Similarity functions are static methods that do not allocate memory.

### `dot(a: *const SparseVector, b: *const SparseVector) i64`

Sparse dot product using merge-join. Only positions present in both vectors contribute to the sum. Runs in O(nnz_a + nnz_b) time.

```zig
const d = sparse.SparseVector.dot(&vec_a, &vec_b);
// d = 12 (example: sum of element-wise products at shared positions)
```

### `cosineSimilarity(a: *const SparseVector, b: *const SparseVector) f64`

Cosine similarity: `dot(a,b) / (||a|| * ||b||)`. For ternary vectors, `||v||^2 = nnz(v)` since all non-zero values are +/-1. Returns 0.0 if either vector is the zero vector.

```zig
const sim = sparse.SparseVector.cosineSimilarity(&vec_a, &vec_b);
// sim = 0.012 (example: near-zero for random sparse vectors)
```

### `hammingDistance(a: *const SparseVector, b: *const SparseVector) usize`

Counts positions where `a[i] != b[i]`. This includes:
- Positions where both are non-zero but differ in value
- Positions where one is non-zero and the other is zero (implicitly)

Uses merge-join to efficiently compare only the non-zero regions.

```zig
const dist = sparse.SparseVector.hammingDistance(&vec_a, &vec_b);
// dist = 1800 (example: most non-zero positions differ for random vectors)
```

## Memory Complexity

| Representation | Memory | Bind Cost | Dot Product Cost |
|----------------|--------|-----------|-----------------|
| Dense (`HybridBigInt`) | O(dimension) | O(dimension) | O(dimension) |
| Sparse (`SparseVector`) | O(nnz) | O(nnz_a + nnz_b) | O(nnz_a + nnz_b) |

For a 10,000-dimensional vector with 500 non-zero elements (95% sparse), the sparse representation uses approximately 20x less memory.

## Complete Example

```zig
const std = @import("std");
const sparse = @import("sparse");
const vsa = @import("vsa");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Create sparse vectors with 10% density
    var vec_a = try sparse.SparseVector.random(allocator, 10000, 0.10, 111);
    defer vec_a.deinit();

    var vec_b = try sparse.SparseVector.random(allocator, 10000, 0.10, 222);
    defer vec_b.deinit();

    // Check properties
    std.debug.print("vec_a: nnz={d}, sparsity={d:.2}%, memory={d} bytes\n", .{
        vec_a.nnz(),
        vec_a.sparsity() * 100.0,
        vec_a.memoryBytes(),
    });
    // vec_a: nnz=1000, sparsity=90.00%, memory=5024 bytes

    std.debug.print("Memory savings vs dense: {d:.1}%\n", .{
        vec_a.memorySavings() * 100.0,
    });
    // Memory savings vs dense: 87.5%

    // Sparse bind (result is sparser than inputs)
    var bound = try sparse.SparseVector.bind(allocator, &vec_a, &vec_b);
    defer bound.deinit();
    std.debug.print("bind result: nnz={d} (expected ~{d})\n", .{
        bound.nnz(),
        @as(usize, @intFromFloat(0.10 * 0.10 * 10000.0)),
    });
    // bind result: nnz=98 (expected ~100)

    // Similarity
    const sim = sparse.SparseVector.cosineSimilarity(&vec_a, &vec_b);
    std.debug.print("cosine similarity: {d:.6}\n", .{sim});
    // cosine similarity: 0.012345

    // Convert to dense for JIT operations
    const dense_a = vec_a.toDense();
    _ = dense_a;

    // Convert dense back to sparse
    var dense_vec = vsa.randomVector(1000, 42);
    var sparse_from_dense = try sparse.SparseVector.fromDense(allocator, &dense_vec);
    defer sparse_from_dense.deinit();
    std.debug.print("Dense->sparse roundtrip: nnz={d}, sparsity={d:.2}%\n", .{
        sparse_from_dense.nnz(),
        sparse_from_dense.sparsity() * 100.0,
    });
    // Dense->sparse roundtrip: nnz=667, sparsity=33.30%
}
```

<details>
<summary>Internal Details</summary>

- **Sorted indices:** The `indices` array is always maintained in ascending sorted order. This invariant enables binary search for `get`/`set` and merge-join for VSA operations.
- **Insertion sort after permute:** After cyclic shifting, indices may become unsorted. The `permute` function uses insertion sort to restore order, which is efficient for nearly-sorted data.
- **No packed mode:** Unlike `HybridBigInt`, sparse vectors do not use bit-packed representation. The overhead of packing/unpacking would negate the sparse access benefits.

</details>
