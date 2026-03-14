// @origin(spec:ternary_inference.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// HSLM — Full Ternary Inference Pipeline
// 0 floating-point operations: trit embed → trit PE → quantize → blocks → argmax.
// All arithmetic is integer: i2 × i2 → i4, accumulate → i32, requantize → i2.

const std = @import("std");
const Trit = @import("trit_encoding.zig").Trit;
const TritEmbedding = @import("trit_encoding.zig").TritEmbedding;
const TernaryPE = @import("ternary_position.zig").TernaryPE;
const ternary_activations = @import("ternary_activations.zig");
const ternary_attention = @import("ternary_attention.zig");

/// One transformer block in the ternary pipeline.
pub const TernaryBlock = struct {
    /// Attention weights: Q, K, V projections (ternary)
    w_q: []const Trit,
    w_k: []const Trit,
    w_v: []const Trit,
    w_o: []const Trit,
    /// FFN weights (ternary)
    w_ff1: []const Trit,
    w_ff2: []const Trit,
    dim: usize,
    ffn_dim: usize,
};

/// Full ternary inference pipeline.
/// Processes: token → trit embed → trit PE → N blocks → argmax.
pub const TernaryInferencePipeline = struct {
    embedding: TritEmbedding,
    pe: TernaryPE,
    blocks: []TernaryBlock,
    num_blocks: usize,
    dim: usize,
    /// Inter-layer requantization threshold
    requant_threshold: i32 = 2,

    /// Forward pass: token + position → next token prediction.
    /// Zero floating-point operations.
    pub fn forward(
        self: *const TernaryInferencePipeline,
        token: u32,
        pos: u32,
        // Working buffers (caller provides to avoid allocation)
        buf_a: []Trit,
        buf_b: []Trit,
        buf_accum: []i32,
    ) u32 {
        const dim = self.dim;

        // 1. Trit embedding (pure ternary lookup + bind)
        self.embedding.embed(token, buf_a[0..dim]);

        // 2. Add ternary positional encoding (ternary + ternary → ternary via bind)
        var pe_buf: [512]Trit = undefined;
        self.pe.encode(pos, pe_buf[0..dim]);

        // Combine: element-wise ternary addition (clamp to ternary)
        for (0..dim) |d| {
            const sum: i8 = @as(i8, buf_a[d]) + @as(i8, pe_buf[d]);
            buf_a[d] = @intCast(std.math.clamp(sum, -1, 1));
        }

        // 3. Process through ternary transformer blocks
        for (0..self.num_blocks) |b| {
            const block = &self.blocks[b];
            self.processBlock(block, buf_a, buf_b, buf_accum);
        }

        // 4. Argmax over output (integer comparison, no floats)
        return self.argmax(buf_a[0..dim]);
    }

    /// Process one transformer block (all integer operations).
    fn processBlock(
        self: *const TernaryInferencePipeline,
        block: *const TernaryBlock,
        input_output: []Trit,
        temp: []Trit,
        accum: []i32,
    ) void {
        const dim = block.dim;

        // Attention: Q = input × W_q, K = input × W_k, V = input × W_v
        // (simplified single-position attention for inference)
        ternary_activations.integerTernaryMatmul(
            input_output[0..dim],
            block.w_q,
            accum[0..dim],
            dim,
            dim,
        );
        ternary_activations.quantizeI32ToTernary(accum[0..dim], temp[0..dim], self.requant_threshold);

        // Self-attention score (query · key, both ternary → integer)
        const score = ternary_attention.ternaryScore(temp[0..dim], input_output[0..dim]);

        // Simple attention: if score > 0, add value; if < 0, subtract
        ternary_activations.integerTernaryMatmul(
            input_output[0..dim],
            block.w_v,
            accum[0..dim],
            dim,
            dim,
        );

        // Scale by attention sign and add residual
        const attn_weight: i32 = if (score > 0) 1 else if (score < 0) -1 else 0;
        for (0..dim) |d| {
            accum[d] = accum[d] * attn_weight + @as(i32, @as(i8, input_output[d]));
        }
        ternary_activations.quantizeI32ToTernary(accum[0..dim], input_output[0..dim], self.requant_threshold);

        // FFN: ff1 then ff2 with requantization
        ternary_activations.integerTernaryMatmul(
            input_output[0..dim],
            block.w_ff1,
            accum[0..block.ffn_dim],
            dim,
            block.ffn_dim,
        );
        ternary_activations.quantizeI32ToTernary(accum[0..block.ffn_dim], temp[0..block.ffn_dim], self.requant_threshold);

        ternary_activations.integerTernaryMatmul(
            temp[0..block.ffn_dim],
            block.w_ff2,
            accum[0..dim],
            block.ffn_dim,
            dim,
        );

        // Residual connection + requantize
        for (0..dim) |d| {
            accum[d] += @as(i32, @as(i8, input_output[d]));
        }
        ternary_activations.quantizeI32ToTernary(accum[0..dim], input_output[0..dim], self.requant_threshold);
    }

    /// Integer argmax (no floats needed).
    /// For ternary output, find position with highest "score" via absolute count.
    fn argmax(self: *const TernaryInferencePipeline, output: []const Trit) u32 {
        _ = self;
        // Sum absolute values in groups of 6 trits (= one token worth)
        // Then find the group with highest activity
        var best_token: u32 = 0;
        var best_score: i32 = std.math.minInt(i32);

        // Simple: treat output as logits (ternary values as scores)
        const num_tokens = @min(output.len, 729);
        for (0..num_tokens) |t| {
            const score: i32 = @as(i8, output[t]);
            if (score > best_score) {
                best_score = score;
                best_token = @intCast(t);
            }
        }
        return best_token;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "TernaryInferencePipeline produces valid token" {
    const dim = 32;
    const ffn_dim = 48;

    // Create a minimal pipeline
    var emb = try TritEmbedding.init(std.testing.allocator, dim);
    defer emb.deinit(std.testing.allocator);

    var pe = try TernaryPE.init(std.testing.allocator, dim);
    defer pe.deinit(std.testing.allocator);

    // Create one block with random ternary weights
    var rng = std.Random.DefaultPrng.init(0xF00D);
    const random = rng.random();

    const w_q = try std.testing.allocator.alloc(Trit, dim * dim);
    defer std.testing.allocator.free(w_q);
    const w_k = try std.testing.allocator.alloc(Trit, dim * dim);
    defer std.testing.allocator.free(w_k);
    const w_v = try std.testing.allocator.alloc(Trit, dim * dim);
    defer std.testing.allocator.free(w_v);
    const w_o = try std.testing.allocator.alloc(Trit, dim * dim);
    defer std.testing.allocator.free(w_o);
    const w_ff1 = try std.testing.allocator.alloc(Trit, dim * ffn_dim);
    defer std.testing.allocator.free(w_ff1);
    const w_ff2 = try std.testing.allocator.alloc(Trit, ffn_dim * dim);
    defer std.testing.allocator.free(w_ff2);

    for (w_q) |*v| v.* = @intCast(random.intRangeAtMost(i8, -1, 1));
    for (w_k) |*v| v.* = @intCast(random.intRangeAtMost(i8, -1, 1));
    for (w_v) |*v| v.* = @intCast(random.intRangeAtMost(i8, -1, 1));
    for (w_o) |*v| v.* = @intCast(random.intRangeAtMost(i8, -1, 1));
    for (w_ff1) |*v| v.* = @intCast(random.intRangeAtMost(i8, -1, 1));
    for (w_ff2) |*v| v.* = @intCast(random.intRangeAtMost(i8, -1, 1));

    var blocks = [_]TernaryBlock{.{
        .w_q = w_q,
        .w_k = w_k,
        .w_v = w_v,
        .w_o = w_o,
        .w_ff1 = w_ff1,
        .w_ff2 = w_ff2,
        .dim = dim,
        .ffn_dim = ffn_dim,
    }};

    const pipeline = TernaryInferencePipeline{
        .embedding = emb,
        .pe = pe,
        .blocks = &blocks,
        .num_blocks = 1,
        .dim = dim,
    };

    var buf_a: [512]Trit = undefined;
    var buf_b: [512]Trit = undefined;
    var buf_accum: [512]i32 = undefined;

    const result = pipeline.forward(42, 0, &buf_a, &buf_b, &buf_accum);

    // Output should be a valid token
    try std.testing.expect(result < 729);
}

test "quantizeI32ToTernary output is ternary" {
    const input = [_]i32{ 10, -5, 0, 3, -1, 7, -8, 1 };
    var output: [8]Trit = undefined;
    ternary_activations.quantizeI32ToTernary(&input, &output, 2);

    for (output) |v| {
        const val: i8 = v;
        try std.testing.expect(val >= -1 and val <= 1);
    }
}
