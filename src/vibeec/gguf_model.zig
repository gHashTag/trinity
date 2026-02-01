// GGUF FULL MODEL - Complete Transformer with all layers
// phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");
const gguf = @import("gguf_reader.zig");
const inference = @import("gguf_inference.zig");
const transformer = @import("gguf_transformer.zig");

pub const FullModel = struct {
    allocator: std.mem.Allocator,
    reader: gguf.GGUFReader,
    config: inference.ModelConfig,

    // Core weights
    token_embedding: []f32,
    output_weight: []f32,
    output_norm: []f32,

    // Per-layer weights
    layers: []LayerWeights,

    // RoPE and KV-cache
    rope: transformer.RoPE,
    kv_caches: []transformer.KVCache,

    pub const LayerWeights = struct {
        attn_norm: []f32,
        ffn_norm: []f32,
        wq: []f32,
        wk: []f32,
        wv: []f32,
        wo: []f32,
        w_gate: []f32,
        w_up: []f32,
        w_down: []f32,
    };

    pub fn init(allocator: std.mem.Allocator, path: []const u8) !FullModel {
        std.debug.print("Loading GGUF model: {s}\n", .{path});

        var reader = try gguf.GGUFReader.init(allocator, path);
        errdefer reader.deinit();

        const arch = reader.getMetadataString("general.architecture") orelse "llama";
        var key_buf: [64]u8 = undefined;

        // Get vocab size from tokenizer
        const vocab_size = blk: {
            if (reader.metadata.get("tokenizer.ggml.tokens")) |v| {
                if (v == .array) break :blk @as(u32, @intCast(v.array.len));
            }
            break :blk @as(u32, 32000);
        };

        const config = inference.ModelConfig{
            .vocab_size = vocab_size,
            .hidden_size = @intCast(reader.getMetadataU64(std.fmt.bufPrint(&key_buf, "{s}.embedding_length", .{arch}) catch "llama.embedding_length") orelse 2048),
            .intermediate_size = @intCast(reader.getMetadataU64(std.fmt.bufPrint(&key_buf, "{s}.feed_forward_length", .{arch}) catch "llama.feed_forward_length") orelse 5632),
            .num_layers = @intCast(reader.getMetadataU64(std.fmt.bufPrint(&key_buf, "{s}.block_count", .{arch}) catch "llama.block_count") orelse 22),
            .num_heads = @intCast(reader.getMetadataU64(std.fmt.bufPrint(&key_buf, "{s}.attention.head_count", .{arch}) catch "llama.attention.head_count") orelse 32),
            .num_kv_heads = @intCast(reader.getMetadataU64(std.fmt.bufPrint(&key_buf, "{s}.attention.head_count_kv", .{arch}) catch "llama.attention.head_count_kv") orelse 4),
            .head_dim = 0,
            .context_length = @intCast(reader.getMetadataU64(std.fmt.bufPrint(&key_buf, "{s}.context_length", .{arch}) catch "llama.context_length") orelse 2048),
            .rope_theta = reader.getMetadataF32(std.fmt.bufPrint(&key_buf, "{s}.rope.freq_base", .{arch}) catch "llama.rope.freq_base") orelse 10000.0,
            .rms_norm_eps = reader.getMetadataF32(std.fmt.bufPrint(&key_buf, "{s}.attention.layer_norm_rms_epsilon", .{arch}) catch "llama.attention.layer_norm_rms_epsilon") orelse 1e-5,
        };

        var model = FullModel{
            .allocator = allocator,
            .reader = reader,
            .config = config,
            .token_embedding = undefined,
            .output_weight = undefined,
            .output_norm = undefined,
            .layers = undefined,
            .rope = undefined,
            .kv_caches = undefined,
        };

        model.config.head_dim = model.config.hidden_size / model.config.num_heads;

        return model;
    }

    pub fn loadWeights(self: *FullModel) !void {
        std.debug.print("Loading weights...\n", .{});

        // Load embeddings
        self.token_embedding = try self.loadTensor("token_embd.weight");
        self.output_weight = try self.loadTensor("output.weight");
        self.output_norm = try self.loadTensor("output_norm.weight");

        // Initialize RoPE
        self.rope = try transformer.RoPE.init(
            self.allocator,
            self.config.head_dim,
            self.config.context_length,
            self.config.rope_theta,
        );

        // Initialize KV caches for each layer
        self.kv_caches = try self.allocator.alloc(transformer.KVCache, self.config.num_layers);
        for (0..self.config.num_layers) |i| {
            self.kv_caches[i] = try transformer.KVCache.init(
                self.allocator,
                self.config.num_kv_heads,
                self.config.head_dim,
                self.config.context_length,
            );
        }

        // Load layer weights
        self.layers = try self.allocator.alloc(LayerWeights, self.config.num_layers);

        for (0..self.config.num_layers) |i| {
            std.debug.print("  Loading layer {d}/{d}...\r", .{ i + 1, self.config.num_layers });

            var name_buf: [64]u8 = undefined;

            self.layers[i] = LayerWeights{
                .attn_norm = try self.loadTensorFmt(&name_buf, "blk.{d}.attn_norm.weight", .{i}),
                .ffn_norm = try self.loadTensorFmt(&name_buf, "blk.{d}.ffn_norm.weight", .{i}),
                .wq = try self.loadTensorFmt(&name_buf, "blk.{d}.attn_q.weight", .{i}),
                .wk = try self.loadTensorFmt(&name_buf, "blk.{d}.attn_k.weight", .{i}),
                .wv = try self.loadTensorFmt(&name_buf, "blk.{d}.attn_v.weight", .{i}),
                .wo = try self.loadTensorFmt(&name_buf, "blk.{d}.attn_output.weight", .{i}),
                .w_gate = try self.loadTensorFmt(&name_buf, "blk.{d}.ffn_gate.weight", .{i}),
                .w_up = try self.loadTensorFmt(&name_buf, "blk.{d}.ffn_up.weight", .{i}),
                .w_down = try self.loadTensorFmt(&name_buf, "blk.{d}.ffn_down.weight", .{i}),
            };
        }

        std.debug.print("  Loaded {d} layers                    \n", .{self.config.num_layers});
    }

    fn loadTensor(self: *FullModel, name: []const u8) ![]f32 {
        const info = self.reader.getTensor(name) orelse return error.TensorNotFound;
        const data = try self.reader.readTensorData(info);
        defer self.allocator.free(data);
        return inference.dequantizeTensor(self.allocator, data, info.tensor_type, info.numElements());
    }

    fn loadTensorFmt(self: *FullModel, buf: []u8, comptime fmt: []const u8, args: anytype) ![]f32 {
        const name = std.fmt.bufPrint(buf, fmt, args) catch return error.NameTooLong;
        return self.loadTensor(name);
    }

    pub fn deinit(self: *FullModel) void {
        // Free layer weights
        if (self.layers.len > 0) {
            for (self.layers) |layer| {
                self.allocator.free(layer.attn_norm);
                self.allocator.free(layer.ffn_norm);
                self.allocator.free(layer.wq);
                self.allocator.free(layer.wk);
                self.allocator.free(layer.wv);
                self.allocator.free(layer.wo);
                self.allocator.free(layer.w_gate);
                self.allocator.free(layer.w_up);
                self.allocator.free(layer.w_down);
            }
            self.allocator.free(self.layers);
        }

        // Free KV caches
        if (self.kv_caches.len > 0) {
            for (self.kv_caches) |*cache| {
                cache.deinit();
            }
            self.allocator.free(self.kv_caches);
        }

        self.rope.deinit();
        self.allocator.free(self.token_embedding);
        self.allocator.free(self.output_weight);
        self.allocator.free(self.output_norm);
        self.reader.deinit();
    }

    pub fn resetKVCache(self: *FullModel) void {
        for (self.kv_caches) |*cache| {
            cache.reset();
        }
    }

    // Forward pass for single token
    pub fn forward(self: *FullModel, token: u32, pos: usize) ![]f32 {
        const hidden_size = self.config.hidden_size;

        // Get embedding
        const emb_start = token * hidden_size;
        const hidden = try self.allocator.alloc(f32, hidden_size);
        defer self.allocator.free(hidden);
        @memcpy(hidden, self.token_embedding[emb_start..][0..hidden_size]);

        // Process through all layers
        const temp = try self.allocator.alloc(f32, hidden_size);
        defer self.allocator.free(temp);

        for (0..self.config.num_layers) |i| {
            try self.forwardLayer(temp, hidden, i, pos);
            @memcpy(hidden, temp);
        }

        // Final RMS norm
        inference.rmsNorm(temp, hidden, self.output_norm, self.config.rms_norm_eps);

        // Output projection
        const logits = try self.allocator.alloc(f32, self.config.vocab_size);
        inference.matVec(logits, self.output_weight, temp, self.config.vocab_size, hidden_size);

        return logits;
    }

    fn forwardLayer(self: *FullModel, output: []f32, input: []const f32, layer_idx: usize, pos: usize) !void {
        const layer = self.layers[layer_idx];
        const hidden_size = self.config.hidden_size;
        const num_heads = self.config.num_heads;
        const num_kv_heads = self.config.num_kv_heads;
        const head_dim = self.config.head_dim;
        const intermediate_size = self.config.intermediate_size;
        const rms_eps = self.config.rms_norm_eps;

        // Pre-attention norm
        const normed = try self.allocator.alloc(f32, hidden_size);
        defer self.allocator.free(normed);
        inference.rmsNorm(normed, input, layer.attn_norm, rms_eps);

        // Compute Q, K, V
        const q = try self.allocator.alloc(f32, num_heads * head_dim);
        defer self.allocator.free(q);
        const k = try self.allocator.alloc(f32, num_kv_heads * head_dim);
        defer self.allocator.free(k);
        const v = try self.allocator.alloc(f32, num_kv_heads * head_dim);
        defer self.allocator.free(v);

        inference.matVec(q, layer.wq, normed, num_heads * head_dim, hidden_size);
        inference.matVec(k, layer.wk, normed, num_kv_heads * head_dim, hidden_size);
        inference.matVec(v, layer.wv, normed, num_kv_heads * head_dim, hidden_size);

        // Apply RoPE
        for (0..num_heads) |h| {
            self.rope.apply(q[h * head_dim ..][0..head_dim], pos);
        }
        for (0..num_kv_heads) |h| {
            self.rope.apply(k[h * head_dim ..][0..head_dim], pos);
        }

        // Update KV cache
        self.kv_caches[layer_idx].append(k, v);

        // Attention
        const attn_out = try self.allocator.alloc(f32, num_heads * head_dim);
        defer self.allocator.free(attn_out);

        const scale = 1.0 / @sqrt(@as(f32, @floatFromInt(head_dim)));
        const kv_group_size = num_heads / num_kv_heads;
        const seq_len = self.kv_caches[layer_idx].seq_len;

        for (0..num_heads) |h| {
            const kv_h = h / kv_group_size;
            const q_head = q[h * head_dim ..][0..head_dim];

            // Attention scores
            const scores = try self.allocator.alloc(f32, seq_len);
            defer self.allocator.free(scores);

            for (0..seq_len) |t| {
                const k_offset = t * num_kv_heads * head_dim + kv_h * head_dim;
                const k_vec = self.kv_caches[layer_idx].k_cache[k_offset..][0..head_dim];

                var dot: f32 = 0.0;
                for (0..head_dim) |i| {
                    dot += q_head[i] * k_vec[i];
                }
                scores[t] = dot * scale;
            }

            // Softmax
            inference.softmax(scores, scores);

            // Weighted sum
            const out_head = attn_out[h * head_dim ..][0..head_dim];
            @memset(out_head, 0.0);

            for (0..seq_len) |t| {
                const v_offset = t * num_kv_heads * head_dim + kv_h * head_dim;
                const v_vec = self.kv_caches[layer_idx].v_cache[v_offset..][0..head_dim];
                const score = scores[t];

                for (0..head_dim) |i| {
                    out_head[i] += score * v_vec[i];
                }
            }
        }

        // Output projection
        const attn_proj = try self.allocator.alloc(f32, hidden_size);
        defer self.allocator.free(attn_proj);
        inference.matVec(attn_proj, layer.wo, attn_out, hidden_size, num_heads * head_dim);

        // Residual
        for (0..hidden_size) |i| {
            output[i] = input[i] + attn_proj[i];
        }

        // Pre-FFN norm
        inference.rmsNorm(normed, output, layer.ffn_norm, rms_eps);

        // FFN with SwiGLU
        const gate = try self.allocator.alloc(f32, intermediate_size);
        defer self.allocator.free(gate);
        const up = try self.allocator.alloc(f32, intermediate_size);
        defer self.allocator.free(up);

        inference.matVec(gate, layer.w_gate, normed, intermediate_size, hidden_size);
        inference.matVec(up, layer.w_up, normed, intermediate_size, hidden_size);

        // SwiGLU
        for (0..intermediate_size) |i| {
            gate[i] = inference.silu(gate[i]) * up[i];
        }

        // Down projection
        const ffn_out = try self.allocator.alloc(f32, hidden_size);
        defer self.allocator.free(ffn_out);
        inference.matVec(ffn_out, layer.w_down, gate, hidden_size, intermediate_size);

        // Residual
        for (0..hidden_size) |i| {
            output[i] += ffn_out[i];
        }
    }

    // Generate next token
    pub fn generate(self: *FullModel, token: u32, pos: usize, temperature: f32) !u32 {
        const logits = try self.forward(token, pos);
        defer self.allocator.free(logits);

        // Apply temperature
        if (temperature > 0) {
            for (logits) |*l| {
                l.* /= temperature;
            }
        }

        // Softmax
        const probs = try self.allocator.alloc(f32, logits.len);
        defer self.allocator.free(probs);
        inference.softmax(probs, logits);

        return inference.sample(probs, temperature);
    }

    pub fn printConfig(self: *const FullModel) void {
        std.debug.print("\nMODEL CONFIG\n", .{});
        std.debug.print("  Vocab size:       {d}\n", .{self.config.vocab_size});
        std.debug.print("  Hidden size:      {d}\n", .{self.config.hidden_size});
        std.debug.print("  Intermediate:     {d}\n", .{self.config.intermediate_size});
        std.debug.print("  Num layers:       {d}\n", .{self.config.num_layers});
        std.debug.print("  Num heads:        {d}\n", .{self.config.num_heads});
        std.debug.print("  Num KV heads:     {d}\n", .{self.config.num_kv_heads});
        std.debug.print("  Head dim:         {d}\n", .{self.config.head_dim});
        std.debug.print("  Context length:   {d}\n", .{self.config.context_length});
    }
};

test "model_config" {
    // Just verify compilation
}
