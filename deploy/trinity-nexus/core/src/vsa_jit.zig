// Trinity JIT-Accelerated VSA Operations
// Provides 15-260x speedup for hot paths via native code generation
//
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3

const std = @import("std");
const builtin = @import("builtin");
const jit_unified = @import("jit_unified.zig");
const hybrid = @import("hybrid.zig");

pub const HybridBigInt = hybrid.HybridBigInt;
pub const Trit = hybrid.Trit;
pub const MAX_TRITS = hybrid.MAX_TRITS;

// ═══════════════════════════════════════════════════════════════════════════════
// JIT-ACCELERATED VSA ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

/// JIT-accelerated VSA engine with compiled function caching
pub const JitVSAEngine = struct {
    allocator: std.mem.Allocator,

    // Cached JIT-compiled functions for common dimensions
    dot_cache: std.AutoHashMap(usize, jit_unified.JitDotFn),
    bind_cache: std.AutoHashMap(usize, jit_unified.JitDotFn),
    hamming_cache: std.AutoHashMap(usize, jit_unified.JitDotFn),
    cosine_cache: std.AutoHashMap(usize, jit_unified.JitDotFn),
    bundle_cache: std.AutoHashMap(usize, jit_unified.JitDotFn),

    // Keep compilers alive to prevent exec_mem from being freed
    compilers: std.ArrayListUnmanaged(jit_unified.UnifiedJitCompiler),

    // Statistics
    jit_hits: u64 = 0,
    jit_misses: u64 = 0,
    total_ops: u64 = 0,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .dot_cache = std.AutoHashMap(usize, jit_unified.JitDotFn).init(allocator),
            .bind_cache = std.AutoHashMap(usize, jit_unified.JitDotFn).init(allocator),
            .hamming_cache = std.AutoHashMap(usize, jit_unified.JitDotFn).init(allocator),
            .cosine_cache = std.AutoHashMap(usize, jit_unified.JitDotFn).init(allocator),
            .bundle_cache = std.AutoHashMap(usize, jit_unified.JitDotFn).init(allocator),
            .compilers = .{},
        };
    }

    pub fn deinit(self: *Self) void {
        // Clean up all compilers (which frees exec_mem)
        for (self.compilers.items) |*compiler| {
            compiler.deinit();
        }
        self.compilers.deinit(self.allocator);
        self.dot_cache.deinit();
        self.bind_cache.deinit();
        self.hamming_cache.deinit();
        self.cosine_cache.deinit();
        self.bundle_cache.deinit();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // JIT DOT PRODUCT
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get or compile JIT function for dot product
    fn getDotFunction(self: *Self, dimension: usize) !jit_unified.JitDotFn {
        if (self.dot_cache.get(dimension)) |func| {
            self.jit_hits += 1;
            return func;
        }

        // Compile new function
        self.jit_misses += 1;

        // Create compiler and add to list (keeps exec_mem alive)
        try self.compilers.append(self.allocator, jit_unified.UnifiedJitCompiler.init(self.allocator));
        const compiler = &self.compilers.items[self.compilers.items.len - 1];

        try compiler.compileDotProduct(dimension);
        const func = try compiler.finalize();

        try self.dot_cache.put(dimension, func);
        return func;
    }

    /// JIT-accelerated dot product for HybridBigInt vectors
    pub fn dotProduct(self: *Self, a: *HybridBigInt, b: *HybridBigInt) !i64 {
        self.total_ops += 1;

        // Ensure vectors are unpacked for direct memory access
        a.ensureUnpacked();
        b.ensureUnpacked();

        // Use the larger dimension
        const dim = @max(a.trit_len, b.trit_len);

        // Get or compile JIT function
        const func = try self.getDotFunction(dim);

        // Call JIT-compiled function directly on unpacked cache
        // Cast [MAX_TRITS]Trit to *anyopaque
        const a_ptr: *anyopaque = @ptrCast(&a.unpacked_cache);
        const b_ptr: *anyopaque = @ptrCast(&b.unpacked_cache);

        return func(a_ptr, b_ptr);
    }

    /// Fallback to non-JIT dot product (for comparison)
    pub fn dotProductFallback(a: *HybridBigInt, b: *HybridBigInt) i64 {
        return @intCast(a.dotProduct(b));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // JIT BIND
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get or compile JIT function for bind
    fn getBindFunction(self: *Self, dimension: usize) !jit_unified.JitDotFn {
        if (self.bind_cache.get(dimension)) |func| {
            self.jit_hits += 1;
            return func;
        }

        // Compile new function
        self.jit_misses += 1;

        // Create compiler and add to list (keeps exec_mem alive)
        try self.compilers.append(self.allocator, jit_unified.UnifiedJitCompiler.init(self.allocator));
        const compiler = &self.compilers.items[self.compilers.items.len - 1];

        try compiler.compileBind(dimension);
        const func = try compiler.finalize();

        try self.bind_cache.put(dimension, func);
        return func;
    }

    /// JIT-accelerated bind for HybridBigInt vectors (modifies a in place)
    pub fn bind(self: *Self, a: *HybridBigInt, b: *HybridBigInt) !void {
        self.total_ops += 1;

        // Ensure vectors are unpacked for direct memory access
        a.ensureUnpacked();
        b.ensureUnpacked();

        // Use the larger dimension
        const dim = @max(a.trit_len, b.trit_len);

        // Get or compile JIT function
        const func = try self.getBindFunction(dim);

        // Call JIT-compiled function (modifies a in place)
        const a_ptr: *anyopaque = @ptrCast(&a.unpacked_cache);
        const b_ptr: *anyopaque = @ptrCast(&b.unpacked_cache);

        _ = func(a_ptr, b_ptr);

        // Mark as modified (dirty) since JIT wrote to unpacked cache
        a.dirty = true;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // JIT FUSED COSINE SIMILARITY (single-pass computation)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get or compile JIT function for fused cosine similarity
    fn getCosineFunction(self: *Self, dimension: usize) !?jit_unified.JitDotFn {
        if (self.cosine_cache.get(dimension)) |func| {
            self.jit_hits += 1;
            return func;
        }

        // Try to compile fused cosine (only available on ARM64)
        try self.compilers.append(self.allocator, jit_unified.UnifiedJitCompiler.init(self.allocator));
        const compiler = &self.compilers.items[self.compilers.items.len - 1];

        compiler.compileFusedCosine(dimension) catch |err| {
            // Remove the failed compiler
            _ = self.compilers.pop();
            if (err == error.UnsupportedOperation) {
                return null; // Fall back to 3x dot product
            }
            return err;
        };

        self.jit_misses += 1;
        const func = try compiler.finalize();
        try self.cosine_cache.put(dimension, func);
        return func;
    }

    /// JIT-accelerated cosine similarity using fused kernel (2.5x faster on ARM64)
    /// cos(a,b) = dot(a,b) / sqrt(dot(a,a) * dot(b,b))
    pub fn cosineSimilarity(self: *Self, a: *HybridBigInt, b: *HybridBigInt) !f64 {
        self.total_ops += 1;

        // Ensure vectors are unpacked
        a.ensureUnpacked();
        b.ensureUnpacked();

        const dim = @max(a.trit_len, b.trit_len);

        // Try fused cosine kernel (ARM64 only, 2.5x faster)
        if (try self.getCosineFunction(dim)) |func| {
            const a_ptr: *anyopaque = @ptrCast(&a.unpacked_cache);
            const b_ptr: *anyopaque = @ptrCast(&b.unpacked_cache);

            // Function returns f64 bit pattern as i64
            const result_bits = func(a_ptr, b_ptr);
            return @bitCast(result_bits);
        }

        // Fallback: use 3 separate JIT dot products
        const dot_ab = try self.dotProduct(a, b);
        const dot_aa = try self.dotProduct(a, a);
        const dot_bb = try self.dotProduct(b, b);

        // Handle zero vectors
        if (dot_aa == 0 or dot_bb == 0) {
            return 0.0;
        }

        const norm = @sqrt(@as(f64, @floatFromInt(dot_aa)) * @as(f64, @floatFromInt(dot_bb)));
        return @as(f64, @floatFromInt(dot_ab)) / norm;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // JIT HAMMING DISTANCE (count of differing positions)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get or compile JIT function for hamming distance
    fn getHammingFunction(self: *Self, dimension: usize) !?jit_unified.JitDotFn {
        if (self.hamming_cache.get(dimension)) |func| {
            self.jit_hits += 1;
            return func;
        }

        // Try to compile new function (only available on ARM64)
        try self.compilers.append(self.allocator, jit_unified.UnifiedJitCompiler.init(self.allocator));
        const compiler = &self.compilers.items[self.compilers.items.len - 1];

        compiler.compileHamming(dimension) catch |err| {
            // Remove the failed compiler
            _ = self.compilers.pop();
            if (err == error.UnsupportedOperation) {
                return null; // Fall back to scalar
            }
            return err;
        };

        self.jit_misses += 1;
        const func = try compiler.finalize();
        try self.hamming_cache.put(dimension, func);
        return func;
    }

    /// JIT-accelerated hamming distance
    /// For ternary: counts positions where a[i] != b[i]
    pub fn hammingDistance(self: *Self, a: *HybridBigInt, b: *HybridBigInt) !i64 {
        self.total_ops += 1;

        // Ensure vectors are unpacked
        a.ensureUnpacked();
        b.ensureUnpacked();

        const dim = @max(a.trit_len, b.trit_len);

        // Try JIT SIMD version (available on ARM64)
        if (try self.getHammingFunction(dim)) |func| {
            const a_ptr: *anyopaque = @ptrCast(&a.unpacked_cache);
            const b_ptr: *anyopaque = @ptrCast(&b.unpacked_cache);
            return func(a_ptr, b_ptr);
        }

        // Scalar fallback
        var count: i64 = 0;
        for (0..dim) |i| {
            if (a.unpacked_cache[i] != b.unpacked_cache[i]) {
                count += 1;
            }
        }
        return count;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // JIT BUNDLE OPERATION (n-ary addition with threshold)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Get or compile JIT function for bundle operation
    fn getBundleFunction(self: *Self, dimension: usize) !?jit_unified.JitDotFn {
        if (self.bundle_cache.get(dimension)) |func| {
            self.jit_hits += 1;
            return func;
        }

        // Try to compile bundle SIMD (only available on ARM64)
        try self.compilers.append(self.allocator, jit_unified.UnifiedJitCompiler.init(self.allocator));
        const compiler = &self.compilers.items[self.compilers.items.len - 1];

        compiler.compileBundleSIMD(dimension) catch |err| {
            // Remove the failed compiler
            _ = self.compilers.pop();
            if (err == error.UnsupportedOperation) {
                return null; // Fall back to scalar
            }
            return err;
        };

        self.jit_misses += 1;
        const func = try compiler.finalize();
        try self.bundle_cache.put(dimension, func);
        return func;
    }

    /// JIT-accelerated bundle operation
    /// result[i] = threshold(a[i] + b[i]) where >0→1, <0→-1, =0→0
    /// Modifies 'a' in place
    pub fn bundle(self: *Self, a: *HybridBigInt, b: *HybridBigInt) !void {
        self.total_ops += 1;

        // Ensure vectors are unpacked
        a.ensureUnpacked();
        b.ensureUnpacked();

        const dim = @max(a.trit_len, b.trit_len);

        // Try JIT SIMD version (ARM64 only)
        if (try self.getBundleFunction(dim)) |func| {
            const a_ptr: *anyopaque = @ptrCast(&a.unpacked_cache);
            const b_ptr: *anyopaque = @ptrCast(&b.unpacked_cache);
            _ = func(a_ptr, b_ptr);
            a.dirty = true;
            return;
        }

        // Scalar fallback
        for (0..dim) |i| {
            const sum: i16 = @as(i16, a.unpacked_cache[i]) + @as(i16, b.unpacked_cache[i]);
            if (sum > 0) {
                a.unpacked_cache[i] = 1;
            } else if (sum < 0) {
                a.unpacked_cache[i] = -1;
            } else {
                a.unpacked_cache[i] = 0;
            }
        }
        a.dirty = true;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STATISTICS
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn getStats(self: *const Self) Stats {
        const total_cache = self.jit_hits + self.jit_misses;
        const hit_rate = if (total_cache > 0)
            @as(f64, @floatFromInt(self.jit_hits)) / @as(f64, @floatFromInt(total_cache)) * 100.0
        else
            0.0;

        return Stats{
            .total_ops = self.total_ops,
            .jit_hits = self.jit_hits,
            .jit_misses = self.jit_misses,
            .cache_size = self.dot_cache.count() + self.bind_cache.count() + self.hamming_cache.count() + self.cosine_cache.count() + self.bundle_cache.count(),
            .hit_rate = hit_rate,
        };
    }

    pub fn printStats(self: *const Self) void {
        const stats = self.getStats();
        std.debug.print("\n", .{});
        std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
        std.debug.print("              JIT VSA ENGINE STATISTICS\n", .{});
        std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
        std.debug.print("  Total operations: {d}\n", .{stats.total_ops});
        std.debug.print("  JIT cache hits:   {d}\n", .{stats.jit_hits});
        std.debug.print("  JIT cache misses: {d}\n", .{stats.jit_misses});
        std.debug.print("  Cache size:       {d} functions\n", .{stats.cache_size});
        std.debug.print("  Hit rate:         {d:.1}%\n", .{stats.hit_rate});
        std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    }

    pub const Stats = struct {
        total_ops: u64,
        jit_hits: u64,
        jit_misses: u64,
        cache_size: usize,
        hit_rate: f64,
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONVENIENCE FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Global JIT engine (thread-local for safety)
threadlocal var global_engine: ?JitVSAEngine = null;

/// Initialize global JIT engine
pub fn initGlobal(allocator: std.mem.Allocator) void {
    if (global_engine == null) {
        global_engine = JitVSAEngine.init(allocator);
    }
}

/// Deinitialize global JIT engine
pub fn deinitGlobal() void {
    if (global_engine) |*engine| {
        engine.deinit();
        global_engine = null;
    }
}

/// JIT-accelerated dot product using global engine
pub fn jitDotProduct(allocator: std.mem.Allocator, a: *HybridBigInt, b: *HybridBigInt) !i64 {
    initGlobal(allocator);
    return global_engine.?.dotProduct(a, b);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "JitVSAEngine init and deinit" {
    var engine = JitVSAEngine.init(std.testing.allocator);
    defer engine.deinit();

    try std.testing.expect(engine.total_ops == 0);
}

test "JitVSAEngine dot product correctness" {
    if (!jit_unified.is_jit_supported) return;

    var engine = JitVSAEngine.init(std.testing.allocator);
    defer engine.deinit();

    // Create test vectors using setTrit (proper API)
    var a = HybridBigInt.zero();
    var b = HybridBigInt.zero();

    // Simple test: all 1s dot all 1s = dimension
    const test_len = 64;

    for (0..test_len) |i| {
        a.setTrit(i, 1);
        b.setTrit(i, 1);
    }

    const expected: i64 = test_len;

    // JIT dot product
    const jit_result = try engine.dotProduct(&a, &b);

    // Fallback dot product
    const fallback_result = JitVSAEngine.dotProductFallback(&a, &b);

    try std.testing.expectEqual(expected, jit_result);
    try std.testing.expectEqual(expected, fallback_result);
}

test "JitVSAEngine cache hits" {
    if (!jit_unified.is_jit_supported) return;

    var engine = JitVSAEngine.init(std.testing.allocator);
    defer engine.deinit();

    var a = HybridBigInt.zero();
    var b = HybridBigInt.zero();
    a.trit_len = 64;
    b.trit_len = 64;

    // First call - cache miss
    _ = try engine.dotProduct(&a, &b);
    try std.testing.expectEqual(@as(u64, 1), engine.jit_misses);
    try std.testing.expectEqual(@as(u64, 0), engine.jit_hits);

    // Second call - cache hit
    _ = try engine.dotProduct(&a, &b);
    try std.testing.expectEqual(@as(u64, 1), engine.jit_misses);
    try std.testing.expectEqual(@as(u64, 1), engine.jit_hits);

    // Third call - cache hit
    _ = try engine.dotProduct(&a, &b);
    try std.testing.expectEqual(@as(u64, 1), engine.jit_misses);
    try std.testing.expectEqual(@as(u64, 2), engine.jit_hits);
}

test "JitVSAEngine benchmark vs fallback" {
    if (!jit_unified.is_jit_supported) return;

    var engine = JitVSAEngine.init(std.testing.allocator);
    defer engine.deinit();

    const dim = 1024;
    const iterations = 10000;

    // Create test vectors using setTrit
    var a = HybridBigInt.zero();
    var b = HybridBigInt.zero();

    for (0..dim) |i| {
        const val_a: Trit = @intCast(@as(i32, @intCast(i % 3)) - 1);
        const val_b: Trit = @intCast(@as(i32, @intCast((i + 1) % 3)) - 1);
        a.setTrit(i, val_a);
        b.setTrit(i, val_b);
    }

    // Warm up JIT cache
    _ = try engine.dotProduct(&a, &b);

    // Benchmark JIT
    var timer = std.time.Timer.start() catch unreachable;
    var jit_result: i64 = 0;
    for (0..iterations) |_| {
        jit_result = try engine.dotProduct(&a, &b);
    }
    const jit_ns = timer.read();

    // Benchmark fallback
    timer.reset();
    var fallback_result: i64 = 0;
    for (0..iterations) |_| {
        fallback_result = JitVSAEngine.dotProductFallback(&a, &b);
    }
    const fallback_ns = timer.read();

    // Results should match
    try std.testing.expectEqual(jit_result, fallback_result);

    const jit_ms = @as(f64, @floatFromInt(jit_ns)) / 1_000_000.0;
    const fallback_ms = @as(f64, @floatFromInt(fallback_ns)) / 1_000_000.0;
    const speedup = fallback_ms / jit_ms;

    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("        JIT VSA ENGINE BENCHMARK (HybridBigInt)\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Dimension: {d} trits\n", .{dim});
    std.debug.print("  Iterations: {d}\n", .{iterations});
    std.debug.print("───────────────────────────────────────────────────────────────\n", .{});
    std.debug.print("  Fallback (HybridBigInt.dotProduct): {d:.3} ms\n", .{fallback_ms});
    std.debug.print("  JIT (NEON SIMD):                    {d:.3} ms\n", .{jit_ms});
    std.debug.print("───────────────────────────────────────────────────────────────\n", .{});
    std.debug.print("  SPEEDUP: {d:.2}x\n", .{speedup});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});

    engine.printStats();

    // JIT should be faster
    try std.testing.expect(speedup > 1.0);
}

test "JitVSAEngine various dimensions" {
    if (!jit_unified.is_jit_supported) return;

    var engine = JitVSAEngine.init(std.testing.allocator);
    defer engine.deinit();

    const test_dims = [_]usize{ 8, 16, 32, 64, 100, 128, 256, 512, 1000 };

    for (test_dims) |dim| {
        var a = HybridBigInt.zero();
        var b = HybridBigInt.zero();

        var expected: i64 = 0;
        for (0..dim) |i| {
            a.setTrit(i, 1);
            b.setTrit(i, 1);
            expected += 1;
        }

        const result = try engine.dotProduct(&a, &b);
        try std.testing.expectEqual(expected, result);
    }

    // Should have compiled functions for each unique dimension
    try std.testing.expectEqual(@as(usize, test_dims.len), engine.dot_cache.count());
}

test "JitVSAEngine bind correctness" {
    if (!jit_unified.is_jit_supported) return;

    var engine = JitVSAEngine.init(std.testing.allocator);
    defer engine.deinit();

    // Test bind: result[i] = a[i] * b[i] (ternary multiplication)
    var a = HybridBigInt.zero();
    var b = HybridBigInt.zero();

    const dim = 16;
    for (0..dim) |i| {
        // Pattern: a = [1, -1, 0, 1, -1, 0, ...], b = [1, 1, 1, -1, -1, -1, ...]
        const a_val: Trit = @intCast(@as(i32, @intCast(i % 3)) - 1);
        const b_val: Trit = if (i < dim / 2) @as(Trit, 1) else @as(Trit, -1);
        a.setTrit(i, a_val);
        b.setTrit(i, b_val);
    }

    // Compute expected result
    var expected = HybridBigInt.zero();
    for (0..dim) |i| {
        const a_val = a.getTrit(i);
        const b_val = b.getTrit(i);
        expected.setTrit(i, a_val * b_val);
    }

    // JIT bind
    try engine.bind(&a, &b);

    // Verify result
    for (0..dim) |i| {
        try std.testing.expectEqual(expected.getTrit(i), a.getTrit(i));
    }
}

test "JitVSAEngine cosine similarity correctness" {
    if (!jit_unified.is_jit_supported) return;

    var engine = JitVSAEngine.init(std.testing.allocator);
    defer engine.deinit();

    // Test identical vectors: cos(a, a) = 1.0
    var a = HybridBigInt.zero();
    const dim = 64;
    for (0..dim) |i| {
        a.setTrit(i, 1);
    }

    const cos_identical = try engine.cosineSimilarity(&a, &a);
    try std.testing.expectApproxEqRel(@as(f64, 1.0), cos_identical, 0.001);

    // Test orthogonal vectors: cos(a, -a) = -1.0
    var neg_a = HybridBigInt.zero();
    for (0..dim) |i| {
        neg_a.setTrit(i, -1);
    }

    const cos_opposite = try engine.cosineSimilarity(&a, &neg_a);
    try std.testing.expectApproxEqRel(@as(f64, -1.0), cos_opposite, 0.001);
}

test "JitVSAEngine hamming distance correctness" {
    if (!jit_unified.is_jit_supported) return;

    var engine = JitVSAEngine.init(std.testing.allocator);
    defer engine.deinit();

    // Test identical vectors: hamming(a, a) = 0
    var a = HybridBigInt.zero();
    const dim = 64;
    for (0..dim) |i| {
        a.setTrit(i, 1);
    }

    const hamming_identical = try engine.hammingDistance(&a, &a);
    try std.testing.expectEqual(@as(i64, 0), hamming_identical);

    // Test completely different vectors: hamming(a, -a) = dim
    var neg_a = HybridBigInt.zero();
    for (0..dim) |i| {
        neg_a.setTrit(i, -1);
    }

    const hamming_opposite = try engine.hammingDistance(&a, &neg_a);
    try std.testing.expectEqual(@as(i64, dim), hamming_opposite);

    // Test half different: change half the trits
    var half = HybridBigInt.zero();
    for (0..dim) |i| {
        half.setTrit(i, if (i < dim / 2) @as(Trit, 1) else @as(Trit, -1));
    }

    const hamming_half = try engine.hammingDistance(&a, &half);
    try std.testing.expectEqual(@as(i64, dim / 2), hamming_half);
}
