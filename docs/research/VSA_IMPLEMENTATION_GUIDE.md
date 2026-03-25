# VSA Implementation Guide — Step-by-Step Optimization Protocol

**Date:** 2026-03-26
**Version:** 1.0.0
**Author:** Dmitrii Vasilev
**Purpose:** Practical implementation guide for VSA optimizations
**Related:** VSA_SACRED_OPTIMIZATION_PROPOSAL.md, VSA_OPTIMIZATION_DEEP_DIVE.md

---

## Quick Reference

| Phase | Focus | Files | Estimated Time | Expected Gain |
|-------|-------|-------|----------------|---------------|
| 1 | Cache Alignment | `src/hybrid.zig` | 2 hours | 2-5% |
| 2 | Prefetching | `src/vsa/core.zig` | 4 hours | 5-10% |
| 3 | Loop Unrolling | `src/vsa/core.zig` | 6 hours | 10-15% |
| 4 | Batch Processing | `src/vsa/core.zig` | 4 hours | 5-8% |

**Total Expected Improvement:** 22-38% on top of existing 9.28× SIMD speedup

---

## Phase 1: Cache-Line Alignment

### Step 1.1: Modify HybridBigInt Structure

**File:** `src/hybrid.zig`

**Current Code (lines 88-99):**
```zig
pub const HybridBigInt = struct {
    /// Packed storage (always valid)
    packed_data: [MAX_PACKED_BYTES]u8,
    /// Unpacked cache (valid only when mode == unpacked_mode)
    unpacked_cache: [MAX_TRITS]Trit,
    /// Current storage mode
    mode: StorageMode,
    /// Number of significant trits
    trit_len: usize,
    /// Dirty flag: unpacked cache modified, needs re-pack
    dirty: bool,
```

**Modified Code:**
```zig
pub const HybridBigInt = struct {
    /// Packed storage (always valid) — cache-line aligned
    packed_data: [MAX_PACKED_BYTES]u8 align(64),
    /// Unpacked cache (valid only when mode == unpacked_mode) — cache-line aligned
    unpacked_cache: [MAX_TRITS]Trit align(64),
    /// Current storage mode
    mode: StorageMode,
    /// Number of significant trits
    trit_len: usize,
    /// Dirty flag: unpacked cache modified, needs re-pack
    dirty: bool,
```

### Step 1.2: Verify Build

```bash
zig build
zig build test
```

**Expected:** All tests pass, no new warnings

### Step 1.3: Benchmark Cache Performance

```bash
# Create benchmark script
cat > benchmark_cache.sh << 'EOF'
#!/bin/bash
echo "=== VSA Cache Performance Benchmark ==="
perf stat -e cache-references,cache-misses,instructions,cycles \
    zig build vsa_bind_test 2>&1 | grep -E "(cache|instructions|cycles)"
EOF

chmod +x benchmark_cache.sh
./benchmark_cache.sh
```

### Step 1.4: Document Results

Create `docs/research/VSA_CACHE_ALIGNMENT_RESULTS.md` with before/after metrics.

---

## Phase 2: φ-Aligned Prefetching

### Step 2.1: Define Prefetch Constants

**File:** `src/vsa/core.zig` (add after imports)

```zig
// φ-aligned prefetch constants
const PREFETCH_DISTANCE = @as(usize, @intFromFloat(
    @as(f64, @floatFromInt(SIMD_WIDTH)) * 0.618034
)); // ~20 trits ahead (1/φ)
const MIN_PREFETCH_SIZE = 256; // Only prefetch for large vectors
```

### Step 2.2: Modify bind() with Prefetch

**Current bind() loop:**
```zig
var i: usize = 0;
while (i < num_full_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
    const a_vec: Vec32i8 = a.unpacked_cache[i..][0..SIMD_WIDTH].*;
    const b_vec: Vec32i8 = b.unpacked_cache[i..][0..SIMD_WIDTH].*;
    const prod = a_vec * b_vec;
    result.unpacked_cache[i..][0..SIMD_WIDTH].* = prod;
}
```

