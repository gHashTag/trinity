// VSA Core — Operations
// Pure VSA operations on trit arrays (no HybridBigInt dependency)
//
// Operations: bind, unbind, bundle, similarity, permute
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const common = @import("common.zig");
const Trit = common.Trit;
const Vec32i8 = common.Vec32i8;
const Vec32i16 = common.Vec32i16;
const SIMD_WIDTH = common.SIMD_WIDTH;

// ═══════════════════════════════════════════════════════════════════════════════
// Basic Operations (on trit slices)
// ═══════════════════════════════════════════════════════════════════════════════

/// Bind operation (XOR-like for balanced ternary)
/// Returns new allocated slice (caller owns memory)
pub fn bind(allocator: std.mem.Allocator, a: []const Trit, b: []const Trit) ![]Trit {
    const len = @max(a.len, b.len);
    var result = try allocator.alloc(Trit, len);
    errdefer allocator.free(result);

    const min_len = @min(a.len, b.len);
    const num_full_chunks = min_len / SIMD_WIDTH;

    // SIMD chunks
    var i: usize = 0;
    while (i < num_full_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
        const a_vec: Vec32i8 = a[i..][0..SIMD_WIDTH].*;
        const b_vec: Vec32i8 = b[i..][0..SIMD_WIDTH].*;
        const prod = a_vec * b_vec;
        result[i..][0..SIMD_WIDTH].* = prod;
    }

    // Remainder
    while (i < len) : (i += 1) {
        const a_trit: Trit = if (i < a.len) a[i] else 0;
        const b_trit: Trit = if (i < b.len) b[i] else 0;
        result[i] = a_trit * b_trit;
    }

    return result;
}

/// Unbind operation (same as bind for XOR-like binding)
pub fn unbind(allocator: std.mem.Allocator, bound: []const Trit, key: []const Trit) ![]Trit {
    return bind(allocator, bound, key);
}

/// Bundle 2 vectors (majority vote)
pub fn bundle2(allocator: std.mem.Allocator, a: []const Trit, b: []const Trit) ![]Trit {
    const len = @max(a.len, b.len);
    var result = try allocator.alloc(Trit, len);

    for (0..len) |i| {
        const a_trit: Trit = if (i < a.len) a[i] else 0;
        const b_trit: Trit = if (i < b.len) b[i] else 0;
        const sum = a_trit + b_trit;

        // Majority vote: -2→-1, -1→-1, 0→0, 1→1, 2→1
        result[i] = if (sum > 0) 1 else if (sum < 0) -1 else 0;
    }

    return result;
}

/// Bundle 3 vectors (majority vote)
pub fn bundle3(allocator: std.mem.Allocator, a: []const Trit, b: []const Trit, c: []const Trit) ![]Trit {
    const len = @max(@max(a.len, b.len), c.len);
    var result = try allocator.alloc(Trit, len);

    for (0..len) |i| {
        const a_trit: Trit = if (i < a.len) a[i] else 0;
        const b_trit: Trit = if (i < b.len) b[i] else 0;
        const c_trit: Trit = if (i < c.len) c[i] else 0;
        const sum = a_trit + b_trit + c_trit;

        // Majority vote
        result[i] = if (sum > 0) 1 else if (sum < 0) -1 else 0;
    }

    return result;
}

