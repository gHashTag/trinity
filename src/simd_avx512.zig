// Trinity SIMD AVX-512 Optimizations
// 512-bit vector operations for VSA (64 trits per operation)
//
// ⲤⲀⲔⲢⲀ ⲪⲞⲢⲘⲨⲖⲀ: V = n × 3^k × π^m × φ^p × e^q
// φ² + 1/φ² = 3

const std = @import("std");
const hybrid = @import("hybrid.zig");
const vsa = @import("vsa.zig");

const HybridBigInt = hybrid.HybridBigInt;
const Trit = hybrid.Trit;

// ═══════════════════════════════════════════════════════════════════════════════
// AVX-512 VECTOR TYPES (512-bit = 64 bytes = 64 i8 trits)
// ═══════════════════════════════════════════════════════════════════════════════

/// AVX-512 vector: 64 trits in parallel
pub const Vec64i8 = @Vector(64, i8);

/// AVX-512 vector for intermediate calculations
pub const Vec64i16 = @Vector(64, i16);

/// AVX-512 width
pub const AVX512_WIDTH = 64;

/// Number of AVX-512 chunks for max trits
pub const AVX512_CHUNKS = hybrid.MAX_TRITS / AVX512_WIDTH; // 59049 / 64 = 922

// Legacy AVX2 types for fallback
pub const Vec32i8 = @Vector(32, i8);
pub const AVX2_WIDTH = 32;

// ═══════════════════════════════════════════════════════════════════════════════
// AVX-512 PRIMITIVE OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// AVX-512 bind: XOR-like multiplication for trits (64 at a time)
/// For trits: bind(a, b) = a * b (element-wise)
pub inline fn avx512Bind(a: Vec64i8, b: Vec64i8) Vec64i8 {
    return a * b;
}

/// AVX-512 bundle: majority voting for 2 vectors
/// sum > 0 → 1, sum < 0 → -1, sum == 0 → 0
pub inline fn avx512Bundle2(a: Vec64i8, b: Vec64i8) Vec64i8 {
    const a16: Vec64i16 = a;
    const b16: Vec64i16 = b;
    const sum = a16 + b16;

    // Vectorized sign extraction
    const zeros: Vec64i16 = @splat(0);
    const ones: Vec64i16 = @splat(1);
    const neg_ones: Vec64i16 = @splat(-1);

    // result = (sum > 0) ? 1 : ((sum < 0) ? -1 : 0)
    const pos_mask = sum > zeros;
    const neg_mask = sum < zeros;

    var result: Vec64i16 = zeros;
    result = @select(i16, pos_mask, ones, result);
    result = @select(i16, neg_mask, neg_ones, result);

    // Truncate back to i8
    const result_i8: Vec64i8 = @truncate(result);
    return result_i8;
}

/// AVX-512 dot product (returns scalar)
pub inline fn avx512Dot(a: Vec64i8, b: Vec64i8) i64 {
    const a16: Vec64i16 = a;
    const b16: Vec64i16 = b;
    const products = a16 * b16;
    return @reduce(.Add, products);
}

/// AVX-512 check if all zeros
pub inline fn avx512IsZero(v: Vec64i8) bool {
    const zeros: Vec64i8 = @splat(0);
    return @reduce(.And, v == zeros);
}

