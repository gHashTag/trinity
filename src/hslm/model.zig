// @origin(spec:model.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// HSLM — Full Model Assembly
// Embedding → 3× TrinityBlock → Output Projection
// ~1.24M ternary parameters, ~248KB

const std = @import("std");
const constants = @import("constants.zig");
const tokenizer_mod = @import("tokenizer.zig");
const embedding_mod = @import("embedding.zig");
const trinity_block = @import("trinity_block.zig");
const autograd = @import("autograd.zig");
const simd_ops = @import("simd_ops.zig");
const sparse_ternary = @import("sparse_ternary.zig");
const ste_mod = @import("ste.zig");
const trit_encoding = @import("trit_encoding.zig");
const ternary_position = @import("ternary_position.zig");
const ternary_activations = @import("ternary_activations.zig");
const ternary_inference = @import("ternary_inference.zig");

const VOCAB_SIZE = constants.VOCAB_SIZE;
const EMBED_DIM = constants.EMBED_DIM;
const VSA_DIM = constants.VSA_DIM;
const CONTEXT_LEN = constants.CONTEXT_LEN;
const Config = constants.Config;

// Sacred logit scale: 1/d^γ where γ = φ⁻³ ≈ 0.236 (optimal for ternary weights)
// Standard 1/√d assumes Gaussian weights; ternary {-1,0,+1} has different variance
const SACRED_LOGIT_SCALE: f32 = @floatCast(1.0 / std.math.pow(f64, @as(f64, EMBED_DIM), constants.SACRED_GAMMA));

// ═══════════════════════════════════════════════════════════════════════════════
// HSLM MODEL
// ═══════════════════════════════════════════════════════════════════════════════

