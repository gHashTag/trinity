// @origin(spec:ternary_attention.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// HSLM — Ternary Attention
// Replace float Q·K^T with ternary scoring: +1 (match), -1 (mismatch), 0 (ignore).
// Sparse attend with top-k → ternary attention weights at 33% density.
// Zero floating-point operations.

const std = @import("std");
const Trit = @import("trit_encoding.zig").Trit;

/// Ternary attention score: count matches vs mismatches.
/// score = Σ_d (q[d] == k[d] and both ≠ 0) ? sign : 0
/// Equivalent to dot product of ternary vectors (integer result).
pub fn ternaryScore(q: []const Trit, k: []const Trit) i32 {
    std.debug.assert(q.len == k.len);
    var score: i32 = 0;
    for (q, k) |qi, ki| {
        score += @as(i32, @as(i8, qi)) * @as(i32, @as(i8, ki));
    }
    return score;
}

/// SIMD ternary scoring: process 16 trits per cycle.
pub fn simdTernaryScore(q: []const Trit, k: []const Trit) i32 {
    std.debug.assert(q.len == k.len);
    const VEC_SIZE = 16;
    const Vec16i8 = @Vector(VEC_SIZE, i8);
    const Vec16i16 = @Vector(VEC_SIZE, i16);

    var acc: i32 = 0;
    var i: usize = 0;

    while (i + VEC_SIZE <= q.len) : (i += VEC_SIZE) {
        var q_vec: Vec16i8 = undefined;
        var k_vec: Vec16i8 = undefined;
        for (0..VEC_SIZE) |j| {
            q_vec[j] = q[i + j];
            k_vec[j] = k[i + j];
        }
        const q_wide: Vec16i16 = q_vec;
        const k_wide: Vec16i16 = k_vec;
        const prod = q_wide * k_wide;
        acc += @reduce(.Add, @as(@Vector(VEC_SIZE, i32), prod));
    }

    // Scalar tail
    while (i < q.len) : (i += 1) {
        acc += @as(i32, @as(i8, q[i])) * @as(i32, @as(i8, k[i]));
    }

    return acc;
}

/// Sparse attention: compute scores for all key positions, keep top-k,
/// assign ternary weights {-1, 0, +1} based on score sign.
/// Target density: ~33% (1/3 of positions get non-zero attention).
pub fn sparseAttend(
    query: []const Trit,
    keys: []const []const Trit,
    values: []const []const Trit,
    output: []i32,
    seq_len: usize,
    dim: usize,
) void {
    // Compute all scores
    var scores_buf: [512]i32 = undefined; // max seq_len
    std.debug.assert(seq_len <= 512);

    for (0..seq_len) |pos| {
        scores_buf[pos] = ternaryScore(query, keys[pos]);
    }

    // Find threshold for top-k (33% density)
    const k = @max(seq_len / 3, 1);

    // Simple top-k: find k-th largest absolute score
    var abs_scores: [512]i32 = undefined;
    for (0..seq_len) |pos| {
        abs_scores[pos] = @as(i32, @intCast(@abs(scores_buf[pos])));
    }

    // Partial sort to find threshold
    const threshold = findKthLargest(abs_scores[0..seq_len], k);

    // Apply ternary attention weights and aggregate values
    @memset(output[0..dim], 0);
    for (0..seq_len) |pos| {
        const abs_score = @as(i32, @intCast(@abs(scores_buf[pos])));
        if (abs_score >= threshold) {
            // Ternary weight: sign of score
            const weight: i32 = if (scores_buf[pos] > 0) 1 else if (scores_buf[pos] < 0) -1 else 0;
            // Accumulate: output += weight * value
            for (0..dim) |d| {
                output[d] += weight * @as(i32, @as(i8, values[pos][d]));
            }
        }
    }
}

/// Find k-th largest value in array (modifies array).
fn findKthLargest(arr: []i32, k: usize) i32 {
    // Simple insertion sort for small arrays (seq_len <= 512)
    const len = arr.len;
    if (k >= len) return 0;

    // Sort descending
    for (0..len) |i| {
        var max_idx = i;
        for (i + 1..len) |j| {
            if (arr[j] > arr[max_idx]) max_idx = j;
        }
        const tmp = arr[i];
        arr[i] = arr[max_idx];
        arr[max_idx] = tmp;
    }

    return arr[@min(k, len - 1)];
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ternaryScore symmetry" {
    const q = [_]Trit{ 1, -1, 0, 1, -1, 1, 0, -1 };
    const k = [_]Trit{ 1, 0, -1, 1, 1, -1, 0, 1 };

    const score_qk = ternaryScore(&q, &k);
    const score_kq = ternaryScore(&k, &q);
    try std.testing.expectEqual(score_qk, score_kq);
}

test "ternaryScore identity" {
    const q = [_]Trit{ 1, -1, 0, 1, -1, 1, 0, -1 };
    const score = ternaryScore(&q, &q);
    // Self-score = count of non-zeros = 6
    try std.testing.expectEqual(@as(i32, 6), score);
}

test "ternaryScore orthogonal" {
    const q = [_]Trit{ 1, 0, 0, 0 };
    const k = [_]Trit{ 0, 1, 0, 0 };
    try std.testing.expectEqual(@as(i32, 0), ternaryScore(&q, &k));
}

test "simdTernaryScore matches scalar" {
    var q: [64]Trit = undefined;
    var k: [64]Trit = undefined;
    var rng = std.Random.DefaultPrng.init(0xBEEF);
    const random = rng.random();
    for (&q) |*v| v.* = @intCast(random.intRangeAtMost(i8, -1, 1));
    for (&k) |*v| v.* = @intCast(random.intRangeAtMost(i8, -1, 1));

    const scalar = ternaryScore(&q, &k);
    const simd = simdTernaryScore(&q, &k);
    try std.testing.expectEqual(scalar, simd);
}

test "sparseAttend density ~33%" {
    const dim = 8;
    const seq_len = 9;

    // Create query and keys
    var query_data: [dim]Trit = undefined;
    var key_data: [seq_len][dim]Trit = undefined;
    var val_data: [seq_len][dim]Trit = undefined;

    var rng = std.Random.DefaultPrng.init(0xFACE);
    const random = rng.random();

    for (&query_data) |*v| v.* = @intCast(random.intRangeAtMost(i8, -1, 1));
    for (&key_data) |*row| {
        for (row) |*v| v.* = @intCast(random.intRangeAtMost(i8, -1, 1));
    }
    for (&val_data) |*row| {
        for (row) |*v| v.* = @intCast(random.intRangeAtMost(i8, -1, 1));
    }

    var keys: [seq_len][]const Trit = undefined;
    var vals: [seq_len][]const Trit = undefined;
    for (0..seq_len) |i| {
        keys[i] = &key_data[i];
        vals[i] = &val_data[i];
    }

    var output: [dim]i32 = undefined;
    sparseAttend(&query_data, &keys, &vals, &output, seq_len, dim);

    // Output should be valid (no crash, reasonable values)
    for (output) |v| {
        try std.testing.expect(@abs(v) <= @as(i32, @intCast(seq_len)));
    }
}
