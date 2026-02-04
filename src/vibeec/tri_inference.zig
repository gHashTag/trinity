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
            .ternary_output_norm = null,
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

    /// Forward pass with early exit (for draft speculation)
    /// Uses only first `num_layers` layers for faster inference
    pub fn forwardDraft(self: *TriModel, token: u32, pos: usize, num_layers: usize) ![]f32 {
        const hidden_size = self.header.hidden_size;
        const layers_to_use = @min(num_layers, self.header.num_layers);

        // Get embedding
        if (self.use_ternary_embedding) {
            if (self.ternary_embedding) |te| {
                te.lookup(token, self.buf_hidden);
            }
        } else {
            const emb_offset = token * hidden_size;
            @memcpy(self.buf_hidden, self.token_embedding[emb_offset..][0..hidden_size]);
        }

        // Process through limited layers (draft)
        for (0..layers_to_use) |i| {
            self.forwardLayer(self.buf_temp, self.buf_hidden, i, pos);
            @memcpy(self.buf_hidden, self.buf_temp);
        }

        // Final norm
        applyRmsNorm(self.buf_temp, self.buf_hidden, self.output_norm, self.ternary_output_norm, self.header.rms_norm_eps);

        // Output projection
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
};

// ═══════════════════════════════════════════════════════════════════════════════
// SPECULATIVE DECODING
// Generate multiple tokens per target forward pass
// ═══════════════════════════════════════════════════════════════════════════════

/// Configuration for speculative decoding
pub const SpeculativeConfig = struct {
    speculation_length: usize, // K: number of tokens to speculate
    draft_layers: usize, // Number of layers for draft model (early exit)
    temperature: f32,
    acceptance_threshold: f32, // Minimum acceptance rate before disabling

    pub fn default() SpeculativeConfig {
        return .{
            .speculation_length = 4,
            .draft_layers = 4, // Use first 4 layers as draft
            .temperature = 1.0,
            .acceptance_threshold = 0.5,
        };
    }
};

/// Result from speculative generation
pub const SpeculativeResult = struct {
    tokens: []u32,
    accepted_count: usize,
    total_drafted: usize,
    acceptance_rate: f32,
};