pub const HSLM = struct {
    config: Config,
    emb: embedding_mod.Embedding,
    blocks: []trinity_block.TrinityBlock,
    // Output projection: EMBED_DIM → VOCAB_SIZE (ternary weights)
    output_weights: []i8,
    output_bias: []f32,
    output_shadow: []f32,
    // Gradient buffers for output projection
    grad_output_shadow: []f32,
    grad_output_bias: []f32,
    // Training cache
    cache_pre_rms: [EMBED_DIM]f32 = [_]f32{0.0} ** EMBED_DIM,
    cache_rms_scale: f32 = 1.0,
    is_worker: bool = false,
    // Dropout (applied in forwardTrain only)
    dropout_rate: f32 = 0.0,
    dropout_prng: std.Random.DefaultPrng = std.Random.DefaultPrng.init(0x1234_5678),
    // Optional ternary architecture components
    use_ternary_inference: bool = false,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        return initWithSeed(allocator, 0);
    }

    pub fn initWithSeed(allocator: std.mem.Allocator, seed_offset: u64) !Self {
        return initWithConfigAndSeed(allocator, Config{}, seed_offset);
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, config: Config) !Self {
        return initWithConfigAndSeed(allocator, config, 0);
    }

    pub fn initWithConfigAndSeed(allocator: std.mem.Allocator, config: Config, seed_offset: u64) !Self {
        return initFull(allocator, config, seed_offset, false);
    }

    /// Initialize with all weights zeroed. Reduces seed variance in ternary models
    /// by starting from a deterministic state. All shadow weights = 0, all ternary = 0.
    /// Symmetry is broken by the optimizer (AdamW/LAMB momentum) and input data order.
    pub fn initZero(allocator: std.mem.Allocator) !Self {
        return initFull(allocator, Config{}, 0, true);
    }

    pub fn initZeroWithConfig(allocator: std.mem.Allocator, config: Config) !Self {
        return initFull(allocator, config, 0, true);
    }

    fn initFull(allocator: std.mem.Allocator, config: Config, seed_offset: u64, zero_init: bool) !Self {
        const emb = try embedding_mod.Embedding.init(allocator);

        const num_blocks = config.num_blocks;
        const blocks = try allocator.alloc(trinity_block.TrinityBlock, num_blocks);
        errdefer allocator.free(blocks);
        var blocks_inited: usize = 0;
        errdefer for (blocks[0..blocks_inited]) |*b| b.deinit();
        for (0..num_blocks) |i| {
            blocks[i] = try trinity_block.TrinityBlock.init(allocator);
            blocks_inited += 1;
        }

        const out_w = try allocator.alloc(i8, EMBED_DIM * VOCAB_SIZE);
        const out_b = try allocator.alloc(f32, VOCAB_SIZE);
        const out_s = try allocator.alloc(f32, EMBED_DIM * VOCAB_SIZE);

        // Gradient buffers for output
        const g_os = try allocator.alloc(f32, EMBED_DIM * VOCAB_SIZE);
        const g_ob = try allocator.alloc(f32, VOCAB_SIZE);
        @memset(g_os, 0.0);
        @memset(g_ob, 0.0);

        if (zero_init) {
            // Zero initialization: all shadows = 0, all ternary = 0, all biases = 0
            // Symmetry broken by optimizer momentum and data order
            @memset(out_s, 0.0);
            @memset(out_w, 0);
            @memset(out_b, 0.0);

            // Zero all block weights too
            for (blocks) |*block| {
                @memset(block.tnn.shadow_up, 0.0);
                @memset(block.tnn.shadow_down, 0.0);
                @memset(block.tnn.bias_up, 0.0);
                @memset(block.tnn.bias_down, 0.0);
                block.tnn.requantize();
                @memset(block.sacred_attn.shadow_q, 0.0);
                @memset(block.sacred_attn.shadow_k, 0.0);
                @memset(block.sacred_attn.shadow_v, 0.0);
                @memset(block.sacred_attn.shadow_o, 0.0);
                block.sacred_attn.requantize();
            }
        } else {
            // Standard Xavier init (seed_offset XORed for reproducibility experiments)
            const scale = 1.0 / @sqrt(@as(f32, @floatFromInt(EMBED_DIM)));
            var prng = std.Random.DefaultPrng.init(0xDEAD_CAFE ^ seed_offset);
            const rng = prng.random();
            for (0..EMBED_DIM * VOCAB_SIZE) |i| {
                out_s[i] = (rng.float(f32) * 2.0 - 1.0) * scale;
            }
            quantizeAbsMean(out_s, out_w);
            @memset(out_b, 0.0);
        }

        return Self{
            .config = config,
            .emb = emb,
            .blocks = blocks,
            .output_weights = out_w,
            .output_bias = out_b,
            .output_shadow = out_s,
            .grad_output_shadow = g_os,
            .grad_output_bias = g_ob,
            .allocator = allocator,
        };
    }

    /// Worker-light init: allocates weights + grads + caches, skips shadow weights.
    /// Workers process forward/backward but never requantize or run optimizer.
    /// Saves ~7MB per worker (no shadow weights for TNN, attention, or output projection).
    pub fn initWorker(allocator: std.mem.Allocator) !Self {
        return initWorkerWithConfig(allocator, Config{});
    }

    pub fn initWorkerWithConfig(allocator: std.mem.Allocator, config: Config) !Self {
        const emb = try embedding_mod.Embedding.init(allocator);

        const num_blocks = config.num_blocks;
        const blocks = try allocator.alloc(trinity_block.TrinityBlock, num_blocks);
        errdefer allocator.free(blocks);
        var blocks_inited: usize = 0;
        errdefer for (blocks[0..blocks_inited]) |*b| b.deinit();
        for (0..num_blocks) |i| {
            blocks[i] = try trinity_block.TrinityBlock.initWorker(allocator);
            blocks_inited += 1;
        }

        const out_w = try allocator.alloc(i8, EMBED_DIM * VOCAB_SIZE);
        const out_b = try allocator.alloc(f32, VOCAB_SIZE);
        @memset(out_w, 0);
        @memset(out_b, 0.0);

        // Gradient buffers for output (own copy per worker)
        const g_os = try allocator.alloc(f32, EMBED_DIM * VOCAB_SIZE);
        const g_ob = try allocator.alloc(f32, VOCAB_SIZE);
        @memset(g_os, 0.0);
        @memset(g_ob, 0.0);

        return Self{
            .config = config,
            .emb = emb,
            .blocks = blocks,
            .output_weights = out_w,
            .output_bias = out_b,
            .output_shadow = &.{},
            .grad_output_shadow = g_os,
            .grad_output_bias = g_ob,
            .is_worker = true,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.emb.deinit();
        for (self.blocks) |*b| b.deinit();
        self.allocator.free(self.blocks);
        self.allocator.free(self.output_weights);
        self.allocator.free(self.output_bias);
        if (!self.is_worker) {
            self.allocator.free(self.output_shadow);
        }
        self.allocator.free(self.grad_output_shadow);
        self.allocator.free(self.grad_output_bias);
    }

    /// Forward pass for a single sequence
    /// Returns logits for the last position (VOCAB_SIZE)
    /// When use_ternary_inference is true, uses full ternary pipeline
    /// (trit encoding → ternary PE → ternary activations → ternary attention).
    pub fn forward(self: *Self, tokens: []const u16, logits: []f32) void {
        // Ternary inference mode is a flag for future integration.
        // Full ternary pipeline (ternary_inference.zig) operates at the module
        // level and is tested independently. Integration into the block-level
        // forward pass requires matching the TrinityBlock interface.
        _ = self.use_ternary_inference;

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

        for (self.blocks) |*block| {
            block.sacred_attn.resetCache();
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

        // Step 3: Output projection from last position (with RMS norm + logit scaling)
        const last_off = (seq_len - 1) * EMBED_DIM;
        const last_hidden = cur_float[last_off .. last_off + EMBED_DIM];

        // RMS normalization (same as forwardTrain)
        var rms_sq: f64 = 0.0;
        for (0..EMBED_DIM) |ii| {
            rms_sq += @as(f64, last_hidden[ii]) * @as(f64, last_hidden[ii]);
        }
        const rms: f32 = @floatCast(@sqrt(rms_sq / @as(f64, EMBED_DIM) + 1e-6));
        var norm_hidden: [EMBED_DIM]f32 = undefined;
        for (0..EMBED_DIM) |ii| {
            norm_hidden[ii] = last_hidden[ii] / rms;
        }

        sparse_ternary.branchlessMatvec(&norm_hidden, self.output_weights, logits, EMBED_DIM, VOCAB_SIZE);
        for (0..VOCAB_SIZE) |j| {
            logits[j] = logits[j] * SACRED_LOGIT_SCALE + self.output_bias[j];
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

        for (self.blocks) |*block| {
            block.sacred_attn.resetCache();
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

        // Output projection for each position (with RMS norm + sacred scaling)
        for (0..seq_len) |pos| {
            const f_off = pos * EMBED_DIM;
            const l_off = pos * VOCAB_SIZE;

            // RMS normalization per position
            var rms_sq: f64 = 0.0;
            for (0..EMBED_DIM) |ii| {
                rms_sq += @as(f64, cur_float[f_off + ii]) * @as(f64, cur_float[f_off + ii]);
            }
            const rms: f32 = @floatCast(@sqrt(rms_sq / @as(f64, EMBED_DIM) + 1e-6));
            var norm_hidden: [EMBED_DIM]f32 = undefined;
            for (0..EMBED_DIM) |ii| {
                norm_hidden[ii] = cur_float[f_off + ii] / rms;
            }

            sparse_ternary.branchlessMatvec(
                &norm_hidden,
                self.output_weights,
                all_logits[l_off .. l_off + VOCAB_SIZE],
                EMBED_DIM,
                VOCAB_SIZE,
            );
            for (0..VOCAB_SIZE) |j| {
                all_logits[l_off + j] = all_logits[l_off + j] * SACRED_LOGIT_SCALE + self.output_bias[j];
            }
        }
    }

    /// Forward pass returning hidden states (before output projection) for all positions.
    /// Used by T-JEPA to extract representations.
    pub fn forwardHidden(self: *Self, tokens: []const u16, hidden_out: []f32) void {
        const seq_len = @min(tokens.len, CONTEXT_LEN);

        var float_seq: [CONTEXT_LEN * EMBED_DIM]f32 = undefined;
        var trit_seq: [CONTEXT_LEN * VSA_DIM]i8 = undefined;
        self.emb.embedSequence(tokens[0..seq_len], &float_seq, &trit_seq);

        var cur_float: [CONTEXT_LEN * EMBED_DIM]f32 = float_seq;
        var cur_trit: [CONTEXT_LEN * VSA_DIM]i8 = trit_seq;
        var next_float: [CONTEXT_LEN * EMBED_DIM]f32 = undefined;
        var next_trit: [CONTEXT_LEN * VSA_DIM]i8 = undefined;

        for (self.blocks) |*block| {
            block.sacred_attn.resetCache();
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

        // Copy hidden states (no output projection)
        @memcpy(hidden_out[0 .. seq_len * EMBED_DIM], cur_float[0 .. seq_len * EMBED_DIM]);
    }

    /// Backward pass through blocks only (no output projection).
    /// Used by T-JEPA where gradient comes from representation loss, not logits.
    pub fn backwardHidden(self: *Self, grad_hidden: []const f32) void {
        var grad_current: [EMBED_DIM]f32 = undefined;
        @memcpy(&grad_current, grad_hidden[0..EMBED_DIM]);
        var grad_next: [EMBED_DIM]f32 = undefined;

        var block_idx: usize = self.blocks.len;
        while (block_idx > 0) {
            block_idx -= 1;
            self.blocks[block_idx].tnn.backward(&grad_current, &grad_next);
            var grad_attn_input: [EMBED_DIM]f32 = undefined;
            self.blocks[block_idx].sacred_attn.backward(&grad_next, &grad_attn_input);
            grad_current = grad_attn_input;
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

    /// Sampling parameters for text generation
    pub const SampleParams = struct {
        temperature: f32 = 0.8,
        top_k: usize = 20,
        rep_penalty: f32 = 1.2,
    };

    /// Generate next token with sampling: repetition penalty → temperature → top-k → weighted random
    pub fn generateSampled(self: *Self, tokens: []const u16, params: SampleParams, rng: std.Random) u16 {
        var logits: [VOCAB_SIZE]f32 = undefined;
        self.forward(tokens, &logits);

        // 1. Repetition penalty: penalize recent tokens
        const window = @min(tokens.len, 32);
        for (tokens[tokens.len - window ..]) |tok| {
            if (tok < VOCAB_SIZE) {
                if (logits[tok] > 0) {
                    logits[tok] /= params.rep_penalty;
                } else {
                    logits[tok] *= params.rep_penalty;
                }
            }
        }

        // 2. Temperature scaling
        if (params.temperature > 0) {
            const inv_t = 1.0 / params.temperature;
            for (&logits) |*l| l.* *= inv_t;
        }

        // 3. Softmax → probabilities
        var probs: [VOCAB_SIZE]f32 = undefined;
        softmax(&logits, &probs);

        // 4. Top-k: find k-th largest, zero everything below
        if (params.top_k > 0 and params.top_k < VOCAB_SIZE) {
            // Find top-k threshold via partial sort (selection)
            var top_vals: [64]f32 = [_]f32{0.0} ** 64; // max top_k = 64
            const k = @min(params.top_k, 64);
            for (0..k) |i| top_vals[i] = -std.math.inf(f32);

            for (probs) |p| {
                if (p > top_vals[k - 1]) {
                    top_vals[k - 1] = p;
                    // Bubble up
                    var j: usize = k - 1;
                    while (j > 0 and top_vals[j] > top_vals[j - 1]) : (j -= 1) {
                        const tmp = top_vals[j];
                        top_vals[j] = top_vals[j - 1];
                        top_vals[j - 1] = tmp;
                    }
                }
            }
            const threshold = top_vals[k - 1];

            // Zero out below threshold, renormalize
            var sum: f64 = 0.0;
            for (&probs) |*p| {
                if (p.* < threshold) {
                    p.* = 0.0;
                } else {
                    sum += @as(f64, p.*);
                }
            }
            if (sum > 0) {
                const inv: f32 = @floatCast(1.0 / sum);
                for (&probs) |*p| p.* *= inv;
            }
        }

        // 5. Weighted random sample
        const r = rng.float(f32);
        var cumsum: f32 = 0.0;
        for (probs, 0..) |p, i| {
            cumsum += p;
            if (r < cumsum) return @intCast(i);
        }
        return @intCast(VOCAB_SIZE - 1); // fallback
    }

    /// Generate a sequence of tokens (argmax, deterministic)
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

    /// Get consciousness statistics (average ratio across all blocks)
    pub fn consciousnessStats(self: *const Self) struct { ratio: f64 } {
        var total_ratio: f64 = 0.0;
        for (self.blocks) |*block| {
            total_ratio += block.gate.consciousnessRatio();
        }
        return .{
            .ratio = if (self.blocks.len > 0) total_ratio / @as(f64, @floatFromInt(self.blocks.len)) else 0.0,
        };
    }

    /// Re-quantize all ternary weights from shadow floats
    pub fn requantize(self: *Self) void {
        for (self.blocks) |*block| {
            block.tnn.requantize();
            block.sacred_attn.requantize();
        }
        quantizeAbsMean(self.output_shadow, self.output_weights);
    }

    /// Re-quantize using STE mode (TWN/vanilla/progressive)
    pub fn requantizeSte(self: *Self, config: ste_mod.SteConfig, step: u32) void {
        for (self.blocks) |*block| {
            block.tnn.requantizeSte(config, step);
            block.sacred_attn.requantizeSte(config, step);
        }
        _ = ste_mod.quantizeForMode(self.output_shadow, self.output_weights, config, step);
    }

    /// Forward pass with activation caching for training
    pub fn forwardTrain(self: *Self, tokens: []const u16, logits: []f32) void {
        const seq_len = @min(tokens.len, CONTEXT_LEN);

        // Step 1: Embed all tokens
        var float_seq: [CONTEXT_LEN * EMBED_DIM]f32 = undefined;
        var trit_seq: [CONTEXT_LEN * VSA_DIM]i8 = undefined;
        self.emb.embedSequence(tokens[0..seq_len], &float_seq, &trit_seq);

        // Step 2: Process through Trinity Blocks
        var cur_float: [CONTEXT_LEN * EMBED_DIM]f32 = float_seq;
        var cur_trit: [CONTEXT_LEN * VSA_DIM]i8 = trit_seq;
        var next_float: [CONTEXT_LEN * EMBED_DIM]f32 = undefined;
        var next_trit: [CONTEXT_LEN * VSA_DIM]i8 = undefined;

        const last_pos = seq_len - 1;

        for (self.blocks) |*block| {
            block.sacred_attn.resetCache();

            for (0..seq_len) |pos| {
                const f_off = pos * EMBED_DIM;
                const t_off = pos * VSA_DIM;

                // Sacred Attention (accumulates KV cache internally)
                var attn_out: [EMBED_DIM]f32 = undefined;
                if (pos == last_pos) {
                    block.sacred_attn.processPositionCached(
                        cur_float[f_off .. f_off + EMBED_DIM],
                        pos,
                        &attn_out,
                    );
                } else {
                    block.sacred_attn.processPosition(
                        cur_float[f_off .. f_off + EMBED_DIM],
                        pos,
                        &attn_out,
                    );
                }

                // TNN Dense FFN (with caching for last pos)
                if (pos == last_pos) {
                    block.tnn.forwardCached(
                        &attn_out,
                        next_float[f_off .. f_off + EMBED_DIM],
                    );
                } else {
                    block.tnn.forward(
                        &attn_out,
                        next_float[f_off .. f_off + EMBED_DIM],
                    );
                }

                // VSA attention + consciousness gate
                var context: [VSA_DIM]i8 = undefined;
                const max_sim = block.attn.forwardCausal(pos, cur_trit[0 .. (pos + 1) * VSA_DIM], &context);

                if (block.gate.isConscious(max_sim)) {
                    const pos_offset = pos * VSA_DIM;
                    const current_trit = cur_trit[pos_offset .. pos_offset + VSA_DIM];
                    var reasoned: [VSA_DIM]i8 = undefined;
                    block.reason.forward(current_trit, &context, &reasoned);

                    var vsa_float: [EMBED_DIM]f32 = undefined;
                    trinity_block.projectVsaToEmbed(&reasoned, &vsa_float);
                    for (0..EMBED_DIM) |ii| {
                        next_float[f_off + ii] += vsa_float[ii] * 0.1;
                    }
                    @memcpy(next_trit[t_off .. t_off + VSA_DIM], &reasoned);
                } else {
                    @memcpy(next_trit[t_off .. t_off + VSA_DIM], &context);
                }
            }
            cur_float = next_float;
            cur_trit = next_trit;
        }

        // Step 3: Fused dropout + RMS norm (single pass over memory)
        const last_off = last_pos * EMBED_DIM;
        const last_hidden = cur_float[last_off .. last_off + EMBED_DIM];

        // Fused: dropout → cache → RMS accumulate in one pass
        var rms_sq: f64 = 0.0;
        if (self.dropout_rate > 0.0) {
            const inv_keep = 1.0 / (1.0 - self.dropout_rate);
            const rng = self.dropout_prng.random();
            for (0..EMBED_DIM) |ii| {
                const val = if (rng.float(f32) < self.dropout_rate) @as(f32, 0.0) else last_hidden[ii] * inv_keep;
                last_hidden[ii] = val;
                self.cache_pre_rms[ii] = val;
                rms_sq += @as(f64, val) * @as(f64, val);
            }
        } else {
            for (0..EMBED_DIM) |ii| {
                const val = last_hidden[ii];
                self.cache_pre_rms[ii] = val;
                rms_sq += @as(f64, val) * @as(f64, val);
            }
        }
        const rms: f32 = @floatCast(@sqrt(rms_sq / @as(f64, EMBED_DIM) + 1e-6));
        self.cache_rms_scale = rms;

        const inv_rms = 1.0 / rms;
        var normalized: [EMBED_DIM]f32 = undefined;
        for (0..EMBED_DIM) |ii| {
            normalized[ii] = self.cache_pre_rms[ii] * inv_rms;
        }

        // Output projection from normalized (sacred scale: 1/d^γ, γ = φ⁻³)
        sparse_ternary.branchlessMatvec(&normalized, self.output_weights, logits, EMBED_DIM, VOCAB_SIZE);
        for (0..VOCAB_SIZE) |j| {
            logits[j] = logits[j] * SACRED_LOGIT_SCALE + self.output_bias[j];
        }
    }

    /// Backward pass through output projection → RMS norm → blocks
    pub fn backward(self: *Self, grad_logits: []const f32) void {
        // Step 1: Output projection backward (sacred scale: 1/d^γ)
        // ∂L/∂hidden_rms[i] = sum_j(grad_logits[j] * scale * W[i*VOCAB+j]) using ternary STE
        var grad_hidden_rms: [EMBED_DIM]f32 = undefined;
        sparse_ternary.branchlessVecmat(grad_logits, self.output_weights, &grad_hidden_rms, EMBED_DIM, VOCAB_SIZE);
        for (0..EMBED_DIM) |i| {
            grad_hidden_rms[i] *= SACRED_LOGIT_SCALE;
        }

        // Output weight grad: ∂L/∂W[i*VOCAB+j] += grad_logits[j] * scale * normalized[i]
        var normalized: [EMBED_DIM]f32 = undefined;
        for (0..EMBED_DIM) |i| {
            normalized[i] = self.cache_pre_rms[i] / self.cache_rms_scale;
        }
        // Scale grad_logits for weight grad accumulation
        var scaled_grad: [VOCAB_SIZE]f32 = undefined;
        for (0..VOCAB_SIZE) |j| {
            scaled_grad[j] = grad_logits[j] * SACRED_LOGIT_SCALE;
        }
        simd_ops.outerProductAccumSimd(self.grad_output_shadow, &scaled_grad, &normalized, EMBED_DIM, VOCAB_SIZE);
        // Output bias grad (no scale — bias is added after scaling)
        for (0..VOCAB_SIZE) |j| {
            self.grad_output_bias[j] += grad_logits[j];
        }

        // Step 2: RMS norm backward
        var grad_pre_rms: [EMBED_DIM]f32 = undefined;
        autograd.rmsNormBackward(&grad_hidden_rms, &normalized, self.cache_rms_scale, &grad_pre_rms);

        // Step 3: Backward through blocks in reverse (last position only)
        var grad_current: [EMBED_DIM]f32 = grad_pre_rms;
        var grad_next: [EMBED_DIM]f32 = undefined;

        var block_idx: usize = self.blocks.len;
        while (block_idx > 0) {
            block_idx -= 1;
            // TNN Dense FFN backward
            self.blocks[block_idx].tnn.backward(&grad_current, &grad_next);
            // Sacred Attention backward
            var grad_attn_input: [EMBED_DIM]f32 = undefined;
            self.blocks[block_idx].sacred_attn.backward(&grad_next, &grad_attn_input);
            grad_current = grad_attn_input;
        }
        // Stop at embedding (don't backprop into embedding table)
    }

    /// Zero all gradient buffers
    pub fn zeroGrad(self: *Self) void {
        @memset(self.grad_output_shadow, 0.0);
        @memset(self.grad_output_bias, 0.0);
        for (self.blocks) |*block| {
            block.tnn.zeroGrad();
            block.sacred_attn.zeroGrad();
        }
    }

    /// Total parameter count
    pub fn paramCount(self: *const Self) usize {
        return self.config.paramCount();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

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
    try std.testing.expect(model.config.num_blocks == constants.DEFAULT_BLOCKS);
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

test "forwardTrain produces finite logits" {
    const allocator = std.testing.allocator;
    var model = try HSLM.init(allocator);
    defer model.deinit();

    const tokens = [_]u16{ 1, 42, 100, 200 };
    var logits: [VOCAB_SIZE]f32 = undefined;
    model.forwardTrain(&tokens, &logits);

    for (logits) |v| {
        try std.testing.expect(!std.math.isNan(v));
        try std.testing.expect(!std.math.isInf(v));
    }
}

test "backward produces gradients" {
    const allocator = std.testing.allocator;
    var model = try HSLM.init(allocator);
    defer model.deinit();

    const tokens = [_]u16{ 1, 42, 100, 200 };
    var logits: [VOCAB_SIZE]f32 = undefined;
    model.forwardTrain(&tokens, &logits);

    // Fake gradient
    var grad_logits: [VOCAB_SIZE]f32 = undefined;
    for (&grad_logits) |*v| v.* = 0.001;

    model.zeroGrad();
    model.backward(&grad_logits);

    // Output weight grads should be non-zero
    var any_nonzero = false;
    for (model.grad_output_shadow) |g| {
        if (g != 0.0) {
            any_nonzero = true;
            break;
        }
    }
    try std.testing.expect(any_nonzero);

    // Block gradients should also have non-zero values
    any_nonzero = false;
    for (model.blocks[0].tnn.grad_shadow_up) |g| {
        if (g != 0.0) {
            any_nonzero = true;
            break;
        }
    }
    try std.testing.expect(any_nonzero);
}

test "forwardTrain vs forward loss comparison" {
    const allocator = std.testing.allocator;
    var model = try HSLM.init(allocator);
    defer model.deinit();

    const tokens = [_]u16{ 1, 42, 100, 200, 50, 75, 10, 20, 30 };
    const target = [_]u16{42};

    // forward() loss
    var logits_f: [VOCAB_SIZE]f32 = undefined;
    model.forward(&tokens, &logits_f);
    var tf = try autograd.Tensor.init(allocator, 1, VOCAB_SIZE, false);
    defer tf.deinit();
    @memcpy(tf.data, &logits_f);
    const loss_f = autograd.forwardCrossEntropy(&tf, &target);

    // forwardTrain() loss
    var logits_t: [VOCAB_SIZE]f32 = undefined;
    model.forwardTrain(&tokens, &logits_t);
    var tt = try autograd.Tensor.init(allocator, 1, VOCAB_SIZE, false);
    defer tt.deinit();
    @memcpy(tt.data, &logits_t);
    const loss_t = autograd.forwardCrossEntropy(&tt, &target);

    // Both should produce the same logits (both use RMS norm + logit scaling now)
    for (0..VOCAB_SIZE) |i| {
        try std.testing.expectApproxEqAbs(logits_f[i], logits_t[i], 1e-3);
    }

    // Loss should be finite and reasonable
    try std.testing.expect(!std.math.isNan(loss_f));
    try std.testing.expect(!std.math.isNan(loss_t));
    try std.testing.expect(!std.math.isInf(loss_f));
    try std.testing.expect(!std.math.isInf(loss_t));
    try std.testing.expect(loss_f > 0.0);
    try std.testing.expect(loss_t > 0.0);
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
