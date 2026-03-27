// ═══════════════════════════════════════════════════════════════════════════════
// VSA Core — Operations (GENERATED from specs/vsa/ops.tri)
// Stage 1.0: Full template codegen
// DO NOT EDIT — Generated from specs/vsa/ops.tri
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const common = @import("common.zig");
const Allocator = std.mem.Allocator;
const Trit = common.Trit;
const Vec32i8 = common.Vec32i8;
const Vec32i16 = common.Vec32i16;
const SIMD_WIDTH = common.SIMD_WIDTH;

pub fn bind(allocator: std.mem.Allocator, a: []const Trit, b: []const Trit) ![]Trit {
    const len = @max(a.len, b.len);
    var result = try allocator.alloc(Trit, len);
    for (0..len) |i| {
        const a_val = if (i < a.len) a[i] else 0;
        const b_val = if (i < b.len) b[i] else 0;
        result[i] = if (b_val == 0) a_val else b_val * a_val;
    }
    return result;
}

pub fn unbind(allocator: std.mem.Allocator, bound: []const Trit, key: []const Trit) ![]Trit {
    const len = @max(bound.len, key.len);
    var result = try allocator.alloc(Trit, len);
    for (0..len) |i| {
        const b_val = if (i < bound.len) bound[i] else 0;
        const k_val = if (i < key.len) key[i] else 0;
        result[i] = if (k_val == 0) b_val else k_val * b_val;
    }
    return result;
}

pub fn bundle2(allocator: std.mem.Allocator, a: []const Trit, b: []const Trit) ![]Trit {
    const len = @max(a.len, b.len);
    var result = try allocator.alloc(Trit, len);
    for (0..len) |i| {
        const a_val = if (i < a.len) a[i] else 0;
        const b_val = if (i < b.len) b[i] else 0;
        const sum = a_val + b_val;
        result[i] = if (sum > 0) 1 else if (sum < 0) -1 else 0;
    }
    return result;
}

pub fn bundle3(allocator: std.mem.Allocator, a: []const Trit, b: []const Trit, c: []const Trit) ![]Trit {
    const len = @max(@max(a.len, b.len), c.len);
    var result = try allocator.alloc(Trit, len);
    for (0..len) |i| {
        const a_val = if (i < a.len) a[i] else 0;
        const b_val = if (i < b.len) b[i] else 0;
        const c_val = if (i < c.len) c[i] else 0;
        const sum = a_val + b_val + c_val;
        result[i] = if (sum > 0) 1 else if (sum < 0) -1 else 0;
    }
    return result;
}

pub fn bundleN(allocator: std.mem.Allocator, vectors: []const []const Trit) ![]Trit {
    if (vectors.len == 0) return error.EmptyVectorList;
    var len: usize = 0;
    for (vectors) |v| len = @max(len, v.len);
    var result = try allocator.alloc(Trit, len);
    for (0..len) |i| {
        var sum: i32 = 0;
        for (vectors) |v| {
            const val = if (i < v.len) v[i] else 0;
            sum += val;
        }
        result[i] = if (sum > 0) 1 else if (sum < 0) -1 else 0;
    }
    return result;
}

pub fn permute(allocator: std.mem.Allocator, v: []const Trit, n: usize) ![]Trit {
    if (v.len == 0) return try allocator.alloc(Trit, 0);
    const result = try allocator.alloc(Trit, v.len);
    const rotate = @mod(n, v.len);
    for (0..v.len) |i| {
        const src_idx = if (i >= rotate) i - rotate else i + v.len - rotate;
        result[i] = v[src_idx];
    }
    return result;
}

pub fn inversePermute(allocator: std.mem.Allocator, v: []const Trit, n: usize) ![]Trit {
    if (v.len == 0) return try allocator.alloc(Trit, 0);
    const result = try allocator.alloc(Trit, v.len);
    const rotate = @mod(n, v.len);
    for (0..v.len) |i| {
        const src_idx = (i + rotate) % v.len;
        result[i] = v[src_idx];
    }
    return result;
}

