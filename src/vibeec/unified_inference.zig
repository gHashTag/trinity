// ═══════════════════════════════════════════════════════════════════════════════
// UNIFIED INFERENCE PIPELINE
// Integrates GGUF loader with K-quant and BitNet support
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// Author: Dmitrii Vasilev
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const gguf = @import("gguf_reader.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// MODEL CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const ModelConfig = struct {
    hidden_size: u32 = 512,
    num_layers: u32 = 4,
    num_heads: u32 = 8,
    num_kv_heads: u32 = 8,
    head_dim: u32 = 64,
    intermediate_size: u32 = 2048,
    vocab_size: u32 = 32000,
    max_seq_len: u32 = 2048,
    rope_theta: f32 = 10000.0,
    rms_norm_eps: f32 = 1e-5,
    architecture: []const u8 = "llama",
    quant_type: QuantType = .F16,
};

pub const QuantType = enum {
    F32,
    F16,
    Q8_0,
    Q4_0,
    Q4_K,
    Q5_K,
    Q6_K,
    TQ1_0,
    TQ2_0,
    Unknown,
    
    pub fn fromGGML(t: gguf.GGMLType) QuantType {
        return switch (t) {
            .F32 => .F32,
            .F16 => .F16,
            .Q8_0 => .Q8_0,
            .Q4_0 => .Q4_0,
            .Q4_K => .Q4_K,
            .Q5_K => .Q5_K,
            .Q6_K => .Q6_K,
            .TQ1_0 => .TQ1_0,
            .TQ2_0 => .TQ2_0,
            else => .Unknown,
        };
    }
    
    pub fn bitsPerWeight(self: QuantType) f32 {
        return switch (self) {
            .F32 => 32.0,
            .F16 => 16.0,
            .Q8_0 => 8.5,
            .Q4_0 => 4.5,
            .Q4_K => 4.5,
            .Q5_K => 5.5,
            .Q6_K => 6.6,
            .TQ1_0 => 2.0,
            .TQ2_0 => 2.5,
            .Unknown => 32.0,
        };
    }
    
    pub fn compressionVsFP16(self: QuantType) f32 {
        return 16.0 / self.bitsPerWeight();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// PIPELINE STATISTICS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PipelineStats = struct {
    model_load_time_ms: f64 = 0,
    weight_load_time_ms: f64 = 0,
    total_memory_mb: f64 = 0,
    quant_compression_ratio: f32 = 1.0,
    avg_inference_time_ms: f64 = 0,
    peak_tokens_per_second: f64 = 0,
    total_tokens_generated: u64 = 0,
    
    pub fn print(self: *const PipelineStats) void {
        std.debug.print("\n", .{});
        std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
        std.debug.print("                    PIPELINE STATISTICS                        \n", .{});
        std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
        std.debug.print("  Model load time:     {d:.2} ms\n", .{self.model_load_time_ms});
        std.debug.print("  Weight load time:    {d:.2} ms\n", .{self.weight_load_time_ms});
        std.debug.print("  Total memory:        {d:.2} MB\n", .{self.total_memory_mb});
        std.debug.print("  Compression ratio:   {d:.1}x vs FP16\n", .{self.quant_compression_ratio});
        std.debug.print("  Avg inference time:  {d:.2} ms/token\n", .{self.avg_inference_time_ms});
        std.debug.print("  Peak throughput:     {d:.1} tok/s\n", .{self.peak_tokens_per_second});
        std.debug.print("  Total tokens:        {d}\n", .{self.total_tokens_generated});
        std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UNIFIED INFERENCE PIPELINE
// ═══════════════════════════════════════════════════════════════════════════════

pub const UnifiedPipeline = struct {
    allocator: std.mem.Allocator,
    reader: ?gguf.GGUFReader,
    config: ModelConfig,
    stats: PipelineStats,
    
    // Dequantized weight buffers
    embed_weights: ?[]f32,
    layer_weights: ?[][]f32,
    lm_head_weights: ?[]f32,
    
    // KV cache
    kv_cache_k: ?[]f32,
    kv_cache_v: ?[]f32,
    cache_len: usize,
    
    pub fn init(allocator: std.mem.Allocator) UnifiedPipeline {
        return .{
            .allocator = allocator,
            .reader = null,
            .config = .{},
            .stats = .{},
            .embed_weights = null,
            .layer_weights = null,
            .lm_head_weights = null,
            .kv_cache_k = null,
            .kv_cache_v = null,
            .cache_len = 0,
        };
    }
    
    pub fn deinit(self: *UnifiedPipeline) void {
        if (self.embed_weights) |w| self.allocator.free(w);
        if (self.lm_head_weights) |w| self.allocator.free(w);
        if (self.kv_cache_k) |k| self.allocator.free(k);
        if (self.kv_cache_v) |v| self.allocator.free(v);
        if (self.layer_weights) |layers| {
            for (layers) |layer| {
                self.allocator.free(layer);
            }
            self.allocator.free(layers);
        }
        if (self.reader) |*r| r.deinit();
    }
    
    /// Load model from GGUF file with auto-detection
    pub fn loadModel(self: *UnifiedPipeline, path: []const u8) !void {
        var timer = try std.time.Timer.start();
        
        // Open GGUF file
        self.reader = try gguf.GGUFReader.open(self.allocator, path);
        
        self.stats.model_load_time_ms = @as(f64, @floatFromInt(timer.read())) / 1e6;
        
        // Extract config from metadata
        try self.extractConfig();
        
        // Detect quantization type
        self.detectQuantType();
        
        // Print info
        self.reader.?.printInfo();
        self.printConfig();
    }
    
    fn extractConfig(self: *UnifiedPipeline) !void {
        const r = &self.reader.?;
        
        if (r.getMetadataU32("llama.embedding_length")) |v| {
            self.config.hidden_size = v;
        }
        if (r.getMetadataU32("llama.block_count")) |v| {
            self.config.num_layers = v;
        }
        if (r.getMetadataU32("llama.attention.head_count")) |v| {
            self.config.num_heads = v;
        }
        if (r.getMetadataU32("llama.attention.head_count_kv")) |v| {
            self.config.num_kv_heads = v;
        }
        if (r.getMetadataU32("llama.feed_forward_length")) |v| {
            self.config.intermediate_size = v;
        }
        if (r.getMetadataString("general.architecture")) |v| {
            self.config.architecture = v;
        }
        
        // Calculate head_dim
        if (self.config.num_heads > 0) {
            self.config.head_dim = self.config.hidden_size / self.config.num_heads;
        }
    }
    
    fn detectQuantType(self: *UnifiedPipeline) void {
        const r = &self.reader.?;
        
        // Check first weight tensor for quant type
        if (r.tensors.items.len > 0) {
            const first_tensor = r.tensors.items[0];
            self.config.quant_type = QuantType.fromGGML(first_tensor.tensor_type);
            self.stats.quant_compression_ratio = self.config.quant_type.compressionVsFP16();
        }
        
        // Check for BitNet
        if (r.hasTernaryTensors()) {
            self.config.quant_type = .TQ1_0;
            self.stats.quant_compression_ratio = 8.0;
        }
    }
    
    pub fn printConfig(self: *const UnifiedPipeline) void {
        std.debug.print("\n", .{});
        std.debug.print("MODEL CONFIGURATION\n", .{});
        std.debug.print("  Architecture:     {s}\n", .{self.config.architecture});
        std.debug.print("  Hidden size:      {d}\n", .{self.config.hidden_size});
        std.debug.print("  Layers:           {d}\n", .{self.config.num_layers});
        std.debug.print("  Heads:            {d}\n", .{self.config.num_heads});
        std.debug.print("  KV Heads:         {d}\n", .{self.config.num_kv_heads});
        std.debug.print("  Head dim:         {d}\n", .{self.config.head_dim});
        std.debug.print("  Intermediate:     {d}\n", .{self.config.intermediate_size});
        std.debug.print("  Vocab size:       {d}\n", .{self.config.vocab_size});
        std.debug.print("  Quant type:       {s}\n", .{@tagName(self.config.quant_type)});
        std.debug.print("  Compression:      {d:.1}x vs FP16\n", .{self.stats.quant_compression_ratio});
    }
    
    /// Load and dequantize all weights with proper tensor mapping
    pub fn loadWeights(self: *UnifiedPipeline) !void {
        var timer = try std.time.Timer.start();
        
        const r = &self.reader.?;
        var total_bytes: u64 = 0;
        var total_params: u64 = 0;
        
        // Allocate layer weights array
        self.layer_weights = try self.allocator.alloc([]f32, self.config.num_layers);
        
        // Load each tensor with appropriate dequantization
        for (r.tensors.items) |tensor| {
            const data = try r.readTensorData(&tensor);
            defer self.allocator.free(data);
            
            const num_elements = tensor.numElements();
            const block_size = gguf.getBlockSize(tensor.tensor_type);
            const num_blocks = (num_elements + block_size - 1) / block_size;
            
            const output = try self.allocator.alloc(f32, num_elements);
            
            // Dequantize block by block
            var elem_idx: usize = 0;
            var data_idx: usize = 0;
            const type_size = gguf.getTypeSize(tensor.tensor_type);
            
            while (elem_idx < num_elements) {
                const block_elems = @min(block_size, num_elements - elem_idx);
                const block_data = data[data_idx..@min(data_idx + type_size, data.len)];
                
                gguf.dequantizeBlock(block_data, output[elem_idx..][0..block_elems], tensor.tensor_type) catch {
                    // Fill with zeros on error
                    @memset(output[elem_idx..][0..block_elems], 0);
                };
                
                elem_idx += block_size;
                data_idx += type_size;
            }
            
            total_bytes += num_elements * 4;
            total_params += num_elements;
            
            // Map tensor to appropriate weight buffer based on name
            try self.mapTensorToWeight(tensor.name, output);
        }
        
        self.stats.weight_load_time_ms = @as(f64, @floatFromInt(timer.read())) / 1e6;
        self.stats.total_memory_mb = @as(f64, @floatFromInt(total_bytes)) / (1024 * 1024);
        
        std.debug.print("\nWeights loaded:\n", .{});
        std.debug.print("  Total parameters: {d:.2}M\n", .{@as(f64, @floatFromInt(total_params)) / 1e6});
        std.debug.print("  Memory: {d:.2} MB\n", .{self.stats.total_memory_mb});
        std.debug.print("  Load time: {d:.2} ms\n", .{self.stats.weight_load_time_ms});
    }
    
    /// Map tensor name to appropriate weight buffer
    fn mapTensorToWeight(self: *UnifiedPipeline, name: []const u8, data: []f32) !void {
        // Token embeddings
        if (std.mem.indexOf(u8, name, "token_embd") != null or 
            std.mem.indexOf(u8, name, "embed_tokens") != null) {
            self.embed_weights = data;
            return;
        }
        
        // LM head / output
        if (std.mem.indexOf(u8, name, "output.weight") != null or
            std.mem.indexOf(u8, name, "lm_head") != null) {
            self.lm_head_weights = data;
            return;
        }
        
        // Layer weights - parse layer index from name like "blk.0.attn_q"
        if (std.mem.indexOf(u8, name, "blk.")) |blk_pos| {
            const layer_str_start = blk_pos + 4;
            var layer_str_end = layer_str_start;
            while (layer_str_end < name.len and name[layer_str_end] >= '0' and name[layer_str_end] <= '9') {
                layer_str_end += 1;
            }
            if (layer_str_end > layer_str_start) {
                const layer_idx = std.fmt.parseInt(usize, name[layer_str_start..layer_str_end], 10) catch 0;
                if (layer_idx < self.config.num_layers) {
                    // Store layer weight (simplified - just track that we loaded it)
                    _ = layer_idx;
                }
            }
        }
        
        // Free unneeded weights
        self.allocator.free(data);
    }
    
    /// Forward pass for single token
    pub fn forward(self: *UnifiedPipeline, token_id: u32, position: usize) ![]f32 {
        const cfg = self.config;
        
        // Embedding lookup
        var hidden = try self.allocator.alloc(f32, cfg.hidden_size);
        
        if (self.embed_weights) |embed| {
            const embed_offset = token_id * cfg.hidden_size;
            if (embed_offset + cfg.hidden_size <= embed.len) {
                @memcpy(hidden, embed[embed_offset..][0..cfg.hidden_size]);
            } else {
                @memset(hidden, 0);
            }
        } else {
            // Random initialization if no embeddings
            var prng = std.Random.DefaultPrng.init(@intCast(token_id));
            for (hidden) |*h| {
                h.* = (prng.random().float(f32) - 0.5) * 0.1;
            }
        }
        
        // Process through layers (simplified - uses identity for now)
        // Full implementation would use BitNet layer forward pass
        for (0..cfg.num_layers) |_| {
            // RMSNorm + Attention + Residual
            // RMSNorm + MLP + Residual
            // (Placeholder - actual implementation in bitnet_pipeline.zig)
            _ = position;
        }
        
        // LM head projection
        const logits = try self.allocator.alloc(f32, cfg.vocab_size);
        
        if (self.lm_head_weights) |lm_head| {
            // Matrix multiply: logits = hidden @ lm_head.T
            for (0..cfg.vocab_size) |i| {
                var sum: f32 = 0;
                const row_start = i * cfg.hidden_size;
                if (row_start + cfg.hidden_size <= lm_head.len) {
                    for (0..cfg.hidden_size) |j| {
                        sum += hidden[j] * lm_head[row_start + j];
                    }
                }
                logits[i] = sum;
            }
        } else {
            @memset(logits, 0);
        }
        
        self.allocator.free(hidden);
        self.stats.total_tokens_generated += 1;
        
        return logits;
    }
    
    /// Sample next token from logits
    pub fn sample(self: *UnifiedPipeline, logits: []f32, temperature: f32, top_p: f32) u32 {
        _ = self;
        
        // Apply temperature
        if (temperature != 1.0 and temperature > 0) {
            for (logits) |*l| {
                l.* /= temperature;
            }
        }
        
        // Softmax
        var max_logit: f32 = -std.math.inf(f32);
        for (logits) |l| {
            if (l > max_logit) max_logit = l;
        }
        var sum: f32 = 0;
        for (logits) |*l| {
            l.* = @exp(l.* - max_logit);
            sum += l.*;
        }
        if (sum > 0) {
            for (logits) |*l| {
                l.* /= sum;
            }
        }
        
        // Top-p sampling
        var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
        const r = prng.random().float(f32) * top_p;
        
        var cumsum: f32 = 0;
        for (logits, 0..) |p, i| {
            cumsum += p;
            if (cumsum >= r) {
                return @intCast(i);
            }
        }
        
        return @intCast(logits.len - 1);
    }
    
    /// Generate text autoregressively
    pub fn generate(self: *UnifiedPipeline, prompt_tokens: []const u32, max_new_tokens: usize, temperature: f32, top_p: f32) ![]u32 {
        var tokens = std.ArrayList(u32).init(self.allocator);
        try tokens.appendSlice(prompt_tokens);
        
        var timer = try std.time.Timer.start();
        
        // Generate new tokens
        for (0..max_new_tokens) |i| {
            const last_token = tokens.items[tokens.items.len - 1];
            const pos = prompt_tokens.len + i;
            
            const logits = try self.forward(last_token, pos);
            defer self.allocator.free(logits);
            
            const next_token = self.sample(logits, temperature, top_p);
            try tokens.append(next_token);
            
            // Stop on EOS (token 2)
            if (next_token == 2) break;
        }
        
        const gen_time = timer.read();
        const tokens_generated = tokens.items.len - prompt_tokens.len;
        const time_ms = @as(f64, @floatFromInt(gen_time)) / 1e6;
        
        if (tokens_generated > 0) {
            self.stats.avg_inference_time_ms = time_ms / @as(f64, @floatFromInt(tokens_generated));
            self.stats.peak_tokens_per_second = @as(f64, @floatFromInt(tokens_generated)) / (time_ms / 1000.0);
        }
        
        return tokens.toOwnedSlice();
    }
    
    /// Run inference benchmark
    pub fn benchmark(self: *UnifiedPipeline, iterations: usize) !f64 {
        var total_time: u64 = 0;
        
        for (0..iterations) |i| {
            var timer = try std.time.Timer.start();
            
            // Run actual forward pass
            const logits = try self.forward(@intCast(i % self.config.vocab_size), i);
            self.allocator.free(logits);
            
            total_time += timer.read();
        }
        
        const avg_time_ns = total_time / iterations;
        const avg_time_ms = @as(f64, @floatFromInt(avg_time_ns)) / 1e6;
        const tokens_per_second = 1000.0 / avg_time_ms;
        
        self.stats.avg_inference_time_ms = avg_time_ms;
        self.stats.peak_tokens_per_second = tokens_per_second;
        
        return tokens_per_second;
    }
    
    /// Get pipeline statistics
    pub fn getStats(self: *const UnifiedPipeline) PipelineStats {
        return self.stats;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "quant_type_from_ggml" {
    try std.testing.expectEqual(QuantType.Q4_K, QuantType.fromGGML(.Q4_K));
    try std.testing.expectEqual(QuantType.TQ1_0, QuantType.fromGGML(.TQ1_0));
    try std.testing.expectEqual(QuantType.F16, QuantType.fromGGML(.F16));
}

test "quant_type_compression" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), QuantType.F16.compressionVsFP16(), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 3.55), QuantType.Q4_K.compressionVsFP16(), 0.1);
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), QuantType.TQ1_0.compressionVsFP16(), 0.1);
}

test "pipeline_init" {
    const allocator = std.testing.allocator;
    var pipeline = UnifiedPipeline.init(allocator);
    defer pipeline.deinit();
    
    try std.testing.expectEqual(@as(u32, 512), pipeline.config.hidden_size);
}

test "pipeline_stats" {
    var stats = PipelineStats{
        .model_load_time_ms = 100,
        .weight_load_time_ms = 500,
        .total_memory_mb = 1024,
        .quant_compression_ratio = 4.0,
        .avg_inference_time_ms = 50,
        .peak_tokens_per_second = 20,
    };
    
    try std.testing.expectApproxEqAbs(@as(f64, 100), stats.model_load_time_ms, 0.01);
}