/// AVX-512 negate
pub inline fn avx512Negate(v: Vec64i8) Vec64i8 {
    const zeros: Vec64i8 = @splat(0);
    return zeros - v;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HIGH-LEVEL AVX-512 VSA OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Load 64 bytes from unaligned memory into Vec64i8
inline fn loadUnaligned64(ptr: [*]const i8) Vec64i8 {
    // Use @as with array to handle unaligned access
    const arr: *const [64]i8 = @ptrCast(ptr);
    return arr.*;
}

/// Store Vec64i8 to unaligned memory
inline fn storeUnaligned64(ptr: [*]i8, vec: Vec64i8) void {
    const arr: *[64]i8 = @ptrCast(ptr);
    arr.* = vec;
}

/// AVX-512 optimized bind for HybridBigInt
/// Uses direct pointer casting for zero-copy SIMD loads
pub fn bindAvx512(a: *HybridBigInt, b: *HybridBigInt) HybridBigInt {
    a.ensureUnpacked();
    b.ensureUnpacked();

    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;

    const len = @max(a.trit_len, b.trit_len);
    result.trit_len = len;
    result.dirty = true;

    const num_chunks = len / AVX512_WIDTH;

    // Get pointers for direct SIMD access
    const a_ptr: [*]const i8 = @ptrCast(&a.unpacked_cache);
    const b_ptr: [*]const i8 = @ptrCast(&b.unpacked_cache);
    const r_ptr: [*]i8 = @ptrCast(&result.unpacked_cache);

    // Process 64 trits at a time with AVX-512 using unaligned loads
    for (0..num_chunks) |chunk| {
        const offset = chunk * AVX512_WIDTH;

        const a_vec = loadUnaligned64(a_ptr + offset);
        const b_vec = loadUnaligned64(b_ptr + offset);

        const res_vec = avx512Bind(a_vec, b_vec);

        storeUnaligned64(r_ptr + offset, res_vec);
    }

    // Handle remainder with scalar
    const remainder_start = num_chunks * AVX512_WIDTH;
    for (remainder_start..len) |i| {
        const a_t: Trit = if (i < a.trit_len) a.unpacked_cache[i] else 0;
        const b_t: Trit = if (i < b.trit_len) b.unpacked_cache[i] else 0;
        result.unpacked_cache[i] = a_t * b_t;
    }

    return result;
}

/// AVX-512 optimized bundle for HybridBigInt
pub fn bundleAvx512(a: *HybridBigInt, b: *HybridBigInt) HybridBigInt {
    a.ensureUnpacked();
    b.ensureUnpacked();

    var result = HybridBigInt.zero();
    result.mode = .unpacked_mode;

    const len = @max(a.trit_len, b.trit_len);
    result.trit_len = len;
    result.dirty = true;

    const num_chunks = len / AVX512_WIDTH;

    const a_ptr: [*]const i8 = @ptrCast(&a.unpacked_cache);
    const b_ptr: [*]const i8 = @ptrCast(&b.unpacked_cache);
    const r_ptr: [*]i8 = @ptrCast(&result.unpacked_cache);

    // Process 64 trits at a time
    for (0..num_chunks) |chunk| {
        const offset = chunk * AVX512_WIDTH;

        const a_vec = loadUnaligned64(a_ptr + offset);
        const b_vec = loadUnaligned64(b_ptr + offset);

        const res_vec = avx512Bundle2(a_vec, b_vec);

        storeUnaligned64(r_ptr + offset, res_vec);
    }

    // Handle remainder
    const remainder_start = num_chunks * AVX512_WIDTH;
    for (remainder_start..len) |i| {
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

    return result;
}

/// AVX-512 optimized dot product
pub fn dotAvx512(a: *HybridBigInt, b: *HybridBigInt) i64 {
    a.ensureUnpacked();
    b.ensureUnpacked();

    const len = @min(a.trit_len, b.trit_len);
    const num_chunks = len / AVX512_WIDTH;

    const a_ptr: [*]const i8 = @ptrCast(&a.unpacked_cache);
    const b_ptr: [*]const i8 = @ptrCast(&b.unpacked_cache);

    var total: i64 = 0;

    // Process 64 trits at a time
    for (0..num_chunks) |chunk| {
        const offset = chunk * AVX512_WIDTH;

        const a_vec = loadUnaligned64(a_ptr + offset);
        const b_vec = loadUnaligned64(b_ptr + offset);

        total += avx512Dot(a_vec, b_vec);
    }

    // Handle remainder
    const remainder_start = num_chunks * AVX512_WIDTH;
    for (remainder_start..len) |i| {
        total += @as(i64, a.unpacked_cache[i]) * @as(i64, b.unpacked_cache[i]);
    }

    return total;
}

/// AVX-512 cosine similarity
pub fn cosineSimilarityAvx512(a: *HybridBigInt, b: *HybridBigInt) f64 {
    const dot_ab = dotAvx512(a, b);
    const dot_aa = dotAvx512(a, a);
    const dot_bb = dotAvx512(b, b);

    if (dot_aa == 0 or dot_bb == 0) return 0.0;

    const norm_a = @sqrt(@as(f64, @floatFromInt(dot_aa)));
    const norm_b = @sqrt(@as(f64, @floatFromInt(dot_bb)));

    return @as(f64, @floatFromInt(dot_ab)) / (norm_a * norm_b);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ADAPTIVE SIMD - Auto-select best implementation
// ═══════════════════════════════════════════════════════════════════════════════

/// SIMD capability detection
pub const SimdLevel = enum {
    scalar,
    avx2,
    avx512,
};

/// Detect best available SIMD level at comptime
pub fn detectSimdLevel() SimdLevel {
    // Zig's @Vector will use best available instructions
    // For explicit control, check CPU features
    const features = std.Target.x86.featureSet;
    _ = features;

    // For now, always use AVX2 as it's faster in benchmarks
    // AVX-512 causes frequency throttling on many CPUs
    return .avx2;
}

/// Adaptive bind - uses best available SIMD
pub fn bindAdaptive(a: *HybridBigInt, b: *HybridBigInt) HybridBigInt {
    // AVX2 is faster in benchmarks due to AVX-512 throttling
    // Use vsa.bind which already uses 32-wide vectors
    return vsa.bind(a, b);
}

/// Adaptive bundle
pub fn bundleAdaptive(a: *HybridBigInt, b: *HybridBigInt) HybridBigInt {
    return vsa.bundle2(a, b);
}

/// Adaptive dot product
pub fn dotAdaptive(a: *HybridBigInt, b: *HybridBigInt) i64 {
    // Use hybrid's SIMD dot product
    return a.dotProduct(b);
}

/// Adaptive cosine similarity
pub fn cosineSimilarityAdaptive(a: *HybridBigInt, b: *HybridBigInt) f64 {
    return vsa.cosineSimilarity(a, b);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "AVX-512 bind correctness" {
    var a = vsa.randomVector(1000, 12345);
    var b = vsa.randomVector(1000, 67890);

    // Reference (current SIMD)
    const ref_result = vsa.bind(&a, &b);

    // AVX-512
    const avx_result = bindAvx512(&a, &b);

    for (0..1000) |i| {
        try std.testing.expectEqual(ref_result.unpacked_cache[i], avx_result.unpacked_cache[i]);
    }
}

test "AVX-512 bundle correctness" {
    var a = vsa.randomVector(1000, 11111);
    var b = vsa.randomVector(1000, 22222);

    const ref_result = vsa.bundle2(&a, &b);
    const avx_result = bundleAvx512(&a, &b);

    for (0..1000) |i| {
        try std.testing.expectEqual(ref_result.unpacked_cache[i], avx_result.unpacked_cache[i]);
    }
}

test "AVX-512 dot correctness" {
    var a = vsa.randomVector(1000, 33333);
    var b = vsa.randomVector(1000, 44444);

    // Reference scalar
    var ref_dot: i64 = 0;
    for (0..1000) |i| {
        ref_dot += @as(i64, a.unpacked_cache[i]) * @as(i64, b.unpacked_cache[i]);
    }

    const avx_dot = dotAvx512(&a, &b);

    try std.testing.expectEqual(ref_dot, avx_dot);
}

test "AVX-512 cosine similarity" {
    var a = vsa.randomVector(1000, 55555);
    var b = vsa.randomVector(1000, 55555); // Same seed = identical

    const sim = cosineSimilarityAvx512(&a, &b);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sim, 0.001);
}

test "benchmark AVX-512 vs AVX2 vs Scalar" {
    const sizes = [_]usize{ 100, 500, 1000, 2000, 5000, 10000 };
    const iterations = 1000;

    std.debug.print("\n\n", .{});
    std.debug.print("╔═══════════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║              BENCHMARK: AVX-512 (64-wide) vs AVX2 (32-wide) vs Scalar             ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║  Size  │  Scalar   │   AVX2    │  AVX-512  │ 512/Scalar│ 512/AVX2  │   Winner   ║\n", .{});
    std.debug.print("╠═══════════════════════════════════════════════════════════════════════════════════╣\n", .{});

    for (sizes) |size| {
        var a = vsa.randomVector(size, 12345);
        var b = vsa.randomVector(size, 67890);

        // Benchmark Scalar (naive loop)
        var timer = std.time.Timer.start() catch unreachable;
        for (0..iterations) |_| {
            var result = HybridBigInt.zero();
            result.mode = .unpacked_mode;
            result.trit_len = size;
            for (0..size) |i| {
                result.unpacked_cache[i] = a.unpacked_cache[i] * b.unpacked_cache[i];
            }
            std.mem.doNotOptimizeAway(&result);
        }
        const scalar_ns = timer.read();

        // Benchmark AVX2 (current vsa.bind)
        timer.reset();
        for (0..iterations) |_| {
            const result = vsa.bind(&a, &b);
            std.mem.doNotOptimizeAway(&result);
        }
        const avx2_ns = timer.read();

        // Benchmark AVX-512
        timer.reset();
        for (0..iterations) |_| {
            const result = bindAvx512(&a, &b);
            std.mem.doNotOptimizeAway(&result);
        }
        const avx512_ns = timer.read();

        const scalar_us = @as(f64, @floatFromInt(scalar_ns)) / 1000.0 / @as(f64, @floatFromInt(iterations));
        const avx2_us = @as(f64, @floatFromInt(avx2_ns)) / 1000.0 / @as(f64, @floatFromInt(iterations));
        const avx512_us = @as(f64, @floatFromInt(avx512_ns)) / 1000.0 / @as(f64, @floatFromInt(iterations));

        const speedup_vs_scalar = scalar_us / avx512_us;
        const speedup_vs_avx2 = avx2_us / avx512_us;

        const winner: []const u8 = if (avx512_us < avx2_us and avx512_us < scalar_us) "AVX-512" else if (avx2_us < scalar_us) "AVX2" else "SCALAR";

        std.debug.print("║ {d:5} │ {d:6.1} us │ {d:6.1} us │ {d:6.1} us │   {d:5.2}x  │   {d:5.2}x  │ {s:10} ║\n", .{ size, scalar_us, avx2_us, avx512_us, speedup_vs_scalar, speedup_vs_avx2, winner });
    }

    std.debug.print("╚═══════════════════════════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("512/Scalar > 1.0 means AVX-512 is faster than scalar\n", .{});
    std.debug.print("512/AVX2 > 1.0 means AVX-512 is faster than AVX2\n", .{});
}
