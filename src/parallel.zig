// Trinity Parallel Compute
// Multi-threaded VSA operations using CPU threads
//
// IMPLEMENTATION STATUS:
// - parallelBind, parallelBundle, parallelDot: WORKING (spawn threads per call)
// - pooledBind, pooledBundle, pooledDot: WORKING (create pool per call)
// - getPool(): NOT IMPLEMENTED (returns error.NotImplemented)
// - batchBind, batchSimilarity: WORKING
//
// NOTE: The pooled operations create a new thread pool for each call.
// This is less efficient than a singleton pool but still works correctly.
// The getPool() function was intended for a singleton pool but never implemented.
//
// φ² + 1/φ² = 3

const std = @import("std");
const hybrid = @import("hybrid.zig");
const vsa = @import("vsa.zig");

const HybridBigInt = hybrid.HybridBigInt;
const Trit = hybrid.Trit;
const Thread = std.Thread;

// ═══════════════════════════════════════════════════════════════════════════════
// PARALLEL CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Number of worker threads (simulating GPU warps)
pub const NUM_THREADS = 8;

/// Minimum chunk size per thread
pub const MIN_CHUNK_SIZE = 64;

// ═══════════════════════════════════════════════════════════════════════════════
// THREAD POOL - Using std.Thread.Pool from Zig stdlib
// ═══════════════════════════════════════════════════════════════════════════════

/// Task function type
pub const TaskFn = *const fn (*anyopaque) void;

/// Wrapper around std.Thread.Pool for VSA operations
pub const ThreadPool = struct {
    pool: std.Thread.Pool,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        var pool: std.Thread.Pool = undefined;
        try pool.init(.{ .allocator = allocator, .n_jobs = NUM_THREADS });
        return Self{ .pool = pool };
    }

    pub fn deinit(self: *Self) void {
        self.pool.deinit();
    }

    pub fn spawn(self: *Self, comptime func: anytype, args: anytype) void {
        self.pool.spawn(func, args);
    }

    pub fn finish(self: *Self) void {
        self.pool.finish();
    }
};

/// Global allocator for pool
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

/// Get or create global thread pool
/// WARNING: NOT IMPLEMENTED - this was planned for a singleton pool pattern
/// but was never finished. Use pooledBind/pooledBundle/pooledDot instead,
/// which create their own pools per call.
pub fn getPool() !*ThreadPool {
    // TODO: Implement proper singleton pool with thread-safe initialization
    // For now, use the pooled* functions which create pools per call
    return error.NotImplemented;
}

/// Shutdown global pool
pub fn shutdownPool() void {
    // No-op for now
}

// ═══════════════════════════════════════════════════════════════════════════════
// PARALLEL BIND
// ═══════════════════════════════════════════════════════════════════════════════

/// Thread context for parallel bind
const BindContext = struct {
    a: []const Trit,
    b: []const Trit,
    result: []Trit,
    start: usize,
    end: usize,
};

/// Worker function for parallel bind
fn bindWorker(ctx: *BindContext) void {
    for (ctx.start..ctx.end) |i| {
        ctx.result[i] = ctx.a[i] * ctx.b[i];
    }
}

