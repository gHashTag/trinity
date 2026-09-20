const std = @import("std");
const tc = @import("trinity_constants.zig");

pub const LayerKind = enum { gauge, higgs, lepton, cosmology };

pub fn initStd(kind: LayerKind) f64 {
    return tc.trinityInitStd(@enumFromInt(@intFromEnum(kind)));
}

pub fn trinityInitWeight(
    rng: std.Random,
    fan_in: u32,
    kind: LayerKind,
) f64 {
    const std_val = initStd(kind) / @sqrt(@as(f64, @floatFromInt(fan_in)));
    return rng.floatNorm(f64) * std_val;
}

pub fn initTensor(
    allocator: std.mem.Allocator,
    rows: u32,
    cols: u32,
    kind: LayerKind,
    seed: u64,
) ![]f64 {
    const n = @as(usize, rows) * @as(usize, cols);
    const tensor = try allocator.alloc(f64, n);
    var prng = std.Random.DefaultPrng.init(seed);
    const rng = prng.random();
    for (tensor) |*w| {
        w.* = trinityInitWeight(rng, cols, kind);
    }
    return tensor;
}

pub fn initEmbedding(
    allocator: std.mem.Allocator,
    vocab_size: u32,
    d_model: u32,
    seed: u64,
) ![]f64 {
    return initTensor(allocator, vocab_size, d_model, .cosmology, seed);
}

pub fn initAttentionQKV(
    allocator: std.mem.Allocator,
    d_model: u32,
    n_heads: u32,
    seed: u64,
) ![]f64 {
    return initTensor(allocator, n_heads * tc.D_HEAD, d_model, .gauge, seed);
}

pub fn initFFN(
    allocator: std.mem.Allocator,
    d_model: u32,
    d_ffn: u32,
    seed: u64,
) ![]f64 {
    return initTensor(allocator, d_ffn, d_model, .lepton, seed);
}

test "init std values" {
    try std.testing.expect(initStd(.gauge) > initStd(.higgs));
    try std.testing.expect(initStd(.higgs) > initStd(.lepton));
    try std.testing.expect(initStd(.lepton) > initStd(.cosmology));
}

test "trinity init weight is finite" {
    var prng = std.Random.DefaultPrng.init(42);
    const rng = prng.random();
    var all_finite = true;
    for (0..100) |_| {
        const w = trinityInitWeight(rng, 144, .gauge);
        if (!std.math.isFinite(w)) all_finite = false;
    }
    try std.testing.expect(all_finite);
}

test "init tensor dimensions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const tensor = try initTensor(arena.allocator(), 8, 18, .gauge, 42);
    try std.testing.expectEqual(@as(usize, 144), tensor.len);
}

test "init embedding uses cosmology std" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const emb = try initEmbedding(arena.allocator(), 100, tc.D_MODEL, 42);
    try std.testing.expectEqual(@as(usize, 100 * 144), emb.len);
}
