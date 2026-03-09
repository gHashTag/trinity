---
sidebar_position: 1
---

# Performance Tuning Guide

Optimize Trinity applications for maximum performance. This guide covers SIMD optimization, memory management, VSA operation tuning, and benchmarking best practices.

## Overview

Trinity's balanced ternary architecture provides unique performance characteristics:

| Aspect | Performance | Notes |
|--------|-------------|-------|
| **Memory Density** | 1.58 bits/trit | 20x more compact than float32 |
| **Compute** | Add-only operations | No multiplication needed for binding |
| **SIMD Potential** | High | Ternary operations vectorize well |
| **Cache Efficiency** | Excellent | Packed representation reduces cache misses |

## SIMD Optimization

### Understanding SIMD in Trinity

SIMD (Single Instruction, Multiple Data) allows processing multiple trits simultaneously. Zig's `@Vector()` type is the key to unlocking this performance.

### Basic SIMD Operations

#### Vectorized Binding

```zig
const std = @import("std");
const vsa = @import("trinity/vsa");

// Scalar version (slow)
fn bindScalar(a: []const i2, b: []const i2, result: []i2) void {
    for (a, 0..) |trit_a, i| {
        result[i] = trit_a * b[i];
    }
}

// SIMD version (8x faster on AVX2)
fn bindSIMD(a: []const i2, b: []const i2, result: []i2) void {
    const Vec = @Vector(16, i2);  // Process 16 trits at once
    const len = a.len / 16;

    var i: usize = 0;
    while (i < len) : (i += 1) {
        const va: Vec = a[i*16..][0..16].*;
        const vb: Vec = b[i*16..][0..16].*;
        result[i*16..][0..16].* = va * vb;
    }

    // Handle remainder
    const remainder = a.len % 16;
    if (remainder > 0) {
        const start = len * 16;
        for (0..remainder) |j| {
            result[start + j] = a[start + j] * b[start + j];
        }
    }
}
```

#### Vectorized Similarity Calculation

```zig
// Cosine similarity with SIMD
fn cosineSimilaritySIMD(a: []const i2, b: []const i2) f64 {
    const Vec = @Vector(16, i32);  // Use i32 to avoid overflow
    const len = a.len / 16;

    var dotVec: Vec = @splat(0);
    var i: usize = 0;

    while (i < len) : (i += 1) {
        const va: Vec = @intCast(a[i*16..][0..16].*);
        const vb: Vec = @intCast(b[i*16..][0..16].*);
        dotVec += va * vb;
    }

    // Reduce vector to scalar
    var dotSum: i32 = 0;
    for (0..16) |j| {
        dotSum += dotVec[j];
    }

    // Handle remainder
    for (len * 16..a.len) |j| {
        dotSum += @as(i32, a[j]) * @as(i32, b[j]);
    }

    return @as(f64, @floatFromInt(dotSum)) / @as(f64, @floatFromInt(a.len));
}
```

### SIMD Optimization Tips

| Tip | Benefit | Example |
|-----|---------|---------|
| **Align to 16/32 bytes** | Prevents cross-cache-line loads | `alignas(32) var data: [1024]i2` |
| **Use power-of-2 sizes** | Enables loop unrolling | Process 16/32/64 trits at once |
| **Prefetch memory** | Hides latency | `@prefetch(ptr[i + 8])` |
| **Avoid branches** | Keeps vector pipeline full | Use ternary operators instead of if |
| **Batch operations** | Amortizes overhead | Process 1000+ trits at once |

### Compiler Hints

```zig
// Tell Zig to vectorize
fn optimizedBind(a: []const i2, b: []const i2, result: []i2) void {
    @setRuntimeSafety(false);  // Disable bounds checking
    @setOptimizationMode(.Optimized);  // Force optimization

    const Vec = @Vector(32, i2);
    // ... implementation
}
```

## Memory Management

### HybridBigInt Memory Efficiency

Trinity's `HybridBigInt` uses a packed representation that's 20x more memory-efficient than float32 arrays.

#### Memory Comparison

| Representation | 10,000 Trits | Memory |
|----------------|--------------|--------|
| `[]f32` | 10,000 × 32-bit | 40 KB |
| `[]i8` (ternary) | 10,000 × 8-bit | 10 KB |
| `HybridBigInt` (packed) | 10,000 × 1.58-bit | 2 KB |

#### Pool Allocation for Frequent Operations