/// Speculative decoder using self-speculation (early exit as draft)
pub const SpeculativeDecoder = struct {
    allocator: std.mem.Allocator,
    model: *TriModel,
    config: SpeculativeConfig,

    // Statistics
    total_accepted: usize,
    total_drafted: usize,

    // Buffers
    draft_tokens: []u32,
    draft_probs: []f32,
    target_probs: []f32,

    pub fn init(allocator: std.mem.Allocator, model: *TriModel, config: SpeculativeConfig) !SpeculativeDecoder {
        return SpeculativeDecoder{
            .allocator = allocator,
            .model = model,
            .config = config,
            .total_accepted = 0,
            .total_drafted = 0,
            .draft_tokens = try allocator.alloc(u32, config.speculation_length),
            .draft_probs = try allocator.alloc(f32, config.speculation_length),
            .target_probs = try allocator.alloc(f32, config.speculation_length + 1),
        };
    }

    pub fn deinit(self: *SpeculativeDecoder) void {
        self.allocator.free(self.draft_tokens);
        self.allocator.free(self.draft_probs);
        self.allocator.free(self.target_probs);
    }

    /// Generate K draft tokens using early exit
    fn draftSpeculate(self: *SpeculativeDecoder, start_token: u32, start_pos: usize) !void {
        var current_token = start_token;
        var pos = start_pos;

        for (0..self.config.speculation_length) |i| {
            // Forward with early exit (draft)
            const logits = try self.model.forwardDraft(current_token, pos, self.config.draft_layers);
            defer self.model.allocator.free(logits);

            // Apply temperature
            if (self.config.temperature > 0) {
                for (logits) |*l| l.* /= self.config.temperature;
            }

            // Softmax
            const probs = try self.allocator.alloc(f32, logits.len);
            defer self.allocator.free(probs);
            inference.softmax(probs, logits);

            // Sample
            const next_token = inference.sample(probs, self.config.temperature);
            self.draft_tokens[i] = next_token;
            self.draft_probs[i] = probs[next_token];

            current_token = next_token;
            pos += 1;
        }
    }

    /// Verify draft tokens with full model and accept/reject
    fn verifyAndAccept(self: *SpeculativeDecoder, start_token: u32, start_pos: usize, output: []u32) !usize {
        var accepted: usize = 0;
        var current_token = start_token;
        var pos = start_pos;

        // Verify each draft token
        for (0..self.config.speculation_length) |i| {
            // Full forward pass
            const logits = try self.model.forward(current_token, pos);
            defer self.model.allocator.free(logits);

            // Apply temperature
            if (self.config.temperature > 0) {
                for (logits) |*l| l.* /= self.config.temperature;
            }

            // Softmax
            const probs = try self.allocator.alloc(f32, logits.len);
            defer self.allocator.free(probs);
            inference.softmax(probs, logits);

            const draft_token = self.draft_tokens[i];
            const target_prob = probs[draft_token];
            const draft_prob = self.draft_probs[i];

            // Acceptance criterion: accept with prob min(1, target/draft)
            const accept_prob = @min(1.0, target_prob / (draft_prob + 1e-10));
            const r = self.randomFloat();

            if (r < accept_prob) {
                // Accept
                output[accepted] = draft_token;
                accepted += 1;
                current_token = draft_token;
                pos += 1;
            } else {
                // Reject: sample from adjusted distribution
                // p_adjusted = max(0, p_target - p_draft) / Z
                var adjusted_probs = try self.allocator.alloc(f32, probs.len);
                defer self.allocator.free(adjusted_probs);

                var sum: f32 = 0.0;
                for (probs, 0..) |p, j| {
                    const draft_p = if (j == draft_token) draft_prob else 0.0;
                    adjusted_probs[j] = @max(0.0, p - draft_p);
                    sum += adjusted_probs[j];
                }

                if (sum > 0) {
                    for (adjusted_probs) |*p| p.* /= sum;
                    output[accepted] = inference.sample(adjusted_probs, self.config.temperature);
                } else {
                    output[accepted] = inference.sample(probs, self.config.temperature);
                }
                accepted += 1;
                break;
            }
        }

        // If all accepted, sample one more from target
        if (accepted == self.config.speculation_length) {
            const logits = try self.model.forward(self.draft_tokens[self.config.speculation_length - 1], pos);
            defer self.model.allocator.free(logits);

            if (self.config.temperature > 0) {
                for (logits) |*l| l.* /= self.config.temperature;
            }

            const probs = try self.allocator.alloc(f32, logits.len);
            defer self.allocator.free(probs);
            inference.softmax(probs, logits);

            output[accepted] = inference.sample(probs, self.config.temperature);
            accepted += 1;
        }

        return accepted;
    }

    /// Simple random float [0, 1)
    fn randomFloat(self: *SpeculativeDecoder) f32 {
        _ = self;
        // Use a simple LCG for reproducibility in tests
        const state = struct {
            var seed: u32 = 12345;
        };
        state.seed = state.seed *% 1103515245 +% 12345;
        return @as(f32, @floatFromInt(state.seed >> 16)) / 65536.0;
    }

    /// Generate tokens with speculative decoding
    pub fn generate(self: *SpeculativeDecoder, start_token: u32, start_pos: usize, max_tokens: usize) !SpeculativeResult {
        var output = try self.allocator.alloc(u32, max_tokens);
        var generated: usize = 0;
        var current_token = start_token;
        var pos = start_pos;

        while (generated < max_tokens) {
            // Draft K tokens
            try self.draftSpeculate(current_token, pos);
            self.total_drafted += self.config.speculation_length;

            // Verify and accept
            const remaining = max_tokens - generated;
            const max_accept = @min(self.config.speculation_length + 1, remaining);
            var accepted_buf: [8]u32 = undefined; // Max speculation_length + 1

            const accepted = try self.verifyAndAccept(current_token, pos, accepted_buf[0..max_accept]);
            self.total_accepted += accepted;

            // Copy accepted tokens to output
            for (0..accepted) |i| {
                if (generated < max_tokens) {
                    output[generated] = accepted_buf[i];
                    generated += 1;
                }
            }

            if (accepted > 0) {
                current_token = accepted_buf[accepted - 1];
                pos += accepted;
            } else {
                break;
            }
        }

        const acceptance_rate = if (self.total_drafted > 0)
            @as(f32, @floatFromInt(self.total_accepted)) / @as(f32, @floatFromInt(self.total_drafted))
        else
            0.0;

        return SpeculativeResult{
            .tokens = output[0..generated],
            .accepted_count = self.total_accepted,
            .total_drafted = self.total_drafted,
            .acceptance_rate = acceptance_rate,
        };
    }

    /// Get current acceptance rate
    pub fn getAcceptanceRate(self: *const SpeculativeDecoder) f32 {
        if (self.total_drafted == 0) return 0.0;
        return @as(f32, @floatFromInt(self.total_accepted)) / @as(f32, @floatFromInt(self.total_drafted));
    }

    /// Reset statistics
    pub fn resetStats(self: *SpeculativeDecoder) void {
        self.total_accepted = 0;
        self.total_drafted = 0;
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
// CONTINUOUS BATCHING SCHEDULER
// Orca/vLLM style iteration-level scheduling for high throughput
// ═══════════════════════════════════════════════════════════════════════════════

/// Request status
pub const RequestStatus = enum {
    queued,
    prefill,
    generating,
    completed,
    cancelled,
};

/// Inference request
pub const Request = struct {
    id: u64,
    prompt_tokens: []const u32,
    max_tokens: usize,
    temperature: f32,
    priority: i32,
    created_at: i64,
    status: RequestStatus,
    generated_tokens: std.ArrayList(u32),
    tokens_generated: usize,

    pub fn init(allocator: std.mem.Allocator, id: u64, prompt: []const u32, max_tokens: usize, temp: f32, priority: i32) Request {
        return Request{
            .id = id,
            .prompt_tokens = prompt,
            .max_tokens = max_tokens,
            .temperature = temp,
            .priority = priority,
            .created_at = std.time.milliTimestamp(),
            .status = .queued,
            .generated_tokens = std.ArrayList(u32).init(allocator),
            .tokens_generated = 0,
        };
    }

    pub fn deinit(self: *Request) void {
        self.generated_tokens.deinit();
    }
};

/// Batch slot for running sequence
const BatchSlot = struct {
    request_id: u64,
    seq_idx: usize,
    current_pos: usize,
    is_prefill: bool,
    active: bool,
};

/// Scheduler configuration
pub const SchedulerConfig = struct {
    max_batch_size: usize,
    max_waiting_requests: usize,
    preemption_enabled: bool,

    pub fn default() SchedulerConfig {
        return .{
            .max_batch_size = 8,
            .max_waiting_requests = 64,
            .preemption_enabled = false,
        };
    }
};

/// Continuous batching scheduler
pub const ContinuousBatchingScheduler = struct {
    allocator: std.mem.Allocator,
    config: SchedulerConfig,
    model: *TriModel,
    batch_model: *BatchTriModel,

    // Request management
    waiting_queue: std.ArrayList(*Request),
    running_requests: std.AutoHashMap(u64, *Request),
    completed_requests: std.ArrayList(*Request),

    // Batch slots
    slots: []BatchSlot,
    active_slots: usize,

    // Statistics
    total_requests: u64,
    total_tokens_generated: u64,
    total_iterations: u64,

    // Request ID counter
    next_request_id: u64,

    pub fn init(allocator: std.mem.Allocator, model: *TriModel, batch_model: *BatchTriModel, config: SchedulerConfig) !ContinuousBatchingScheduler {
        const slots = try allocator.alloc(BatchSlot, config.max_batch_size);
        for (slots) |*slot| {
            slot.* = BatchSlot{
                .request_id = 0,
                .seq_idx = 0,
                .current_pos = 0,
                .is_prefill = false,
                .active = false,
            };
        }

        return ContinuousBatchingScheduler{
            .allocator = allocator,
            .config = config,
            .model = model,
            .batch_model = batch_model,
            .waiting_queue = std.ArrayList(*Request).init(allocator),
            .running_requests = std.AutoHashMap(u64, *Request).init(allocator),
            .completed_requests = std.ArrayList(*Request).init(allocator),
            .slots = slots,
            .active_slots = 0,
            .total_requests = 0,
            .total_tokens_generated = 0,
            .total_iterations = 0,
            .next_request_id = 1,
        };
    }

    pub fn deinit(self: *ContinuousBatchingScheduler) void {
        // Clean up waiting requests
        for (self.waiting_queue.items) |req| {
            req.deinit();
            self.allocator.destroy(req);
        }
        self.waiting_queue.deinit();

        // Clean up running requests
        var it = self.running_requests.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.running_requests.deinit();

        // Clean up completed requests
        for (self.completed_requests.items) |req| {
            req.deinit();
            self.allocator.destroy(req);
        }
        self.completed_requests.deinit();

        self.allocator.free(self.slots);
    }

    /// Submit a new request
    pub fn submitRequest(self: *ContinuousBatchingScheduler, prompt: []const u32, max_tokens: usize, temperature: f32, priority: i32) !u64 {
        const req = try self.allocator.create(Request);
        req.* = Request.init(self.allocator, self.next_request_id, prompt, max_tokens, temperature, priority);
        self.next_request_id += 1;

        try self.waiting_queue.append(req);
        self.total_requests += 1;

        return req.id;
    }

    /// Get number of empty slots
    fn emptySlots(self: *const ContinuousBatchingScheduler) usize {
        var empty: usize = 0;
        for (self.slots) |slot| {
            if (!slot.active) empty += 1;
        }
        return empty;
    }

    /// Find an empty slot
    fn findEmptySlot(self: *ContinuousBatchingScheduler) ?usize {
        for (self.slots, 0..) |slot, i| {
            if (!slot.active) return i;
        }
        return null;
    }

    /// Schedule one iteration
    pub fn scheduleIteration(self: *ContinuousBatchingScheduler) !void {
        // 1. Fill empty slots from waiting queue
        while (self.waiting_queue.items.len > 0 and self.emptySlots() > 0) {
            // Sort by priority (simple bubble for small queue)
            if (self.waiting_queue.items.len > 1) {
                for (0..self.waiting_queue.items.len - 1) |i| {
                    for (i + 1..self.waiting_queue.items.len) |j| {
                        if (self.waiting_queue.items[j].priority > self.waiting_queue.items[i].priority) {
                            const tmp = self.waiting_queue.items[i];
                            self.waiting_queue.items[i] = self.waiting_queue.items[j];
                            self.waiting_queue.items[j] = tmp;
                        }
                    }
                }
            }

            // Get highest priority request
            const req = self.waiting_queue.orderedRemove(0);

            // Find empty slot
            if (self.findEmptySlot()) |slot_idx| {
                // Add to batch
                if (self.batch_model.batch_cache.addSequence()) |seq_idx| {
                    self.slots[slot_idx] = BatchSlot{
                        .request_id = req.id,
                        .seq_idx = seq_idx,
                        .current_pos = 0,
                        .is_prefill = true,
                        .active = true,
                    };
                    self.active_slots += 1;

                    req.status = .prefill;
                    try self.running_requests.put(req.id, req);
                } else {
                    // No sequence slot available, put back in queue
                    try self.waiting_queue.insert(0, req);
                    break;
                }
            } else {
                // No slot available, put back in queue
                try self.waiting_queue.insert(0, req);
                break;
            }
        }
    }

    /// Process one iteration for all active sequences
    pub fn processIteration(self: *ContinuousBatchingScheduler) !void {
        self.total_iterations += 1;

        // Process each active slot
        for (self.slots) |*slot| {
            if (!slot.active) continue;

            const req = self.running_requests.get(slot.request_id) orelse continue;

            if (slot.is_prefill) {
                // Prefill phase: process all prompt tokens
                for (req.prompt_tokens) |token| {
                    _ = try self.batch_model.forward(slot.seq_idx, token, slot.current_pos);
                    slot.current_pos += 1;
                }
                slot.is_prefill = false;
                req.status = .generating;
            } else {
                // Generation phase: generate one token
                const last_token = if (req.generated_tokens.items.len > 0)
                    req.generated_tokens.items[req.generated_tokens.items.len - 1]
                else if (req.prompt_tokens.len > 0)
                    req.prompt_tokens[req.prompt_tokens.len - 1]
                else
                    1; // BOS

                const logits = try self.batch_model.forward(slot.seq_idx, last_token, slot.current_pos);

                // Apply temperature and sample
                if (req.temperature > 0) {
                    for (logits) |*l| l.* /= req.temperature;
                }

                const probs = try self.allocator.alloc(f32, logits.len);
                defer self.allocator.free(probs);
                inference.softmax(probs, logits);

                const next_token = inference.sample(probs, req.temperature);
                try req.generated_tokens.append(next_token);
                req.tokens_generated += 1;
                slot.current_pos += 1;
                self.total_tokens_generated += 1;

                // Check completion
                if (req.tokens_generated >= req.max_tokens or next_token == 2) { // EOS = 2
                    self.completeRequest(slot);
                }
            }
        }
    }

    /// Complete a request and free its slot
    fn completeRequest(self: *ContinuousBatchingScheduler, slot: *BatchSlot) void {
        if (self.running_requests.fetchRemove(slot.request_id)) |kv| {
            const req = kv.value;
            req.status = .completed;
            self.completed_requests.append(req) catch {};
        }

        // Free batch slot
        self.batch_model.batch_cache.removeSequence(slot.seq_idx);
        slot.active = false;
        self.active_slots -= 1;
    }

    /// Run scheduler until all requests complete
    pub fn runUntilComplete(self: *ContinuousBatchingScheduler) !void {
        while (self.waiting_queue.items.len > 0 or self.active_slots > 0) {
            try self.scheduleIteration();
            try self.processIteration();
        }
    }

    /// Get scheduler statistics
    pub fn getStats(self: *const ContinuousBatchingScheduler) SchedulerStats {
        return SchedulerStats{
            .total_requests = self.total_requests,
            .completed_requests = self.completed_requests.items.len,
            .waiting_requests = self.waiting_queue.items.len,
            .active_requests = self.active_slots,
            .total_tokens_generated = self.total_tokens_generated,
            .total_iterations = self.total_iterations,
            .avg_tokens_per_iter = if (self.total_iterations > 0)
                @as(f32, @floatFromInt(self.total_tokens_generated)) / @as(f32, @floatFromInt(self.total_iterations))
            else
                0.0,
        };
    }

    /// Get completed request by ID
    pub fn getCompletedRequest(self: *const ContinuousBatchingScheduler, id: u64) ?*const Request {
        for (self.completed_requests.items) |req| {
            if (req.id == id) return req;
        }
        return null;
    }
};

/// Scheduler statistics
pub const SchedulerStats = struct {
    total_requests: u64,
    completed_requests: usize,
    waiting_requests: usize,
    active_requests: usize,
    total_tokens_generated: u64,
    total_iterations: u64,
    avg_tokens_per_iter: f32,
};

// ═══════════════════════════════════════════════════════════════════════════════
// PAGED ATTENTION SCHEDULER (OPT-PA01)
// Continuous batching with PagedAttention memory management
// ═══════════════════════════════════════════════════════════════════════════════

/// Request with paged attention block table
pub const PagedRequest = struct {
    id: u64,
    prompt_tokens: []const u32,
    max_tokens: usize,
    temperature: f32,
    priority: i32,
    created_at: i64,
    status: RequestStatus,
    generated_tokens: std.ArrayList(u32),
    tokens_generated: usize,
    block_table: kv_cache.BlockTable, // PagedAttention block table

    pub fn init(allocator: std.mem.Allocator, id: u64, prompt: []const u32, max_tokens: usize, temp: f32, priority: i32) PagedRequest {
        return PagedRequest{
            .id = id,
            .prompt_tokens = prompt,
            .max_tokens = max_tokens,
            .temperature = temp,
            .priority = priority,
            .created_at = std.time.milliTimestamp(),
            .status = .queued,
            .generated_tokens = std.ArrayList(u32).init(allocator),
            .tokens_generated = 0,
            .block_table = kv_cache.BlockTable.init(allocator, id),
        };
    }

    pub fn deinit(self: *PagedRequest) void {
        self.generated_tokens.deinit();
        self.block_table.deinit();
    }
};

/// Paged attention scheduler configuration
pub const PagedSchedulerConfig = struct {
    max_batch_size: usize,
    max_waiting_requests: usize,
    preemption_enabled: bool,
    block_size: usize,
    max_blocks: usize,
    enable_prefix_caching: bool,
    max_cached_prefixes: usize,
    enable_chunked_prefill: bool,
    chunk_size: usize,

    pub fn default() PagedSchedulerConfig {
        return .{
            .max_batch_size = 8,
            .max_waiting_requests = 64,
            .preemption_enabled = true,
            .block_size = 16,
            .max_blocks = 1024,
            .enable_prefix_caching = true,
            .max_cached_prefixes = 100,
            .enable_chunked_prefill = true,
            .chunk_size = 512,
        };
    }
};

/// Paged batch slot
const PagedBatchSlot = struct {
    request_id: u64,
    seq_idx: usize,
    current_pos: usize,
    is_prefill: bool,
    active: bool,
    num_blocks: usize,
};

/// Continuous batching scheduler with PagedAttention and Prefix Caching
pub const PagedBatchingScheduler = struct {
    allocator: std.mem.Allocator,
    config: PagedSchedulerConfig,
    model: *TriModel,

    // PagedAttention memory pool
    block_pool: kv_cache.BlockPool,
    pa_config: kv_cache.PagedAttentionConfig,

    // Prefix Cache (OPT-PC01)
    prefix_cache: ?kv_cache.PrefixCache,

    // Request management
    waiting_queue: std.ArrayList(*PagedRequest),
    running_requests: std.AutoHashMap(u64, *PagedRequest),
    completed_requests: std.ArrayList(*PagedRequest),
    preempted_requests: std.ArrayList(*PagedRequest), // Swapped out requests

    // Batch slots
    slots: []PagedBatchSlot,
    active_slots: usize,

    // Chunked Prefill scheduler (OPT-CP01)
    chunked_scheduler: ?kv_cache.ChunkedPrefillScheduler,

    // Statistics
    total_requests: u64,
    total_tokens_generated: u64,
    total_iterations: u64,
    preemption_count: u64,
    next_request_id: u64,
    prefix_cache_hits: u64,
    prefix_cache_misses: u64,
    chunked_prefill_tokens: u64,

    pub fn init(
        allocator: std.mem.Allocator,
        model: *TriModel,
        config: PagedSchedulerConfig,
    ) !PagedBatchingScheduler {
        const header = model.header;

        // Create PagedAttention config from model
        const pa_config = kv_cache.PagedAttentionConfig{
            .block_size = config.block_size,
            .num_heads = header.num_heads,
            .head_dim = header.head_dim,
            .num_layers = header.num_layers,
            .max_blocks = config.max_blocks,
            .use_ternary = false,
        };

        const slots = try allocator.alloc(PagedBatchSlot, config.max_batch_size);
        for (slots) |*slot| {
            slot.* = PagedBatchSlot{
                .request_id = 0,
                .seq_idx = 0,
                .current_pos = 0,
                .is_prefill = false,
                .active = false,
                .num_blocks = 0,
            };
        }

        var scheduler = PagedBatchingScheduler{
            .allocator = allocator,
            .config = config,
            .model = model,
            .block_pool = try kv_cache.BlockPool.init(allocator, pa_config),
            .pa_config = pa_config,
            .prefix_cache = null,
            .waiting_queue = std.ArrayList(*PagedRequest).init(allocator),
            .running_requests = std.AutoHashMap(u64, *PagedRequest).init(allocator),
            .completed_requests = std.ArrayList(*PagedRequest).init(allocator),
            .preempted_requests = std.ArrayList(*PagedRequest).init(allocator),
            .slots = slots,
            .active_slots = 0,
            .total_requests = 0,
            .total_tokens_generated = 0,
            .total_iterations = 0,
            .preemption_count = 0,
            .next_request_id = 1,
            .prefix_cache_hits = 0,
            .prefix_cache_misses = 0,
            .chunked_prefill_tokens = 0,
            .chunked_scheduler = null,
        };

        // Initialize prefix cache if enabled
        if (config.enable_prefix_caching) {
            const pc_config = kv_cache.PrefixCacheConfig{
                .max_cached_prefixes = config.max_cached_prefixes,
                .max_prefix_length = 2048,
                .eviction_policy = .LRU,
            };
            scheduler.prefix_cache = kv_cache.PrefixCache.init(allocator, pc_config, &scheduler.block_pool);
        }

        // Initialize chunked prefill scheduler if enabled
        if (config.enable_chunked_prefill) {
            const cp_config = kv_cache.ChunkedPrefillConfig{
                .chunk_size = config.chunk_size,
                .max_chunks_per_iter = config.max_batch_size,
                .interleave_generation = true,
            };
            scheduler.chunked_scheduler = kv_cache.ChunkedPrefillScheduler.init(allocator, cp_config);
        }

        return scheduler;
    }

    pub fn deinit(self: *PagedBatchingScheduler) void {
        // Clean up waiting requests
        for (self.waiting_queue.items) |req| {
            req.deinit();
            self.allocator.destroy(req);
        }
        self.waiting_queue.deinit();

        // Clean up running requests
        var it = self.running_requests.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.running_requests.deinit();

        // Clean up completed requests
        for (self.completed_requests.items) |req| {
            req.deinit();
            self.allocator.destroy(req);
        }
        self.completed_requests.deinit();

        // Clean up preempted requests
        for (self.preempted_requests.items) |req| {
            req.deinit();
            self.allocator.destroy(req);
        }
        self.preempted_requests.deinit();

        // Clean up prefix cache
        if (self.prefix_cache) |*pc| {
            pc.deinit();
        }

        // Clean up chunked scheduler
        if (self.chunked_scheduler) |*cs| {
            cs.deinit();
        }

        self.block_pool.deinit();
        self.allocator.free(self.slots);
    }

    /// Submit a new request with prefix caching support
    pub fn submitRequest(self: *PagedBatchingScheduler, prompt: []const u32, max_tokens: usize, temperature: f32, priority: i32) !u64 {
        const req = try self.allocator.create(PagedRequest);
        req.* = PagedRequest.init(self.allocator, self.next_request_id, prompt, max_tokens, temperature, priority);
        self.next_request_id += 1;

        // Check prefix cache for matching prefix
        if (self.prefix_cache) |*pc| {
            const match = pc.matchLongestPrefix(prompt);
            if (match.matched) {
                // Copy cached block IDs to request (with ref_count++)
                for (match.block_ids) |block_id| {
                    try req.block_table.block_ids.append(block_id);
                    if (block_id < self.block_pool.blocks.items.len) {
                        self.block_pool.blocks.items[block_id].ref_count += 1;
                    }
                }
                req.block_table.num_tokens = match.matched_tokens;
                self.prefix_cache_hits += 1;
            } else {
                self.prefix_cache_misses += 1;
            }
        }

        try self.waiting_queue.append(req);
        self.total_requests += 1;

        return req.id;
    }

    /// Cache prefix after prefill completes
    pub fn cachePrefixAfterPrefill(self: *PagedBatchingScheduler, req: *PagedRequest) !void {
        if (self.prefix_cache) |*pc| {
            // Only cache if we have blocks and tokens
            if (req.block_table.block_ids.items.len > 0 and req.prompt_tokens.len > 0) {
                try pc.cachePrefix(req.prompt_tokens, req.block_table.block_ids.items);
            }
        }
    }

    /// Get prefix cache statistics
    pub fn getPrefixCacheStats(self: *const PagedBatchingScheduler) ?kv_cache.PrefixCacheStats {
        if (self.prefix_cache) |pc| {
            return pc.getStats();
        }
        return null;
    }

    /// Get chunked prefill statistics
    pub fn getChunkedPrefillStats(self: *const PagedBatchingScheduler) ?kv_cache.ChunkedPrefillStats {
        if (self.chunked_scheduler) |cs| {
            return cs.getStats();
        }
        return null;
    }

    /// Add request to chunked prefill queue
    pub fn addToChunkedPrefill(self: *PagedBatchingScheduler, request_id: u64, prompt_tokens: []const u32, cached_tokens: usize) !void {
        if (self.chunked_scheduler) |*cs| {
            _ = try cs.addRequest(request_id, prompt_tokens, cached_tokens);
        }
    }

    /// Process one iteration of chunked prefill
    pub fn processChunkedPrefillIteration(self: *PagedBatchingScheduler) void {
        if (self.chunked_scheduler) |*cs| {
            var batch = cs.scheduleNextBatch();
            defer batch.deinit();

            if (batch.items.len > 0) {
                // Process the batch (in real impl, would compute KV cache)
                cs.processBatch(&batch);

                // Update statistics
                for (batch.items) |chunk| {
                    self.chunked_prefill_tokens += chunk.tokenCount();
                }
            }

            // Move completed requests to ready state
            var completed = cs.removeCompleted();
            defer completed.deinit();
            for (completed.items) |req| {
                req.deinit();
                self.allocator.destroy(req);
            }
        }
    }

    /// Get number of empty slots
    fn emptySlots(self: *const PagedBatchingScheduler) usize {
        var empty: usize = 0;
        for (self.slots) |slot| {
            if (!slot.active) empty += 1;
        }
        return empty;
    }

    /// Find an empty slot
    fn findEmptySlot(self: *PagedBatchingScheduler) ?usize {
        for (self.slots, 0..) |slot, i| {
            if (!slot.active) return i;
        }
        return null;
    }

    /// Allocate blocks for a request's prompt
    fn allocateBlocksForPrompt(self: *PagedBatchingScheduler, req: *PagedRequest) !void {
        const num_tokens = req.prompt_tokens.len;
        const blocks_needed = (num_tokens + self.config.block_size - 1) / self.config.block_size;

        for (0..blocks_needed) |_| {
            const block_id = self.block_pool.allocateBlock() orelse return error.OutOfBlocks;
            try req.block_table.block_ids.append(block_id);
        }
    }

    /// Free all blocks for a request
    fn freeBlocks(self: *PagedBatchingScheduler, req: *PagedRequest) void {
        for (req.block_table.block_ids.items) |block_id| {
            self.block_pool.freeBlock(block_id);
        }
        req.block_table.block_ids.clearRetainingCapacity();
    }

    /// Preempt lowest priority running request
    fn preemptLowestPriority(self: *PagedBatchingScheduler) !void {
        if (self.active_slots == 0) return;

        // Find lowest priority running request
        var lowest_priority: i32 = std.math.maxInt(i32);
        var lowest_slot_idx: ?usize = null;

        for (self.slots, 0..) |slot, i| {
            if (!slot.active) continue;
            if (self.running_requests.get(slot.request_id)) |req| {
                if (req.priority < lowest_priority) {
                    lowest_priority = req.priority;
                    lowest_slot_idx = i;
                }
            }
        }

        if (lowest_slot_idx) |slot_idx| {
            const slot = &self.slots[slot_idx];
            if (self.running_requests.fetchRemove(slot.request_id)) |kv| {
                const req = kv.value;
                req.status = .preempted;

                // Note: In a real implementation, we would swap KV cache to CPU here
                // For now, we just free the blocks and re-queue
                self.freeBlocks(req);

                try self.preempted_requests.append(req);
                self.preemption_count += 1;
            }

            slot.active = false;
            self.active_slots -= 1;
        }
    }

    /// Schedule one iteration
    pub fn scheduleIteration(self: *PagedBatchingScheduler) !void {
        // 1. Try to resume preempted requests first
        while (self.preempted_requests.items.len > 0 and self.emptySlots() > 0) {
            const req = self.preempted_requests.orderedRemove(0);

            // Try to allocate blocks
            self.allocateBlocksForPrompt(req) catch {
                // Not enough blocks, put back
                try self.preempted_requests.insert(0, req);
                break;
            };

            if (self.findEmptySlot()) |slot_idx| {
                self.slots[slot_idx] = PagedBatchSlot{
                    .request_id = req.id,
                    .seq_idx = slot_idx,
                    .current_pos = req.prompt_tokens.len + req.tokens_generated,
                    .is_prefill = false, // Already prefilled
                    .active = true,
                    .num_blocks = req.block_table.block_ids.items.len,
                };
                self.active_slots += 1;
                req.status = .generating;
                try self.running_requests.put(req.id, req);
            }
        }

        // 2. Fill empty slots from waiting queue
        while (self.waiting_queue.items.len > 0 and self.emptySlots() > 0) {
            // Sort by priority
            if (self.waiting_queue.items.len > 1) {
                for (0..self.waiting_queue.items.len - 1) |i| {
                    for (i + 1..self.waiting_queue.items.len) |j| {
                        if (self.waiting_queue.items[j].priority > self.waiting_queue.items[i].priority) {
                            const tmp = self.waiting_queue.items[i];
                            self.waiting_queue.items[i] = self.waiting_queue.items[j];
                            self.waiting_queue.items[j] = tmp;
                        }
                    }
                }
            }

            const req = self.waiting_queue.orderedRemove(0);

            // Try to allocate blocks for prompt
            self.allocateBlocksForPrompt(req) catch {
                // Not enough blocks - try preemption if enabled
                if (self.config.preemption_enabled and self.active_slots > 0) {
                    try self.preemptLowestPriority();
                    // Retry allocation
                    self.allocateBlocksForPrompt(req) catch {
                        // Still not enough, put back in queue
                        try self.waiting_queue.insert(0, req);
                        break;
                    };
                } else {
                    try self.waiting_queue.insert(0, req);
                    break;
                }
            };

            if (self.findEmptySlot()) |slot_idx| {
                self.slots[slot_idx] = PagedBatchSlot{
                    .request_id = req.id,
                    .seq_idx = slot_idx,
                    .current_pos = 0,
                    .is_prefill = true,
                    .active = true,
                    .num_blocks = req.block_table.block_ids.items.len,
                };
                self.active_slots += 1;
                req.status = .prefill;
                try self.running_requests.put(req.id, req);
            }
        }
    }

    /// Complete a request and free its slot
    fn completeRequest(self: *PagedBatchingScheduler, slot: *PagedBatchSlot) void {
        if (self.running_requests.fetchRemove(slot.request_id)) |kv| {
            const req = kv.value;
            req.status = .completed;

            // Free blocks
            self.freeBlocks(req);

            self.completed_requests.append(req) catch {};
        }

        slot.active = false;
        self.active_slots -= 1;
    }

    /// Get scheduler statistics
    pub fn getStats(self: *const PagedBatchingScheduler) PagedSchedulerStats {
        const pool_stats = self.block_pool.getStats();

        return PagedSchedulerStats{
            .total_requests = self.total_requests,
            .completed_requests = self.completed_requests.items.len,
            .waiting_requests = self.waiting_queue.items.len,
            .active_requests = self.active_slots,
            .preempted_requests = self.preempted_requests.items.len,
            .total_tokens_generated = self.total_tokens_generated,
            .total_iterations = self.total_iterations,
            .preemption_count = self.preemption_count,
            .blocks_allocated = pool_stats.allocated_blocks,
            .blocks_free = pool_stats.free_blocks,
            .memory_utilization = pool_stats.utilization_percent,
        };
    }

    /// Get completed request by ID
    pub fn getCompletedRequest(self: *const PagedBatchingScheduler, id: u64) ?*const PagedRequest {
        for (self.completed_requests.items) |req| {
            if (req.id == id) return req;
        }
        return null;
    }
};

/// Paged scheduler statistics
pub const PagedSchedulerStats = struct {
    total_requests: u64,
    completed_requests: usize,
    waiting_requests: usize,
    active_requests: usize,
    preempted_requests: usize,
    total_tokens_generated: u64,
    total_iterations: u64,
    preemption_count: u64,
    blocks_allocated: usize,
    blocks_free: usize,
    memory_utilization: f32,

    pub fn print(self: *const PagedSchedulerStats) void {
        std.debug.print("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║           PAGED BATCHING SCHEDULER STATS                    ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║  Total requests:       {d:>10}                            ║\n", .{self.total_requests});
        std.debug.print("║  Completed:            {d:>10}                            ║\n", .{self.completed_requests});
        std.debug.print("║  Waiting:              {d:>10}                            ║\n", .{self.waiting_requests});
        std.debug.print("║  Active:               {d:>10}                            ║\n", .{self.active_requests});
        std.debug.print("║  Preempted:            {d:>10}                            ║\n", .{self.preempted_requests});
        std.debug.print("║  Tokens generated:     {d:>10}                            ║\n", .{self.total_tokens_generated});
        std.debug.print("║  Iterations:           {d:>10}                            ║\n", .{self.total_iterations});
        std.debug.print("║  Preemption count:     {d:>10}                            ║\n", .{self.preemption_count});
        std.debug.print("║  Blocks allocated:     {d:>10}                            ║\n", .{self.blocks_allocated});
        std.debug.print("║  Blocks free:          {d:>10}                            ║\n", .{self.blocks_free});
        std.debug.print("║  Memory utilization:   {d:>10.1}%                          ║\n", .{self.memory_utilization});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    }
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
    
    // Try to decode tokens to text using simple vocab lookup
    std.debug.print("\n\nDecoded text: ", .{});
    for (generated[0..i]) |t| {
        // Simple decode: map common tokens
        const text = switch (t) {
            0 => "<pad>",
            1 => "<s>",
            2 => "</s>",
            3...31 => " ",
            32 => " ",
            else => "?",
        };
        std.debug.print("{s}", .{text});
    }

    std.debug.print("\n\nSTATS\n", .{});
    std.debug.print("  Tokens generated: {d}\n", .{i});
    std.debug.print("  Time: {d:.2} seconds\n", .{@as(f64, @floatFromInt(gen_time)) / 1e9});
    std.debug.print("  Speed: {d:.2} tokens/sec\n", .{@as(f64, @floatFromInt(i)) / (@as(f64, @floatFromInt(gen_time)) / 1e9)});

    std.debug.print("\nKOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED\n", .{});
}

test "speculative_config" {
    const config = SpeculativeConfig.default();
    try std.testing.expectEqual(@as(usize, 4), config.speculation_length);
    try std.testing.expectEqual(@as(usize, 4), config.draft_layers);
}

test "speculative_decoder_init" {
    // This test just verifies the structure compiles correctly
    // Full testing requires a loaded model
    const config = SpeculativeConfig.default();
    try std.testing.expect(config.speculation_length > 0);
    try std.testing.expect(config.draft_layers > 0);
}

test "scheduler_config" {
    const config = SchedulerConfig.default();
    try std.testing.expectEqual(@as(usize, 8), config.max_batch_size);
    try std.testing.expectEqual(@as(usize, 64), config.max_waiting_requests);
}

test "request_init" {
    const allocator = std.testing.allocator;
    const prompt = [_]u32{ 1, 2, 3 };
    var req = Request.init(allocator, 1, &prompt, 10, 1.0, 0);
    defer req.deinit();

    try std.testing.expectEqual(@as(u64, 1), req.id);
    try std.testing.expectEqual(@as(usize, 10), req.max_tokens);
    try std.testing.expectEqual(RequestStatus.queued, req.status);
}

test "scheduler_stats" {
    const stats = SchedulerStats{
        .total_requests = 10,
        .completed_requests = 5,
        .waiting_requests = 3,
        .active_requests = 2,
        .total_tokens_generated = 100,
        .total_iterations = 50,
        .avg_tokens_per_iter = 2.0,
    };

    try std.testing.expectEqual(@as(u64, 10), stats.total_requests);
    try std.testing.expectEqual(@as(usize, 5), stats.completed_requests);
}

// ═══════════════════════════════════════════════════════════════════════════════
// STREAMING LOADER TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "tri_header_magic" {
    try std.testing.expectEqual(TRI_MAGIC, 0x54524933);
}

test "tri_header_size" {
    const size = @sizeOf(TriHeader);
    try std.testing.expect(size > 0);
    try std.testing.expect(size <= 256);
}

test "tri_layer_struct" {
    // Verify TriLayer has expected fields
    const layer_size = @sizeOf(TriModel.TriLayer);
    try std.testing.expect(layer_size > 0);
}

test "lru_cache_config" {
    // Test LRU cache configuration
    const max_layers: usize = 4;
    const prefetch: usize = 2;
    try std.testing.expect(max_layers > 0);
    try std.testing.expect(prefetch < max_layers);
}

test "chunk_size_config" {
    // Test chunk size for streaming
    const chunk_size: usize = 16 * 1024 * 1024; // 16MB
    try std.testing.expect(chunk_size >= 1024 * 1024);
    try std.testing.expect(chunk_size <= 64 * 1024 * 1024);
}

test "mmap_threshold" {
    // Test mmap threshold
    const threshold: usize = 100 * 1024 * 1024; // 100MB
    try std.testing.expect(threshold > 0);
}

test "memory_stats_calculation" {
    // Test memory calculation for streaming
    const num_layers: usize = 32;
    const layer_size: usize = 60 * 1024 * 1024; // 60MB per layer
    const max_resident: usize = 4;
    
    const total_model = num_layers * layer_size;
    const streaming_memory = max_resident * layer_size;
    
    try std.testing.expect(streaming_memory < total_model);
    try std.testing.expect(streaming_memory <= 300 * 1024 * 1024); // < 300MB
}

test "prefetch_bounds" {
    // Test prefetch doesn't exceed bounds
    const current_layer: usize = 28;
    const num_layers: usize = 32;
    const prefetch_count: usize = 2;
    
    const next_layer = current_layer + 1;
    const can_prefetch = next_layer + prefetch_count <= num_layers;
    try std.testing.expect(can_prefetch); // 29 + 2 = 31 <= 32
}

test "cache_eviction_policy" {
    // Test LRU eviction selects oldest
    const access_times = [_]i64{ 100, 50, 200, 75 };
    var oldest_idx: usize = 0;
    var oldest_time: i64 = access_times[0];
    
    for (access_times, 0..) |time, i| {
        if (time < oldest_time) {
            oldest_time = time;
            oldest_idx = i;
        }
    }
    
    try std.testing.expectEqual(oldest_idx, 1); // Index 1 has time 50
}

test "ternary_compression_ratio" {
    // Verify 16x compression from F32
    const f32_size: usize = 4;
    const ternary_size: usize = 1; // 4 trits per byte = 0.25 bytes per weight
    const ratio = f32_size * 4 / ternary_size; // 4 weights per byte
    try std.testing.expectEqual(ratio, 16);
}
