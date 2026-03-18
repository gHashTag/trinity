// @origin(spec:embedding.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// HSLM — Dual Embedding Layer
// TNN float (243-dim) + VSA ternary (1024-dim) per token
// Position encoding via cyclic permutation (VSA) and sinusoidal (TNN)

const std = @import("std");
const math = std.math;
const constants = @import("constants.zig");

const VOCAB_SIZE = constants.VOCAB_SIZE;
const EMBED_DIM = constants.EMBED_DIM;
const VSA_DIM = constants.VSA_DIM;
const CONTEXT_LEN = constants.CONTEXT_LEN;
const PHI = constants.PHI;

// ═══════════════════════════════════════════════════════════════════════════════
// EMBEDDING TABLE
// ═══════════════════════════════════════════════════════════════════════════════

pub const Embedding = struct {
    // Float embedding table: VOCAB_SIZE × EMBED_DIM (TNN space)
    float_table: []f32,
    // Ternary embedding table: VOCAB_SIZE × VSA_DIM (VSA space)
    trit_table: []i8,
    // Sinusoidal position encodings: CONTEXT_LEN × EMBED_DIM
    pos_float: []f32,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        const float_table = try allocator.alloc(f32, VOCAB_SIZE * EMBED_DIM);
        const trit_table = try allocator.alloc(i8, VOCAB_SIZE * VSA_DIM);
        const pos_float = try allocator.alloc(f32, CONTEXT_LEN * EMBED_DIM);

        var self = Self{
            .float_table = float_table,
            .trit_table = trit_table,
            .pos_float = pos_float,
            .allocator = allocator,
        };

        self.initFloatEmbeddings();
        self.initTritEmbeddings();
        self.initPositionEncodings();

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.float_table);
        self.allocator.free(self.trit_table);
        self.allocator.free(self.pos_float);
    }

    /// Look up float embedding for a token and add position encoding
    pub fn embedFloat(self: *const Self, token_id: u16, position: usize, output: []f32) void {
        std.debug.assert(output.len >= EMBED_DIM);
        const tok_idx = @as(usize, token_id);
        const tok_offset = tok_idx * EMBED_DIM;
        const pos_offset = position * EMBED_DIM;

        for (0..EMBED_DIM) |i| {
            output[i] = self.float_table[tok_offset + i] + self.pos_float[pos_offset + i];
        }
    }

    /// Look up ternary embedding for a token with positional permutation
    pub fn embedTrit(self: *const Self, token_id: u16, position: usize, output: []i8) void {
        std.debug.assert(output.len >= VSA_DIM);
        const tok_idx = @as(usize, token_id);
        const tok_offset = tok_idx * VSA_DIM;

        // Copy base embedding
        @memcpy(output[0..VSA_DIM], self.trit_table[tok_offset .. tok_offset + VSA_DIM]);

        // Apply cyclic permutation for position encoding (VSA standard)
        if (position > 0) {
            cyclicPermute(output[0..VSA_DIM], position);
        }
    }

    /// Embed a full sequence (batch of tokens)
    pub fn embedSequence(
        self: *const Self,
        tokens: []const u16,
        float_out: []f32,
        trit_out: []i8,
    ) void {
        const seq_len = @min(tokens.len, CONTEXT_LEN);
        for (0..seq_len) |pos| {
            const f_offset = pos * EMBED_DIM;
            const t_offset = pos * VSA_DIM;
            self.embedFloat(tokens[pos], pos, float_out[f_offset .. f_offset + EMBED_DIM]);
            self.embedTrit(tokens[pos], pos, trit_out[t_offset .. t_offset + VSA_DIM]);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // BRIDGE: float ↔ trit conversion
    // ═══════════════════════════════════════════════════════════════════════

    /// Quantize float vector to ternary using AbsMean quantization (BitNet b1.58)
    pub fn floatToTrit(float_vec: []const f32, trit_vec: []i8) void {
        // Compute mean absolute value
        var sum: f32 = 0.0;
        for (float_vec) |v| {
            sum += @abs(v);
        }
        const mean_abs = sum / @as(f32, @floatFromInt(float_vec.len));
        const scale = if (mean_abs > 1e-6) mean_abs else 1.0;

        for (float_vec, 0..) |v, i| {
            if (i >= trit_vec.len) break;
            const scaled = v / scale;
            if (scaled > 0.5) {
                trit_vec[i] = 1;
            } else if (scaled < -0.5) {
                trit_vec[i] = -1;
            } else {
                trit_vec[i] = 0;
            }
        }
    }

    /// Convert ternary vector to float (direct cast)
    pub fn tritToFloat(trit_vec: []const i8, float_vec: []f32) void {
        for (trit_vec, 0..) |t, i| {
            if (i >= float_vec.len) break;
            float_vec[i] = @floatFromInt(t);
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // PRIVATE INIT
    // ═══════════════════════════════════════════════════════════════════════

    fn initFloatEmbeddings(self: *Self) void {
        // Xavier-style initialization scaled by 1/sqrt(EMBED_DIM)
        const scale = 1.0 / @sqrt(@as(f32, @floatFromInt(EMBED_DIM)));
        var prng = std.Random.DefaultPrng.init(0xDEAD_BEEF_CAFE_1234);
        const rng = prng.random();

        for (0..VOCAB_SIZE * EMBED_DIM) |i| {
            // Uniform [-scale, +scale]
            const u = rng.float(f32);
            self.float_table[i] = (u * 2.0 - 1.0) * scale;
        }
    }

    fn initTritEmbeddings(self: *Self) void {
        // Random ternary vectors {-1, 0, +1} with ~1/3 probability each
        var prng = std.Random.DefaultPrng.init(0xCAFE_BABE_1234_5678);
        const rng = prng.random();

        for (0..VOCAB_SIZE * VSA_DIM) |i| {
            const r = rng.intRangeAtMost(i8, -1, 1);
            self.trit_table[i] = r;
        }
    }

    fn initPositionEncodings(self: *Self) void {
        // Sacred φ-based position encodings (GGRoPE-inspired)
        // φ is the most irrational number → maximally non-repeating frequencies
        // TRINITY_SCALE = 3/π puts frequencies in useful range for CONTEXT_LEN=81
        const SACRED_PHI: f64 = 1.6180339887498948482;
        const TRINITY_SCALE: f64 = 3.0 / std.math.pi;

        for (0..CONTEXT_LEN) |pos| {
            for (0..EMBED_DIM) |i| {
                const p = @as(f64, @floatFromInt(pos));
                const t = @as(f64, @floatFromInt(2 * (i / 2))) / @as(f64, @floatFromInt(EMBED_DIM));
                const freq = math.pow(f64, SACRED_PHI, -t) * TRINITY_SCALE;
                const angle = p * freq;

                const idx = pos * EMBED_DIM + i;
                if (i % 2 == 0) {
                    self.pos_float[idx] = @floatCast(@sin(angle));
                } else {
                    self.pos_float[idx] = @floatCast(@cos(angle));
                }
            }
        }
    }
};

/// In-place cyclic permutation of a trit vector by `count` positions
fn cyclicPermute(vec: []i8, count: usize) void {
    const n = vec.len;
    if (n == 0) return;
    const shift = count % n;
    if (shift == 0) return;

    // Simple rotation: reverse(0..n), reverse(0..shift), reverse(shift..n)
    reverseSlice(vec, 0, n);
    reverseSlice(vec, 0, shift);
    reverseSlice(vec, shift, n);
}

fn reverseSlice(vec: []i8, start: usize, end: usize) void {
    var lo = start;
    var hi = end - 1;
    while (lo < hi) {
        const tmp = vec[lo];
        vec[lo] = vec[hi];
        vec[hi] = tmp;
        lo += 1;
        hi -= 1;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "embedding init/deinit" {
    const allocator = std.testing.allocator;
    var emb = try Embedding.init(allocator);
    defer emb.deinit();

    try std.testing.expect(emb.float_table.len == VOCAB_SIZE * EMBED_DIM);
    try std.testing.expect(emb.trit_table.len == VOCAB_SIZE * VSA_DIM);
    try std.testing.expect(emb.pos_float.len == CONTEXT_LEN * EMBED_DIM);
}

test "float embedding lookup" {
    const allocator = std.testing.allocator;
    var emb = try Embedding.init(allocator);
    defer emb.deinit();

    var output: [EMBED_DIM]f32 = undefined;
    emb.embedFloat(42, 0, &output);

    // Should have non-zero values
    var any_nonzero = false;
    for (output) |v| {
        if (v != 0.0) {
            any_nonzero = true;
            break;
        }
    }
    try std.testing.expect(any_nonzero);
}

test "trit embedding with position" {
    const allocator = std.testing.allocator;
    var emb = try Embedding.init(allocator);
    defer emb.deinit();

    var out0: [VSA_DIM]i8 = undefined;
    var out1: [VSA_DIM]i8 = undefined;

    emb.embedTrit(42, 0, &out0);
    emb.embedTrit(42, 1, &out1);

    // Same token at different positions should differ (permuted)
    var differ = false;
    for (0..VSA_DIM) |i| {
        if (out0[i] != out1[i]) {
            differ = true;
            break;
        }
    }
    try std.testing.expect(differ);
}

test "float to trit roundtrip" {
    var float_vec = [_]f32{ 0.8, -0.9, 0.1, 0.0, -0.3, 1.0, -1.0, 0.5 };
    var trit_vec: [8]i8 = undefined;

    Embedding.floatToTrit(&float_vec, &trit_vec);

    // Should produce ternary values
    for (trit_vec) |t| {
        try std.testing.expect(t >= -1 and t <= 1);
    }
}

test "phi-PE produces distinct encodings for all positions" {
    const allocator = std.testing.allocator;
    var emb = try Embedding.init(allocator);
    defer emb.deinit();

    // Every position should have a unique encoding
    for (0..CONTEXT_LEN) |pos1| {
        for (pos1 + 1..CONTEXT_LEN) |pos2| {
            var diff: f64 = 0.0;
            for (0..EMBED_DIM) |i| {
                const d = @as(f64, emb.pos_float[pos1 * EMBED_DIM + i]) -
                    @as(f64, emb.pos_float[pos2 * EMBED_DIM + i]);
                diff += d * d;
            }
            // L2 distance should be non-zero between any two positions
            try std.testing.expect(diff > 1e-6);
        }
    }
}

test "cyclic permute" {
    var vec = [_]i8{ 1, -1, 0, 1, -1 };
    const original = vec;

    cyclicPermute(&vec, 2);

    // After permuting by 2, should differ
    var same = true;
    for (0..5) |i| {
        if (vec[i] != original[i]) {
            same = false;
            break;
        }
    }
    try std.testing.expect(!same);

    // Permuting by len should restore original
    var vec2 = [_]i8{ 1, -1, 0, 1, -1 };
    cyclicPermute(&vec2, 5);
    try std.testing.expectEqualSlices(i8, &[_]i8{ 1, -1, 0, 1, -1 }, &vec2);
}
