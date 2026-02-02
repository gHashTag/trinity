// ═══════════════════════════════════════════════════════════════════════════════
// TRI INFERENCE - Fast inference using ternary .tri models
// 5-10x speedup via elimination of multiplications
// φ² + 1/φ² = 3 = TRINITY = QUTRIT = CODON
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const ternary = @import("ternary_weights.zig");
const inference = @import("gguf_inference.zig");
const transformer = @import("gguf_transformer.zig");
const flash = @import("flash_attention.zig");
const parallel = @import("parallel_inference.zig");
const kv_cache = @import("kv_cache.zig");
const simd = @import("simd_matmul.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// .TRI FILE FORMAT
// ═══════════════════════════════════════════════════════════════════════════════

pub const TRI_MAGIC: u32 = 0x54524933; // "TRI3"

pub const TriHeader = packed struct {
    magic: u32,
    version: u32,
    model_type: u32,
    vocab_size: u32,
    hidden_size: u32,
    intermediate_size: u32,
    num_layers: u32,
    num_heads: u32,
    num_kv_heads: u32,
    head_dim: u32,
    context_length: u32,
    rope_theta: f32,
    rms_norm_eps: f32,
    total_params: u64,
    ternary_size: u64,
    embedding_offset: u64,
    output_norm_offset: u64,
    output_weight_offset: u64,
    layers_offset: u64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY MODEL
// ═══════════════════════════════════════════════════════════════════════════════

pub const TriModel = struct {
    allocator: std.mem.Allocator,
    header: TriHeader,

    // Embeddings (f32 or ternary)
    token_embedding: []f32,
    ternary_embedding: ?ternary.TernaryEmbedding,
    use_ternary_embedding: bool,
    output_norm: []f32,
    ternary_output_norm: ?simd.TernaryNormWeights,

    // Output projection (ternary)
    output_weight: []u8,
    output_scale: f32,

    // Layers
    layers: []TriLayer,

    // RoPE and KV-cache
    rope: transformer.RoPE,
    kv_caches: []transformer.KVCache,

    // Ternary KV cache (OPT-T03/T04) - 16x memory reduction
    ternary_kv_caches: ?[]kv_cache.TernaryKVCache,
    use_ternary_kv: bool,

    // Pre-allocated buffers
    buf_hidden: []f32,
    buf_temp: []f32,
    buf_normed: []f32,
    buf_q: []f32,
    buf_k: []f32,
    buf_v: []f32,
    buf_attn_out: []f32,
    buf_attn_proj: []f32,
    buf_ffn_gate: []f32,
    buf_ffn_up: []f32,
    buf_ffn_out: []f32,
    buf_scores: []f32,

    pub const TriLayer = struct {
        attn_norm: []f32,
        ffn_norm: []f32,
        // Optional ternary norm weights (16x memory reduction)
        ternary_attn_norm: ?simd.TernaryNormWeights,
        ternary_ffn_norm: ?simd.TernaryNormWeights,
        wq: []u8,
        wk: []u8,
        wv: []u8,
        wo: []u8,
        scale_q: f32,
        scale_k: f32,
        scale_v: f32,
        scale_o: f32,
        w_gate: []u8,
        w_up: []u8,
        w_down: []u8,
        scale_gate: f32,
        scale_up: f32,
        scale_down: f32,
    };

    pub fn init(allocator: std.mem.Allocator, path: []const u8) !TriModel {
        std.debug.print("Loading TRI model: {s}\n", .{path});

        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        var reader = file.reader();

        // Read header
        var header: TriHeader = undefined;
        _ = try reader.readAll(std.mem.asBytes(&header));

        if (header.magic != TRI_MAGIC) {
            return error.InvalidMagic;
        }

        std.debug.print("\nTRI MODEL CONFIG\n", .{});
        std.debug.print("  Vocab size:       {d}\n", .{header.vocab_size});
        std.debug.print("  Hidden size:      {d}\n", .{header.hidden_size});
        std.debug.print("  Intermediate:     {d}\n", .{header.intermediate_size});
        std.debug.print("  Num layers:       {d}\n", .{header.num_layers});
        std.debug.print("  Num heads:        {d}\n", .{header.num_heads});
        std.debug.print("  Num KV heads:     {d}\n", .{header.num_kv_heads});
        std.debug.print("  Head dim:         {d}\n", .{header.head_dim});
        std.debug.print("  Context length:   {d}\n", .{header.context_length});

        var model = TriModel{
            .allocator = allocator,
            .header = header,
            .token_embedding = undefined,
            .ternary_embedding = null,
            .use_ternary_embedding = false,
            .output_norm = undefined,
            .output_weight = undefined,
            .output_scale = undefined,
            .layers = undefined,
            .rope = undefined,
            .kv_caches = undefined,
            .ternary_kv_caches = null,
            .use_ternary_kv = false,
            .buf_hidden = undefined,
            .buf_temp = undefined,
            .buf_normed = undefined,
            .buf_q = undefined,
            .buf_k = undefined,
            .buf_v = undefined,
            .buf_attn_out = undefined,
            .buf_attn_proj = undefined,
            .buf_ffn_gate = undefined,
            .buf_ffn_up = undefined,
            .buf_ffn_out = undefined,
            .buf_scores = undefined,
        };

        // Read token embeddings
        const emb_size = header.vocab_size * header.hidden_size;
        model.token_embedding = try allocator.alloc(f32, emb_size);
        _ = try reader.readAll(std.mem.sliceAsBytes(model.token_embedding));

        // Read output norm
        model.output_norm = try allocator.alloc(f32, header.hidden_size);
        _ = try reader.readAll(std.mem.sliceAsBytes(model.output_norm));
        model.ternary_output_norm = null;

        // Read output weight scale + ternary data
        _ = try reader.readAll(std.mem.asBytes(&model.output_scale));
        const output_ternary_size = (emb_size + 3) / 4;
        model.output_weight = try allocator.alloc(u8, output_ternary_size);
        _ = try reader.readAll(model.output_weight);

        // Read layers
        model.layers = try allocator.alloc(TriLayer, header.num_layers);

        for (0..header.num_layers) |i| {
            var layer: TriLayer = undefined;

            // Read norms
            layer.attn_norm = try allocator.alloc(f32, header.hidden_size);
            _ = try reader.readAll(std.mem.sliceAsBytes(layer.attn_norm));

            layer.ffn_norm = try allocator.alloc(f32, header.hidden_size);
            _ = try reader.readAll(std.mem.sliceAsBytes(layer.ffn_norm));

            // Initialize ternary norm weights as null (can be enabled later)
            layer.ternary_attn_norm = null;
            layer.ternary_ffn_norm = null;

            // Read attention scales
            _ = try reader.readAll(std.mem.asBytes(&layer.scale_q));
            _ = try reader.readAll(std.mem.asBytes(&layer.scale_k));
            _ = try reader.readAll(std.mem.asBytes(&layer.scale_v));
            _ = try reader.readAll(std.mem.asBytes(&layer.scale_o));

            // Read attention ternary weights
            const q_size = header.num_heads * header.head_dim * header.hidden_size;
            const kv_size = header.num_kv_heads * header.head_dim * header.hidden_size;

            layer.wq = try allocator.alloc(u8, (q_size + 3) / 4);
            _ = try reader.readAll(layer.wq);

            layer.wk = try allocator.alloc(u8, (kv_size + 3) / 4);
            _ = try reader.readAll(layer.wk);

            layer.wv = try allocator.alloc(u8, (kv_size + 3) / 4);
            _ = try reader.readAll(layer.wv);

            layer.wo = try allocator.alloc(u8, (q_size + 3) / 4);
            _ = try reader.readAll(layer.wo);

            // Read FFN scales
            _ = try reader.readAll(std.mem.asBytes(&layer.scale_gate));
            _ = try reader.readAll(std.mem.asBytes(&layer.scale_up));
            _ = try reader.readAll(std.mem.asBytes(&layer.scale_down));

            // Read FFN ternary weights
            const ffn_size = header.intermediate_size * header.hidden_size;

            layer.w_gate = try allocator.alloc(u8, (ffn_size + 3) / 4);
            _ = try reader.readAll(layer.w_gate);

            layer.w_up = try allocator.alloc(u8, (ffn_size + 3) / 4);
            _ = try reader.readAll(layer.w_up);

            layer.w_down = try allocator.alloc(u8, (ffn_size + 3) / 4);
            _ = try reader.readAll(layer.w_down);

            model.layers[i] = layer;
            std.debug.print("  Loaded layer {d}/{d}...\r", .{ i + 1, header.num_layers });
        }
        std.debug.print("  Loaded {d} layers                    \n", .{header.num_layers});

        // Initialize RoPE
        model.rope = try transformer.RoPE.init(
            allocator,
            header.head_dim,
            header.context_length,
            header.rope_theta,
        );

        // Initialize KV caches
        model.kv_caches = try allocator.alloc(transformer.KVCache, header.num_layers);
        for (0..header.num_layers) |i| {
            model.kv_caches[i] = try transformer.KVCache.init(
                allocator,
                header.num_kv_heads,
                header.head_dim,
                header.context_length,
            );
        }

        // Allocate buffers
        model.buf_hidden = try allocator.alloc(f32, header.hidden_size);
        model.buf_temp = try allocator.alloc(f32, header.hidden_size);
        model.buf_normed = try allocator.alloc(f32, header.hidden_size);
        model.buf_q = try allocator.alloc(f32, header.num_heads * header.head_dim);
        model.buf_k = try allocator.alloc(f32, header.num_kv_heads * header.head_dim);
        model.buf_v = try allocator.alloc(f32, header.num_kv_heads * header.head_dim);
        model.buf_attn_out = try allocator.alloc(f32, header.num_heads * header.head_dim);
        model.buf_attn_proj = try allocator.alloc(f32, header.hidden_size);
        model.buf_ffn_gate = try allocator.alloc(f32, header.intermediate_size);
        model.buf_ffn_up = try allocator.alloc(f32, header.intermediate_size);
        model.buf_ffn_out = try allocator.alloc(f32, header.hidden_size);
        model.buf_scores = try allocator.alloc(f32, header.context_length);

        return model;
    }

    pub fn deinit(self: *TriModel) void {
        if (self.token_embedding.len > 0) {
            self.allocator.free(self.token_embedding);
        }
        if (self.ternary_embedding) |*emb| {
            emb.deinit();
        }
        self.allocator.free(self.output_norm);
        self.allocator.free(self.output_weight);

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

        for (self.kv_caches) |*cache| {
            cache.deinit();
        }
        self.allocator.free(self.kv_caches);

        // Free ternary KV caches if enabled
        if (self.ternary_kv_caches) |caches| {
            for (caches) |*cache| {
                cache.deinit();
            }
            self.allocator.free(caches);
        }

        self.rope.deinit();

        self.allocator.free(self.buf_hidden);
        self.allocator.free(self.buf_temp);
        self.allocator.free(self.buf_normed);
        self.allocator.free(self.buf_q);
        self.allocator.free(self.buf_k);
        self.allocator.free(self.buf_v);
        self.allocator.free(self.buf_attn_out);
        self.allocator.free(self.buf_attn_proj);
        self.allocator.free(self.buf_ffn_gate);
        self.allocator.free(self.buf_ffn_up);
        self.allocator.free(self.buf_ffn_out);
        self.allocator.free(self.buf_scores);
    }

    pub fn resetKVCache(self: *TriModel) void {
        for (self.kv_caches) |*cache| {
            cache.reset();
        }
        if (self.ternary_kv_caches) |caches| {
            for (caches) |*cache| {
                cache.reset();
            }
        }
    }

    /// Enable ternary embeddings for 16x memory reduction
    /// Call after load() but before inference
    pub fn enableTernaryEmbeddings(self: *TriModel) !void {
        if (self.ternary_embedding != null) return; // Already enabled

        const header = self.header;
        self.ternary_embedding = try ternary.TernaryEmbedding.initFromF32(
            self.allocator,
            self.token_embedding,
            header.vocab_size,
            header.hidden_size,
        );
        self.use_ternary_embedding = true;

        // Print memory savings
        const stats = self.ternary_embedding.?.memoryStats();

        std.debug.print("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║           TERNARY EMBEDDINGS ENABLED                         ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║  f32 embeddings:    {d:>10} bytes                        ║\n", .{stats.f32_bytes});
        std.debug.print("║  Ternary embeddings:{d:>10} bytes                        ║\n", .{stats.ternary_bytes});
        std.debug.print("║  Compression:       {d:>10.1}x                            ║\n", .{stats.compression_ratio});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});

        // Free f32 embeddings to save memory
        self.allocator.free(self.token_embedding);
        self.token_embedding = &[_]f32{};
    }

    /// Enable ternary KV cache for 16x memory reduction
    /// Call after load() but before inference
    pub fn enableTernaryKVCache(self: *TriModel) !void {
        if (self.ternary_kv_caches != null) return; // Already enabled

        const header = self.header;
        self.ternary_kv_caches = try self.allocator.alloc(kv_cache.TernaryKVCache, header.num_layers);

        for (self.ternary_kv_caches.?) |*cache| {
            cache.* = try kv_cache.TernaryKVCache.init(
                self.allocator,
                header.num_kv_heads,
                header.head_dim,
                header.context_length,
            );
        }

        self.use_ternary_kv = true;

        // Print memory savings
        const f32_mem = header.num_layers * header.context_length * header.num_kv_heads * header.head_dim * 2 * 4;
        const ternary_mem = self.ternary_kv_caches.?[0].memoryUsage() * header.num_layers;
        const ratio = @as(f32, @floatFromInt(f32_mem)) / @as(f32, @floatFromInt(ternary_mem));

        std.debug.print("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║           TERNARY KV CACHE ENABLED                           ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║  f32 KV cache:      {d:>10} bytes                        ║\n", .{f32_mem});
        std.debug.print("║  Ternary KV cache:  {d:>10} bytes                        ║\n", .{ternary_mem});
        std.debug.print("║  Compression:       {d:>10.1}x                            ║\n", .{ratio});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    }

    /// Enable ternary normalization for all layers (16x memory reduction for norm weights)
    pub fn enableTernaryNorm(self: *TriModel) !void {
        // Quantize output norm
        self.ternary_output_norm = try simd.quantizeToTernary(self.allocator, self.output_norm);

        for (self.layers) |*layer| {
            // Quantize attn_norm to ternary
            layer.ternary_attn_norm = try simd.quantizeToTernary(self.allocator, layer.attn_norm);
            // Quantize ffn_norm to ternary
            layer.ternary_ffn_norm = try simd.quantizeToTernary(self.allocator, layer.ffn_norm);
        }

        // Calculate memory savings (include output_norm)
        const f32_mem = (self.header.num_layers * 2 + 1) * self.header.hidden_size * 4; // 2 norms per layer + output_norm
        const ternary_mem = (self.header.num_layers * 2 + 1) * ((self.header.hidden_size + 3) / 4); // 2 bits per weight
        const ratio = @as(f32, @floatFromInt(f32_mem)) / @as(f32, @floatFromInt(ternary_mem));

        std.debug.print("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║           TERNARY NORMALIZATION ENABLED                      ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║  f32 norm weights:     {d:>10} bytes                     ║\n", .{f32_mem});
        std.debug.print("║  Ternary norm weights: {d:>10} bytes                     ║\n", .{ternary_mem});
        std.debug.print("║  Compression:          {d:>10.1}x                         ║\n", .{ratio});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    }

    /// Apply RMSNorm using ternary weights if available, otherwise f32
    inline fn applyRmsNorm(output: []f32, input: []const f32, f32_weights: []const f32, ternary_weights: ?simd.TernaryNormWeights, eps: f32) void {
        if (ternary_weights) |tw| {
            simd.simdTernaryRmsNorm(output, input, tw, eps);
        } else {
            inference.rmsNorm(output, input, f32_weights, eps);
        }
    }

    // Forward pass using TERNARY matmul (NO MULTIPLICATIONS!)
    pub fn forward(self: *TriModel, token: u32, pos: usize) ![]f32 {
        const hidden_size = self.header.hidden_size;

        // Get embedding (f32 or ternary)
        if (self.use_ternary_embedding and self.ternary_embedding != null) {
            self.ternary_embedding.?.lookupSIMD(self.buf_hidden, token);
        } else {
            const emb_start = token * hidden_size;
            @memcpy(self.buf_hidden, self.token_embedding[emb_start..][0..hidden_size]);
        }

        // Process through layers
        for (0..self.header.num_layers) |i| {
            self.forwardLayer(self.buf_temp, self.buf_hidden, i, pos);
            @memcpy(self.buf_hidden, self.buf_temp);
        }

        // Final norm (ternary if enabled)
        applyRmsNorm(self.buf_temp, self.buf_hidden, self.output_norm, self.ternary_output_norm, self.header.rms_norm_eps);

        // Output projection using PARALLEL TERNARY matmul
        const logits = try self.allocator.alloc(f32, self.header.vocab_size);
        parallel.parallelTernaryMatmul(
            logits,
            self.output_weight,
            self.buf_temp,
            self.header.vocab_size,
            hidden_size,
            self.output_scale,
        );

        return logits;
    }

    fn forwardLayer(self: *TriModel, output: []f32, input: []const f32, layer_idx: usize, pos: usize) void {
        const layer = self.layers[layer_idx];
        const hidden_size = self.header.hidden_size;
        const num_heads = self.header.num_heads;
        const num_kv_heads = self.header.num_kv_heads;
        const head_dim = self.header.head_dim;
        const intermediate_size = self.header.intermediate_size;
        const rms_eps = self.header.rms_norm_eps;

        // Pre-attention norm (ternary if enabled)
        applyRmsNorm(self.buf_normed, input, layer.attn_norm, layer.ternary_attn_norm, rms_eps);

        // Compute Q, K, V using PARALLEL TERNARY matmul
        parallel.parallelTernaryMatmul(self.buf_q, layer.wq, self.buf_normed, num_heads * head_dim, hidden_size, layer.scale_q);
        parallel.parallelTernaryMatmul(self.buf_k, layer.wk, self.buf_normed, num_kv_heads * head_dim, hidden_size, layer.scale_k);
        parallel.parallelTernaryMatmul(self.buf_v, layer.wv, self.buf_normed, num_kv_heads * head_dim, hidden_size, layer.scale_v);

        // Apply RoPE
        for (0..num_heads) |h| {
            self.rope.apply(self.buf_q[h * head_dim ..][0..head_dim], pos);
        }
        for (0..num_kv_heads) |h| {
            self.rope.apply(self.buf_k[h * head_dim ..][0..head_dim], pos);
        }

        // Update KV cache (f32 or ternary)
        const scale = 1.0 / @sqrt(@as(f32, @floatFromInt(head_dim)));

        if (self.use_ternary_kv and self.ternary_kv_caches != null) {
            // TERNARY KV CACHE PATH (16x memory reduction)
            self.ternary_kv_caches.?[layer_idx].append(self.buf_k, self.buf_v);

            const seq_len = self.ternary_kv_caches.?[layer_idx].seq_len;

            // Use ternary attention (no K dequantization!)
            flash.ternaryAttentionGQA(
                self.buf_attn_out,
                self.buf_q,
                &self.ternary_kv_caches.?[layer_idx],
                num_heads,
                num_kv_heads,
                head_dim,
                scale,
                self.buf_scores,
            );
            _ = seq_len;
        } else {
            // F32 KV CACHE PATH (original)
            self.kv_caches[layer_idx].append(self.buf_k, self.buf_v);

            const kv_group_size = num_heads / num_kv_heads;
            const seq_len = self.kv_caches[layer_idx].seq_len;

            for (0..num_heads) |h| {
                const kv_h = h / kv_group_size;
                const q_head = self.buf_q[h * head_dim ..][0..head_dim];

                // Compute attention scores with SIMD dot product
                for (0..seq_len) |t| {
                    const k_offset = t * num_kv_heads * head_dim + kv_h * head_dim;
                    const k_vec = self.kv_caches[layer_idx].k_cache[k_offset..][0..head_dim];
                    self.buf_scores[t] = flash.simdDot(q_head, k_vec) * scale;
                }

                // Softmax
                inference.softmax(self.buf_scores[0..seq_len], self.buf_scores[0..seq_len]);

                // Weighted sum with SIMD
                const out_head = self.buf_attn_out[h * head_dim ..][0..head_dim];
                @memset(out_head, 0.0);

                for (0..seq_len) |t| {
                    const v_offset = t * num_kv_heads * head_dim + kv_h * head_dim;
                    const v_vec = self.kv_caches[layer_idx].v_cache[v_offset..][0..head_dim];
                    const score_val = self.buf_scores[t];

                    // SIMD scale-add
                    const Vec8 = @Vector(8, f32);
                    const weight_vec: Vec8 = @splat(score_val);
                    var j: usize = 0;
                    while (j + 8 <= head_dim) : (j += 8) {
                        const out_vec: Vec8 = out_head[j..][0..8].*;
                        const v_vec8: Vec8 = v_vec[j..][0..8].*;
                        out_head[j..][0..8].* = out_vec + v_vec8 * weight_vec;
                    }
                    while (j < head_dim) : (j += 1) {
                        out_head[j] += score_val * v_vec[j];
                    }
                }
            }
        }

        // Output projection using PARALLEL TERNARY matmul
        parallel.parallelTernaryMatmul(self.buf_attn_proj, layer.wo, self.buf_attn_out, hidden_size, num_heads * head_dim, layer.scale_o);

        // Residual
        for (0..hidden_size) |i| {
            output[i] = input[i] + self.buf_attn_proj[i];
        }

        // Pre-FFN norm (ternary if enabled)
        applyRmsNorm(self.buf_normed, output, layer.ffn_norm, layer.ternary_ffn_norm, rms_eps);

        // FFN using PARALLEL TERNARY matmul
        parallel.parallelTernaryMatmul(self.buf_ffn_gate, layer.w_gate, self.buf_normed, intermediate_size, hidden_size, layer.scale_gate);
        parallel.parallelTernaryMatmul(self.buf_ffn_up, layer.w_up, self.buf_normed, intermediate_size, hidden_size, layer.scale_up);

        // SwiGLU activation
        for (0..intermediate_size) |i| {
            self.buf_ffn_gate[i] = inference.silu(self.buf_ffn_gate[i]) * self.buf_ffn_up[i];
        }

        // Down projection using PARALLEL TERNARY matmul
        parallel.parallelTernaryMatmul(self.buf_ffn_out, layer.w_down, self.buf_ffn_gate, hidden_size, intermediate_size, layer.scale_down);

        // Residual
        for (0..hidden_size) |i| {
            output[i] += self.buf_ffn_out[i];
        }
    }

    pub fn generate(self: *TriModel, token: u32, pos: usize, temperature: f32) !u32 {
        const logits = try self.forward(token, pos);
        defer self.allocator.free(logits);

        if (temperature > 0) {
            for (logits) |*l| {
                l.* /= temperature;
            }
        }

        const probs = try self.allocator.alloc(f32, logits.len);
        defer self.allocator.free(probs);
        inference.softmax(probs, logits);

        return inference.sample(probs, temperature);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BATCH TRI MODEL (INF-004)
// Multiple sequences processed in parallel
// ═══════════════════════════════════════════════════════════════════════════════

/// Batch inference wrapper for TriModel
/// Processes multiple sequences in parallel with shared weights
pub const BatchTriModel = struct {
    allocator: std.mem.Allocator,
    model: *TriModel,
    batch_cache: kv_cache.BatchKVCache,
    max_batch_size: usize,

    // Per-sequence buffers
    buf_hidden: [][]f32,
    buf_output: [][]f32,

    pub fn init(allocator: std.mem.Allocator, model: *TriModel, max_batch_size: usize) !BatchTriModel {
        const header = model.header;

        var batch = BatchTriModel{
            .allocator = allocator,
            .model = model,
            .batch_cache = try kv_cache.BatchKVCache.init(
                allocator,
                max_batch_size,
                header.num_layers,
                header.num_kv_heads,
                header.head_dim,
                header.context_length,
            ),
            .max_batch_size = max_batch_size,
            .buf_hidden = try allocator.alloc([]f32, max_batch_size),
            .buf_output = try allocator.alloc([]f32, max_batch_size),
        };

        // Allocate per-sequence buffers
        for (0..max_batch_size) |i| {
            batch.buf_hidden[i] = try allocator.alloc(f32, header.hidden_size);
            batch.buf_output[i] = try allocator.alloc(f32, header.vocab_size);
        }

        return batch;
    }

    pub fn deinit(self: *BatchTriModel) void {
        for (0..self.max_batch_size) |i| {
            self.allocator.free(self.buf_hidden[i]);
            self.allocator.free(self.buf_output[i]);
        }
        self.allocator.free(self.buf_hidden);
        self.allocator.free(self.buf_output);
        self.batch_cache.deinit();
    }

    /// Add new sequence to batch
    pub fn addSequence(self: *BatchTriModel) ?usize {
        return self.batch_cache.addSequence();
    }

    /// Remove sequence from batch
    pub fn removeSequence(self: *BatchTriModel, seq_idx: usize) void {
        self.batch_cache.removeSequence(seq_idx);
    }

    /// Forward pass for single sequence in batch
    pub fn forwardSequence(self: *BatchTriModel, seq_idx: usize, token: u32) ![]f32 {
        if (seq_idx >= self.max_batch_size or !self.batch_cache.active[seq_idx]) {
            return error.InvalidSequence;
        }

        const model = self.model;
        const header = model.header;
        const hidden_size = header.hidden_size;
        const pos = self.batch_cache.positions[seq_idx];

        // Get embedding
        if (model.use_ternary_embedding and model.ternary_embedding != null) {
            model.ternary_embedding.?.lookupSIMD(self.buf_hidden[seq_idx], token);
        } else {
            const emb_start = token * hidden_size;
            @memcpy(self.buf_hidden[seq_idx], model.token_embedding[emb_start..][0..hidden_size]);
        }

        // Process through layers using sequence-specific KV cache
        for (0..header.num_layers) |layer_idx| {
            const cache = self.batch_cache.getCache(seq_idx, layer_idx);
            self.forwardLayerWithCache(self.buf_hidden[seq_idx], layer_idx, pos, cache);
        }

        // Output projection (ternary norm if enabled)
        TriModel.applyRmsNorm(model.buf_normed, self.buf_hidden[seq_idx], model.output_norm, model.ternary_output_norm, header.rms_norm_eps);
        parallel.parallelTernaryMatmul(
            self.buf_output[seq_idx],
            model.output_weight,
            model.buf_normed,
            header.vocab_size,
            hidden_size,
            model.output_scale,
        );

        // Update position
        self.batch_cache.positions[seq_idx] = pos + 1;

        return self.buf_output[seq_idx];
    }

    /// Forward layer with specific KV cache
    fn forwardLayerWithCache(
        self: *BatchTriModel,
        hidden: []f32,
        layer_idx: usize,
        pos: usize,
        cache: *kv_cache.RingKVCache,
    ) void {
        const model = self.model;
        const header = model.header;
        const layer = model.layers[layer_idx];

        const hidden_size = header.hidden_size;
        const num_heads = header.num_heads;
        const num_kv_heads = header.num_kv_heads;
        const head_dim = header.head_dim;
        const intermediate_size = header.intermediate_size;

        // Attention norm (ternary if enabled)
        TriModel.applyRmsNorm(model.buf_normed, hidden, layer.attn_norm, layer.ternary_attn_norm, header.rms_norm_eps);

        // Q, K, V projections
        parallel.parallelTernaryMatmul(model.buf_q, layer.wq, model.buf_normed, num_heads * head_dim, hidden_size, layer.scale_q);
        parallel.parallelTernaryMatmul(model.buf_k, layer.wk, model.buf_normed, num_kv_heads * head_dim, hidden_size, layer.scale_k);
        parallel.parallelTernaryMatmul(model.buf_v, layer.wv, model.buf_normed, num_kv_heads * head_dim, hidden_size, layer.scale_v);

        // Apply RoPE (applies to all heads)
        model.rope.apply(model.buf_q, pos);
        model.rope.apply(model.buf_k, pos);

        // Update KV cache
        cache.append(model.buf_k, model.buf_v);

        // Attention
        const scale = 1.0 / @sqrt(@as(f32, @floatFromInt(head_dim)));
        const kv_group_size = num_heads / num_kv_heads;
        const seq_len = cache.seqLen();

        for (0..num_heads) |h| {
            const kv_h = h / kv_group_size;
            const q_head = model.buf_q[h * head_dim ..][0..head_dim];
            const out_head = model.buf_attn_out[h * head_dim ..][0..head_dim];

            // Use streaming attention with sliding window mask
            // This enables infinite context with fixed memory
            kv_cache.streamingAttention(
                out_head,
                q_head,
                cache,
                kv_h,
                model.buf_scores[0..seq_len],
                scale,
            );
        }

        // Output projection
        parallel.parallelTernaryMatmul(model.buf_attn_proj, layer.wo, model.buf_attn_out, hidden_size, num_heads * head_dim, layer.scale_o);

        // Residual
        for (0..hidden_size) |i| {
            hidden[i] += model.buf_attn_proj[i];
        }

        // FFN (ternary norm if enabled)
        TriModel.applyRmsNorm(model.buf_normed, hidden, layer.ffn_norm, layer.ternary_ffn_norm, header.rms_norm_eps);
        parallel.parallelTernaryMatmul(model.buf_ffn_gate, layer.w_gate, model.buf_normed, intermediate_size, hidden_size, layer.scale_gate);
        parallel.parallelTernaryMatmul(model.buf_ffn_up, layer.w_up, model.buf_normed, intermediate_size, hidden_size, layer.scale_up);

        // SwiGLU (gate * silu(gate) * up)
        for (0..intermediate_size) |i| {
            model.buf_ffn_gate[i] = inference.silu(model.buf_ffn_gate[i]) * model.buf_ffn_up[i];
        }

        parallel.parallelTernaryMatmul(model.buf_ffn_out, layer.w_down, model.buf_ffn_gate, hidden_size, intermediate_size, layer.scale_down);

        // Residual
        for (0..hidden_size) |i| {
            hidden[i] += model.buf_ffn_out[i];
        }
    }

    /// Batch forward for multiple sequences
    /// Returns array of logits for each active sequence
    pub fn batchForward(self: *BatchTriModel, tokens: []const BatchToken) !void {
        for (tokens) |bt| {
            _ = try self.forwardSequence(bt.seq_idx, bt.token);
        }
    }

    /// Get number of active sequences
    pub fn activeCount(self: *const BatchTriModel) usize {
        return self.batch_cache.activeCount();
    }

    /// Memory usage
    pub fn memoryUsage(self: *const BatchTriModel) usize {
        return self.batch_cache.memoryUsage();
    }
};

/// Token with sequence ID for batch processing
pub const BatchToken = struct {
    seq_idx: usize,
    token: u32,
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN - Benchmark TRI vs GGUF
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const path = if (args.len > 1) args[1] else "models/smollm2-360m.tri";

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           TRI INFERENCE - TERNARY SPEEDUP                    ║\n", .{});
    std.debug.print("║           φ² + 1/φ² = 3 = TRINITY                            ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    var model = try TriModel.init(allocator, path);
    defer model.deinit();

    // Generate tokens
    std.debug.print("\nGENERATING TEXT\n", .{});
    std.debug.print("================\n", .{});

    var current_token: u32 = 1; // BOS
    const num_tokens: usize = 20;
    const temperature: f32 = 0.7;

    model.resetKVCache();
    var timer = try std.time.Timer.start();

    var generated: [32]u32 = undefined;
    var i: usize = 0;
    while (i < num_tokens) : (i += 1) {
        const next_token = model.generate(current_token, i, temperature) catch |err| {
            std.debug.print("\nGeneration error at token {d}: {}\n", .{ i, err });
            break;
        };
        generated[i] = next_token;
        current_token = next_token;

        if ((i + 1) % 5 == 0) {
            std.debug.print("  Generated {d}/{d} tokens...\r", .{ i + 1, num_tokens });
        }
    }

    const gen_time = timer.read();

    std.debug.print("\n\nGenerated tokens: ", .{});
    for (generated[0..i]) |t| {
        std.debug.print("{d} ", .{t});
    }

    std.debug.print("\n\nSTATS\n", .{});
    std.debug.print("  Tokens generated: {d}\n", .{i});
    std.debug.print("  Time: {d:.2} seconds\n", .{@as(f64, @floatFromInt(gen_time)) / 1e9});
    std.debug.print("  Speed: {d:.2} tokens/sec\n", .{@as(f64, @floatFromInt(i)) / (@as(f64, @floatFromInt(gen_time)) / 1e9)});

    std.debug.print("\nKOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED\n", .{});
}
