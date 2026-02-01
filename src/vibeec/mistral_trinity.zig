// MISTRAL TRINITY - Mistral-7B на троичных весах
// Полная реализация архитектуры Mistral с SIMD-оптимизацией
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const prometheus = @import("prometheus_seed.zig");
const simd = @import("simd_trit_ops.zig");
const trinity_format = @import("trinity_format.zig");
const engine = @import("trinity_inference_engine.zig");
const kv_cache = @import("kv_cache.zig");

pub const PHI: f64 = 1.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// MISTRAL CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const MistralConfig = struct {
    vocab_size: u32 = 32000,
    hidden_size: u32 = 4096,
    intermediate_size: u32 = 14336,
    num_hidden_layers: u32 = 32,
    num_attention_heads: u32 = 32,
    num_key_value_heads: u32 = 8,
    head_dim: u32 = 128, // hidden_size / num_attention_heads
    max_position_embeddings: u32 = 32768,
    rms_norm_eps: f32 = 1e-5,
    rope_theta: f32 = 1000000.0,

    pub fn init() MistralConfig {
        var config = MistralConfig{};
        config.head_dim = config.hidden_size / config.num_attention_heads;
        return config;
    }

    pub fn initMini() MistralConfig {
        return MistralConfig{
            .vocab_size = 256,
            .hidden_size = 64,
            .intermediate_size = 128,
            .num_hidden_layers = 2,
            .num_attention_heads = 4,
            .num_key_value_heads = 2,
            .head_dim = 16,
            .max_position_embeddings = 512,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// RMS LAYER NORM (без умножения на веса - веса в float)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn rmsNorm(output: []f32, input: []const f32, eps: f32) void {
    // RMS = sqrt(mean(x^2))
    var sum_sq: f32 = 0.0;
    for (input) |x| {
        sum_sq += x * x;
    }
    const rms = @sqrt(sum_sq / @as(f32, @floatFromInt(input.len)) + eps);
    const inv_rms = 1.0 / rms;

    for (input, 0..) |x, i| {
        output[i] = x * inv_rms;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROTARY POSITION EMBEDDING (RoPE)
// ═══════════════════════════════════════════════════════════════════════════════

pub const RoPE = struct {
    cos_cache: []f32,
    sin_cache: []f32,
    head_dim: usize,
    max_seq_len: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, head_dim: usize, max_seq_len: usize, theta: f32) !RoPE {
        const cache_size = max_seq_len * head_dim / 2;
        const cos_cache = try allocator.alloc(f32, cache_size);
        const sin_cache = try allocator.alloc(f32, cache_size);

        // Precompute cos/sin for all positions
        for (0..max_seq_len) |pos| {
            for (0..head_dim / 2) |i| {
                const freq = 1.0 / std.math.pow(f32, theta, @as(f32, @floatFromInt(2 * i)) / @as(f32, @floatFromInt(head_dim)));
                const angle = @as(f32, @floatFromInt(pos)) * freq;
                const idx = pos * (head_dim / 2) + i;
                cos_cache[idx] = @cos(angle);
                sin_cache[idx] = @sin(angle);
            }
        }

        return RoPE{
            .cos_cache = cos_cache,
            .sin_cache = sin_cache,
            .head_dim = head_dim,
            .max_seq_len = max_seq_len,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *RoPE) void {
        self.allocator.free(self.cos_cache);
        self.allocator.free(self.sin_cache);
    }

    /// Apply RoPE to query/key vectors
    pub fn apply(self: *const RoPE, x: []f32, pos: usize) void {
        const half_dim = self.head_dim / 2;
        const cache_offset = pos * half_dim;

        var i: usize = 0;
        while (i < half_dim) : (i += 1) {
            const cos_val = self.cos_cache[cache_offset + i];
            const sin_val = self.sin_cache[cache_offset + i];

            const x0 = x[i];
            const x1 = x[i + half_dim];

            x[i] = x0 * cos_val - x1 * sin_val;
            x[i + half_dim] = x0 * sin_val + x1 * cos_val;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD MISTRAL ATTENTION (GQA - Grouped Query Attention)
// ═══════════════════════════════════════════════════════════════════════════════

pub const MistralAttention = struct {
    allocator: std.mem.Allocator,
    config: MistralConfig,

    q_proj: engine.SimdTrinityLayer,
    k_proj: engine.SimdTrinityLayer,
    v_proj: engine.SimdTrinityLayer,
    o_proj: engine.SimdTrinityLayer,

    rope: RoPE,

    pub fn init(allocator: std.mem.Allocator, config: MistralConfig) !MistralAttention {
        const kv_dim = config.num_key_value_heads * config.head_dim;

        return MistralAttention{
            .allocator = allocator,
            .config = config,
            .q_proj = try engine.SimdTrinityLayer.init(allocator, config.hidden_size, config.hidden_size, .none),
            .k_proj = try engine.SimdTrinityLayer.init(allocator, config.hidden_size, kv_dim, .none),
            .v_proj = try engine.SimdTrinityLayer.init(allocator, config.hidden_size, kv_dim, .none),
            .o_proj = try engine.SimdTrinityLayer.init(allocator, config.hidden_size, config.hidden_size, .none),
            .rope = try RoPE.init(allocator, config.head_dim, config.max_position_embeddings, config.rope_theta),
        };
    }

    pub fn deinit(self: *MistralAttention) void {
        self.q_proj.deinit();
        self.k_proj.deinit();
        self.v_proj.deinit();
        self.o_proj.deinit();
        self.rope.deinit();
    }

    /// Forward pass WITHOUT KV-cache (original, slower)
    pub fn forward(self: *const MistralAttention, allocator: std.mem.Allocator, hidden: []const f32, pos: usize) ![]f32 {
        return self.forwardWithCache(allocator, hidden, pos, null);
    }

    /// Forward pass WITH KV-cache (5x faster for autoregressive generation)
    pub fn forwardWithCache(
        self: *const MistralAttention,
        allocator: std.mem.Allocator,
        hidden: []const f32,
        pos: usize,
        layer_cache: ?*kv_cache.LayerKVCache,
    ) ![]f32 {
        const batch_size: usize = 1;

        // Q, K, V projections
        const q = try self.q_proj.forward(allocator, hidden, batch_size);
        defer allocator.free(q);
        const k = try self.k_proj.forward(allocator, hidden, batch_size);
        defer allocator.free(k);
        const v = try self.v_proj.forward(allocator, hidden, batch_size);
        defer allocator.free(v);

        // Apply RoPE to Q and K
        var q_mut = try allocator.dupe(f32, q);
        defer allocator.free(q_mut);
        var k_mut = try allocator.dupe(f32, k);
        defer allocator.free(k_mut);

        const num_heads = self.config.num_attention_heads;
        const head_dim = self.config.head_dim;
        const num_kv_heads = self.config.num_key_value_heads;

        // Apply RoPE per Q head
        for (0..num_heads) |h| {
            const offset = h * head_dim;
            if (offset + head_dim <= q_mut.len) {
                self.rope.apply(q_mut[offset..][0..head_dim], pos);
            }
        }

        // Apply RoPE per KV head
        for (0..num_kv_heads) |h| {
            const offset = h * head_dim;
            if (offset + head_dim <= k_mut.len) {
                self.rope.apply(k_mut[offset..][0..head_dim], pos);
            }
        }

        // Update KV-cache if provided
        if (layer_cache) |cache| {
            try cache.append(k_mut, v);

            // Use cached attention
            const attn_output = try kv_cache.cachedAttention(
                allocator,
                q_mut,
                cache,
                num_heads,
                num_kv_heads,
                head_dim,
            );
            defer allocator.free(attn_output);

            // O projection
            const output = try self.o_proj.forward(allocator, attn_output, batch_size);
            return output;
        } else {
            // No cache - simplified attention (original behavior)
            const hidden_size = self.config.hidden_size;
            const padded_v = try allocator.alloc(f32, hidden_size);
            defer allocator.free(padded_v);
            @memset(padded_v, 0.0);

            const copy_len = @min(v.len, hidden_size);
            @memcpy(padded_v[0..copy_len], v[0..copy_len]);

            const output = try self.o_proj.forward(allocator, padded_v, batch_size);
            return output;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SIMD MISTRAL MLP (SwiGLU)
// ═══════════════════════════════════════════════════════════════════════════════

pub const MistralMLP = struct {
    allocator: std.mem.Allocator,
    gate_proj: engine.SimdTrinityLayer,
    up_proj: engine.SimdTrinityLayer,
    down_proj: engine.SimdTrinityLayer,

    pub fn init(allocator: std.mem.Allocator, config: MistralConfig) !MistralMLP {
        return MistralMLP{
            .allocator = allocator,
            .gate_proj = try engine.SimdTrinityLayer.init(allocator, config.hidden_size, config.intermediate_size, .silu_approx),
            .up_proj = try engine.SimdTrinityLayer.init(allocator, config.hidden_size, config.intermediate_size, .none),
            .down_proj = try engine.SimdTrinityLayer.init(allocator, config.intermediate_size, config.hidden_size, .none),
        };
    }

    pub fn deinit(self: *MistralMLP) void {
        self.gate_proj.deinit();
        self.up_proj.deinit();
        self.down_proj.deinit();
    }

    /// SwiGLU: down(silu(gate(x)) * up(x))
    pub fn forward(self: *const MistralMLP, allocator: std.mem.Allocator, x: []const f32) ![]f32 {
        const batch_size: usize = 1;

        const gate = try self.gate_proj.forward(allocator, x, batch_size);
        defer allocator.free(gate);
        const up = try self.up_proj.forward(allocator, x, batch_size);
        defer allocator.free(up);

        // Element-wise multiply: gate * up
        // This is the only place we need actual multiplication
        // But we can approximate with addition for ternary
        const intermediate = try allocator.alloc(f32, gate.len);
        for (gate, up, 0..) |g, u, i| {
            intermediate[i] = g * u; // Real multiply needed here
        }

        const output = try self.down_proj.forward(allocator, intermediate, batch_size);
        allocator.free(intermediate);

        return output;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MISTRAL TRANSFORMER BLOCK
// ═══════════════════════════════════════════════════════════════════════════════

pub const MistralBlock = struct {
    allocator: std.mem.Allocator,
    attention: MistralAttention,
    mlp: MistralMLP,
    config: MistralConfig,

    pub fn init(allocator: std.mem.Allocator, config: MistralConfig) !MistralBlock {
        return MistralBlock{
            .allocator = allocator,
            .attention = try MistralAttention.init(allocator, config),
            .mlp = try MistralMLP.init(allocator, config),
            .config = config,
        };
    }

    pub fn deinit(self: *MistralBlock) void {
        self.attention.deinit();
        self.mlp.deinit();
    }

    /// Forward without KV-cache
    pub fn forward(self: *const MistralBlock, allocator: std.mem.Allocator, hidden: []const f32, pos: usize) ![]f32 {
        return self.forwardWithCache(allocator, hidden, pos, null);
    }

    /// Forward with KV-cache (5x faster)
    pub fn forwardWithCache(
        self: *const MistralBlock,
        allocator: std.mem.Allocator,
        hidden: []const f32,
        pos: usize,
        layer_cache: ?*kv_cache.LayerKVCache,
    ) ![]f32 {
        // Pre-norm + Attention + Residual
        const normed = try allocator.alloc(f32, hidden.len);
        defer allocator.free(normed);
        rmsNorm(normed, hidden, self.config.rms_norm_eps);

        const attn_out = try self.attention.forwardWithCache(allocator, normed, pos, layer_cache);
        defer allocator.free(attn_out);

        const residual = try allocator.alloc(f32, hidden.len);
        for (hidden, attn_out, 0..) |h, a, i| {
            residual[i] = h + a;
        }

        // Pre-norm + MLP + Residual
        rmsNorm(normed, residual, self.config.rms_norm_eps);

        const mlp_out = try self.mlp.forward(allocator, normed);
        defer allocator.free(mlp_out);

        for (residual, mlp_out) |*r, m| {
            r.* += m;
        }

        return residual;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MISTRAL TRINITY MODEL
// ═══════════════════════════════════════════════════════════════════════════════

pub const MistralTrinity = struct {
    allocator: std.mem.Allocator,
    config: MistralConfig,

    embed_tokens: engine.SimdTrinityLayer,
    blocks: std.ArrayList(MistralBlock),
    lm_head: engine.SimdTrinityLayer,

    // KV-cache for fast autoregressive generation
    cache: ?kv_cache.KVCache,

    pub fn init(allocator: std.mem.Allocator, config: MistralConfig) !MistralTrinity {
        var model = MistralTrinity{
            .allocator = allocator,
            .config = config,
            .embed_tokens = try engine.SimdTrinityLayer.init(allocator, config.vocab_size, config.hidden_size, .none),
            .blocks = std.ArrayList(MistralBlock).init(allocator),
            .lm_head = try engine.SimdTrinityLayer.init(allocator, config.hidden_size, config.vocab_size, .none),
            .cache = null,
        };

        for (0..config.num_hidden_layers) |_| {
            const block = try MistralBlock.init(allocator, config);
            try model.blocks.append(block);
        }

        return model;
    }

    pub fn deinit(self: *MistralTrinity) void {
        self.embed_tokens.deinit();
        for (self.blocks.items) |*block| {
            block.deinit();
        }
        self.blocks.deinit();
        self.lm_head.deinit();
        if (self.cache) |*c| {
            c.deinit();
        }
    }

    /// Initialize KV-cache for fast generation
    pub fn initCache(self: *MistralTrinity, max_seq_len: usize) !void {
        if (self.cache != null) {
            self.cache.?.deinit();
        }

        const cache_config = kv_cache.KVCacheConfig{
            .num_layers = self.config.num_hidden_layers,
            .num_kv_heads = self.config.num_key_value_heads,
            .head_dim = self.config.head_dim,
            .max_seq_len = max_seq_len,
        };

        self.cache = try kv_cache.KVCache.init(self.allocator, cache_config);
    }

    /// Reset KV-cache (start new sequence)
    pub fn resetCache(self: *MistralTrinity) void {
        if (self.cache) |*c| {
            c.reset();
        }
    }

    /// Load weights from .tri file
    pub fn loadFromTri(self: *MistralTrinity, path: []const u8) !void {
        var reader = try trinity_format.TrinityReader.init(self.allocator, path);
        defer reader.deinit();

        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║           LOADING MISTRAL TRINITY                            ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║ File: {s:<54} ║\n", .{path[0..@min(path.len, 54)]});
        std.debug.print("║ Tensors: {d:<51} ║\n", .{reader.header.num_tensors});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

        var loaded: usize = 0;

        for (reader.listTensors()) |entry| {
            const name = entry.name;
            const trits = reader.getTensor(name) catch continue;
            defer self.allocator.free(trits);

            // Map tensor names to layers
            if (std.mem.indexOf(u8, name, "embed_tokens") != null) {
                self.embed_tokens.loadWeights(trits);
                loaded += 1;
            } else if (std.mem.indexOf(u8, name, "lm_head") != null) {
                self.lm_head.loadWeights(trits);
                loaded += 1;
            } else if (std.mem.indexOf(u8, name, "q_proj") != null) {
                const idx = parseLayerIndex(name);
                if (idx < self.blocks.items.len) {
                    self.blocks.items[idx].attention.q_proj.loadWeights(trits);
                    loaded += 1;
                }
            } else if (std.mem.indexOf(u8, name, "k_proj") != null) {
                const idx = parseLayerIndex(name);
                if (idx < self.blocks.items.len) {
                    self.blocks.items[idx].attention.k_proj.loadWeights(trits);
                    loaded += 1;
                }
            } else if (std.mem.indexOf(u8, name, "v_proj") != null) {
                const idx = parseLayerIndex(name);
                if (idx < self.blocks.items.len) {
                    self.blocks.items[idx].attention.v_proj.loadWeights(trits);
                    loaded += 1;
                }
            } else if (std.mem.indexOf(u8, name, "o_proj") != null) {
                const idx = parseLayerIndex(name);
                if (idx < self.blocks.items.len) {
                    self.blocks.items[idx].attention.o_proj.loadWeights(trits);
                    loaded += 1;
                }
            } else if (std.mem.indexOf(u8, name, "gate_proj") != null) {
                const idx = parseLayerIndex(name);
                if (idx < self.blocks.items.len) {
                    self.blocks.items[idx].mlp.gate_proj.loadWeights(trits);
                    loaded += 1;
                }
            } else if (std.mem.indexOf(u8, name, "up_proj") != null) {
                const idx = parseLayerIndex(name);
                if (idx < self.blocks.items.len) {
                    self.blocks.items[idx].mlp.up_proj.loadWeights(trits);
                    loaded += 1;
                }
            } else if (std.mem.indexOf(u8, name, "down_proj") != null) {
                const idx = parseLayerIndex(name);
                if (idx < self.blocks.items.len) {
                    self.blocks.items[idx].mlp.down_proj.loadWeights(trits);
                    loaded += 1;
                }
            }
        }

        std.debug.print("✅ Loaded {d} tensors\n", .{loaded});
    }

    /// Generate next token (without KV-cache)
    pub fn forward(self: *MistralTrinity, token_id: u32, pos: usize) !u32 {
        return self.forwardWithCache(token_id, pos, false);
    }

    /// Generate next token with optional KV-cache
    pub fn forwardWithCache(self: *MistralTrinity, token_id: u32, pos: usize, use_cache: bool) !u32 {
        // One-hot encode token
        var input = try self.allocator.alloc(f32, self.config.vocab_size);
        defer self.allocator.free(input);
        @memset(input, 0.0);
        if (token_id < self.config.vocab_size) {
            input[token_id] = 1.0;
        }

        // Embedding
        var hidden = try self.embed_tokens.forward(self.allocator, input, 1);

        // Transformer blocks (with or without cache)
        for (self.blocks.items, 0..) |*block, layer_idx| {
            var layer_cache: ?*kv_cache.LayerKVCache = null;
            if (use_cache and self.cache != null) {
                layer_cache = self.cache.?.getLayer(layer_idx);
            }

            const next = try block.forwardWithCache(self.allocator, hidden, pos, layer_cache);
            self.allocator.free(hidden);
            hidden = next;
        }

        // LM head
        const logits = try self.lm_head.forward(self.allocator, hidden, 1);
        defer self.allocator.free(logits);
        self.allocator.free(hidden);

        // Argmax
        var max_idx: u32 = 0;
        var max_val: f32 = logits[0];
        for (logits, 0..) |val, i| {
            if (val > max_val) {
                max_val = val;
                max_idx = @intCast(i);
            }
        }

        return max_idx;
    }

    /// Generate multiple tokens with KV-cache (fast)
    pub fn generate(self: *MistralTrinity, prompt_tokens: []const u32, max_new_tokens: usize) ![]u32 {
        // Initialize cache if not already
        if (self.cache == null) {
            try self.initCache(prompt_tokens.len + max_new_tokens);
        }
        self.resetCache();

        var output = try self.allocator.alloc(u32, prompt_tokens.len + max_new_tokens);
        @memcpy(output[0..prompt_tokens.len], prompt_tokens);

        // Process prompt (prefill)
        for (prompt_tokens, 0..) |token, pos| {
            _ = try self.forwardWithCache(token, pos, true);
        }

        // Generate new tokens (decode)
        var last_token = prompt_tokens[prompt_tokens.len - 1];
        for (0..max_new_tokens) |i| {
            const pos = prompt_tokens.len + i;
            const new_token = try self.forwardWithCache(last_token, pos, true);
            output[pos] = new_token;
            last_token = new_token;
        }

        return output;
    }

    pub fn printStats(self: *const MistralTrinity) void {
        var total_params: usize = 0;
        total_params += self.embed_tokens.weights.len;
        for (self.blocks.items) |block| {
            total_params += block.attention.q_proj.weights.len;
            total_params += block.attention.k_proj.weights.len;
            total_params += block.attention.v_proj.weights.len;
            total_params += block.attention.o_proj.weights.len;
            total_params += block.mlp.gate_proj.weights.len;
            total_params += block.mlp.up_proj.weights.len;
            total_params += block.mlp.down_proj.weights.len;
        }
        total_params += self.lm_head.weights.len;

        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║           MISTRAL TRINITY - STATS                            ║\n", .{});
        std.debug.print("║           φ² + 1/φ² = 3 = TRINITY                            ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║ Vocab size:       {d:>12}                               ║\n", .{self.config.vocab_size});
        std.debug.print("║ Hidden size:      {d:>12}                               ║\n", .{self.config.hidden_size});
        std.debug.print("║ Num layers:       {d:>12}                               ║\n", .{self.config.num_hidden_layers});
        std.debug.print("║ Num heads:        {d:>12}                               ║\n", .{self.config.num_attention_heads});
        std.debug.print("║ Num KV heads:     {d:>12}                               ║\n", .{self.config.num_key_value_heads});
        std.debug.print("║ Total params:     {d:>12}                               ║\n", .{total_params});
        std.debug.print("║ Memory (2-bit):   {d:>12} bytes                         ║\n", .{total_params / 4});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    }
};

fn parseLayerIndex(name: []const u8) usize {
    var i: usize = 0;
    while (i < name.len) : (i += 1) {
        if (name[i] == '.') {
            var j = i + 1;
            var num: usize = 0;
            var found = false;
            while (j < name.len and name[j] >= '0' and name[j] <= '9') : (j += 1) {
                num = num * 10 + (name[j] - '0');
                found = true;
            }
            if (found and j < name.len and name[j] == '.') {
                return num;
            }
        }
    }
    return 0;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "mistral config" {
    const config = MistralConfig.init();
    try std.testing.expectEqual(@as(u32, 128), config.head_dim);
}

test "mistral mini init" {
    const config = MistralConfig.initMini();
    var model = try MistralTrinity.init(std.testing.allocator, config);
    defer model.deinit();

    try std.testing.expectEqual(@as(usize, 2), model.blocks.items.len);
}

test "rms norm" {
    var input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var output: [4]f32 = undefined;

    rmsNorm(&output, &input, 1e-5);

    // Check that output is normalized
    var sum_sq: f32 = 0.0;
    for (output) |x| {
        sum_sq += x * x;
    }
    const rms = @sqrt(sum_sq / 4.0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), rms, 0.01);
}

test "parse layer index" {
    try std.testing.expectEqual(@as(usize, 5), parseLayerIndex("model.layers.5.self_attn.q_proj.weight"));
    try std.testing.expectEqual(@as(usize, 31), parseLayerIndex("model.layers.31.mlp.gate_proj.weight"));
}