/// Parallel bind operation using multiple threads
pub fn parallelBind(a: *HybridBigInt, b: *HybridBigInt, result: *HybridBigInt) !void {
    a.ensureUnpacked();
    b.ensureUnpacked();

    const len = @max(a.trit_len, b.trit_len);
    result.mode = .unpacked_mode;
    result.trit_len = len;
    result.dirty = true;

    // For small vectors, use single-threaded
    if (len < MIN_CHUNK_SIZE * 2) {
        for (0..len) |i| {
            const a_t: Trit = if (i < a.trit_len) a.unpacked_cache[i] else 0;
            const b_t: Trit = if (i < b.trit_len) b.unpacked_cache[i] else 0;
            result.unpacked_cache[i] = a_t * b_t;
        }
        return;
    }

    // Calculate chunk size
    const num_threads = @min(NUM_THREADS, len / MIN_CHUNK_SIZE);
    const chunk_size = len / num_threads;

    // Create thread contexts
    var contexts: [NUM_THREADS]BindContext = undefined;
    var threads: [NUM_THREADS]?Thread = [_]?Thread{null} ** NUM_THREADS;

    for (0..num_threads) |t| {
        const start = t * chunk_size;
        const end = if (t == num_threads - 1) len else (t + 1) * chunk_size;

        contexts[t] = BindContext{
            .a = a.unpacked_cache[0..a.trit_len],
            .b = b.unpacked_cache[0..b.trit_len],
            .result = result.unpacked_cache[0..len],
            .start = start,
            .end = end,
        };

        threads[t] = try Thread.spawn(.{}, bindWorker, .{&contexts[t]});
    }

    // Wait for all threads
    for (threads[0..num_threads]) |maybe_thread| {
        if (maybe_thread) |thread| {
            thread.join();
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PARALLEL BUNDLE
// ═══════════════════════════════════════════════════════════════════════════════

/// Thread context for parallel bundle
const BundleContext = struct {
    a: []const Trit,
    b: []const Trit,
    result: []Trit,
    start: usize,
    end: usize,
};

/// Worker function for parallel bundle
fn bundleWorker(ctx: *BundleContext) void {
    for (ctx.start..ctx.end) |i| {
        const sum: i16 = @as(i16, ctx.a[i]) + @as(i16, ctx.b[i]);
        if (sum > 0) {
            ctx.result[i] = 1;
        } else if (sum < 0) {
            ctx.result[i] = -1;
        } else {
            ctx.result[i] = 0;
        }
    }
}

/// Parallel bundle operation
pub fn parallelBundle(a: *HybridBigInt, b: *HybridBigInt, result: *HybridBigInt) !void {
    a.ensureUnpacked();
    b.ensureUnpacked();

    const len = @max(a.trit_len, b.trit_len);
    result.mode = .unpacked_mode;
    result.trit_len = len;
    result.dirty = true;

    if (len < MIN_CHUNK_SIZE * 2) {
        for (0..len) |i| {
            const a_t: i16 = if (i < a.trit_len) a.unpacked_cache[i] else 0;
            const b_t: i16 = if (i < b.trit_len) b.unpacked_cache[i] else 0;
            const sum = a_t + b_t;
            if (sum > 0) {
                result.unpacked_cache[i] = 1;
            } else if (sum < 0) {
                result.unpacked_cache[i] = -1;
            } else {
                result.unpacked_cache[i] = 0;
            }
        }
        return;
    }

    const num_threads = @min(NUM_THREADS, len / MIN_CHUNK_SIZE);
    const chunk_size = len / num_threads;

    var contexts: [NUM_THREADS]BundleContext = undefined;
    var threads: [NUM_THREADS]?Thread = [_]?Thread{null} ** NUM_THREADS;

    for (0..num_threads) |t| {
        const start = t * chunk_size;
        const end = if (t == num_threads - 1) len else (t + 1) * chunk_size;

        contexts[t] = BundleContext{
            .a = a.unpacked_cache[0..a.trit_len],
            .b = b.unpacked_cache[0..b.trit_len],
            .result = result.unpacked_cache[0..len],
            .start = start,
            .end = end,
        };

        threads[t] = try Thread.spawn(.{}, bundleWorker, .{&contexts[t]});
    }

    for (threads[0..num_threads]) |maybe_thread| {
        if (maybe_thread) |thread| {
            thread.join();
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PARALLEL DOT PRODUCT
// ═══════════════════════════════════════════════════════════════════════════════

/// Thread context for parallel dot product
const DotContext = struct {
    a: []const Trit,
    b: []const Trit,
    start: usize,
    end: usize,
    partial_sum: i64 = 0,
};

/// Worker function for parallel dot product
fn dotWorker(ctx: *DotContext) void {
    var sum: i64 = 0;
    for (ctx.start..ctx.end) |i| {
        sum += @as(i64, ctx.a[i]) * @as(i64, ctx.b[i]);
    }
    ctx.partial_sum = sum;
}

/// Parallel dot product
pub fn parallelDot(a: *HybridBigInt, b: *HybridBigInt) !i64 {
    a.ensureUnpacked();
    b.ensureUnpacked();

    const len = @min(a.trit_len, b.trit_len);

    if (len < MIN_CHUNK_SIZE * 2) {
        var sum: i64 = 0;
        for (0..len) |i| {
            sum += @as(i64, a.unpacked_cache[i]) * @as(i64, b.unpacked_cache[i]);
        }
        return sum;
    }

    const num_threads = @min(NUM_THREADS, len / MIN_CHUNK_SIZE);
    const chunk_size = len / num_threads;

    var contexts: [NUM_THREADS]DotContext = undefined;
    var threads: [NUM_THREADS]?Thread = [_]?Thread{null} ** NUM_THREADS;

    for (0..num_threads) |t| {
        const start = t * chunk_size;
        const end = if (t == num_threads - 1) len else (t + 1) * chunk_size;

        contexts[t] = DotContext{
            .a = a.unpacked_cache[0..a.trit_len],
            .b = b.unpacked_cache[0..b.trit_len],
            .start = start,
            .end = end,
            .partial_sum = 0,
        };

        threads[t] = try Thread.spawn(.{}, dotWorker, .{&contexts[t]});
    }

    // Reduce partial sums
    var total: i64 = 0;
    for (0..num_threads) |t| {
        if (threads[t]) |thread| {
            thread.join();
        }
        total += contexts[t].partial_sum;
    }

    return total;
}

// ═══════════════════════════════════════════════════════════════════════════════
// POOLED OPERATIONS - Using pre-spawned thread pool (fast!)
// ═══════════════════════════════════════════════════════════════════════════════

/// Pooled bind - uses std.Thread.Pool with WaitGroup
pub fn pooledBind(a: *HybridBigInt, b: *HybridBigInt, result: *HybridBigInt) !void {
    a.ensureUnpacked();
    b.ensureUnpacked();

    const len = @max(a.trit_len, b.trit_len);
    result.mode = .unpacked_mode;
    result.trit_len = len;
    result.dirty = true;

    // For small vectors, use single-threaded
    if (len < MIN_CHUNK_SIZE * 2) {
        for (0..len) |i| {
            const a_t: Trit = if (i < a.trit_len) a.unpacked_cache[i] else 0;
            const b_t: Trit = if (i < b.trit_len) b.unpacked_cache[i] else 0;
            result.unpacked_cache[i] = a_t * b_t;
        }
        return;
    }

    var pool: std.Thread.Pool = undefined;
    try pool.init(.{ .allocator = gpa.allocator(), .n_jobs = NUM_THREADS });
    defer pool.deinit();

    var wg: std.Thread.WaitGroup = .{};

    const num_threads = @min(NUM_THREADS, len / MIN_CHUNK_SIZE);
    const chunk_size = len / num_threads;

    var contexts: [NUM_THREADS]BindContext = undefined;

    for (0..num_threads) |t| {
        const start = t * chunk_size;
        const end = if (t == num_threads - 1) len else (t + 1) * chunk_size;

        contexts[t] = BindContext{
            .a = a.unpacked_cache[0..a.trit_len],
            .b = b.unpacked_cache[0..b.trit_len],
            .result = result.unpacked_cache[0..len],
            .start = start,
            .end = end,
        };

        pool.spawnWg(&wg, bindWorker, .{&contexts[t]});
    }

    wg.wait();
}

/// Pooled bundle - uses std.Thread.Pool with WaitGroup
pub fn pooledBundle(a: *HybridBigInt, b: *HybridBigInt, result: *HybridBigInt) !void {
    a.ensureUnpacked();
    b.ensureUnpacked();

    const len = @max(a.trit_len, b.trit_len);
    result.mode = .unpacked_mode;
    result.trit_len = len;
    result.dirty = true;

    if (len < MIN_CHUNK_SIZE * 2) {
        for (0..len) |i| {
            const a_t: i16 = if (i < a.trit_len) a.unpacked_cache[i] else 0;
            const b_t: i16 = if (i < b.trit_len) b.unpacked_cache[i] else 0;
            const sum = a_t + b_t;
            if (sum > 0) {
                result.unpacked_cache[i] = 1;
            } else if (sum < 0) {
                result.unpacked_cache[i] = -1;
            } else {
                result.unpacked_cache[i] = 0;
            }
        }
        return;
    }

    var pool: std.Thread.Pool = undefined;
    try pool.init(.{ .allocator = gpa.allocator(), .n_jobs = NUM_THREADS });
    defer pool.deinit();

    var wg: std.Thread.WaitGroup = .{};

    const num_threads = @min(NUM_THREADS, len / MIN_CHUNK_SIZE);
    const chunk_size = len / num_threads;

    var contexts: [NUM_THREADS]BundleContext = undefined;

    for (0..num_threads) |t| {
        const start = t * chunk_size;
        const end = if (t == num_threads - 1) len else (t + 1) * chunk_size;

        contexts[t] = BundleContext{
            .a = a.unpacked_cache[0..a.trit_len],
            .b = b.unpacked_cache[0..b.trit_len],
            .result = result.unpacked_cache[0..len],
            .start = start,
            .end = end,
        };

        pool.spawnWg(&wg, bundleWorker, .{&contexts[t]});
    }

    wg.wait();
}

/// Pooled dot product - uses std.Thread.Pool with WaitGroup
pub fn pooledDot(a: *HybridBigInt, b: *HybridBigInt) !i64 {
    a.ensureUnpacked();
    b.ensureUnpacked();

    const len = @min(a.trit_len, b.trit_len);

    if (len < MIN_CHUNK_SIZE * 2) {
        var sum: i64 = 0;
        for (0..len) |i| {
            sum += @as(i64, a.unpacked_cache[i]) * @as(i64, b.unpacked_cache[i]);
        }
        return sum;
    }

    var pool: std.Thread.Pool = undefined;
    try pool.init(.{ .allocator = gpa.allocator(), .n_jobs = NUM_THREADS });
    defer pool.deinit();

    var wg: std.Thread.WaitGroup = .{};

    const num_threads = @min(NUM_THREADS, len / MIN_CHUNK_SIZE);
    const chunk_size = len / num_threads;

    var contexts: [NUM_THREADS]DotContext = undefined;

    for (0..num_threads) |t| {
        const start = t * chunk_size;
        const end = if (t == num_threads - 1) len else (t + 1) * chunk_size;

        contexts[t] = DotContext{
            .a = a.unpacked_cache[0..a.trit_len],
            .b = b.unpacked_cache[0..b.trit_len],
            .start = start,
            .end = end,
            .partial_sum = 0,
        };

        pool.spawnWg(&wg, dotWorker, .{&contexts[t]});
    }

    wg.wait();

    // Reduce partial sums
    var total: i64 = 0;
    for (0..num_threads) |t| {
        total += contexts[t].partial_sum;
    }

    return total;
}

// ═══════════════════════════════════════════════════════════════════════════════
// BATCH OPERATIONS (GPU-like)
// ═══════════════════════════════════════════════════════════════════════════════

/// Batch bind: process multiple vector pairs in parallel
pub fn batchBind(
    pairs: []const struct { a: *HybridBigInt, b: *HybridBigInt },
    results: []*HybridBigInt,
) !void {
    // Each pair processed by a thread
    const num_threads = @min(NUM_THREADS, pairs.len);

    const BatchContext = struct {
        pairs: []const struct { a: *HybridBigInt, b: *HybridBigInt },
        results: []*HybridBigInt,
        start: usize,
        end: usize,
    };

    const batchWorker = struct {
        fn work(ctx: *BatchContext) void {
            for (ctx.start..ctx.end) |i| {
                ctx.pairs[i].a.ensureUnpacked();
                ctx.pairs[i].b.ensureUnpacked();

                const len = @max(ctx.pairs[i].a.trit_len, ctx.pairs[i].b.trit_len);
                ctx.results[i].mode = .unpacked_mode;
                ctx.results[i].trit_len = len;
                ctx.results[i].dirty = true;

                for (0..len) |j| {
                    const a_t: Trit = if (j < ctx.pairs[i].a.trit_len) ctx.pairs[i].a.unpacked_cache[j] else 0;
                    const b_t: Trit = if (j < ctx.pairs[i].b.trit_len) ctx.pairs[i].b.unpacked_cache[j] else 0;
                    ctx.results[i].unpacked_cache[j] = a_t * b_t;
                }
            }
        }
    }.work;

    var contexts: [NUM_THREADS]BatchContext = undefined;
    var threads: [NUM_THREADS]?Thread = [_]?Thread{null} ** NUM_THREADS;

    const chunk_size = (pairs.len + num_threads - 1) / num_threads;

    for (0..num_threads) |t| {
        const start = t * chunk_size;
        const end = @min((t + 1) * chunk_size, pairs.len);
        if (start >= end) break;

        contexts[t] = BatchContext{
            .pairs = pairs,
            .results = results,
            .start = start,
            .end = end,
        };

        threads[t] = try Thread.spawn(.{}, batchWorker, .{&contexts[t]});
    }

    for (threads[0..num_threads]) |maybe_thread| {
        if (maybe_thread) |thread| {
            thread.join();
        }
    }
}

/// Batch similarity: compute similarity for multiple pairs
pub fn batchSimilarity(
    pairs: []const struct { a: *HybridBigInt, b: *HybridBigInt },
    results: []f64,
) !void {
    const num_threads = @min(NUM_THREADS, pairs.len);

    const BatchSimContext = struct {
        pairs: []const struct { a: *HybridBigInt, b: *HybridBigInt },
        results: []f64,
        start: usize,
        end: usize,
    };

    const batchSimWorker = struct {
        fn work(ctx: *BatchSimContext) void {
            for (ctx.start..ctx.end) |i| {
                ctx.results[i] = vsa.cosineSimilarity(ctx.pairs[i].a, ctx.pairs[i].b);
            }
        }
    }.work;

    var contexts: [NUM_THREADS]BatchSimContext = undefined;
    var threads: [NUM_THREADS]?Thread = [_]?Thread{null} ** NUM_THREADS;

    const chunk_size = (pairs.len + num_threads - 1) / num_threads;

    for (0..num_threads) |t| {
        const start = t * chunk_size;
        const end = @min((t + 1) * chunk_size, pairs.len);
        if (start >= end) break;

        contexts[t] = BatchSimContext{
            .pairs = pairs,
            .results = results,
            .start = start,
            .end = end,
        };

        threads[t] = try Thread.spawn(.{}, batchSimWorker, .{&contexts[t]});
    }

    for (threads[0..num_threads]) |maybe_thread| {
        if (maybe_thread) |thread| {
            thread.join();
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "parallelBind correctness" {
    var a = vsa.randomVector(1000, 12345);
    var b = vsa.randomVector(1000, 67890);

    // Sequential result
    const seq_result = vsa.bind(&a, &b);

    // Parallel result
    var par_result = HybridBigInt.zero();
    try parallelBind(&a, &b, &par_result);

    // Compare
    for (0..1000) |i| {
        try std.testing.expectEqual(seq_result.unpacked_cache[i], par_result.unpacked_cache[i]);
    }
}

test "parallelBundle correctness" {
    var a = vsa.randomVector(1000, 11111);
    var b = vsa.randomVector(1000, 22222);

    const seq_result = vsa.bundle2(&a, &b);

    var par_result = HybridBigInt.zero();
    try parallelBundle(&a, &b, &par_result);

    for (0..1000) |i| {
        try std.testing.expectEqual(seq_result.unpacked_cache[i], par_result.unpacked_cache[i]);
    }
}

test "parallelDot correctness" {
    var a = vsa.randomVector(1000, 33333);
    var b = vsa.randomVector(1000, 44444);

    // Sequential dot
    var seq_dot: i64 = 0;
    for (0..1000) |i| {
        seq_dot += @as(i64, a.unpacked_cache[i]) * @as(i64, b.unpacked_cache[i]);
    }

    // Parallel dot
    const par_dot = try parallelDot(&a, &b);

    try std.testing.expectEqual(seq_dot, par_dot);
}

test "pooledBind correctness" {
    var a = vsa.randomVector(1000, 12345);
    var b = vsa.randomVector(1000, 67890);

    const seq_result = vsa.bind(&a, &b);

    var pool_result = HybridBigInt.zero();
    try pooledBind(&a, &b, &pool_result);

    for (0..1000) |i| {
        try std.testing.expectEqual(seq_result.unpacked_cache[i], pool_result.unpacked_cache[i]);
    }
}

test "pooledBundle correctness" {
    var a = vsa.randomVector(1000, 11111);
    var b = vsa.randomVector(1000, 22222);

    const seq_result = vsa.bundle2(&a, &b);

    var pool_result = HybridBigInt.zero();
    try pooledBundle(&a, &b, &pool_result);

    for (0..1000) |i| {
        try std.testing.expectEqual(seq_result.unpacked_cache[i], pool_result.unpacked_cache[i]);
    }
}

test "pooledDot correctness" {
    var a = vsa.randomVector(1000, 33333);
    var b = vsa.randomVector(1000, 44444);

    var seq_dot: i64 = 0;
    for (0..1000) |i| {
        seq_dot += @as(i64, a.unpacked_cache[i]) * @as(i64, b.unpacked_cache[i]);
    }

    const pool_dot = try pooledDot(&a, &b);

    try std.testing.expectEqual(seq_dot, pool_dot);
}

test "benchmark SIMD vs Spawn vs Pool" {
    const sizes = [_]usize{ 100, 500, 1000, 2000, 5000 };
    const iterations = 100;

    std.debug.print("\n\n", .{});
    std.debug.print("╔═══════════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║              BENCHMARK: SIMD vs SPAWN vs THREAD POOL                              ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║  Size  │   SIMD    │   Spawn   │   Pool    │ Pool/SIMD │ Pool/Spawn │   Winner   ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════════════════════════╣\n", .{});

    for (sizes) |size| {
        var a = vsa.randomVector(size, 12345);
        var b = vsa.randomVector(size, 67890);

        // Benchmark SIMD (sequential)
        var timer = std.time.Timer.start() catch unreachable;
        for (0..iterations) |_| {
            _ = vsa.bind(&a, &b);
        }
        const simd_ns = timer.read();

        // Benchmark Spawn (old parallel)
        timer.reset();
        var result = HybridBigInt.zero();
        for (0..iterations) |_| {
            parallelBind(&a, &b, &result) catch {};
        }
        const spawn_ns = timer.read();

        // Benchmark Pool (new!)
        timer.reset();
        for (0..iterations) |_| {
            pooledBind(&a, &b, &result) catch {};
        }
        const pool_ns = timer.read();

        const simd_us = @as(f64, @floatFromInt(simd_ns)) / 1000.0 / @as(f64, @floatFromInt(iterations));
        const spawn_us = @as(f64, @floatFromInt(spawn_ns)) / 1000.0 / @as(f64, @floatFromInt(iterations));
        const pool_us = @as(f64, @floatFromInt(pool_ns)) / 1000.0 / @as(f64, @floatFromInt(iterations));

        const pool_vs_simd = simd_us / pool_us;
        const pool_vs_spawn = spawn_us / pool_us;

        const winner: []const u8 = if (pool_us < simd_us and pool_us < spawn_us) "POOL" else if (simd_us < spawn_us) "SIMD" else "SPAWN";

        std.debug.print("║ {d:5} │ {d:6.1} us │ {d:6.1} us │ {d:6.1} us │   {d:5.2}x  │    {d:5.1}x   │ {s:10} ║\n", .{ size, simd_us, spawn_us, pool_us, pool_vs_simd, pool_vs_spawn, winner });
    }

    std.debug.print("╚═══════════════════════════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Pool/SIMD > 1.0 means Pool is faster than SIMD\n", .{});
    std.debug.print("Pool/Spawn shows speedup from eliminating thread spawn overhead\n", .{});

    // Cleanup
    shutdownPool();
}
