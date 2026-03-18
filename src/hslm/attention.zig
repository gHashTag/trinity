// @origin(spec:attention.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// HSLM — VSA Attention
// Attention via ternary cosine similarity scores + weighted bundle
// No softmax, no QKV projections — pure hyperdimensional computing

const std = @import("std");
const constants = @import("constants.zig");

const VSA_DIM = constants.VSA_DIM;
const CONTEXT_LEN = constants.CONTEXT_LEN;

// ═══════════════════════════════════════════════════════════════════════════════
// VSA ATTENTION
// ═══════════════════════════════════════════════════════════════════════════════

pub const VSAAttention = struct {
    // Scratch buffers
    sim_scores: [CONTEXT_LEN]f64,
    temp_vec: [VSA_DIM]i8,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .sim_scores = [_]f64{0.0} ** CONTEXT_LEN,
            .temp_vec = [_]i8{0} ** VSA_DIM,
            .allocator = allocator,
        };
    }

    /// Compute VSA attention for a single query position
    /// Returns: context vector (weighted bundle of values) and max similarity score
    pub fn forward(
        self: *Self,
        query: []const i8, // VSA_DIM: current position trit vector
        keys: []const i8, // seq_len * VSA_DIM: all position trit vectors
        values: []const i8, // seq_len * VSA_DIM: all position trit vectors (same as keys in base case)
        seq_len: usize,
        context_out: []i8, // VSA_DIM: output context vector
    ) f64 {
        const slen = @min(seq_len, CONTEXT_LEN);

        // Step 1: Compute similarity scores between query and all keys
        // max_sim excludes self-position to avoid trivial 1.0 (for consciousness gate)
        var max_sim: f64 = -1.0;
        for (0..slen) |i| {
            const key_offset = i * VSA_DIM;
            const key = keys[key_offset .. key_offset + VSA_DIM];
            self.sim_scores[i] = cosineSimilarityTrit(query, key);
        }
        // Find max similarity excluding query position (last visible position)
        const query_pos = slen - 1;
        for (0..slen) |i| {
            if (i != query_pos and self.sim_scores[i] > max_sim) {
                max_sim = self.sim_scores[i];
            }
        }
        // Fallback: if only 1 position visible, use self-similarity
        if (slen <= 1) max_sim = self.sim_scores[0];

        // Step 2: Weighted bundle — accumulate (similarity × value) in integer accumulators
        var accum: [VSA_DIM]i32 = [_]i32{0} ** VSA_DIM;

        for (0..slen) |i| {
            const score = self.sim_scores[i];
            if (score <= 0.0) continue; // Skip negative/zero similarity

            const val_offset = i * VSA_DIM;
            const val = values[val_offset .. val_offset + VSA_DIM];

            // Quantize score to integer weight (1..10 range)
            const weight: i32 = @intFromFloat(@max(1.0, score * 10.0));

            for (0..VSA_DIM) |d| {
                accum[d] += @as(i32, val[d]) * weight;
            }
        }

        // Step 3: Majority vote to produce ternary output
        for (0..VSA_DIM) |d| {
            if (accum[d] > 0) {
                context_out[d] = 1;
            } else if (accum[d] < 0) {
                context_out[d] = -1;
            } else {
                context_out[d] = 0;
            }
        }

        return max_sim;
    }

    /// Causal (autoregressive) attention: only attend to positions <= current
    pub fn forwardCausal(
        self: *Self,
        position: usize,
        trit_sequence: []const i8, // full_seq_len * VSA_DIM
        context_out: []i8,
    ) f64 {
        const visible_len = position + 1;
        const query_offset = position * VSA_DIM;
        const query = trit_sequence[query_offset .. query_offset + VSA_DIM];

        return self.forward(
            query,
            trit_sequence,
            trit_sequence,
            visible_len,
            context_out,
        );
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY COSINE SIMILARITY (standalone, no HybridBigInt dependency)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn cosineSimilarityTrit(a: []const i8, b: []const i8) f64 {
    const n = @min(a.len, b.len);
    var dot: i64 = 0;
    var norm_a: i64 = 0;
    var norm_b: i64 = 0;

    // SIMD-friendly loop
    var i: usize = 0;
    while (i + 32 <= n) : (i += 32) {
        const av: @Vector(32, i16) = @as(@Vector(32, i8), a[i..][0..32].*);
        const bv: @Vector(32, i16) = @as(@Vector(32, i8), b[i..][0..32].*);
        const prod = av * bv;
        const aa = av * av;
        const bb = bv * bv;
        dot += @reduce(.Add, prod);
        norm_a += @reduce(.Add, aa);
        norm_b += @reduce(.Add, bb);
    }

    // Scalar remainder
    while (i < n) : (i += 1) {
        const ai: i64 = a[i];
        const bi: i64 = b[i];
        dot += ai * bi;
        norm_a += ai * ai;
        norm_b += bi * bi;
    }

    if (norm_a == 0 or norm_b == 0) return 0.0;

    const na = @sqrt(@as(f64, @floatFromInt(norm_a)));
    const nb = @sqrt(@as(f64, @floatFromInt(norm_b)));
    return @as(f64, @floatFromInt(dot)) / (na * nb);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "cosine similarity identical vectors" {
    var a = [_]i8{1} ** 32 ++ [_]i8{-1} ** 32;
    var b = [_]i8{1} ** 32 ++ [_]i8{-1} ** 32;
    const sim = cosineSimilarityTrit(&a, &b);
    try std.testing.expectApproxEqAbs(1.0, sim, 1e-10);
}

test "cosine similarity opposite vectors" {
    var a = [_]i8{1} ** 32 ++ [_]i8{-1} ** 32;
    var b = [_]i8{-1} ** 32 ++ [_]i8{1} ** 32;
    const sim = cosineSimilarityTrit(&a, &b);
    try std.testing.expectApproxEqAbs(-1.0, sim, 1e-10);
}

test "vsa attention forward" {
    const allocator = std.testing.allocator;
    var attn = VSAAttention.init(allocator);

    // Create a small sequence: 3 positions × VSA_DIM
    const seq_len = 3;
    var sequence: [seq_len * VSA_DIM]i8 = undefined;

    // Fill with deterministic pattern
    var prng = std.Random.DefaultPrng.init(12345);
    const rng = prng.random();
    for (&sequence) |*v| {
        v.* = rng.intRangeAtMost(i8, -1, 1);
    }

    var context: [VSA_DIM]i8 = undefined;
    const max_sim = attn.forwardCausal(2, &sequence, &context);

    // Max similarity should be between -1 and 1
    try std.testing.expect(max_sim >= -1.0 and max_sim <= 1.0);

    // Context should be ternary
    for (context) |t| {
        try std.testing.expect(t >= -1 and t <= 1);
    }
}

test "vsa attention self-similarity is highest" {
    const allocator = std.testing.allocator;
    var attn = VSAAttention.init(allocator);

    // When query == key, self-similarity should be 1.0
    var query: [VSA_DIM]i8 = undefined;
    var prng = std.Random.DefaultPrng.init(999);
    const rng = prng.random();
    for (&query) |*v| {
        v.* = rng.intRangeAtMost(i8, -1, 1);
    }

    // Sequence with 1 position = the query itself
    var context: [VSA_DIM]i8 = undefined;
    const max_sim = attn.forward(&query, &query, &query, 1, &context);
    try std.testing.expectApproxEqAbs(1.0, max_sim, 1e-10);
}