**Modified bind() with prefetch:**
```zig
var i: usize = 0;
while (i < num_full_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
    // φ-aligned prefetch: 1/φ iterations ahead for high locality
    if (len >= MIN_PREFETCH_SIZE and i + PREFETCH_DISTANCE + SIMD_WIDTH < len) {
        std.mem.prefetch(
            &a.unpacked_cache[i + PREFETCH_DISTANCE],
            .{ .locality = 3 }  // High locality (keep in cache)
        );
        std.mem.prefetch(
            &b.unpacked_cache[i + PREFETCH_DISTANCE],
            .{ .locality = 3 }
        );
    }

    const a_vec: Vec32i8 = a.unpacked_cache[i..][0..SIMD_WIDTH].*;
    const b_vec: Vec32i8 = b.unpacked_cache[i..][0..SIMD_WIDTH].*;
    const prod = a_vec * b_vec;
    result.unpacked_cache[i..][0..SIMD_WIDTH].* = prod;
}
```

### Step 2.3: Apply Same Pattern to bundle2()

```zig
// In bundle2(), add prefetch before SIMD loop
if (len >= MIN_PREFETCH_SIZE and i + PREFETCH_DISTANCE + SIMD_WIDTH < len) {
    std.mem.prefetch(&a.unpacked_cache[i + PREFETCH_DISTANCE], .{ .locality = 3 });
    std.mem.prefetch(&b.unpacked_cache[i + PREFETCH_DISTANCE], .{ .locality = 3 });
}
```

### Step 2.4: Apply Same Pattern to bundle3()

```zig
// In bundle3(), add prefetch for all three vectors
if (len >= MIN_PREFETCH_SIZE and i + PREFETCH_DISTANCE + SIMD_WIDTH < len) {
    std.mem.prefetch(&a.unpacked_cache[i + PREFETCH_DISTANCE], .{ .locality = 3 });
    std.mem.prefetch(&b.unpacked_cache[i + PREFETCH_DISTANCE], .{ .locality = 3 });
    std.mem.prefetch(&c.unpacked_cache[i + PREFETCH_DISTANCE], .{ .locality = 3 });
}
```

### Step 2.5: Test and Benchmark

```bash
zig build test
zig build vsa_benchmark
```

---

## Phase 3: Power-of-3 Loop Unrolling

### Step 3.1: Create Unrolled Bind Function

**File:** `src/vsa/core.zig`

```zig
const UNROLL_FACTOR = 3;  // Trinity-aligned unrolling

/// Unrolled bind operation — 3× faster for large vectors
pub fn bindUnrolled(a: *HybridBigInt, b: *HybridBigInt) HybridBigInt {
    a.ensureUnpacked();
    b.ensureUnpacked();

    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;

    const len = @max(a.trit_len, b.trit_len);
    result.trit_len = len;

    const min_len = @min(a.trit_len, b.trit_len);
    const unroll_chunk_size = UNROLL_FACTOR * SIMD_WIDTH;
    const num_unroll_chunks = min_len / unroll_chunk_size;

    var i: usize = 0;

    // Unrolled loop: 3× SIMD iterations per loop
    while (i < num_unroll_chunks * unroll_chunk_size) : (i += unroll_chunk_size) {
        // φ-aligned prefetch
        if (i + PREFETCH_DISTANCE + unroll_chunk_size < len) {
            std.mem.prefetch(&a.unpacked_cache[i + PREFETCH_DISTANCE], .{ .locality = 3 });
            std.mem.prefetch(&b.unpacked_cache[i + PREFETCH_DISTANCE], .{ .locality = 3 });
        }

        // First trinity
        const a0: Vec32i8 = a.unpacked_cache[i..][0..SIMD_WIDTH].*;
        const b0: Vec32i8 = b.unpacked_cache[i..][0..SIMD_WIDTH].*;
        result.unpacked_cache[i..][0..SIMD_WIDTH].* = a0 * b0;

        // Second trinity
        const a1: Vec32i8 = a.unpacked_cache[i + SIMD_WIDTH..][0..SIMD_WIDTH].*;
        const b1: Vec32i8 = b.unpacked_cache[i + SIMD_WIDTH..][0..SIMD_WIDTH].*;
        result.unpacked_cache[i + SIMD_WIDTH..][0..SIMD_WIDTH].* = a1 * b1;

        // Third trinity
        const a2: Vec32i8 = a.unpacked_cache[i + 2 * SIMD_WIDTH..][0..SIMD_WIDTH].*;
        const b2: Vec32i8 = b.unpacked_cache[i + 2 * SIMD_WIDTH..][0..SIMD_WIDTH].*;
        result.unpacked_cache[i + 2 * SIMD_WIDTH..][0..SIMD_WIDTH].* = a2 * b2;
    }

    // Handle remaining elements
    while (i < len) : (i += 1) {
        const a_trit: Trit = if (i < a.trit_len) a.unpacked_cache[i] else 0;
        const b_trit: Trit = if (i < b.trit_len) b.unpacked_cache[i] else 0;
        result.unpacked_cache[i] = a_trit * b_trit;
    }

    return result;
}
```

