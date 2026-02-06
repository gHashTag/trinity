---
sidebar_position: 9
---

# JIT Compilation API

[VSA](/docs/concepts/glossary) operations run in loops over thousands of vector elements. The JIT compiler replaces these loops with native SIMD instructions, processing 16--32 elements per CPU cycle. Result: **15--260x speedup** on hot paths. You do not need to understand JIT internals -- just create an engine and call the same operations.

The JIT system compiles specialized machine code for your exact vector dimension at runtime. The first call for a given dimension compiles the function. Every subsequent call reuses the cached native code.

**Source files:** `src/vsa_jit.zig`, `src/jit_unified.zig`, `src/jit_arm64.zig`, `src/jit_x86_64.zig`

## Do I Need JIT?

Not every workload benefits from JIT compilation. Use this guide:

:::tip When to enable JIT
**Yes, use JIT if:**
- You run many VSA operations in a loop (encoding, querying, training)
- Your vector dimension is 1000 or higher
- Latency matters (real-time systems, interactive tools)

**No, skip JIT if:**
- You only run a handful of one-off operations
- You are prototyping and want simpler debugging
- Your vector dimension is under 500 (scalar loops are fast enough)
:::

## Expected Speedups

Approximate speedups on ARM64 (Apple Silicon / NEON) compared to scalar loops:

| Dimension | dot product | bind | cosine | permute |
|-----------|-------------|------|--------|---------|
| 1000 | ~15x | ~20x | ~25x | ~50x |
| 5000 | ~30x | ~40x | ~50x | ~150x |
| 10000 | ~50x | ~50x | ~60x | ~260x |

Speedups grow with dimension because SIMD amortizes overhead across more elements.

:::warning
x86-64 support is **partial**. Only dot product and bind have SIMD acceleration. All other operations fall back to scalar loops. ARM64 has full SIMD coverage.
:::

## JitVSAEngine