```zig
const VsaPool = struct {
    const VEC_SIZE = 10000;
    const POOL_SIZE = 100;

    allocator: std.mem.Allocator,
    pool: [POOL_SIZE]?vsa.HybridBigInt,

    fn init(allocator: std.mem.Allocator) VsaPool {
        return .{
            .allocator = allocator,
            .pool = [_]?vsa.HybridBigInt{null} ** POOL_SIZE,
        };
    }

    fn acquire(pool: *VsaPool) !*vsa.HybridBigInt {
        // Find free slot
        for (&pool.pool, 0..) |*slot, i| {
            if (slot.* == null) {
                slot.* = try vsa.HybridBigInt.init(pool.allocator, VEC_SIZE);
                return &slot.*.?;
            }
        }
        return error.PoolExhausted;
    }

    fn release(pool: *VsaPool, vec: *vsa.HybridBigInt) void {
        vec.deinit(pool.allocator);
        for (&pool.pool, 0..) |*slot, i| {
            if (slot.*) |v| {
                if (v == vec.*) {
                    slot.* = null;
                    return;
                }
            }
        }
    }
};
```

### Cache-Friendly Data Structures

#### Structure of Arrays vs. Array of Structures

```zig
// BAD: Array of Structures (cache misses)
const TrinaryVectorSoA = struct {
    data: []vsa.HybridBigInt,
};

// GOOD: Structure of Arrays (cache friendly)
const TrinaryVectorSoA = struct {
    // Store trits contiguously
    trits: []i2,
    length: usize,

    fn deinit(self: *const TrinaryVectorSoA, allocator: std.mem.Allocator) void {
        allocator.free(self.trits);
    }
};
```

### Memory Profiling

```bash
# Build with memory profiling
zig build -Drelease -Dmemory-profile

# Run with memory tracker
./zig-out/bin/tri --profile-memory

# Analyze heap usage
./zig-out/bin/tri --profile-heap > heap.log
zig tools/analyze-profile heap.log
```

## VSA Operation Optimization

### Batch Binding

```zig
// Process multiple bindings in one pass
fn batchBind(vectors: []const vsa.HybridBigInt, keys: []const vsa.HybridBigInt, results: []vsa.HybridBigInt) !void {
    // Pre-allocate all results
    for (0..vectors.len) |i| {
        results[i] = try vsa.HybridBigInt.init(allocator, vectors[i].len);
    }

    // Batch process (better cache locality)
    for (0..vectors.len) |i| {
        _ = try vsa.bind(&vectors[i], &keys[i], &results[i]);
    }
}
```

### Similarity Search Optimization

```zig
// Use spatial partitioning for faster nearest-neighbor search
const LshTable = struct {
    tables: []std.AutoHashMap(u64, []usize),
    num_tables: usize,
    num_hashes: usize,

    fn init(allocator: std.mem.Allocator, num_tables: usize, num_hashes: usize) !LshTable {
        var tables = try allocator.alloc(std.AutoHashMap(u64, []usize), num_tables);
        for (tables) |*table| {
            table.* = std.AutoHashMap(u64, []usize).init(allocator);
        }
        return .{
            .tables = tables,
            .num_tables = num_tables,
            .num_hashes = num_hashes,
        };
    }

    fn insert(lsh: *LshTable, allocator: std.mem.Allocator, idx: usize, vec: *const vsa.HybridBigInt) !void {
        for (0..lsh.num_tables) |t| {
            const hash = computeHash(vec, t);
            const entry = try lsh.tables[t].getOrPut(hash);
            if (!entry.found_existing) {
                entry.value_ptr.* = &[_]usize{};
            }
            // Append index
            const new_list = try allocator.alloc(usize, entry.value_ptr.len + 1);
            @memcpy(new_list[0..entry.value_ptr.len], entry.value_ptr.*);
            new_list[entry.value_ptr.len] = idx;
            entry.value_ptr.* = new_list;
        }
    }

    fn findNearest(lsh: *LshTable, query: *const vsa.HybridBigInt) !?usize {
        var candidates = std.ArrayList(usize).init(allocator);
        defer candidates.deinit();

        for (0..lsh.num_tables) |t| {
            const hash = computeHash(query, t);
            if (lsh.tables[t].get(hash)) |indices| {
                try candidates.appendSlice(indices);
            }
        }

        // Filter by actual similarity
        var best_idx: ?usize = null;
        var best_sim: f64 = 0.0;

        for (candidates.items) |idx| {
            const sim = try vsa.cosineSimilarity(query, &vectors[idx]);
            if (sim > best_sim) {
                best_sim = sim;
                best_idx = idx;
            }
        }

        return best_idx;
    }
};
```

### Permutation Caching

```zig
// Cache frequently used permutations
var perm_cache: std.AutoHashMap(usize, vsa.HybridBigInt) = undefined;

fn getCachedPermutation(vec: *const vsa.HybridBigInt, count: usize) !vsa.HybridBigInt {
    const key = @intFromPtr(vec.ptr) ^ count;

    if (perm_cache.get(key)) |cached| {
        return cached.clone();
    }

    const result = try vsa.permute(vec, count);
    try perm_cache.put(key, result.clone());
    return result;
}
```

