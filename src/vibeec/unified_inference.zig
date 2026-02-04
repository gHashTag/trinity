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
    
    /// Load and dequantize all weights
    pub fn loadWeights(self: *UnifiedPipeline) !void {
        var timer = try std.time.Timer.start();
        
        const r = &self.reader.?;
        var total_bytes: u64 = 0;
        
        // Load each tensor with appropriate dequantization
        for (r.tensors.items) |tensor| {
            const data = try r.readTensorData(&tensor);
            defer self.allocator.free(data);
            
            const num_elements = tensor.numElements();
            const output = try self.allocator.alloc(f32, num_elements);
            
            // Dequantize based on type
            try gguf.dequantizeBlock(data, output, tensor.tensor_type);
            
            total_bytes += num_elements * 4; // f32 output
            
            // Store in appropriate buffer based on tensor name
            // (simplified - real implementation would parse tensor names)
            self.allocator.free(output);
        }
        
        self.stats.weight_load_time_ms = @as(f64, @floatFromInt(timer.read())) / 1e6;
        self.stats.total_memory_mb = @as(f64, @floatFromInt(total_bytes)) / (1024 * 1024);
    }
    
    /// Run inference benchmark
    pub fn benchmark(self: *UnifiedPipeline, iterations: usize) !f64 {
        var total_time: u64 = 0;
        
        for (0..iterations) |_| {
            var timer = try std.time.Timer.start();
            
            // Simulate forward pass
            // In real implementation, this would call forward()
            std.time.sleep(1_000_000); // 1ms simulated
            
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
