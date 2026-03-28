//! SIMD primitives for ternary VSA.
//! Use only TritVector everywhere; scalar code is fallback only.
//!
//! φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

/// Optimal SIMD vector width for i8
pub const SIMD_WIDTH = std.simd.suggestVectorLength(i8) orelse 32;

/// SIMD type for ternary vectors
pub const TritVector = @Vector(SIMD_WIDTH, i8);

/// SIMD type for accumulators (i16 to avoid overflow)
pub const TritVectorWide = @Vector(SIMD_WIDTH, i16);

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY DOT PRODUCT — SIMD scalar product
// ═══════════════════════════════════════════════════════════════════════════════

/// Ternary scalar product (via SIMD)
/// Returns: a[0]*b[0] + a[1]*b[1] + ... + a[N-1]*b[N-1]
pub fn tritDot(a: TritVector, b: TritVector) i32 {
    const product = a * b; // 1 SIMD instruction
    const product_wide: TritVectorWide = product;
    return @reduce(.Add, product_wide);
}

/// Scalar product for slices with auto-alignment
pub fn tritDotSlice(a: []const i8, b: []const i8) i32 {
    std.debug.assert(a.len == b.len);

    const vec_len = SIMD_WIDTH;
    const num_vecs = a.len / vec_len;

    var acc: i32 = 0;
    var i: usize = 0;

    // SIMD part
    while (i < num_vecs * vec_len) : (i += vec_len) {
        const a_vec: TritVector = a[i..][0..vec_len].*;
        const b_vec: TritVector = b[i..][0..vec_len].*;
        acc += tritDot(a_vec, b_vec);
    }

    // Scalar tail
    while (i < a.len) : (i += 1) {
        acc += @as(i32, a[i]) * @as(i32, b[i]);
    }

    return acc;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY BIND — element-wise multiplication (XOR-like)
// ═══════════════════════════════════════════════════════════════════════════════

/// Ternary bind (element-wise mul)
pub fn tritBind(a: TritVector, b: TritVector) TritVector {
    return a * b;
}

/// Bind for slices
pub fn tritBindSlice(dst: []i8, a: []const i8, b: []const i8) void {
    std.debug.assert(dst.len >= a.len);
    std.debug.assert(a.len == b.len);

    const vec_len = SIMD_WIDTH;
    const num_vecs = a.len / vec_len;

    var i: usize = 0;

    // SIMD part
    while (i < num_vecs * vec_len) : (i += vec_len) {
        const a_vec: TritVector = a[i..][0..vec_len].*;
        const b_vec: TritVector = b[i..][0..vec_len].*;
        const result = tritBind(a_vec, b_vec);
        dst[i..][0..vec_len].* = result;
    }

    // Scalar tail
    while (i < a.len) : (i += 1) {
        dst[i] = a[i] * b[i];
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY BUNDLE — majority vote
// ═══════════════════════════════════════════════════════════════════════════════

/// Ternary bundle 2 vectors (majority vote)
pub fn tritBundle2(a: TritVector, b: TritVector) TritVector {
    const a_wide: TritVectorWide = a;
    const b_wide: TritVectorWide = b;
    const sum = a_wide + b_wide;

    const zeros = @as(TritVectorWide, @splat(0));
    const ones = @as(TritVectorWide, @splat(1));
    const neg_ones = @as(TritVectorWide, @splat(-1));

    const pos_mask = sum > zeros;
    const neg_mask = sum < zeros;

    var out = zeros;
    out = @select(i16, pos_mask, ones, out);
    out = @select(i16, neg_mask, neg_ones, out);

    return @as(TritVector, @truncate(out));
}

/// Ternary bundle 3 vectors
pub fn tritBundle3(a: TritVector, b: TritVector, c: TritVector) TritVector {
    const a_wide: TritVectorWide = a;
    const b_wide: TritVectorWide = b;
    const c_wide: TritVectorWide = c;
    const sum = a_wide + b_wide + c_wide;

    const zeros = @as(TritVectorWide, @splat(0));
    const ones = @as(TritVectorWide, @splat(1));
    const neg_ones = @as(TritVectorWide, @splat(-1));

    const pos_mask = sum > zeros;
    const neg_mask = sum < zeros;

    var out = zeros;
    out = @select(i16, pos_mask, ones, out);
    out = @select(i16, neg_mask, neg_ones, out);

    return @as(TritVector, @truncate(out));
}

/// Bundle N vectors (majority vote)
pub fn tritBundleN(vecs: []const TritVector) TritVector {
    if (vecs.len == 0) return @splat(@as(i8, 0));
    if (vecs.len == 1) return vecs[0];
    if (vecs.len == 2) return tritBundle2(vecs[0], vecs[1]);
    if (vecs.len == 3) return tritBundle3(vecs[0], vecs[1], vecs[2]);

    var acc: TritVectorWide = @splat(0);
    for (vecs) |v| {
        acc += @as(TritVectorWide, v);
    }

    const zeros = @as(TritVectorWide, @splat(0));
    const ones = @as(TritVectorWide, @splat(1));
    const neg_ones = @as(TritVectorWide, @splat(-1));

    const pos_mask = acc > zeros;
    const neg_mask = acc < zeros;

    var out = zeros;
    out = @select(i16, pos_mask, ones, out);
    out = @select(i16, neg_mask, neg_ones, out);

    return @as(TritVector, @truncate(out));
}

/// Bundle for slices
pub fn tritBundleSlice(dst: []i8, vecs: []const []const i8) void {
    const vec_len = SIMD_WIDTH;

    for (vecs) |v| {
        std.debug.assert(v.len == vecs[0].len);
    }
    std.debug.assert(dst.len >= vecs[0].len);

    const num_vecs = vecs[0].len / vec_len;

    var i: usize = 0;

    // SIMD part
    while (i < num_vecs * vec_len) : (i += vec_len) {
        var simd_vecs: std.BoundedArray(TritVector, 32) = .{};
        for (vecs) |v| {
            const vec: TritVector = v[i..][0..vec_len].*;
            simd_vecs.append(vec) catch unreachable;
        }
        const result = tritBundleN(simd_vecs.constSlice());
        dst[i..][0..vec_len].* = result;
    }

    // Scalar tail
    while (i < vecs[0].len) : (i += 1) {
        var sum: i16 = 0;
        for (vecs) |v| {
            sum += @as(i16, @intCast(v[i]));
        }
        dst[i] = if (sum > 0) 1 else if (sum < 0) -1 else 0;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY PERMUTE — cyclic permutation
// ═══════════════════════════════════════════════════════════════════════════════

/// Cyclic shift left by k positions (SIMD)
pub fn tritPermuteLeft(v: TritVector, comptime k: comptime_int) TritVector {
    comptime {
        if (k >= SIMD_WIDTH) @compileError("k must be < SIMD_WIDTH");
    }

    if (k == 0) return v;

    var result: TritVector = undefined;
    inline for (0..SIMD_WIDTH) |i| {
        result[i] = v[(i + k) % SIMD_WIDTH];
    }
    return result;
}

/// Cyclic shift right by k positions (SIMD)
pub fn tritPermuteRight(v: TritVector, comptime k: comptime_int) TritVector {
    return tritPermuteLeft(v, SIMD_WIDTH - k);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY SIMILARITY — cosine similarity for trits
// ═══════════════════════════════════════════════════════════════════════════════

/// Cosine similarity for two ternary vectors
pub fn tritCosineSim(a: TritVector, b: TritVector) f64 {
    const dot = tritDot(a, b);
    const norm_a = tritNorm(a);
    const norm_b = tritNorm(b);

    if (norm_a == 0 or norm_b == 0) return 0;

    return @as(f64, @floatFromInt(dot)) / (@as(f64, norm_a) * @as(f64, norm_b));
}

/// L2 norm of ternary vector (sqrt of sum of squares)
pub fn tritNorm(v: TritVector) f64 {
    const squares = v * v;
    const squares_wide: TritVectorWide = squares;
    const sum_sq = @reduce(.Add, squares_wide);
    return std.math.sqrt(@as(f64, @floatFromInt(sum_sq)));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY COUNT — count non-zero trits
// ═══════════════════════════════════════════════════════════════════════════════

/// Count number of non-zero trits in vector
pub fn tritCountNonZero(v: TritVector) usize {
    const zeros = @as(TritVector, @splat(0));
    const nonzero = v != zeros;
    // Convert boolean vector to count
    var count: usize = 0;
    inline for (0..SIMD_WIDTH) |i| {
        if (nonzero[i]) count += 1;
    }
    return count;
}

/// Count number of positive trits
pub fn tritCountPositive(v: TritVector) usize {
    const zeros = @as(TritVector, @splat(0));
    const positive = v > zeros;
    var count: usize = 0;
    inline for (0..SIMD_WIDTH) |i| {
        if (positive[i]) count += 1;
    }
    return count;
}

/// Count number of negative trits
pub fn tritCountNegative(v: TritVector) usize {
    const zeros = @as(TritVector, @splat(0));
    const negative = v < zeros;
    var count: usize = 0;
    inline for (0..SIMD_WIDTH) |i| {
        if (negative[i]) count += 1;
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY RANDOM — random ternary vector generation
// ═══════════════════════════════════════════════════════════════════════════════

/// Random ternary vector (deterministic from seed)
pub fn tritRandom(comptime seed: u64) TritVector {
    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();

    var result: TritVector = undefined;
    inline for (0..SIMD_WIDTH) |i| {
        // Use i for seed variation
        const t = random.intRangeAtMost(i8, -1, 1);
        result[i] = t;
    }
    return result;
}

/// Random ternary vector (runtime seed)
pub fn tritRandomRuntime(seed: u64) TritVector {
    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();

    var result: TritVector = undefined;
    inline for (0..SIMD_WIDTH) |i| {
        result[i] = random.intRangeAtMost(i8, -1, 1);
    }
    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Create zero vector
pub inline fn tritZero() TritVector {
    return @splat(@as(i8, 0));
}

/// Create vector of ones
pub inline fn tritOnes() TritVector {
    return @splat(@as(i8, 1));
}

/// Create vector of -1
pub inline fn tritMinusOnes() TritVector {
    return @splat(@as(i8, -1));
}

/// Verify all trits are in {-1, 0, +1}
pub fn tritIsValid(v: TritVector) bool {
    inline for (0..SIMD_WIDTH) |i| {
        const t = v[i];
        if (t != -1 and t != 0 and t != 1) return false;
    }
    return true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "SIMD_WIDTH is power of 2" {
    const width = SIMD_WIDTH;
    try std.testing.expect(width >= 8 and width <= 64);
    // Check if power of 2
    try std.testing.expect(width & (width - 1) == 0);
}

test "tritDot basic" {
    const a = @as(TritVector, @splat(1));
    const b = @as(TritVector, @splat(1));
    const result = tritDot(a, b);
    try std.testing.expectEqual(@as(i32, SIMD_WIDTH), result);
}

test "tritDot mixed" {
    var a: TritVector = undefined;
    var b: TritVector = undefined;
    inline for (0..SIMD_WIDTH) |i| {
        a[i] = if (i % 2 == 0) 1 else -1;
        b[i] = if (i % 2 == 0) 1 else 1;
    }

    const result = tritDot(a, b);
    // Half 1*1 = 1, half (-1)*1 = -1, sum = 0
    try std.testing.expectEqual(@as(i32, 0), result);
}

test "tritBind" {
    const a = @as(TritVector, @splat(1));
    const b = @as(TritVector, @splat(1));
    const result = tritBind(a, b);
    try std.testing.expectEqual(@as(TritVector, @splat(1)), result);
}

test "tritBundle2 majority" {
    const a = @as(TritVector, @splat(1));
    const b = @as(TritVector, @splat(-1));
    const result = tritBundle2(a, b);
    // 1 + (-1) = 0 -> majority vote = 0
    try std.testing.expectEqual(@as(TritVector, @splat(0)), result);
}

test "tritBundle3 consensus" {
    const a = @as(TritVector, @splat(1));
    const b = @as(TritVector, @splat(1));
    const c = @as(TritVector, @splat(-1));
    const result = tritBundle3(a, b, c);
    // 1 + 1 + (-1) = 1 -> majority vote = 1
    try std.testing.expectEqual(@as(TritVector, @splat(1)), result);
}

test "tritPermuteLeft" {
    const v = comptime init: {
        var result: TritVector = undefined;
        for (0..SIMD_WIDTH) |i| {
            result[i] = @intCast(i);
        }
        break :init result;
    };

    const shifted = tritPermuteLeft(v, 1);

    // Check that it's a cyclic left shift: shifted[i] should be v[(i+1) % SIMD_WIDTH]
    for (0..SIMD_WIDTH) |i| {
        const original_idx = (i + 1) % SIMD_WIDTH;
        try std.testing.expectEqual(v[original_idx], shifted[i]);
    }
}

test "tritPermuteRight" {
    const v = comptime init: {
        var result: TritVector = undefined;
        for (0..SIMD_WIDTH) |i| {
            result[i] = @intCast(i);
        }
        break :init result;
    };

    const shifted = tritPermuteRight(v, 1);

    // Check that it's a cyclic right shift: shifted[i] should be v[(i-1+SIMD_WIDTH) % SIMD_WIDTH]
    for (0..SIMD_WIDTH) |i| {
        const original_idx = (i + SIMD_WIDTH - 1) % SIMD_WIDTH;
        try std.testing.expectEqual(v[original_idx], shifted[i]);
    }
}

test "tritCosineSim identical" {
    const v = @as(TritVector, @splat(1));
    const sim = tritCosineSim(v, v);
    try std.testing.expect(sim > 0.99); // Should be ~1.0
}

test "tritCosineSim orthogonal" {
    const a = @as(TritVector, @splat(1));
    const b = @as(TritVector, @splat(0));
    const sim = tritCosineSim(a, b);
    try std.testing.expectEqual(@as(f64, 0), sim);
}

test "tritCountNonZero" {
    const v = comptime init: {
        var result: TritVector = undefined;
        for (0..SIMD_WIDTH) |i| {
            result[i] = if (i % 2 == 0) 1 else 0;
        }
        break :init result;
    };

    const count = tritCountNonZero(v);
    try std.testing.expectEqual(@as(usize, SIMD_WIDTH / 2), count);
}

test "tritCountPositive" {
    const v = comptime init: {
        var result: TritVector = undefined;
        for (0..SIMD_WIDTH) |i| {
            result[i] = if (i % 2 == 0) 1 else 0;
        }
        break :init result;
    };

    const count = tritCountPositive(v);
    try std.testing.expectEqual(@as(usize, SIMD_WIDTH / 2), count);
}

test "tritCountNegative" {
    const v = comptime init: {
        var result: TritVector = undefined;
        for (0..SIMD_WIDTH) |i| {
            result[i] = if (i % 2 == 0) -1 else 0;
        }
        break :init result;
    };

    const count = tritCountNegative(v);
    try std.testing.expectEqual(@as(usize, SIMD_WIDTH / 2), count);
}

test "tritRandom valid" {
    const v = tritRandom(42);
    try std.testing.expect(tritIsValid(v));
}

test "tritRandomRuntime valid" {
    const v = tritRandomRuntime(12345);
    try std.testing.expect(tritIsValid(v));
}

test "tritDotSlice matches scalar" {
    var a: [128]i8 = undefined;
    var b: [128]i8 = undefined;

    for (0..128) |i| {
        a[i] = if (i % 3 == 0) 1 else if (i % 3 == 1) -1 else 0;
        b[i] = if (i % 3 == 0) 1 else if (i % 3 == 1) 1 else -1;
    }

    const simd_result = tritDotSlice(&a, &b);

    // Scalar version
    var scalar_result: i32 = 0;
    for (0..128) |i| {
        scalar_result += @as(i32, a[i]) * @as(i32, b[i]);
    }

    try std.testing.expectEqual(scalar_result, simd_result);
}

test "helpers" {
    const zero = tritZero();
    try std.testing.expectEqual(@as(TritVector, @splat(0)), zero);

    const ones = tritOnes();
    try std.testing.expectEqual(@as(TritVector, @splat(1)), ones);

    const minus = tritMinusOnes();
    try std.testing.expectEqual(@as(TritVector, @splat(-1)), minus);

    try std.testing.expect(tritIsValid(zero));
    try std.testing.expect(tritIsValid(ones));
    try std.testing.expect(tritIsValid(minus));
}

// φ² + 1/φ² = 3 | TRINITY
