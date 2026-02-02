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

        // Final norm
        inference.rmsNorm(self.buf_temp, self.buf_hidden, self.output_norm, self.header.rms_norm_eps);

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

        // Pre-attention norm
        inference.rmsNorm(self.buf_normed, input, layer.attn_norm, rms_eps);

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

        // Pre-FFN norm
        inference.rmsNorm(self.buf_normed, output, layer.ffn_norm, rms_eps);

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