## Benchmarking Guidelines

### Microbenchmarking Template

```zig
const std = @import("std");
const vsa = @import("trinity/vsa");

fn benchmarkBind(allocator: std.mem.Allocator, iterations: usize) !void {
    const timer = try std.time.Timer.start();

    // Setup
    const vec_a = try vsa.HybridBigInt.random(allocator, 10000);
    defer vec_a.deinit(allocator);
    const vec_b = try vsa.HybridBigInt.random(allocator, 10000);
    defer vec_b.deinit(allocator);
    var result = try vsa.HybridBigInt.init(allocator, 10000);
    defer result.deinit(allocator);

    // Warmup
    for (0..100) |_| {
        _ = try vsa.bind(&vec_a, &vec_b, &result);
    }

    // Benchmark
    const start = timer.lap();
    for (0..iterations) |_| {
        _ = try vsa.bind(&vec_a, &vec_b, &result);
    }
    const end = timer.read();

    // Results
    const elapsed_ns = end - start;
    const avg_ns = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));
    const ops_per_sec = 1_000_000_000.0 / avg_ns;

    std.debug.print(
        \\bind() Benchmark:
        \\  Iterations: {d}
        \\  Total time: {d:.2} ms
        \\  Avg/op: {d:.3} ns
        \\  Ops/sec: {d:.0}
        \\
    , .{ iterations, @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0, avg_ns, ops_per_sec });
}
```

### Performance Regression Testing

```bash
# Create baseline
zig build bench --baseline

# Compare with current
zig build bench --compare

# Output:
# bind(): +2.3% (was 45.2 ns/op, now 46.3 ns/op) [REGRESSION]
# similarity(): -1.8% (was 32.1 ns/op, now 31.5 ns/op) [IMPROVEMENT]
```

### Benchmarking Best Practices

| Practice | Why | Example |
|----------|-----|---------|
| **Warmup iterations** | CPU cache and branch prediction | Run 100+ iterations before measuring |
| **Statistical significance** | Variance in measurements | Use 1000+ iterations, repeat 5+ times |
| **Isolate variables** | Measure one thing at a time | Don't benchmark bind+similarity together |
| **Use realistic data** | Synthetic data can mislead | Use actual corpus data |
| **Check assembly** | Verify compiler optimization | `zig objdump -d binary` |

## Advanced Techniques

### Multi-threading for Batch Operations

```zig
fn parallelBind(vectors: []const vsa.HybridBigInt, keys: []const vsa.HybridBigInt) !void {
    const num_threads = try std.Thread.getCpuCount();
    const chunk_size = vectors.len / num_threads;

    var threads: [16]std.Thread = undefined;

    for (0..num_threads) |i| {
        const start = i * chunk_size;
        const end = if (i == num_threads - 1) vectors.len else (i + 1) * chunk_size;

        threads[i] = try std.Thread.spawn(.{}, struct {
            fn worker(start: usize, end: usize) !void {
                for (start..end) |j| {
                    _ = try vsa.bind(&vectors[j], &keys[j], &results[j]);
                }
            }.worker, .{ start, end });
    }

    for (0..num_threads) |i| {
        threads[i].join();
    }
}
```

### GPU Offloading (Future)

```zig
// Pseudo-code for GPU acceleration
fn gpuBindBatch(vectors: []vsa.HybridBigInt, keys: []vsa.HybridBigInt) !void {
    // 1. Copy data to GPU
    const gpu_vectors = try gpu.copyToGpu(vectors);
    defer gpu.free(gpu_vectors);
    const gpu_keys = try gpu.copyToGpu(keys);
    defer gpu.free(gpu_keys);

    // 2. Launch kernel
    try gpu.launchKernel(bindKernel, .{ gpu_vectors, gpu_keys });

    // 3. Copy results back
    try gpu.copyFromGpu(results, gpu_results);
}
```

## Performance Checklist

Use this checklist before deploying to production:

- [ ] All hot paths use SIMD operations
- [ ] Memory is aligned to cache line boundaries
- [ ] Object pools for frequent allocations
- [ ] Benchmark suite covers critical paths
- [ ] Performance regression tests pass
- [ ] Memory usage is stable (no leaks)
- [ ] CPU utilization is >70% (not bottlenecked)
- [ ] Cache hit rate is >80%

## Further Reading

- [VSA API Reference](/api/vsa) — Core operations and signatures
- [Benchmarks](/benchmarks/) — Performance metrics and comparisons
- [JIT Performance Guide](/benchmarks/jit-performance) — Just-in-time compilation
- [Memory Efficiency Report](/benchmarks/memory-efficiency) — Detailed analysis

---

**Need more performance tips?** Check the [community forum](https://github.com/gHashTag/trinity/discussions) or open a GitHub issue.