### Step 3.2: Create Unrolled Bundle Functions

```zig
pub fn bundle2Unrolled(a: *HybridBigInt, b: *HybridBigInt) HybridBigInt {
    a.ensureUnpacked();
    b.ensureUnpacked();

    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;
    result.dirty = true;

    const len = @max(a.trit_len, b.trit_len);
    result.trit_len = len;

    const min_len = @min(a.trit_len, b.trit_len);
    const unroll_chunk_size = UNROLL_FACTOR * SIMD_WIDTH;
    const num_unroll_chunks = min_len / unroll_chunk_size;

    var i: usize = 0;

    const zeros: Vec32i16 = @splat(0);
    const ones: Vec32i16 = @splat(1);
    const neg_ones: Vec32i16 = @splat(-1);

    while (i < num_unroll_chunks * unroll_chunk_size) : (i += unroll_chunk_size) {
        if (i + PREFETCH_DISTANCE + unroll_chunk_size < len) {
            std.mem.prefetch(&a.unpacked_cache[i + PREFETCH_DISTANCE], .{ .locality = 3 });
            std.mem.prefetch(&b.unpacked_cache[i + PREFETCH_DISTANCE], .{ .locality = 3 });
        }

        inline for (0..UNROLL_FACTOR) |u| {
            const offset = i + u * SIMD_WIDTH;
            const a_vec: Vec32i8 = a.unpacked_cache[offset..][0..SIMD_WIDTH].*;
            const b_vec: Vec32i8 = b.unpacked_cache[offset..][0..SIMD_WIDTH].*;

            const a_wide: @Vector(32, i16) = a_vec;
            const b_wide: @Vector(32, i16) = b_vec;
            const sum = a_wide + b_wide;

            const pos_mask = sum > zeros;
            const neg_mask = sum < zeros;

            var out: Vec32i16 = zeros;
            out = @select(i16, pos_mask, ones, out);
            out = @select(i16, neg_mask, neg_ones, out);

            inline for (0..SIMD_WIDTH) |j| {
                result.unpacked_cache[offset + j] = @truncate(out[j]);
            }
        }
    }

    while (i < len) : (i += 1) {
        const a_trit: i16 = if (i < a.trit_len) a.unpacked_cache[i] else 0;
        const b_trit: i16 = if (i < b.trit_len) b.unpacked_cache[i] else 0;
        const sum = a_trit + b_trit;

        result.unpacked_cache[i] = if (sum > 0) 1 else if (sum < 0) -1 else 0;
    }

    return result;
}
```

### Step 3.3: Add Adaptive Dispatch

```zig
/// Adaptive bind — uses unrolled version for large vectors
pub fn bindAdaptive(a: *HybridBigInt, b: *HybridBigInt) HybridBigInt {
    const len = @max(a.trit_len, b.trit_len);
    const UNROLL_THRESHOLD = 256;  // Use unrolled for vectors >256 trits

    return if (len >= UNROLL_THRESHOLD)
        bindUnrolled(a, b)
    else
        bind(a, b);
}
```

