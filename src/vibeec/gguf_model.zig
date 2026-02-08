// GGUF FULL MODEL - Complete Transformer with all layers
// phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");
const gguf = @import("gguf_reader.zig");
const inference = @import("gguf_inference.zig");
const transformer = @import("gguf_transformer.zig");
const simd = @import("simd_matmul.zig");
const ternary = @import("ternary_weights.zig");

pub const FullModel = struct {
    allocator: std.mem.Allocator,
    reader: gguf.GGUFReader,
    config: inference.ModelConfig,

    // Ternary mode flag
    use_ternary: bool = false,

    // Core weights
    token_embedding: []f32,
    output_weight: []f32,
    output_norm: []f32,

    // Ternary weights (optional - for BitNet models)
    ternary_output_weight: ?[]u8 = null,

    // Per-layer weights
    layers: []LayerWeights,

    // RoPE and KV-cache
    rope: transformer.RoPE,
    kv_caches: []transformer.KVCache,

    // Pre-allocated buffers for forward pass (avoid allocations in hot path)
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

        // QKV bias (optional - used by Qwen2, not by Llama)
        bq: ?[]f32 = null,
        bk: ?[]f32 = null,
        bv: ?[]f32 = null,

        // Ternary versions (optional)
        ternary_wq: ?[]u8 = null,
        ternary_wk: ?[]u8 = null,
        ternary_wv: ?[]u8 = null,
        ternary_wo: ?[]u8 = null,
        ternary_w_gate: ?[]u8 = null,
        ternary_w_up: ?[]u8 = null,
        ternary_w_down: ?[]u8 = null,
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
            // Pre-allocated buffers (initialized in loadWeights)
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

        // Calculate head_dim - try from metadata first, then from Q tensor, finally fallback
        var key_buf2: [64]u8 = undefined;
        if (reader.getMetadataU32(std.fmt.bufPrint(&key_buf2, "{s}.attention.head_dim", .{arch}) catch "")) |hd| {
            model.config.head_dim = hd;
            std.debug.print("  head_dim from metadata: {}\n", .{hd});
        } else {
            // Infer head_dim from Q tensor dimensions
            // Q weight is [hidden_size, num_heads * head_dim] or [num_heads * head_dim, hidden_size]
            if (reader.getTensor("blk.0.attn_q.weight")) |q_tensor| {
                const q_out_dim = if (q_tensor.dims[0] == model.config.hidden_size)
                    q_tensor.dims[1]  // [hidden, q_dim] format
                else
                    q_tensor.dims[0]; // [q_dim, hidden] format
                model.config.head_dim = @intCast(q_out_dim / model.config.num_heads);
                std.debug.print("  head_dim inferred from Q tensor: {} (Q_dim={}, num_heads={})\n", .{
                    model.config.head_dim, q_out_dim, model.config.num_heads
                });
            } else {
                // Fallback to traditional calculation
                model.config.head_dim = model.config.hidden_size / model.config.num_heads;
                std.debug.print("  head_dim fallback: {}\n", .{model.config.head_dim});
            }
        }

        // Infer FFN dimensions from tensors (BitNet has different FFN structure)
        if (reader.getTensor("blk.0.ffn_gate.weight")) |gate_tensor| {
            // gate is [hidden_size, ffn_gate_dim] format
            const gate_out = if (gate_tensor.dims[0] == model.config.hidden_size)
                gate_tensor.dims[1]
            else
                gate_tensor.dims[0];
            model.config.ffn_gate_dim = @intCast(gate_out);
            std.debug.print("  ffn_gate_dim from tensor: {}\n", .{model.config.ffn_gate_dim});
        }

        if (reader.getTensor("blk.0.ffn_down.weight")) |down_tensor| {
            // down is [intermediate, ffn_down_output] format
            // For BitNet: [6912 x 640] means 6912 → 640
            const down_out = @min(down_tensor.dims[0], down_tensor.dims[1]);
            model.config.ffn_down_out_dim = @intCast(down_out);
            std.debug.print("  ffn_down_out_dim from tensor: {}\n", .{model.config.ffn_down_out_dim});
        }

        return model;
    }

    pub fn loadWeights(self: *FullModel) !void {
        std.debug.print("Loading weights...\n", .{});
        
        // ═══════════════════════════════════════════════════════════════════
        // PROFILING: Track time for each phase
        // ═══════════════════════════════════════════════════════════════════
        var total_timer = std.time.Timer.start() catch unreachable;
        var phase_timer = std.time.Timer.start() catch unreachable;
        
        var time_thread_pool: u64 = 0;
        var time_embeddings: u64 = 0;
        var time_rope: u64 = 0;
        var time_kv_cache: u64 = 0;
        var time_layers: u64 = 0;
        var time_buffers: u64 = 0;

        // Thread pool auto-initializes on first use (persistent spin-wait pool)
        phase_timer.reset();
        time_thread_pool = phase_timer.read();

        // Load embeddings
        phase_timer.reset();
        self.token_embedding = try self.loadTensor("token_embd.weight");

        // Try to load output.weight, fallback to tied embeddings (token_embd)
        self.output_weight = self.loadTensor("output.weight") catch |err| blk: {
            if (err == error.TensorNotFound) {
                // Tied embeddings: output = token_embd (common in smaller models)
                std.debug.print("  Using tied embeddings (output = token_embd)\n", .{});
                break :blk self.token_embedding;
            }
            return err;
        };
        
        self.output_norm = try self.loadTensor("output_norm.weight");
        time_embeddings = phase_timer.read();

        // Initialize RoPE
        phase_timer.reset();
        self.rope = try transformer.RoPE.init(
            self.allocator,
            self.config.head_dim,
            self.config.context_length,
            self.config.rope_theta,
        );
        time_rope = phase_timer.read();

        // Initialize KV caches for each layer
        phase_timer.reset();
        self.kv_caches = try self.allocator.alloc(transformer.KVCache, self.config.num_layers);
        for (0..self.config.num_layers) |i| {
            self.kv_caches[i] = try transformer.KVCache.init(
                self.allocator,
                self.config.num_kv_heads,
                self.config.head_dim,
                self.config.context_length,
            );
        }
        time_kv_cache = phase_timer.read();

        // Load layer weights
        phase_timer.reset();
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
                // Try to load QKV bias (optional - Qwen2 has them, Llama doesn't)
                .bq = self.loadTensorFmt(&name_buf, "blk.{d}.attn_q.bias", .{i}) catch null,
                .bk = self.loadTensorFmt(&name_buf, "blk.{d}.attn_k.bias", .{i}) catch null,
                .bv = self.loadTensorFmt(&name_buf, "blk.{d}.attn_v.bias", .{i}) catch null,
            };
        }

        time_layers = phase_timer.read();
        std.debug.print("  Loaded {d} layers                    \n", .{self.config.num_layers});

        // Pre-allocate buffers for forward pass (avoid allocations in hot path)
        phase_timer.reset();
        const hidden_size = self.config.hidden_size;
        const num_heads = self.config.num_heads;
        const num_kv_heads = self.config.num_kv_heads;
        const head_dim = self.config.head_dim;
        const intermediate_size = self.config.intermediate_size;
        const context_length = self.config.context_length;

        self.buf_hidden = try self.allocator.alloc(f32, hidden_size);
        self.buf_temp = try self.allocator.alloc(f32, hidden_size);
        self.buf_normed = try self.allocator.alloc(f32, hidden_size);
        self.buf_q = try self.allocator.alloc(f32, num_heads * head_dim);
        self.buf_k = try self.allocator.alloc(f32, num_kv_heads * head_dim);
        self.buf_v = try self.allocator.alloc(f32, num_kv_heads * head_dim);
        self.buf_attn_out = try self.allocator.alloc(f32, num_heads * head_dim);
        self.buf_attn_proj = try self.allocator.alloc(f32, hidden_size);
        self.buf_ffn_gate = try self.allocator.alloc(f32, intermediate_size);
        self.buf_ffn_up = try self.allocator.alloc(f32, intermediate_size);
        self.buf_ffn_out = try self.allocator.alloc(f32, hidden_size);
        self.buf_scores = try self.allocator.alloc(f32, context_length);
        time_buffers = phase_timer.read();
        
        // ═══════════════════════════════════════════════════════════════════
        // PROFILING RESULTS
        // ═══════════════════════════════════════════════════════════════════
        const total_time = total_timer.read();
        std.debug.print("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║              LOAD WEIGHTS PROFILING                          ║\n", .{});
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║  Thread pool init:  {d:>10.2} ms ({d:>5.1}%)                  ║\n", .{
            @as(f64, @floatFromInt(time_thread_pool)) / 1_000_000.0,
            @as(f64, @floatFromInt(time_thread_pool)) / @as(f64, @floatFromInt(total_time)) * 100.0
        });
        std.debug.print("║  Embeddings:        {d:>10.2} ms ({d:>5.1}%)                  ║\n", .{
            @as(f64, @floatFromInt(time_embeddings)) / 1_000_000.0,
            @as(f64, @floatFromInt(time_embeddings)) / @as(f64, @floatFromInt(total_time)) * 100.0
        });
        std.debug.print("║  RoPE init:         {d:>10.2} ms ({d:>5.1}%)                  ║\n", .{
            @as(f64, @floatFromInt(time_rope)) / 1_000_000.0,
            @as(f64, @floatFromInt(time_rope)) / @as(f64, @floatFromInt(total_time)) * 100.0
        });
        std.debug.print("║  KV cache init:     {d:>10.2} ms ({d:>5.1}%)                  ║\n", .{
            @as(f64, @floatFromInt(time_kv_cache)) / 1_000_000.0,
            @as(f64, @floatFromInt(time_kv_cache)) / @as(f64, @floatFromInt(total_time)) * 100.0
        });
        std.debug.print("║  Layer weights:     {d:>10.2} ms ({d:>5.1}%)  ◄── BOTTLENECK  ║\n", .{
            @as(f64, @floatFromInt(time_layers)) / 1_000_000.0,
            @as(f64, @floatFromInt(time_layers)) / @as(f64, @floatFromInt(total_time)) * 100.0
        });
        std.debug.print("║  Buffer alloc:      {d:>10.2} ms ({d:>5.1}%)                  ║\n", .{
            @as(f64, @floatFromInt(time_buffers)) / 1_000_000.0,
            @as(f64, @floatFromInt(time_buffers)) / @as(f64, @floatFromInt(total_time)) * 100.0
        });
        std.debug.print("╠══════════════════════════════════════════════════════════════╣\n", .{});
        std.debug.print("║  TOTAL:             {d:>10.2} ms                             ║\n", .{
            @as(f64, @floatFromInt(total_time)) / 1_000_000.0
        });
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    }

    fn loadTensor(self: *FullModel, name: []const u8) ![]f32 {
        const info = self.reader.getTensor(name) orelse return error.TensorNotFound;
        const data = try self.reader.readTensorData(info);
        defer self.allocator.free(data);
        return inference.dequantizeTensor(self.allocator, data, info.tensor_type, info.numElements()) catch |err| {
            if (err == error.UnsupportedQuantization) {
                std.debug.print("Unsupported quantization type {d} for tensor: {s}\n", .{ @intFromEnum(info.tensor_type), name });
            }
            return err;
        };
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
                // Free optional bias
                if (layer.bq) |bq| self.allocator.free(bq);
                if (layer.bk) |bk| self.allocator.free(bk);
                if (layer.bv) |bv| self.allocator.free(bv);
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

        // Free pre-allocated buffers
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

        // Thread pool cleanup handled at process exit (persistent daemon threads)

        self.reader.deinit();
    }

    pub fn resetKVCache(self: *FullModel) void {
        for (self.kv_caches) |*cache| {
            cache.reset();
        }
    }

    /// Enable ternary mode - quantize all weights to {-1, 0, +1}
    /// This provides 16x memory savings and faster inference on CPU
    pub fn enableTernaryMode(self: *FullModel) !void {
        if (self.use_ternary) return; // Already enabled

        std.debug.print("\nConverting to ternary weights...\n", .{});
        const stats = ternary.MemoryStats.calculate(self.countParameters());
        stats.print();

        // Convert output weights
        const threshold = ternary.calculateThreshold(self.output_weight);
        self.ternary_output_weight = try ternary.quantizeToTernary(self.allocator, self.output_weight, threshold);

        // Convert layer weights
        for (self.layers) |*layer| {
            const t_wq = ternary.calculateThreshold(layer.wq);
            const t_wk = ternary.calculateThreshold(layer.wk);
            const t_wv = ternary.calculateThreshold(layer.wv);
            const t_wo = ternary.calculateThreshold(layer.wo);
            const t_gate = ternary.calculateThreshold(layer.w_gate);
            const t_up = ternary.calculateThreshold(layer.w_up);
            const t_down = ternary.calculateThreshold(layer.w_down);

            layer.ternary_wq = try ternary.quantizeToTernary(self.allocator, layer.wq, t_wq);
            layer.ternary_wk = try ternary.quantizeToTernary(self.allocator, layer.wk, t_wk);
            layer.ternary_wv = try ternary.quantizeToTernary(self.allocator, layer.wv, t_wv);
            layer.ternary_wo = try ternary.quantizeToTernary(self.allocator, layer.wo, t_wo);
            layer.ternary_w_gate = try ternary.quantizeToTernary(self.allocator, layer.w_gate, t_gate);
            layer.ternary_w_up = try ternary.quantizeToTernary(self.allocator, layer.w_up, t_up);
            layer.ternary_w_down = try ternary.quantizeToTernary(self.allocator, layer.w_down, t_down);
        }

        self.use_ternary = true;
        std.debug.print("Ternary mode enabled!\n", .{});
    }

    /// Count total parameters
    fn countParameters(self: *const FullModel) usize {
        var count: usize = self.token_embedding.len + self.output_weight.len + self.output_norm.len;
        for (self.layers) |layer| {
            count += layer.wq.len + layer.wk.len + layer.wv.len + layer.wo.len;
            count += layer.w_gate.len + layer.w_up.len + layer.w_down.len;
            count += layer.attn_norm.len + layer.ffn_norm.len;
        }
        return count;
    }

    /// Matrix-vector multiply with automatic ternary/float selection
    /// Uses SIMD-optimized ternary matmul when in ternary mode
    fn matVecAuto(self: *const FullModel, output: []f32, weights_f32: []const f32, weights_ternary: ?[]const u8, input: []const f32, rows: usize, cols: usize) void {
        if (self.use_ternary) {
            if (weights_ternary) |tw| {
                // Use SIMD-16 for best performance (5x speedup over scalar)
                ternary.simd16TernaryMatVec(output, tw, input, rows, cols);
                return;
            }
        }
        inference.matVec(output, weights_f32, input, rows, cols);
    }

    /// Matrix-vector multiply using column-major (transposed) layout
    /// GGUF attention weights are stored with output_dim as innermost dimension
    /// This is the correct interpretation for attention projections (QKV, O)
    fn matVecColMajor(_: *const FullModel, output: []f32, weights_f32: []const f32, input: []const f32, rows: usize, cols: usize) void {
        simd.simdMatVecColMajor(output, weights_f32, input, rows, cols);
    }

    // Forward pass for single token - OPTIMIZED with pre-allocated buffers
    pub fn forward(self: *FullModel, token: u32, pos: usize) ![]f32 {
        const hidden_size = self.config.hidden_size;

        // Get embedding (use pre-allocated buffer)
        // NOTE: GGUF stores tensors in column-major order
        // token_embd.weight has dims=[hidden_size, vocab_size] where hidden_size is innermost
        // Memory layout: for each token t, all hidden dims h are contiguous
        // Access: embedding[t][h] = data[t * hidden_size + h]
        const emb_offset = @as(usize, token) * hidden_size;
        @memcpy(self.buf_hidden, self.token_embedding[emb_offset..][0..hidden_size]);

        // Process through all layers (no allocations!)
        for (0..self.config.num_layers) |i| {
            self.forwardLayerOptimized(self.buf_temp, self.buf_hidden, i, pos);
            @memcpy(self.buf_hidden, self.buf_temp);
        }

        // Final RMS norm
        inference.rmsNorm(self.buf_temp, self.buf_hidden, self.output_norm, self.config.rms_norm_eps);

        // Output projection (only allocation is for return value)
        // Use parallel matVec for large vocab_size (32000 rows = big win from threading)
        const logits = try self.allocator.alloc(f32, self.config.vocab_size);
        simd.simdMatVecParallel(logits, self.output_weight, self.buf_temp, self.config.vocab_size, hidden_size);

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

        // Add QKV bias if present (Qwen2 architecture)
        if (layer.bq) |bq| {
            for (q, 0..) |*qv, i| {
                qv.* += bq[i];
            }
        }
        if (layer.bk) |bk| {
            for (k, 0..) |*kv, i| {
                kv.* += bk[i];
            }
        }
        if (layer.bv) |bv| {
            for (v, 0..) |*vv, i| {
                vv.* += bv[i];
            }
        }

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

    // OPTIMIZED forward layer - uses pre-allocated buffers (NO ALLOCATIONS!)
    pub fn forwardLayerOptimized(self: *FullModel, output: []f32, input: []const f32, layer_idx: usize, pos: usize) void {
        const layer = self.layers[layer_idx];
        const hidden_size = self.config.hidden_size;
        const num_heads = self.config.num_heads;
        const num_kv_heads = self.config.num_kv_heads;
        const head_dim = self.config.head_dim;
        const intermediate_size = self.config.intermediate_size;
        const rms_eps = self.config.rms_norm_eps;

        // Pre-attention norm (use buf_normed)
        inference.rmsNorm(self.buf_normed, input, layer.attn_norm, rms_eps);

        // Compute Q, K, V (use buf_q, buf_k, buf_v)
        // Row-major matVec: output[i] = sum_j(mat[i * cols + j] * vec[j])
        simd.simdMatVecParallel(self.buf_q, layer.wq, self.buf_normed, num_heads * head_dim, hidden_size);
        simd.simdMatVec(self.buf_k, layer.wk, self.buf_normed, num_kv_heads * head_dim, hidden_size);
        simd.simdMatVec(self.buf_v, layer.wv, self.buf_normed, num_kv_heads * head_dim, hidden_size);

        // Add QKV bias if present (Qwen2 architecture)
        if (layer.bq) |bq| {
            for (self.buf_q, 0..) |*qv, i| {
                qv.* += bq[i];
            }
        }
        if (layer.bk) |bk| {
            for (self.buf_k, 0..) |*kv, i| {
                kv.* += bk[i];
            }
        }
        if (layer.bv) |bv| {
            for (self.buf_v, 0..) |*vv, i| {
                vv.* += bv[i];
            }
        }

        // Apply RoPE
        for (0..num_heads) |h| {
            self.rope.apply(self.buf_q[h * head_dim ..][0..head_dim], pos);
        }
        for (0..num_kv_heads) |h| {
            self.rope.apply(self.buf_k[h * head_dim ..][0..head_dim], pos);
        }

        // Update KV cache
        self.kv_caches[layer_idx].append(self.buf_k, self.buf_v);

        // Attention (use buf_attn_out, buf_scores)
        const scale = 1.0 / @sqrt(@as(f32, @floatFromInt(head_dim)));
        const kv_group_size = num_heads / num_kv_heads;
        const seq_len = self.kv_caches[layer_idx].seq_len;

        for (0..num_heads) |h| {
            const kv_h = h / kv_group_size;
            const q_head = self.buf_q[h * head_dim ..][0..head_dim];

            // Attention scores with SIMD dot product
            for (0..seq_len) |t| {
                const k_offset = t * num_kv_heads * head_dim + kv_h * head_dim;
                const k_vec = self.kv_caches[layer_idx].k_cache[k_offset..][0..head_dim];
                self.buf_scores[t] = simd.simdDot(q_head, k_vec) * scale;
            }

            // Softmax
            inference.softmax(self.buf_scores[0..seq_len], self.buf_scores[0..seq_len]);

            // Weighted sum with SIMD
            const out_head = self.buf_attn_out[h * head_dim ..][0..head_dim];
            @memset(out_head, 0.0);

            for (0..seq_len) |t| {
                const v_offset = t * num_kv_heads * head_dim + kv_h * head_dim;
                const v_vec = self.kv_caches[layer_idx].v_cache[v_offset..][0..head_dim];
                const score = self.buf_scores[t];

                // SIMD scale and add
                for (0..head_dim) |i| {
                    out_head[i] += score * v_vec[i];
                }
            }
        }

        // Output projection (use buf_attn_proj)
        simd.simdMatVecParallel(self.buf_attn_proj, layer.wo, self.buf_attn_out, hidden_size, num_heads * head_dim);

        // Residual - SIMD optimized
        @memcpy(output, input);
        simd.simdResidualAdd(output, self.buf_attn_proj);

        // Pre-FFN norm
        inference.rmsNorm(self.buf_normed, output, layer.ffn_norm, rms_eps);

        // FFN dimensions - use inferred values for BitNet, fallback for standard Llama
        // BitNet: gate/up output to ffn_gate_dim (1728), then expand 4x to intermediate (6912)
        const ffn_gate_out = if (self.config.ffn_gate_dim > 0) self.config.ffn_gate_dim else intermediate_size;
        const ffn_down_out = if (self.config.ffn_down_out_dim > 0) self.config.ffn_down_out_dim else hidden_size;

        // FFN with SwiGLU (use buf_ffn_gate, buf_ffn_up)
        // gate/up: hidden_size → ffn_gate_out (5632 rows — parallelize!)
        simd.simdMatVecParallel(self.buf_ffn_gate[0..ffn_gate_out], layer.w_gate, self.buf_normed, ffn_gate_out, hidden_size);
        simd.simdMatVecParallel(self.buf_ffn_up[0..ffn_gate_out], layer.w_up, self.buf_normed, ffn_gate_out, hidden_size);

        // SwiGLU on partial buffers
        simd.simdSwiGLU(self.buf_ffn_gate[0..ffn_gate_out], self.buf_ffn_gate[0..ffn_gate_out], self.buf_ffn_up[0..ffn_gate_out]);

        // BitNet expansion: replicate 4x if ffn_gate_dim < intermediate_size
        if (ffn_gate_out < intermediate_size) {
            const expand_ratio = intermediate_size / ffn_gate_out;
            var i: usize = 0;
            while (i < ffn_gate_out) : (i += 1) {
                const val = self.buf_ffn_gate[i];
                var j: usize = 0;
                while (j < expand_ratio) : (j += 1) {
                    self.buf_ffn_gate[i * expand_ratio + j] = val;
                }
            }
        }

        // Down projection (use buf_ffn_out)
        // down: intermediate_size → ffn_down_out (2048 rows — parallelize!)
        simd.simdMatVecParallel(self.buf_ffn_out[0..ffn_down_out], layer.w_down, self.buf_ffn_gate, ffn_down_out, intermediate_size);

        // Residual - SIMD optimized
        simd.simdResidualAdd(output, self.buf_ffn_out);
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
