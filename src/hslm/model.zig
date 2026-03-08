// HSLM — Full Model Assembly
// Embedding → 3× TrinityBlock → Output Projection
// ~1.24M ternary parameters, ~248KB

const std = @import("std");
const constants = @import("constants.zig");
const tokenizer_mod = @import("tokenizer.zig");
const embedding_mod = @import("embedding.zig");
const trinity_block = @import("trinity_block.zig");

const VOCAB_SIZE = constants.VOCAB_SIZE;
const EMBED_DIM = constants.EMBED_DIM;
const VSA_DIM = constants.VSA_DIM;
const NUM_BLOCKS = constants.NUM_BLOCKS;
const CONTEXT_LEN = constants.CONTEXT_LEN;
const Config = constants.Config;

// ═══════════════════════════════════════════════════════════════════════════════
// HSLM MODEL
// ═══════════════════════════════════════════════════════════════════════════════

pub const HSLM = struct {
    config: Config,
    emb: embedding_mod.Embedding,
    blocks: [NUM_BLOCKS]trinity_block.TrinityBlock,
    // Output projection: EMBED_DIM → VOCAB_SIZE (ternary weights)
    output_weights: []i8,
    output_bias: []f32,
    output_shadow: []f32,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        return initWithConfig(allocator, Config{});
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, config: Config) !Self {
        const emb = try embedding_mod.Embedding.init(allocator);

        var blocks: [NUM_BLOCKS]trinity_block.TrinityBlock = undefined;
        for (0..NUM_BLOCKS) |i| {
            blocks[i] = try trinity_block.TrinityBlock.init(allocator);
        }

        const out_w = try allocator.alloc(i8, EMBED_DIM * VOCAB_SIZE);
        const out_b = try allocator.alloc(f32, VOCAB_SIZE);
        const out_s = try allocator.alloc(f32, EMBED_DIM * VOCAB_SIZE);

        // Init output projection
        const scale = 1.0 / @sqrt(@as(f32, @floatFromInt(EMBED_DIM)));
        var prng = std.Random.DefaultPrng.init(0xDEAD_CAFE);
        const rng = prng.random();
        for (0..EMBED_DIM * VOCAB_SIZE) |i| {
            out_s[i] = (rng.float(f32) * 2.0 - 1.0) * scale;
        }
        quantizeAbsMean(out_s, out_w);
        @memset(out_b, 0.0);

        return Self{
            .config = config,
            .emb = emb,
            .blocks = blocks,
            .output_weights = out_w,
            .output_bias = out_b,
            .output_shadow = out_s,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.emb.deinit();
        for (&self.blocks) |*b| b.deinit();
        self.allocator.free(self.output_weights);
        self.allocator.free(self.output_bias);
        self.allocator.free(self.output_shadow);
    }

    /// Forward pass for a single sequence
    /// Returns logits for the last position (VOCAB_SIZE)
    pub fn forward(self: *Self, tokens: []const u16, logits: []f32) void {
        const seq_len = @min(tokens.len, CONTEXT_LEN);

        // Step 1: Embed all tokens (float + trit)
        var float_seq: [CONTEXT_LEN * EMBED_DIM]f32 = undefined;
        var trit_seq: [CONTEXT_LEN * VSA_DIM]i8 = undefined;
        self.emb.embedSequence(tokens[0..seq_len], &float_seq, &trit_seq);

        // Step 2: Process through Trinity Blocks
        var cur_float: [CONTEXT_LEN * EMBED_DIM]f32 = float_seq;
        var cur_trit: [CONTEXT_LEN * VSA_DIM]i8 = trit_seq;
        var next_float: [CONTEXT_LEN * EMBED_DIM]f32 = undefined;
        var next_trit: [CONTEXT_LEN * VSA_DIM]i8 = undefined;

        for (&self.blocks) |*block| {
            for (0..seq_len) |pos| {
                const f_off = pos * EMBED_DIM;
                const t_off = pos * VSA_DIM;
                block.forward(
                    pos,
                    cur_float[f_off .. f_off + EMBED_DIM],
                    cur_trit[0 .. (pos + 1) * VSA_DIM],
                    next_float[f_off .. f_off + EMBED_DIM],
                    next_trit[t_off .. t_off + VSA_DIM],
                );
            }
            cur_float = next_float;
            cur_trit = next_trit;
        }

        // Step 3: Output projection from last position
        const last_off = (seq_len - 1) * EMBED_DIM;
        const last_hidden = cur_float[last_off .. last_off + EMBED_DIM];
        ternaryMatvec(last_hidden, self.output_weights, logits, EMBED_DIM, VOCAB_SIZE);
        for (0..VOCAB_SIZE) |j| {
            logits[j] += self.output_bias[j];
        }
    }

    /// Forward pass returning logits for ALL positions (for training)
    pub fn forwardAll(self: *Self, tokens: []const u16, all_logits: []f32) void {
        const seq_len = @min(tokens.len, CONTEXT_LEN);

        var float_seq: [CONTEXT_LEN * EMBED_DIM]f32 = undefined;
        var trit_seq: [CONTEXT_LEN * VSA_DIM]i8 = undefined;
        self.emb.embedSequence(tokens[0..seq_len], &float_seq, &trit_seq);

        var cur_float: [CONTEXT_LEN * EMBED_DIM]f32 = float_seq;
        var cur_trit: [CONTEXT_LEN * VSA_DIM]i8 = trit_seq;
        var next_float: [CONTEXT_LEN * EMBED_DIM]f32 = undefined;
        var next_trit: [CONTEXT_LEN * VSA_DIM]i8 = undefined;

        for (&self.blocks) |*block| {
            for (0..seq_len) |pos| {
                const f_off = pos * EMBED_DIM;
                const t_off = pos * VSA_DIM;
                block.forward(
                    pos,
                    cur_float[f_off .. f_off + EMBED_DIM],
                    cur_trit[0 .. (pos + 1) * VSA_DIM],
                    next_float[f_off .. f_off + EMBED_DIM],
                    next_trit[t_off .. t_off + VSA_DIM],
                );
            }
            cur_float = next_float;
            cur_trit = next_trit;
        }

        // Output projection for each position
        for (0..seq_len) |pos| {
            const f_off = pos * EMBED_DIM;
            const l_off = pos * VOCAB_SIZE;
            ternaryMatvec(
                cur_float[f_off .. f_off + EMBED_DIM],
                self.output_weights,
                all_logits[l_off .. l_off + VOCAB_SIZE],
                EMBED_DIM,
                VOCAB_SIZE,
            );
            for (0..VOCAB_SIZE) |j| {
                all_logits[l_off + j] += self.output_bias[j];
            }
        }
    }

    /// Generate next token (greedy)
    pub fn generate(self: *Self, tokens: []const u16) u16 {
        var logits: [VOCAB_SIZE]f32 = undefined;
        self.forward(tokens, &logits);

        // Argmax
        var best_idx: usize = 0;
        var best_val: f32 = logits[0];
        for (1..VOCAB_SIZE) |i| {
            if (logits[i] > best_val) {
                best_val = logits[i];
                best_idx = i;
            }
        }
        return @intCast(best_idx);
    }

    /// Generate a sequence of tokens
    pub fn generateSequence(
        self: *Self,
        prompt: []const u16,
        output: []u16,
        max_len: usize,
    ) usize {
        const prompt_len = @min(prompt.len, CONTEXT_LEN - 1);
        @memcpy(output[0..prompt_len], prompt[0..prompt_len]);
        var len = prompt_len;

        while (len < max_len and len < CONTEXT_LEN) {
            const next = self.generate(output[0..len]);
            output[len] = next;
            len += 1;
            if (next == tokenizer_mod.EOS_TOKEN) break;
        }

        return len;
    }

    /// Get consciousness statistics
    pub fn consciousnessStats(self: *const Self) struct { ratio: f64, per_block: [NUM_BLOCKS]f64 } {
        var total_ratio: f64 = 0.0;
        var per_block: [NUM_BLOCKS]f64 = undefined;
        for (0..NUM_BLOCKS) |i| {
            per_block[i] = self.blocks[i].gate.consciousnessRatio();
            total_ratio += per_block[i];
        }
        return .{
            .ratio = total_ratio / @as(f64, NUM_BLOCKS),
            .per_block = per_block,
        };
    }

    /// Re-quantize all ternary weights from shadow floats
    pub fn requantize(self: *Self) void {
        for (&self.blocks) |*block| {
            block.tnn.requantize();
        }
        quantizeAbsMean(self.output_shadow, self.output_weights);
    }

    /// Total parameter count
    pub fn paramCount(self: *const Self) usize {
        _ = self;
        const cfg = Config{};
        return cfg.paramCount();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn ternaryMatvec(input: []const f32, weights: []const i8, output: []f32, in_dim: usize, out_dim: usize) void {
    for (0..out_dim) |j| {
        var sum: f32 = 0.0;
        for (0..in_dim) |i| {
            const w = weights[i * out_dim + j];
            if (w == 1) {
                sum += input[i];
            } else if (w == -1) {
                sum -= input[i];
            }
        }
        output[j] = sum;
    }
}

fn quantizeAbsMean(float_weights: []const f32, ternary_weights: []i8) void {
    var sum: f64 = 0.0;
    for (float_weights) |w| {
        sum += @abs(@as(f64, w));
    }
    const mean_abs = sum / @as(f64, @floatFromInt(float_weights.len));
    const scale: f32 = if (mean_abs > 1e-6) @floatCast(mean_abs) else 1.0;

    for (float_weights, 0..) |w, i| {
        const scaled = w / scale;
        if (scaled > 0.5) {
            ternary_weights[i] = 1;
        } else if (scaled < -0.5) {
            ternary_weights[i] = -1;
        } else {
            ternary_weights[i] = 0;
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SOFTMAX (for loss computation)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn softmax(logits: []const f32, probs: []f32) void {
    // Find max for numerical stability
    var max_val: f32 = logits[0];
    for (logits[1..]) |v| {
        if (v > max_val) max_val = v;
    }

    var sum: f64 = 0.0;
    for (logits, 0..) |v, i| {
        const e = @exp(@as(f64, v - max_val));
        probs[i] = @floatCast(e);
        sum += e;
    }

    const inv_sum: f32 = @floatCast(1.0 / sum);
    for (probs) |*p| {
        p.* *= inv_sum;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "hslm init/deinit" {
    const allocator = std.testing.allocator;
    var model = try HSLM.init(allocator);
    defer model.deinit();

    try std.testing.expect(model.config.vocab_size == VOCAB_SIZE);
    try std.testing.expect(model.config.num_blocks == NUM_BLOCKS);
}

test "hslm forward" {
    const allocator = std.testing.allocator;
    var model = try HSLM.init(allocator);
    defer model.deinit();

    const tokens = [_]u16{ 1, 42, 100, 200 }; // BOS + 3 tokens
    var logits: [VOCAB_SIZE]f32 = undefined;
    model.forward(&tokens, &logits);

    // Logits should be finite
    for (logits) |v| {
        try std.testing.expect(!std.math.isNan(v));
        try std.testing.expect(!std.math.isInf(v));
    }
}

test "hslm generate" {
    const allocator = std.testing.allocator;
    var model = try HSLM.init(allocator);
    defer model.deinit();

    const prompt = [_]u16{ 1, 42, 100 };
    const next = model.generate(&prompt);
    try std.testing.expect(next < VOCAB_SIZE);
}

test "softmax sums to 1" {
    const logits = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    var probs: [5]f32 = undefined;
    softmax(&logits, &probs);

    var sum: f64 = 0.0;
    for (probs) |p| {
        try std.testing.expect(p >= 0.0);
        try std.testing.expect(p <= 1.0);
        sum += p;
    }
    try std.testing.expectApproxEqAbs(1.0, @as(f32, @floatCast(sum)), 1e-5);
}

test "consciousness stats" {
    const allocator = std.testing.allocator;
    var model = try HSLM.init(allocator);
    defer model.deinit();

    // Run a forward pass to get stats
    const tokens = [_]u16{ 1, 42, 100 };
    var logits: [VOCAB_SIZE]f32 = undefined;
    model.forward(&tokens, &logits);

    const stats = model.consciousnessStats();
    try std.testing.expect(stats.ratio >= 0.0);
    try std.testing.expect(stats.ratio <= 1.0);
}