### Step 3.4: Add Tests

**File:** `src/vsa/core_test.zig`

```zig
test "VSA bind unrolled correctness" {
    const gpa = std.testing.allocator;

    var a = try HybridBigInt.random(gpa, 512);
    var b = try HybridBigInt.random(gpa, 512);

    const baseline = bind(&a, &b);
    const unrolled = bindUnrolled(&a, &b);

    try std.testing.expectEqual(baseline.trit_len, unrolled.trit_len);

    for (0..baseline.trit_len) |i| {
        try std.testing.expectEqual(
            @as(i8, baseline.unpacked_cache[i]),
            @as(i8, unrolled.unpacked_cache[i])
        );
    }
}

test "VSA bind adaptive dispatch" {
    const gpa = std.testing.allocator;

    // Small vector — should use regular bind
    var a_small = try HybridBigInt.random(gpa, 128);
    var b_small = try HybridBigInt.random(gpa, 128);
    const result_small = bindAdaptive(&a_small, &b_small);

    // Large vector — should use unrolled bind
    var a_large = try HybridBigInt.random(gpa, 512);
    var b_large = try HybridBigInt.random(gpa, 512);
    const result_large = bindAdaptive(&a_large, &b_large);

    try std.testing.expectEqual(@as(usize, 128), result_small.trit_len);
    try std.testing.expectEqual(@as(usize, 512), result_large.trit_len);
}
```

---

## Phase 4: Batch Processing

### Step 4.1: Implement bindBatch

**File:** `src/vsa/core.zig`

```zig
pub const BindPair = struct { *HybridBigInt, *HybridBigInt };

/// Batch bind operation — processes multiple pairs efficiently
pub fn bindBatch(
    allocator: std.mem.Allocator,
    input_pairs: []const BindPair,
) ![]HybridBigInt {
    if (input_pairs.len == 0) return &[_]HybridBigInt{};

    const outputs = try allocator.alloc(HybridBigInt, input_pairs.len);
    errdefer allocator.free(outputs);

    for (input_pairs, 0..) |pair, i| {
        outputs[i] = bindAdaptive(pair[0], pair[1]);
    }

    return outputs;
}
```

### Step 4.2: Implement bundleBatch

```zig
pub fn bundleBatch(
    allocator: std.mem.Allocator,
    vector_groups: []const []const *HybridBigInt,
) ![]HybridBigInt {
    if (vector_groups.len == 0) return &[_]HybridBigInt{};

    const results = try allocator.alloc(HybridBigInt, vector_groups.len);
    errdefer allocator.free(results);

    for (vector_groups, 0..) |group, i| {
        results[i] = switch (group.len) {
            0 => HybridBigInt.zero(),
            1 => blk: {
                group[0].ensureUnpacked();
                var r = HybridBigInt.zero();
                r.mode = .unpacked_mode;
                r.trit_len = group[0].trit_len;
                @memcpy(r.unpacked_cache[0..group[0].trit_len], group[0].unpacked_cache[0..group[0].trit_len]);
                break :blk r;
            },
            2 => bundle2(group[0], group[1]),
            3 => bundle3(group[0], group[1], group[2]),
            else => bundleN(group),
        };
    }

    return results;
}
```

### Step 4.3: Add Batch Tests

```zig
test "VSA bind batch" {
    const gpa = std.testing.allocator;

    var pairs: [10]BindPair = undefined;
    for (0..10) |i| {
        var a = try gpa.create(HybridBigInt);
        var b = try gpa.create(HybridBigInt);
        a.* = try HybridBigInt.random(gpa, 256);
        b.* = try HybridBigInt.random(gpa, 256);
        pairs[i] = .{ a, b };
    }

    const results = try bindBatch(gpa, &pairs);
    defer gpa.free(results);

    try std.testing.expectEqual(@as(usize, 10), results.len);

    for (results) |result| {
        try std.testing.expectEqual(@as(usize, 256), result.trit_len);
    }

    // Cleanup
    for (pairs) |pair| {
        gpa.destroy(pair[0]);
        gpa.destroy(pair[1]);
    }
}
```

