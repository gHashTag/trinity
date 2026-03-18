// @origin(spec:reasoning.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// HSLM — VSA Symbolic Reasoning (System 2)
// Analogy, chain reasoning, concept blending via VSA algebra
// Activated only when consciousness gate exceeds φ⁻¹ threshold

const std = @import("std");
const constants = @import("constants.zig");
const attn_mod = @import("attention.zig");

const VSA_DIM = constants.VSA_DIM;
const cosineSimilarityTrit = attn_mod.cosineSimilarityTrit;

// ═══════════════════════════════════════════════════════════════════════════════
// VSA REASONING ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

pub const Reasoning = struct {
    // Scratch buffers for intermediate computations
    temp1: [VSA_DIM]i8,
    temp2: [VSA_DIM]i8,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .temp1 = [_]i8{0} ** VSA_DIM,
            .temp2 = [_]i8{0} ** VSA_DIM,
        };
    }

    /// Analogy: A:B :: C:?
    /// Computes: unbind(bind(A,B), A) then bind(result, C) = bind(B, C) essentially
    /// More precisely: D = bind(unbind(bind(A,B), C_domain_key), C)
    /// Simplified: D = bind(unbind(B, A), C) — "what B is to A, apply to C"
    pub fn analogy(
        self: *Self,
        a: []const i8, // Source domain
        b: []const i8, // Source range
        c: []const i8, // Target domain
        result: []i8, // Target range (output)
    ) void {
        // Step 1: relation = unbind(b, a) = bind(b, a) since bind is self-inverse
        bindVec(b, a, &self.temp1);

        // Step 2: result = bind(relation, c)
        bindVec(&self.temp1, c, result);
    }

    /// Chain reasoning: compose multiple relations
    /// Given a chain [v1, v2, v3, ...], compute cumulative binding
    /// chain(v1, v2, v3) = bind(bind(v1, v2), v3)
    pub fn chain(
        self: *Self,
        vectors: []const []const i8,
        result: []i8,
    ) void {
        if (vectors.len == 0) {
            @memset(result[0..VSA_DIM], 0);
            return;
        }

        // Start with first vector
        @memcpy(result[0..VSA_DIM], vectors[0][0..VSA_DIM]);

        // Bind with each subsequent vector
        for (1..vectors.len) |i| {
            @memcpy(&self.temp1, result[0..VSA_DIM]);
            bindVec(&self.temp1, vectors[i], result);
        }
    }

    /// Concept blending: weighted bundle of multiple concepts
    /// blend([A, B, C], [w1, w2, w3]) = majority_vote(w1*A + w2*B + w3*C)
    pub fn blend(
        concepts: []const []const i8,
        weights: []const f64,
        result: []i8,
    ) void {
        var accum: [VSA_DIM]i32 = [_]i32{0} ** VSA_DIM;

        const n = @min(concepts.len, weights.len);
        for (0..n) |i| {
            const w: i32 = @intFromFloat(@max(1.0, @abs(weights[i]) * 10.0));
            const sign: i32 = if (weights[i] >= 0.0) 1 else -1;
            for (0..VSA_DIM) |d| {
                accum[d] += @as(i32, concepts[i][d]) * w * sign;
            }
        }

        // Majority vote
        for (0..VSA_DIM) |d| {
            if (accum[d] > 0) {
                result[d] = 1;
            } else if (accum[d] < 0) {
                result[d] = -1;
            } else {
                result[d] = 0;
            }
        }
    }

    /// Full reasoning pass: analogy + blend with context
    /// Takes the VSA context from attention and the current token embedding,
    /// produces a reasoned output vector
    pub fn forward(
        self: *Self,
        current: []const i8, // Current position VSA embedding (VSA_DIM)
        context: []const i8, // Attention context vector (VSA_DIM)
        output: []i8, // Reasoned output (VSA_DIM)
    ) void {
        // Compute analogy: what is context relative to current?
        // Then blend the analogy result with the context
        self.analogy(current, context, current, &self.temp2);

        const vecs = [_][]const i8{ context, &self.temp2 };
        const wts = [_]f64{ 0.618, 0.382 }; // φ⁻¹ and φ⁻² weights
        blend(&vecs, &wts, output);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// STANDALONE VSA OPERATIONS (trit-level, no HybridBigInt)
// ═══════════════════════════════════════════════════════════════════════════════

/// Element-wise ternary bind (multiplication)
pub fn bindVec(a: []const i8, b: []const i8, out: []i8) void {
    const n = @min(@min(a.len, b.len), out.len);

    // SIMD path
    var i: usize = 0;
    while (i + 32 <= n) : (i += 32) {
        const av: @Vector(32, i8) = a[i..][0..32].*;
        const bv: @Vector(32, i8) = b[i..][0..32].*;
        out[i..][0..32].* = av * bv;
    }

    // Scalar remainder
    while (i < n) : (i += 1) {
        out[i] = @as(i8, @intCast(@as(i16, a[i]) * @as(i16, b[i])));
    }
}

/// Element-wise ternary unbind (same as bind for balanced ternary)
pub fn unbindVec(bound: []const i8, key: []const i8, out: []i8) void {
    bindVec(bound, key, out);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "bind is self-inverse" {
    var a: [VSA_DIM]i8 = undefined;
    var b: [VSA_DIM]i8 = undefined;
    var prng = std.Random.DefaultPrng.init(42);
    const rng = prng.random();

    for (0..VSA_DIM) |i| {
        a[i] = rng.intRangeAtMost(i8, -1, 1);
        b[i] = rng.intRangeAtMost(i8, -1, 1);
    }

    // bind(bind(a, b), b) should recover a (where both are non-zero)
    var bound: [VSA_DIM]i8 = undefined;
    var recovered: [VSA_DIM]i8 = undefined;
    bindVec(&a, &b, &bound);
    bindVec(&bound, &b, &recovered);

    // For positions where b != 0, recovered should equal a
    var match_count: usize = 0;
    var check_count: usize = 0;
    for (0..VSA_DIM) |i| {
        if (b[i] != 0) {
            check_count += 1;
            if (recovered[i] == a[i]) match_count += 1;
        }
    }
    // Should have high recovery rate
    try std.testing.expect(check_count > 0);
    try std.testing.expect(match_count == check_count);
}

test "analogy A:B :: C:D" {
    var reasoning = Reasoning.init();
    var a: [VSA_DIM]i8 = undefined;
    var b: [VSA_DIM]i8 = undefined;
    var c: [VSA_DIM]i8 = undefined;
    var d: [VSA_DIM]i8 = undefined;

    var prng = std.Random.DefaultPrng.init(777);
    const rng = prng.random();
    for (0..VSA_DIM) |i| {
        a[i] = rng.intRangeAtMost(i8, -1, 1);
        b[i] = rng.intRangeAtMost(i8, -1, 1);
        c[i] = rng.intRangeAtMost(i8, -1, 1);
    }

    reasoning.analogy(&a, &b, &c, &d);

    // D should be ternary
    for (d) |t| {
        try std.testing.expect(t >= -1 and t <= 1);
    }

    // D should not be all zeros (with high probability)
    var nonzero: usize = 0;
    for (d) |t| {
        if (t != 0) nonzero += 1;
    }
    try std.testing.expect(nonzero > 0);
}

test "blend produces ternary output" {
    var v1: [VSA_DIM]i8 = [_]i8{1} ** VSA_DIM;
    var v2: [VSA_DIM]i8 = [_]i8{-1} ** VSA_DIM;
    var result: [VSA_DIM]i8 = undefined;

    const vecs = [_][]const i8{ &v1, &v2 };
    const wts = [_]f64{ 0.7, 0.3 };
    Reasoning.blend(&vecs, &wts, &result);

    // v1 has higher weight so result should be mostly +1
    var pos_count: usize = 0;
    for (result) |t| {
        try std.testing.expect(t >= -1 and t <= 1);
        if (t == 1) pos_count += 1;
    }
    try std.testing.expect(pos_count == VSA_DIM); // All +1 since 7 > 3
}

test "reasoning forward produces output" {
    var reasoning = Reasoning.init();

    var current: [VSA_DIM]i8 = undefined;
    var context: [VSA_DIM]i8 = undefined;
    var output: [VSA_DIM]i8 = undefined;

    var prng = std.Random.DefaultPrng.init(555);
    const rng = prng.random();
    for (0..VSA_DIM) |i| {
        current[i] = rng.intRangeAtMost(i8, -1, 1);
        context[i] = rng.intRangeAtMost(i8, -1, 1);
    }

    reasoning.forward(&current, &context, &output);

    for (output) |t| {
        try std.testing.expect(t >= -1 and t <= 1);
    }
}