pub fn cosineSimilarity(a: []const Trit, b: []const Trit) f64 {
    if (a.len != b.len) return 0.0;
    var dot: i64 = 0;
    var norm_a: f64 = 0.0;
    var norm_b: f64 = 0.0;
    for (a, 0..) |ai, i| {
        dot += ai * b[i];
        norm_a += @as(f64, @floatFromInt(ai)) * @as(f64, @floatFromInt(ai));
        norm_b += @as(f64, @floatFromInt(b[i])) * @as(f64, @floatFromInt(b[i]));
    }
    const denom = @sqrt(norm_a) * @sqrt(norm_b);
    if (denom == 0.0) return 0.0;
    return @as(f64, @floatFromInt(dot)) / denom;
}

pub fn hammingDistance(a: []const Trit, b: []const Trit) usize {
    var count: usize = 0;
    const len = @min(a.len, b.len);
    for (0..len) |i| {
        if (a[i] != b[i]) count += 1;
    }
    return count;
}

pub fn hammingSimilarity(a: []const Trit, b: []const Trit) f64 {
    const dist = hammingDistance(a, b);
    const max_len = @max(a.len, b.len);
    if (max_len == 0) return 1.0;
    return 1.0 - (@as(f64, @floatFromInt(dist)) / @as(f64, @floatFromInt(max_len)));
}

pub fn dotSimilarity(a: []const Trit, b: []const Trit) i64 {
    var sum: i64 = 0;
    const len = @min(a.len, b.len);
    for (0..len) |i| {
        sum += a[i] * b[i];
    }
    return sum;
}

pub fn vectorNorm(v: []const Trit) f64 {
    var sum: f64 = 0.0;
    for (v) |x| {
        sum += @as(f64, @floatFromInt(x)) * @as(f64, @floatFromInt(x));
    }
    return @sqrt(sum);
}

pub fn countNonZero(v: []const Trit) usize {
    var count: usize = 0;
    for (v) |x| {
        if (x != 0) count += 1;
    }
    return count;
}

pub fn randomVector(allocator: std.mem.Allocator, len: usize, seed: u64) ![]Trit {
    if (len == 0) return try allocator.alloc(Trit, 0);
    var result = try allocator.alloc(Trit, len);
    var rng = std.Random.DefaultPrng.init(seed);
    for (0..len) |i| {
        const val = rng.random().intRangeAtMost(i3, -1, 1);
        result[i] = @as(Trit, @intCast(val));
    }
    return result;
}

pub fn encodeSequence(allocator: std.mem.Allocator, text: []const u8) ![]Trit {
    const trits_per_byte: usize = 5;
    const result_len = text.len * trits_per_byte;
    var result = try allocator.alloc(Trit, result_len);
    for (text, 0..) |byte, i| {
        const base_idx = i * trits_per_byte;
        const b = @as(i32, byte);
        result[base_idx + 0] = @as(Trit, @intCast(@mod(b + 1, 3))) - 1;
        result[base_idx + 1] = @as(Trit, @intCast(@mod(b + 2, 3))) - 1;
        result[base_idx + 2] = @as(Trit, @intCast(@mod(b + 3, 3))) - 1;
        result[base_idx + 3] = @as(Trit, @intCast(@mod(b + 4, 3))) - 1;
        result[base_idx + 4] = @as(Trit, @intCast(@mod(b + 5, 3))) - 1;
    }
    return result;
}

pub fn probeSequence(allocator: std.mem.Allocator, sequence: []const Trit, query: []const Trit) ![]f64 {
    if (query.len == 0) {
        const result = try allocator.alloc(f64, 1);
        result[0] = 0.0;
        return result;
    }
    if (sequence.len < query.len) {
        const result = try allocator.alloc(f64, 1);
        result[0] = 0.0;
        return result;
    }
    const window_count = sequence.len - query.len + 1;
    var result = try allocator.alloc(f64, window_count);
    for (0..window_count) |i| {
        const window = sequence[i..][0..query.len];
        result[i] = cosineSimilarity(window, query);
    }
    return result;
}

pub fn dotProduct(a: []const Trit, b: []const Trit) i64 {
    var sum: i64 = 0;
    const len = @min(a.len, b.len);
    for (0..len) |i| {
        sum += a[i] * b[i];
    }
    return sum;
}