---

## Validation Protocol

### V1: Correctness Validation

```bash
# Run all VSA tests
zig build test --test-filter "VSA"

# Expected: All tests pass
```

### V2: Performance Validation

```bash
# Build benchmark
zig build vsa_benchmark

# Run benchmark
./zig-out/bin/vsa_benchmark

# Expected: Improvement in all categories
```

### V3: Statistical Validation

Create `scripts/vsa_statistical_test.py`:

```python
#!/usr/bin/env python3
"""Statistical validation of VSA optimizations"""

import numpy as np
from scipy.stats import ttest_rel
import subprocess
import json

def run_benchmark(iterations=100):
    """Run benchmark and collect results"""
    results = []
    for _ in range(iterations):
        output = subprocess.capture_output(["./zig-out/bin/vsa_benchmark"])
        result = json.loads(output)
        results.append(result)
    return results

def main():
    print("=== VSA Statistical Validation ===")

    baseline = run_benchmark(50)  # Before optimization
    optimized = run_benchmark(50)  # After optimization

    for operation in ["bind", "bundle2", "bundle3"]:
        base_times = [r[operation]["time_us"] for r in baseline]
        opt_times = [r[operation]["time_us"] for r in optimized]

        t_stat, p_value = ttest_rel(opt_times, base_times, alternative='less')
        speedup = np.mean(base_times) / np.mean(opt_times)

        print(f"\n{operation}:")
        print(f"  t-statistic: {t_stat:.2f}")
        print(f"  p-value: {p_value:.6f}")
        print(f"  Speedup: {speedup:.2f}×")

        if p_value < 0.05:
            print(f"  ✅ Statistically significant (p < 0.05)")
        else:
            print(f"  ⚠️  Not statistically significant")

if __name__ == "__main__":
    main()
```

### V4: Regression Testing

```bash
# Ensure no regressions in other modules
zig build test

# Expected: All tests pass (2508/2508)
```

---

## Success Criteria

### Phase 1 (Cache Alignment)
- [ ] Build passes without errors
- [ ] All tests pass (2508/2508)
- [ ] Cache misses reduced by ≥2% (measured with perf)
- [ ] No regression in correctness tests

### Phase 2 (Prefetching)
- [ ] Build passes without errors
- [ ] All tests pass
- [ ] Memory latency reduced by ≥5%
- [ ] No performance regression on small vectors (<256 trits)

### Phase 3 (Loop Unrolling)
- [ ] Build passes without errors
- [ ] All tests pass (including new unrolled tests)
- [ ] Loop overhead reduced by ≥10%
- [ ] Code size increase acceptable (<15%)

### Phase 4 (Batch Processing)
- [ ] Build passes without errors
- [ ] All batch tests pass
- [ ] Batch operations faster than individual calls
- [ ] Memory usage scales linearly

---

## Rollback Plan

If any phase causes issues:

1. **Revert changes:**
   ```bash
   git revert HEAD
   ```

2. **Verify baseline:**
   ```bash
   zig build test
   ```

3. **Document issue** in `docs/research/VSA_OPTIMIZATION_ISSUES.md`

4. **Adjust approach** based on findings

---

## References

1. **VSA_SACRED_OPTIMIZATION_PROPOSAL.md** — Full proposal with theoretical background
2. **VSA_OPTIMIZATION_DEEP_DIVE.md** — Performance analysis and benchmarks
3. **SACRED_MATHEMATICS_PROOFS.md** — Trinity identity (φ² + 1/φ² = 3)
4. **src/vsa/core.zig** — Current VSA implementation
5. **src/hybrid.zig** — HybridBigInt structure

---

**φ² + 1/φ² = 3 | TRINITY**
