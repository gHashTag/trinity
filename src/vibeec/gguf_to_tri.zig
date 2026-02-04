// ═══════════════════════════════════════════════════════════════════════════════
// GGUF TO TRI CONVERTER - Convert GGUF models to Ternary .tri format
// 16x memory savings, 5-10x speedup via elimination of multiplications
// φ² + 1/φ² = 3 = TRINITY = QUTRIT = CODON
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const gguf = @import("gguf_reader.zig");
const model_mod = @import("gguf_model.zig");
const ternary = @import("ternary_weights.zig");
const inference = @import("gguf_inference.zig");
const bitnet = @import("bitnet_pipeline.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// PARALLEL QUANTIZATION SUPPORT
// Uses persistent thread pool from bitnet_pipeline.zig
// ═══════════════════════════════════════════════════════════════════════════════

const MIN_TENSOR_SIZE_FOR_PARALLEL: usize = 1048576; // 1M elements

/// Context for parallel layer quantization
const LayerQuantContext = struct {
    layer_idx: usize,
    model: *const model_mod.FullModel,
    allocator: std.mem.Allocator,
    result: ?TernaryModel.TernaryLayer,
    err: ?anyerror,
};

/// Quantize single layer (called from thread)
fn quantizeLayerWorker(ctx: *LayerQuantContext) void {
    const layer = ctx.model.layers[ctx.layer_idx];
    var tri_layer: TernaryModel.TernaryLayer = undefined;
    
    // Keep norms in f32
    tri_layer.attn_norm = ctx.allocator.dupe(f32, layer.attn_norm) catch {
        ctx.err = error.OutOfMemory;
        return;
    };
    tri_layer.ffn_norm = ctx.allocator.dupe(f32, layer.ffn_norm) catch {
        ctx.err = error.OutOfMemory;
        return;
    };
    
    // Convert attention weights
    const t_q = ternary.calculateThreshold(layer.wq);
    const t_k = ternary.calculateThreshold(layer.wk);
    const t_v = ternary.calculateThreshold(layer.wv);
    const t_o = ternary.calculateThreshold(layer.wo);
    
    tri_layer.wq = ternary.quantizeToTernary(ctx.allocator, layer.wq, t_q) catch {
        ctx.err = error.OutOfMemory;
        return;
    };
    tri_layer.wk = ternary.quantizeToTernary(ctx.allocator, layer.wk, t_k) catch {
        ctx.err = error.OutOfMemory;
        return;
    };
    tri_layer.wv = ternary.quantizeToTernary(ctx.allocator, layer.wv, t_v) catch {
        ctx.err = error.OutOfMemory;
        return;
    };
    tri_layer.wo = ternary.quantizeToTernary(ctx.allocator, layer.wo, t_o) catch {
        ctx.err = error.OutOfMemory;
        return;
    };
    
    tri_layer.scale_q = t_q * 2.0;
    tri_layer.scale_k = t_k * 2.0;
    tri_layer.scale_v = t_v * 2.0;
    tri_layer.scale_o = t_o * 2.0;
    
    // Convert FFN weights
    const t_gate = ternary.calculateThreshold(layer.w_gate);
    const t_up = ternary.calculateThreshold(layer.w_up);
    const t_down = ternary.calculateThreshold(layer.w_down);
    
    tri_layer.w_gate = ternary.quantizeToTernary(ctx.allocator, layer.w_gate, t_gate) catch {
        ctx.err = error.OutOfMemory;
        return;
    };
    tri_layer.w_up = ternary.quantizeToTernary(ctx.allocator, layer.w_up, t_up) catch {
        ctx.err = error.OutOfMemory;
        return;
    };
    tri_layer.w_down = ternary.quantizeToTernary(ctx.allocator, layer.w_down, t_down) catch {
        ctx.err = error.OutOfMemory;
        return;
    };
    
    tri_layer.scale_gate = t_gate * 2.0;
    tri_layer.scale_up = t_up * 2.0;
    tri_layer.scale_down = t_down * 2.0;
    
    ctx.result = tri_layer;
    ctx.err = null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// .TRI FILE FORMAT
// ═══════════════════════════════════════════════════════════════════════════════

pub const TRI_MAGIC: u32 = 0x54524933; // "TRI3"
pub const TRI_VERSION: u32 = 1;

pub const TriHeader = packed struct {
    magic: u32,
    version: u32,
    model_type: u32, // 0=SmolLM, 1=SmolLM2, 2=Llama
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
    ternary_size: u64, // Size in bytes after quantization
    embedding_offset: u64,
    output_norm_offset: u64,
    output_weight_offset: u64,
    layers_offset: u64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY MODEL STRUCTURE
// ═══════════════════════════════════════════════════════════════════════════════

pub const TernaryModel = struct {
    allocator: std.mem.Allocator,
    header: TriHeader,

    // Embeddings (kept in f32 for quality)
    token_embedding: []f32,
    output_norm: []f32,

    // Output projection (ternary)
    output_weight: []u8,
    output_scale: f32,

    // Per-layer weights
    layers: []TernaryLayer,

    pub const TernaryLayer = struct {
        // Norms (kept in f32)
        attn_norm: []f32,
        ffn_norm: []f32,

        // Attention weights (ternary)
        wq: []u8,
        wk: []u8,
        wv: []u8,
        wo: []u8,
        scale_q: f32,
        scale_k: f32,
        scale_v: f32,
        scale_o: f32,

        // FFN weights (ternary)
        w_gate: []u8,
        w_up: []u8,
        w_down: []u8,
        scale_gate: f32,
        scale_up: f32,
        scale_down: f32,
    };

    pub fn deinit(self: *TernaryModel) void {
        self.allocator.free(self.token_embedding);
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
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CONVERTER
// ═══════════════════════════════════════════════════════════════════════════════

pub fn convertGgufToTri(allocator: std.mem.Allocator, gguf_path: []const u8, tri_path: []const u8) !void {
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           GGUF → TRI CONVERTER                               ║\n", .{});
    std.debug.print("║           φ² + 1/φ² = 3 = TRINITY                            ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    // Load GGUF model
    std.debug.print("Loading GGUF model: {s}\n", .{gguf_path});
    var model = try model_mod.FullModel.init(allocator, gguf_path);
    defer model.deinit();

    model.printConfig();

    std.debug.print("\nLoading weights...\n", .{});
    try model.loadWeights();

    // Calculate memory savings
    const total_params = countParams(&model);
    const stats = ternary.MemoryStats.calculate(total_params);
    stats.print();

    // Convert to ternary
    std.debug.print("\nConverting to ternary format...\n", .{});
    var tri_model = try convertToTernary(allocator, &model);
    defer tri_model.deinit();

    // Save to .tri file
    std.debug.print("\nSaving to: {s}\n", .{tri_path});
    try saveTri(allocator, &tri_model, tri_path);

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║           CONVERSION COMPLETE                                ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
}

fn countParams(model: *const model_mod.FullModel) usize {
    var count: usize = model.token_embedding.len;
    count += model.output_weight.len;
    count += model.output_norm.len;

    for (model.layers) |layer| {
        count += layer.wq.len + layer.wk.len + layer.wv.len + layer.wo.len;
        count += layer.w_gate.len + layer.w_up.len + layer.w_down.len;
        count += layer.attn_norm.len + layer.ffn_norm.len;
    }
    return count;
}

fn convertToTernary(allocator: std.mem.Allocator, model: *const model_mod.FullModel) !TernaryModel {
    var tri_model: TernaryModel = undefined;
    tri_model.allocator = allocator;

    // Copy embeddings (keep in f32)
    tri_model.token_embedding = try allocator.dupe(f32, model.token_embedding);
    tri_model.output_norm = try allocator.dupe(f32, model.output_norm);

    // Convert output projection to ternary
    const output_threshold = ternary.calculateThreshold(model.output_weight);
    tri_model.output_weight = try ternary.quantizeToTernary(allocator, model.output_weight, output_threshold);
    tri_model.output_scale = output_threshold * 2.0; // Scale for dequantization

    // Convert layers (parallel if enough layers)
    tri_model.layers = try allocator.alloc(TernaryModel.TernaryLayer, model.config.num_layers);
    
    const num_threads = bitnet.getPoolThreadCount();
    const use_parallel = num_threads > 1 and model.config.num_layers >= 4;
    
    if (use_parallel) {
        std.debug.print("  Using {d} threads for parallel quantization...\n", .{num_threads});
        
        // Allocate contexts for all layers
        var contexts = try allocator.alloc(LayerQuantContext, model.config.num_layers);
        defer allocator.free(contexts);
        
        var threads: [16]std.Thread = undefined;
        var active_threads: usize = 0;
        var layer_idx: usize = 0;
        
        while (layer_idx < model.config.num_layers) {
            // Launch batch of threads
            const batch_size = @min(num_threads, model.config.num_layers - layer_idx);
            
            for (0..batch_size) |t| {
                const idx = layer_idx + t;
                contexts[idx] = LayerQuantContext{
                    .layer_idx = idx,
                    .model = model,
                    .allocator = allocator,
                    .result = null,
                    .err = null,
                };
                threads[t] = std.Thread.spawn(.{}, quantizeLayerWorker, .{&contexts[idx]}) catch {
                    // Fallback to sequential
                    quantizeLayerWorker(&contexts[idx]);
                    continue;
                };
                active_threads += 1;
            }
            
            // Wait for batch
            for (0..active_threads) |t| {
                threads[t].join();
            }
            
            // Check for errors and collect results
            for (0..batch_size) |t| {
                const idx = layer_idx + t;
                if (contexts[idx].err) |err| {
                    return err;
                }
                tri_model.layers[idx] = contexts[idx].result.?;
            }
            
            active_threads = 0;
            layer_idx += batch_size;
            std.debug.print("  Converted layers {d}/{d}...\r", .{ layer_idx, model.config.num_layers });
        }
    } else {
        // Sequential fallback
        for (0..model.config.num_layers) |i| {
            const layer = model.layers[i];
            var tri_layer: TernaryModel.TernaryLayer = undefined;

            // Keep norms in f32
            tri_layer.attn_norm = try allocator.dupe(f32, layer.attn_norm);
            tri_layer.ffn_norm = try allocator.dupe(f32, layer.ffn_norm);

            // Convert attention weights
            const t_q = ternary.calculateThreshold(layer.wq);
            const t_k = ternary.calculateThreshold(layer.wk);
            const t_v = ternary.calculateThreshold(layer.wv);
            const t_o = ternary.calculateThreshold(layer.wo);

            tri_layer.wq = try ternary.quantizeToTernary(allocator, layer.wq, t_q);
            tri_layer.wk = try ternary.quantizeToTernary(allocator, layer.wk, t_k);
            tri_layer.wv = try ternary.quantizeToTernary(allocator, layer.wv, t_v);
            tri_layer.wo = try ternary.quantizeToTernary(allocator, layer.wo, t_o);

            tri_layer.scale_q = t_q * 2.0;
            tri_layer.scale_k = t_k * 2.0;
            tri_layer.scale_v = t_v * 2.0;
            tri_layer.scale_o = t_o * 2.0;

            // Convert FFN weights
            const t_gate = ternary.calculateThreshold(layer.w_gate);
            const t_up = ternary.calculateThreshold(layer.w_up);
            const t_down = ternary.calculateThreshold(layer.w_down);

            tri_layer.w_gate = try ternary.quantizeToTernary(allocator, layer.w_gate, t_gate);
            tri_layer.w_up = try ternary.quantizeToTernary(allocator, layer.w_up, t_up);
            tri_layer.w_down = try ternary.quantizeToTernary(allocator, layer.w_down, t_down);

            tri_layer.scale_gate = t_gate * 2.0;
            tri_layer.scale_up = t_up * 2.0;
            tri_layer.scale_down = t_down * 2.0;

            tri_model.layers[i] = tri_layer;

            std.debug.print("  Converted layer {d}/{d}...\r", .{ i + 1, model.config.num_layers });
        }
    }
    std.debug.print("  Converted {d} layers                    \n", .{model.config.num_layers});

    // Fill header
    tri_model.header = TriHeader{
        .magic = TRI_MAGIC,
        .version = TRI_VERSION,
        .model_type = 1, // SmolLM2
        .vocab_size = model.config.vocab_size,
        .hidden_size = model.config.hidden_size,
        .intermediate_size = model.config.intermediate_size,
        .num_layers = model.config.num_layers,
        .num_heads = model.config.num_heads,
        .num_kv_heads = model.config.num_kv_heads,
        .head_dim = model.config.head_dim,
        .context_length = model.config.context_length,
        .rope_theta = model.config.rope_theta,
        .rms_norm_eps = model.config.rms_norm_eps,
        .total_params = @intCast(countParams(model)),
        .ternary_size = 0, // Will be calculated
        .embedding_offset = 0,
        .output_norm_offset = 0,
        .output_weight_offset = 0,
        .layers_offset = 0,
    };

    return tri_model;
}

fn saveTri(allocator: std.mem.Allocator, model: *const TernaryModel, path: []const u8) !void {
    _ = allocator;

    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var writer = file.writer();

    // Write header
    try writer.writeAll(std.mem.asBytes(&model.header));

    // Write token embeddings (f32)
    try writer.writeAll(std.mem.sliceAsBytes(model.token_embedding));

    // Write output norm (f32)
    try writer.writeAll(std.mem.sliceAsBytes(model.output_norm));

    // Write output weight scale + ternary data
    try writer.writeAll(std.mem.asBytes(&model.output_scale));
    try writer.writeAll(model.output_weight);

    // Write layers
    for (model.layers) |layer| {
        // Norms (f32)
        try writer.writeAll(std.mem.sliceAsBytes(layer.attn_norm));
        try writer.writeAll(std.mem.sliceAsBytes(layer.ffn_norm));

        // Attention scales
        try writer.writeAll(std.mem.asBytes(&layer.scale_q));
        try writer.writeAll(std.mem.asBytes(&layer.scale_k));
        try writer.writeAll(std.mem.asBytes(&layer.scale_v));
        try writer.writeAll(std.mem.asBytes(&layer.scale_o));

        // Attention ternary weights
        try writer.writeAll(layer.wq);
        try writer.writeAll(layer.wk);
        try writer.writeAll(layer.wv);
        try writer.writeAll(layer.wo);

        // FFN scales
        try writer.writeAll(std.mem.asBytes(&layer.scale_gate));
        try writer.writeAll(std.mem.asBytes(&layer.scale_up));
        try writer.writeAll(std.mem.asBytes(&layer.scale_down));

        // FFN ternary weights
        try writer.writeAll(layer.w_gate);
        try writer.writeAll(layer.w_up);
        try writer.writeAll(layer.w_down);
    }

    const file_size = try file.getEndPos();
    std.debug.print("  Written {d:.2} MB\n", .{@as(f64, @floatFromInt(file_size)) / 1024 / 1024});
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: gguf_to_tri <input.gguf> [output.tri]\n", .{});
        std.debug.print("\nConverts GGUF model to ternary .tri format\n", .{});
        std.debug.print("16x memory savings, 5-10x speedup\n", .{});
        return;
    }

    const input_path = args[1];
    const output_path = if (args.len > 2) args[2] else blk: {
        // Generate output path by replacing extension
        var buf: [256]u8 = undefined;
        const base = std.fs.path.stem(input_path);
        break :blk std.fmt.bufPrint(&buf, "{s}.tri", .{base}) catch "output.tri";
    };

    try convertGgufToTri(allocator, input_path, output_path);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "tri_header_size" {
    // Verify header is packed correctly (actual size may vary)
    const size = @sizeOf(TriHeader);
    try std.testing.expect(size > 0);
    try std.testing.expect(size <= 256);
}

test "tri_magic_constant" {
    try std.testing.expectEqual(TRI_MAGIC, 0x54524933);
}

test "tri_version" {
    try std.testing.expectEqual(TRI_VERSION, 1);
}

test "ternary_quantization_basic" {
    // Test basic threshold calculation
    const input = [_]f32{ 1.0, -1.0, 0.1, -0.1, 0.5, -0.5, 0.0, 0.0 };
    const threshold = ternary.calculateThreshold(&input);
    
    // Threshold should be positive and less than max
    try std.testing.expect(threshold >= 0.0);
    try std.testing.expect(threshold <= 1.0);
}

test "ternary_threshold_positive" {
    const input = [_]f32{ 1.0, 1.0, 1.0, 1.0 };
    const threshold = ternary.calculateThreshold(&input);
    try std.testing.expect(threshold > 0.0);
}

test "ternary_threshold_negative" {
    const input = [_]f32{ -1.0, -1.0, -1.0, -1.0 };
    const threshold = ternary.calculateThreshold(&input);
    try std.testing.expect(threshold > 0.0);
}

test "ternary_threshold_zero" {
    const input = [_]f32{ 0.0, 0.0, 0.0, 0.0 };
    const threshold = ternary.calculateThreshold(&input);
    try std.testing.expectEqual(threshold, 0.0);
}

test "ternary_memory_savings" {
    // 1M parameters
    const num_params: usize = 1_000_000;
    const stats = ternary.MemoryStats.calculate(num_params);
    
    // FP32: 4 bytes per param = 4MB
    try std.testing.expectEqual(stats.f32_bytes, 4_000_000);
    
    // Ternary: 2 bits per param = 0.25MB
    try std.testing.expectEqual(stats.ternary_bytes, 250_000);
    
    // Compression ratio should be 16x
    const ratio = @as(f32, @floatFromInt(stats.f32_bytes)) / @as(f32, @floatFromInt(stats.ternary_bytes));
    try std.testing.expectApproxEqAbs(ratio, 16.0, 0.1);
}

test "parallel_quantization_context" {
    // Test that LayerQuantContext is properly initialized
    const ctx = LayerQuantContext{
        .layer_idx = 0,
        .model = undefined,
        .allocator = std.testing.allocator,
        .result = null,
        .err = null,
    };
    
    try std.testing.expectEqual(ctx.layer_idx, 0);
    try std.testing.expect(ctx.result == null);
    try std.testing.expect(ctx.err == null);
}

test "thread_pool_available" {
    // Verify thread pool is accessible
    const num_threads = bitnet.getPoolThreadCount();
    try std.testing.expect(num_threads >= 1);
}