The primary interface for JIT-accelerated VSA operations. Create one engine per thread (or use the [global convenience functions](#global-convenience-functions)).

### Construction

```zig
const vsa_jit = @import("vsa_jit");

var engine = vsa_jit.JitVSAEngine.init(allocator);
defer engine.deinit();
```

### Methods

#### `init(allocator: Allocator) JitVSAEngine`

Creates a new JIT engine with empty caches and zero statistics.

#### `deinit(self: *JitVSAEngine) void`

Frees all compiled functions, executable memory, and caches.

#### `dotProduct(self: *JitVSAEngine, a: *HybridBigInt, b: *HybridBigInt) !i64`

Computes the [dot product](/docs/concepts/glossary) of two hypervectors using JIT-compiled SIMD code. Vectors are automatically unpacked before the operation. The function compiles on first use for the given dimension and caches for reuse.

```zig
const dot = try engine.dotProduct(&vec_a, &vec_b);
// dot = 42 (example: sum of element-wise products)
```

#### `bind(self: *JitVSAEngine, a: *HybridBigInt, b: *HybridBigInt) !void`

Element-wise ternary multiplication ([binding](/docs/concepts/glossary)). **Modifies `a` in place.** The result vector `a` is marked dirty so the packed representation recomputes on next access.

```zig
try engine.bind(&vec_a, &vec_b); // vec_a now holds the bound result
```

:::warning
`bind` modifies the first argument in place. Clone the vector first if you need to keep the original.
:::

#### `bundle(self: *JitVSAEngine, a: *HybridBigInt, b: *HybridBigInt) !void`

Element-wise sum with ternary threshold ([bundling](/docs/concepts/glossary)). **Modifies `a` in place.** For each position: positive sum becomes `+1`, negative sum becomes `-1`, zero stays `0`.

```zig
try engine.bundle(&vec_a, &vec_b); // vec_a now holds the bundled result
```

#### `cosineSimilarity(self: *JitVSAEngine, a: *HybridBigInt, b: *HybridBigInt) !f64`

Computes cosine similarity using a fused single-pass kernel on ARM64 (2.5x faster than three separate dot products). On x86-64, falls back to computing `dot(a,b) / sqrt(dot(a,a) * dot(b,b))` using three JIT dot product calls.

Returns a value in the range `[-1.0, 1.0]`.

```zig
const sim = try engine.cosineSimilarity(&vec_a, &vec_b);
// sim = 0.0312 (example: near-zero means unrelated random vectors)
```

:::warning
**Dimension limit:** Vectors with dimension above `MAX_JIT_COSINE_DIM` (32768) automatically fall back to the scalar implementation. The SIMD fused kernel has precision constraints at very high dimensions.
:::

#### `hammingDistance(self: *JitVSAEngine, a: *HybridBigInt, b: *HybridBigInt) !i64`

Counts positions where `a[i] != b[i]`. Uses SIMD comparison on ARM64; scalar fallback on x86-64.

```zig
const dist = try engine.hammingDistance(&vec_a, &vec_b);
// dist = 667 (example: about 2/3 of elements differ for random vectors)
```

#### `permute(self: *JitVSAEngine, v: *HybridBigInt, k: usize) !HybridBigInt`

Cyclic right shift by `k` positions. Returns a **new** `HybridBigInt` (does not modify the input). Matches the semantics of `vsa.permute`: `result[i] = v[(i - k + dim) % dim]`.

```zig
const shifted = try engine.permute(&vec, 5);
// shifted is a new vector with all elements shifted right by 5
```

#### `inversePermute(self: *JitVSAEngine, v: *HybridBigInt, k: usize) !HybridBigInt`

Cyclic left shift by `k` positions (the inverse of `permute`). Returns a new `HybridBigInt`.

```zig
const unshifted = try engine.inversePermute(&shifted, 5);
// unshifted matches the original vec (roundtrip)
```

:::tip
Use `permute` and `inversePermute` as a pair to encode and decode position in sequences. They are exact inverses: `inversePermute(permute(v, k), k) == v`.
:::

#### `getStats(self: *JitVSAEngine) Stats`

Returns current engine statistics.

#### `printStats(self: *JitVSAEngine) void`

Prints formatted statistics to stderr.

### Stats

```zig
pub const Stats = struct {
    total_ops: u64,     // Total operations performed
    jit_hits: u64,      // Cache hits (reused compiled function)
    jit_misses: u64,    // Cache misses (compiled new function)
    cache_size: usize,  // Total compiled functions across all caches
    hit_rate: f64,      // Hit rate as percentage (0-100)
};
```

## Platform Support

| Operation | ARM64 (NEON) | x86-64 (AVX2) | Fallback |
|-----------|-------------|----------------|----------|
| dotProduct | SIMD hybrid | AVX2 hybrid | Scalar loop |
| bind | SIMD | Direct scalar | Scalar loop |
| bundle | SIMD (SMIN/SMAX) | Unsupported | Scalar loop |
| cosineSimilarity | Fused single-pass | 3x dot products | Scalar |
| hammingDistance | SIMD | Unsupported | Scalar loop |
| permute | SIMD | Unsupported | Scalar loop |

**ARM64** has the most complete SIMD coverage. The fused cosine similarity kernel computes `dot(a,b)`, `dot(a,a)`, and `dot(b,b)` in a single pass, reducing memory bandwidth by 2.5x.

**x86-64** currently accelerates dot product and bind only. Other operations use scalar fallbacks. The API stays identical across platforms; only performance differs.

**Unsupported architectures** (e.g., WASM, RISC-V) use scalar fallbacks for all operations.

## Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `MAX_JIT_COSINE_DIM` | 32768 | Maximum dimension for JIT cosine kernel |

## Global Convenience Functions

Thread-local global engine for simple use cases where managing engine lifetime is not worth the complexity:

```zig
const vsa_jit = @import("vsa_jit");

// Initialize once per thread
vsa_jit.initGlobal(allocator);
defer vsa_jit.deinitGlobal();

// Use without managing engine lifetime
const dot = try vsa_jit.jitDotProduct(allocator, &vec_a, &vec_b);
// dot = 42 (example)
```

#### `initGlobal(allocator: Allocator) void`

Initializes the thread-local global engine if not already initialized.

#### `deinitGlobal() void`

Destroys the thread-local global engine and frees all resources.

#### `jitDotProduct(allocator: Allocator, a: *HybridBigInt, b: *HybridBigInt) !i64`

Computes dot product using the global engine (initializes it if needed).

## Complete Example

```zig
const std = @import("std");
const vsa = @import("vsa");
const vsa_jit = @import("vsa_jit");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Create engine
    var engine = vsa_jit.JitVSAEngine.init(allocator);
    defer engine.deinit();

    // Create random test vectors (dimension 2000)
    var vec_a = vsa.randomVector(2000, 111);
    var vec_b = vsa.randomVector(2000, 222);
    var vec_c = vsa.randomVector(2000, 333);

    // JIT dot product (first call compiles, subsequent calls use cache)
    const dot1 = try engine.dotProduct(&vec_a, &vec_b);
    const dot2 = try engine.dotProduct(&vec_a, &vec_c);
    std.debug.print("dot(a,b) = {d}, dot(a,c) = {d}\n", .{ dot1, dot2 });
    // dot(a,b) = 14, dot(a,c) = -8 (example values for random vectors)

    // JIT cosine similarity
    const sim = try engine.cosineSimilarity(&vec_a, &vec_b);
    std.debug.print("cosine(a,b) = {d:.6}\n", .{sim});
    // cosine(a,b) = 0.010500 (example: near-zero for random vectors)

    // JIT bind
    var bound = vec_a; // copy first -- bind modifies in place
    try engine.bind(&bound, &vec_b);

    // JIT permute
    const shifted = try engine.permute(&vec_a, 10);
    const unshifted = try engine.inversePermute(&shifted, 10);

    // Verify roundtrip
    const roundtrip_sim = try engine.cosineSimilarity(&vec_a, &unshifted);
    std.debug.print("permute roundtrip similarity: {d:.6}\n", .{roundtrip_sim});
    // permute roundtrip similarity: 1.000000 (exact roundtrip)

    // Print cache statistics
    engine.printStats();
}
```

**Example statistics output:**

```
===============================================================
              JIT VSA ENGINE STATISTICS
===============================================================
  Total operations: 6
  JIT cache hits:   3
  JIT cache misses: 3
  Cache size:       3 functions
  Hit rate:         50.0%
===============================================================
```

<details>
<summary>Architecture: Compile-Time Backend Selection</summary>

The `jit_unified.zig` module detects the CPU architecture at compile time and selects the appropriate backend:

```zig
pub const Architecture = enum {
    arm64,
    x86_64,
    unsupported,
};

pub const current_arch: Architecture = switch (builtin.cpu.arch) {
    .aarch64 => .arm64,
    .x86_64 => .x86_64,
    else => .unsupported,
};

pub const is_jit_supported = current_arch != .unsupported;
```

On unsupported architectures, all JIT operations gracefully fall back to scalar loops.

</details>

<details>
<summary>Function Types (C calling convention)</summary>

JIT-compiled functions use the C calling convention for cross-language compatibility:

```zig
/// JIT dot product: (ptr_a, ptr_b) -> i64
pub const JitDotFn = *const fn (*anyopaque, *anyopaque) callconv(.c) i64;

/// JIT bind: (ptr_a, ptr_b) -> void (modifies a in place)
pub const JitBindFn = *const fn (*anyopaque, *anyopaque) callconv(.c) void;
```

</details>

<details>
<summary>Caching Strategy</summary>

`JitVSAEngine` maintains six separate caches, each keyed by vector dimension (or dimension + shift for permute). Once compiled for a given dimension, functions are reused for all subsequent operations at that dimension.

```
dot_cache:     dimension -> JitDotFn
bind_cache:    dimension -> JitDotFn
hamming_cache: dimension -> JitDotFn
cosine_cache:  dimension -> JitDotFn
bundle_cache:  dimension -> JitDotFn
permute_cache: (dimension, shift) -> JitDotFn
```

The underlying `UnifiedJitCompiler` instances are stored in an `ArrayList` to keep their executable memory mappings alive for the lifetime of the engine.

</details>

<details>
<summary>UnifiedJitCompiler (Low-Level API)</summary>

The low-level compiler interface used internally by `JitVSAEngine`. Most users should use `JitVSAEngine` instead.

```zig
const jit_unified = @import("jit_unified");

var compiler = jit_unified.UnifiedJitCompiler.init(allocator);
defer compiler.deinit();

// Compile a dot product for 1000-dimensional vectors
try compiler.compileDotProduct(1000);
const func = try compiler.finalize();

// Call the compiled function
const result = func(a_ptr, b_ptr);
```

### Compiler Methods

- `init(allocator: Allocator) UnifiedJitCompiler` -- Create compiler with architecture-appropriate backend
- `deinit(self: *UnifiedJitCompiler) void` -- Free executable memory
- `archName() []const u8` -- Returns human-readable architecture name (e.g., "ARM64 (AArch64)")
- `hasSIMD() bool` -- Whether SIMD instructions are available
- `compileDotProduct(dimension: usize)` -- Emit dot product instructions
- `compileBind(dimension: usize)` -- Emit bind instructions
- `compileFusedCosine(dimension: usize)` -- Emit fused cosine (ARM64 only, returns `error.UnsupportedOperation` on x86-64)
- `compileHamming(dimension: usize)` -- Emit hamming distance (ARM64 only)
- `compileBundleSIMD(dimension: usize)` -- Emit bundle with SMIN/SMAX (ARM64 only)
- `compilePermute(dimension: usize, shift: usize)` -- Emit cyclic shift (ARM64 only)
- `finalize() !JitDotFn` -- Finalize and return executable function pointer

</details>