/// Bundle N vectors (majority vote)
pub fn bundleN(allocator: std.mem.Allocator, vectors: []const []const Trit) ![]Trit {
    if (vectors.len == 0) return error.EmptyVectorList;

    var len: usize = 0;
    for (vectors) |v| {
        len = @max(len, v.len);
    }

    var result = try allocator.alloc(Trit, len);

    for (0..len) |i| {
        var sum: i32 = 0;
        for (vectors) |v| {
            if (i < v.len) sum += v[i];
        }
        result[i] = if (sum > 0) 1 else if (sum < 0) -1 else 0;
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Similarity Metrics
// ═══════════════════════════════════════════════════════════════════════════════

/// Cosine similarity for trit vectors
/// Returns value in [-1, 1]
pub fn cosineSimilarity(a: []const Trit, b: []const Trit) f64 {
    const len = @min(a.len, b.len);

    var dot: i64 = 0;
    var norm_a: i64 = 0;
    var norm_b: i64 = 0;

    const num_chunks = len / SIMD_WIDTH;

    // SIMD chunks
    var i: usize = 0;
    while (i < num_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
        const a_vec: Vec32i8 = a[i..][0..SIMD_WIDTH].*;
        const b_vec: Vec32i8 = b[i..][0..SIMD_WIDTH].*;
        const prod = a_vec * b_vec;
        dot += @reduce(.Add, @as(Vec32i16, prod));
        norm_a += @reduce(.Add, @as(Vec32i16, a_vec * a_vec));
        norm_b += @reduce(.Add, @as(Vec32i16, b_vec * b_vec));
    }

    // Remainder
    while (i < len) : (i += 1) {
        dot += @as(i64, a[i]) * @as(i64, b[i]);
        norm_a += @as(i64, a[i]) * @as(i64, a[i]);
        norm_b += @as(i64, b[i]) * @as(i64, b[i]);
    }

    const norm_product = @sqrt(@as(f64, @floatFromInt(norm_a))) * @sqrt(@as(f64, @floatFromInt(norm_b)));
    if (norm_product == 0) return 0;

    return @as(f64, @floatFromInt(dot)) / norm_product;
}

/// Hamming distance (count of differing positions)
pub fn hammingDistance(a: []const Trit, b: []const Trit) usize {
    const len = @min(a.len, b.len);
    var count: usize = 0;

    for (0..len) |i| {
        if (a[i] != b[i]) count += 1;
    }

    return count;
}

/// Hamming similarity (1 - normalized hamming distance)
pub fn hammingSimilarity(a: []const Trit, b: []const Trit) f64 {
    const len = @min(a.len, b.len);
    if (len == 0) return 1;

    const dist = hammingDistance(a, b);
    return 1.0 - @as(f64, @floatFromInt(dist)) / @as(f64, @floatFromInt(len));
}

/// Dot product similarity
pub fn dotSimilarity(a: []const Trit, b: []const Trit) i64 {
    const len = @min(a.len, b.len);
    var sum: i64 = 0;

    const num_chunks = len / SIMD_WIDTH;

    var i: usize = 0;
    while (i < num_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
        const a_vec: Vec32i8 = a[i..][0..SIMD_WIDTH].*;
        const b_vec: Vec32i8 = b[i..][0..SIMD_WIDTH].*;
        const prod = a_vec * b_vec;
        sum += @reduce(.Add, @as(Vec32i16, prod));
    }

    while (i < len) : (i += 1) {
        sum += @as(i64, a[i]) * @as(i64, b[i]);
    }

    return sum;
}

/// Vector norm (L2)
pub fn vectorNorm(v: []const Trit) f64 {
    var sum: i64 = 0;

    const num_chunks = v.len / SIMD_WIDTH;
    var i: usize = 0;

    while (i < num_chunks * SIMD_WIDTH) : (i += SIMD_WIDTH) {
        const vec: Vec32i8 = v[i..][0..SIMD_WIDTH].*;
        const sq = vec * vec;
        sum += @reduce(.Add, @as(Vec32i16, sq));
    }

    while (i < v.len) : (i += 1) {
        sum += @as(i64, v[i]) * @as(i64, v[i]);
    }

    return @sqrt(@as(f64, @floatFromInt(sum)));
}

// ═══════════════════════════════════════════════════════════════════════════════
// Permutation Operations
// ═══════════════════════════════════════════════════════════════════════════════

/// Cyclic permutation (rotate left by n positions)
pub fn permute(allocator: std.mem.Allocator, v: []const Trit, n: usize) ![]Trit {
    if (v.len == 0) return allocator.alloc(Trit, 0);

    const effective_n = n % v.len;
    if (effective_n == 0) {
        const result = try allocator.alloc(Trit, v.len);
        @memcpy(result, v);
        return result;
    }

    var result = try allocator.alloc(Trit, v.len);

    // Rotate left: result[i] = v[(i + n) % len]
    for (0..v.len) |i| {
        result[i] = v[(i + effective_n) % v.len];
    }

    return result;
}

/// Inverse permutation (rotate right by n positions)
pub fn inversePermute(allocator: std.mem.Allocator, v: []const Trit, n: usize) ![]Trit {
    const len = v.len;
    if (len == 0) return allocator.alloc(Trit, 0);

    const effective_n = n % len;
    return permute(allocator, v, len - effective_n);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Utility Functions
// ═══════════════════════════════════════════════════════════════════════════════

/// Count non-zero trits
pub fn countNonZero(v: []const Trit) usize {
    var count: usize = 0;
    for (v) |t| {
        if (t != 0) count += 1;
    }
    return count;
}

/// Generate random trit vector (Xorshift64)
pub fn randomVector(allocator: std.mem.Allocator, len: usize, seed: u64) ![]Trit {
    var result = try allocator.alloc(Trit, len);
    var rng = Xorshift64.init(seed);

    for (0..len) |i| {
        const r = rng.next();
        // Map to {-1, 0, 1}
        result[i] = switch (@mod(r, 3)) {
            0 => -1,
            1 => 0,
            2 => 1,
            else => unreachable,
        };
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Sequence Operations
// ═══════════════════════════════════════════════════════════════════════════════

/// Encode sequence with position binding
/// Uses permute for each position
pub fn encodeSequence(allocator: std.mem.Allocator, vectors: []const []const Trit) ![]Trit {
    if (vectors.len == 0) return errorEmptySequence;

    var result = try allocator.alloc(Trit, vectors[0].len);
    @memcpy(result, vectors[0]);

    for (1..vectors.len) |i| {
        const permuted = try permute(allocator, vectors[i], i);
        defer allocator.free(permuted);

        const bundled = try bundle2(allocator, result, permuted);
        allocator.free(result);
        result = bundled;
    }

    return result;
}

/// Probe sequence (find best match)
/// query_sequences: list of sequences to match against encoded
pub fn probeSequence(allocator: std.mem.Allocator, encoded: []const Trit, query_sequences: []const []const []const Trit) !usize {
    var best_idx: usize = 0;
    var best_sim: f64 = -1.0;

    for (query_sequences, 0..) |query_seq, idx| {
        const query_encoded = try encodeSequence(allocator, query_seq);
        defer allocator.free(query_encoded);

        const sim = cosineSimilarity(encoded, query_encoded);
        if (sim > best_sim) {
            best_sim = sim;
            best_idx = idx;
        }
    }

    return best_idx;
}

// ═══════════════════════════════════════════════════════════════════════════════
// RNG
// ═══════════════════════════════════════════════════════════════════════════════

const Xorshift64 = struct {
    state: u64,

    fn init(seed: u64) Xorshift64 {
        return .{ .state = seed };
    }

    fn next(self: *Xorshift64) u64 {
        var x = self.state;
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        self.state = x;
        return x;
    }
};

const errorEmptySequence = error.EmptySequence;

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "bind operation" {
    const a = [_]Trit{ 1, -1, 0, 1 };
    const b = [_]Trit{ 1, 1, -1, 0 };

    const result = try bind(std.testing.allocator, &a, &b);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualSlices(Trit, &[_]Trit{ 1, -1, 0, 0 }, result);
}

test "bundle2 majority vote" {
    const a = [_]Trit{ 1, 1, -1, -1 };
    const b = [_]Trit{ 1, -1, 1, -1 };

    const result = try bundle2(std.testing.allocator, &a, &b);
    defer std.testing.allocator.free(result);

    // [2, 0, 0, -2] → [1, 0, 0, -1]
    try std.testing.expectEqualSlices(Trit, &[_]Trit{ 1, 0, 0, -1 }, result);
}

test "cosine similarity" {
    const a = [_]Trit{ 1, 1, 1, 1 };
    const b = [_]Trit{ 1, 1, 1, 1 };

    const sim = cosineSimilarity(&a, &b);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sim, 0.001);
}

test "permute" {
    const v = [_]Trit{ 1, 2, 3, 4, 5 };

    const result = try permute(std.testing.allocator, &v, 2);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualSlices(Trit, &[_]Trit{ 3, 4, 5, 1, 2 }, result);
}

test "random vector deterministic" {
    const seed: u64 = 12345;

    const v1 = try randomVector(std.testing.allocator, 100, seed);
    defer std.testing.allocator.free(v1);

    const v2 = try randomVector(std.testing.allocator, 100, seed);
    defer std.testing.allocator.free(v2);

    try std.testing.expectEqualSlices(Trit, v1, v2);
}

test "countNonZero" {
    const v = [_]Trit{ 1, 0, -1, 0, 1, 0, 0, -1 };
    try std.testing.expectEqual(@as(usize, 4), countNonZero(&v));
}
