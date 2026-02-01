// GGUF INFERENCE ENGINE
// Run inference on GGUF quantized models
// phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");
const gguf = @import("gguf_reader.zig");

// Model configuration extracted from GGUF
pub const ModelConfig = struct {
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
};

// Dequantize Q8_0 tensor to f32
pub fn dequantizeQ8_0Tensor(allocator: std.mem.Allocator, data: []const u8, num_elements: u64) ![]f32 {
    const block_size: usize = 32;
    const type_size: usize = 34; // 2 bytes scale + 32 bytes data
    const num_blocks = (num_elements + block_size - 1) / block_size;

    const result = try allocator.alloc(f32, @intCast(num_elements));
    errdefer allocator.free(result);

    var block_idx: usize = 0;
    while (block_idx < num_blocks) : (block_idx += 1) {
        const block_start = block_idx * type_size;
        if (block_start + type_size > data.len) break;

        const block = data[block_start..][0..type_size];

        // Scale is f16 (2 bytes)
        const scale_bits = @as(u16, block[0]) | (@as(u16, block[1]) << 8);
        const scale = gguf.f16ToF32(scale_bits);

        // 32 int8 values
        const out_start = block_idx * block_size;
        var i: usize = 0;
        while (i < block_size and out_start + i < num_elements) : (i += 1) {
            const val: i8 = @bitCast(block[2 + i]);
            result[out_start + i] = @as(f32, @floatFromInt(val)) * scale;
        }
    }

    return result;
}

// Dequantize Q4_0 tensor to f32
pub fn dequantizeQ4_0Tensor(allocator: std.mem.Allocator, data: []const u8, num_elements: u64) ![]f32 {
    const block_size: usize = 32;
    const type_size: usize = 18; // 2 bytes scale + 16 bytes data (32 * 4 bits / 8)
    const num_blocks = (num_elements + block_size - 1) / block_size;

    const result = try allocator.alloc(f32, @intCast(num_elements));
    errdefer allocator.free(result);

    var block_idx: usize = 0;
    while (block_idx < num_blocks) : (block_idx += 1) {
        const block_start = block_idx * type_size;
        if (block_start + type_size > data.len) break;

        const block = data[block_start..][0..type_size];

        // Scale is f16 (2 bytes)
        const scale_bits = @as(u16, block[0]) | (@as(u16, block[1]) << 8);
        const scale = gguf.f16ToF32(scale_bits);

        // 16 bytes = 32 4-bit values
        const out_start = block_idx * block_size;
        var i: usize = 0;
        while (i < 16 and out_start + i * 2 < num_elements) : (i += 1) {
            const byte = block[2 + i];
            const lo: i8 = @as(i8, @intCast(byte & 0x0F)) - 8;
            const hi: i8 = @as(i8, @intCast(byte >> 4)) - 8;

            if (out_start + i * 2 < num_elements) {
                result[out_start + i * 2] = @as(f32, @floatFromInt(lo)) * scale;
            }
            if (out_start + i * 2 + 1 < num_elements) {
                result[out_start + i * 2 + 1] = @as(f32, @floatFromInt(hi)) * scale;
            }
        }
    }

    return result;
}

// Dequantize F32 tensor (just copy)
pub fn dequantizeF32Tensor(allocator: std.mem.Allocator, data: []const u8, num_elements: u64) ![]f32 {
    const result = try allocator.alloc(f32, @intCast(num_elements));
    const src = std.mem.bytesAsSlice(f32, data[0..@intCast(num_elements * 4)]);
    @memcpy(result, src);
    return result;
}

// Dequantize tensor based on type
pub fn dequantizeTensor(allocator: std.mem.Allocator, data: []const u8, tensor_type: gguf.GGMLType, num_elements: u64) ![]f32 {
    return switch (tensor_type) {
        .Q8_0 => dequantizeQ8_0Tensor(allocator, data, num_elements),
        .Q4_0 => dequantizeQ4_0Tensor(allocator, data, num_elements),
        .F32 => dequantizeF32Tensor(allocator, data, num_elements),
        else => error.UnsupportedQuantization,
    };
}

// RMS Normalization
pub fn rmsNorm(output: []f32, input: []const f32, weight: []const f32, eps: f32) void {
    const n = input.len;

    // Calculate RMS
    var sum_sq: f32 = 0.0;
    for (input) |x| {
        sum_sq += x * x;
    }
    const rms = @sqrt(sum_sq / @as(f32, @floatFromInt(n)) + eps);
    const scale = 1.0 / rms;

    // Normalize and apply weight
    for (output, 0..) |*o, i| {
        o.* = input[i] * scale * weight[i];
    }
}

// Matrix-vector multiplication
pub fn matVec(output: []f32, mat: []const f32, vec: []const f32, rows: usize, cols: usize) void {
    for (0..rows) |i| {
        var sum: f32 = 0.0;
        const row_start = i * cols;
        for (0..cols) |j| {
            sum += mat[row_start + j] * vec[j];
        }
        output[i] = sum;
    }
}

// SiLU activation
pub fn silu(x: f32) f32 {
    return x / (1.0 + @exp(-x));
}

// Softmax
pub fn softmax(output: []f32, input: []const f32) void {
    var max_val: f32 = input[0];
    for (input[1..]) |x| {
        if (x > max_val) max_val = x;
    }

    var sum: f32 = 0.0;
    for (input, 0..) |x, i| {
        output[i] = @exp(x - max_val);
        sum += output[i];
    }

    for (output) |*o| {
        o.* /= sum;
    }
}

// Sample from probability distribution
pub fn sample(probs: []const f32, temperature: f32) u32 {
    if (temperature == 0.0) {
        // Greedy sampling
        var max_idx: u32 = 0;
        var max_val: f32 = probs[0];
        for (probs[1..], 1..) |p, i| {
            if (p > max_val) {
                max_val = p;
                max_idx = @intCast(i);
            }
        }
        return max_idx;
    }

    // Temperature sampling
    var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const random = prng.random();
    const r = random.float(f32);

    var cumsum: f32 = 0.0;
    for (probs, 0..) |p, i| {
        cumsum += p;
        if (r < cumsum) {
            return @intCast(i);
        }
    }
    return @intCast(probs.len - 1);
}

// GGUF Model for inference
pub const GGUFModel = struct {
    allocator: std.mem.Allocator,
    reader: gguf.GGUFReader,
    config: ModelConfig,

    // Loaded weights (dequantized)
    token_embedding: ?[]f32,
    output_weight: ?[]f32,
    output_norm: ?[]f32,

    pub fn init(allocator: std.mem.Allocator, path: []const u8) !GGUFModel {
        var reader = try gguf.GGUFReader.init(allocator, path);
        errdefer reader.deinit();

        const arch = reader.getMetadataString("general.architecture") orelse "llama";

        var key_buf: [64]u8 = undefined;

        const vocab_size = blk: {
            // Try tokenizer.ggml.tokens array length
            if (reader.metadata.get("tokenizer.ggml.tokens")) |v| {
                if (v == .array) {
                    break :blk @as(u32, @intCast(v.array.len));
                }
            }
            // Fallback to output tensor dimension
            if (reader.getTensor("output.weight")) |t| {
                break :blk @as(u32, @intCast(t.dims[1]));
            }
            break :blk @as(u32, 32000);
        };

        const config = ModelConfig{
            .vocab_size = vocab_size,
            .hidden_size = @intCast(reader.getMetadataU64(std.fmt.bufPrint(&key_buf, "{s}.embedding_length", .{arch}) catch "llama.embedding_length") orelse 2048),
            .intermediate_size = @intCast(reader.getMetadataU64(std.fmt.bufPrint(&key_buf, "{s}.feed_forward_length", .{arch}) catch "llama.feed_forward_length") orelse 5632),
            .num_layers = @intCast(reader.getMetadataU64(std.fmt.bufPrint(&key_buf, "{s}.block_count", .{arch}) catch "llama.block_count") orelse 22),
            .num_heads = @intCast(reader.getMetadataU64(std.fmt.bufPrint(&key_buf, "{s}.attention.head_count", .{arch}) catch "llama.attention.head_count") orelse 32),
            .num_kv_heads = @intCast(reader.getMetadataU64(std.fmt.bufPrint(&key_buf, "{s}.attention.head_count_kv", .{arch}) catch "llama.attention.head_count_kv") orelse 4),
            .head_dim = 0, // Will be calculated
            .context_length = @intCast(reader.getMetadataU64(std.fmt.bufPrint(&key_buf, "{s}.context_length", .{arch}) catch "llama.context_length") orelse 2048),
            .rope_theta = reader.getMetadataF32(std.fmt.bufPrint(&key_buf, "{s}.rope.freq_base", .{arch}) catch "llama.rope.freq_base") orelse 10000.0,
            .rms_norm_eps = reader.getMetadataF32(std.fmt.bufPrint(&key_buf, "{s}.attention.layer_norm_rms_epsilon", .{arch}) catch "llama.attention.layer_norm_rms_epsilon") orelse 1e-5,
        };

        var model = GGUFModel{
            .allocator = allocator,
            .reader = reader,
            .config = config,
            .token_embedding = null,
            .output_weight = null,
            .output_norm = null,
        };

        model.config.head_dim = model.config.hidden_size / model.config.num_heads;

        return model;
    }

    pub fn deinit(self: *GGUFModel) void {
        if (self.token_embedding) |e| self.allocator.free(e);
        if (self.output_weight) |w| self.allocator.free(w);
        if (self.output_norm) |n| self.allocator.free(n);
        self.reader.deinit();
    }

    pub fn loadEmbeddings(self: *GGUFModel) !void {
        // Load token embeddings
        if (self.reader.getTensor("token_embd.weight")) |info| {
            const data = try self.reader.readTensorData(info);
            defer self.allocator.free(data);
            self.token_embedding = try dequantizeTensor(self.allocator, data, info.tensor_type, info.numElements());
        }

        // Load output weights
        if (self.reader.getTensor("output.weight")) |info| {
            const data = try self.reader.readTensorData(info);
            defer self.allocator.free(data);
            self.output_weight = try dequantizeTensor(self.allocator, data, info.tensor_type, info.numElements());
        }

        // Load output norm
        if (self.reader.getTensor("output_norm.weight")) |info| {
            const data = try self.reader.readTensorData(info);
            defer self.allocator.free(data);
            self.output_norm = try dequantizeTensor(self.allocator, data, info.tensor_type, info.numElements());
        }
    }

    pub fn printConfig(self: *const GGUFModel) void {
        std.debug.print("\n", .{});
        std.debug.print("MODEL CONFIG\n", .{});
        std.debug.print("  Vocab size:       {d}\n", .{self.config.vocab_size});
        std.debug.print("  Hidden size:      {d}\n", .{self.config.hidden_size});
        std.debug.print("  Intermediate:     {d}\n", .{self.config.intermediate_size});
        std.debug.print("  Num layers:       {d}\n", .{self.config.num_layers});
        std.debug.print("  Num heads:        {d}\n", .{self.config.num_heads});
        std.debug.print("  Num KV heads:     {d}\n", .{self.config.num_kv_heads});
        std.debug.print("  Head dim:         {d}\n", .{self.config.head_dim});
        std.debug.print("  Context length:   {d}\n", .{self.config.context_length});
    }

    // Simple forward pass (embedding lookup + output projection)
    pub fn forward(self: *GGUFModel, token: u32) ![]f32 {
        if (self.token_embedding == null or self.output_weight == null or self.output_norm == null) {
            return error.WeightsNotLoaded;
        }

        const hidden_size = self.config.hidden_size;
        const vocab_size = self.config.vocab_size;

        // Get embedding for token
        const emb_start = token * hidden_size;
        const embedding = self.token_embedding.?[emb_start..][0..hidden_size];

        // Apply RMS norm
        const normed = try self.allocator.alloc(f32, hidden_size);
        defer self.allocator.free(normed);
        rmsNorm(normed, embedding, self.output_norm.?, self.config.rms_norm_eps);

        // Project to vocab (output_weight is [hidden_size, vocab_size])
        const logits = try self.allocator.alloc(f32, vocab_size);
        matVec(logits, self.output_weight.?, normed, vocab_size, hidden_size);

        return logits;
    }

    // Generate next token
    pub fn generateToken(self: *GGUFModel, token: u32, temperature: f32) !u32 {
        const logits = try self.forward(token);
        defer self.allocator.free(logits);

        // Apply temperature and softmax
        if (temperature > 0) {
            for (logits) |*l| {
                l.* /= temperature;
            }
        }

        const probs = try self.allocator.alloc(f32, logits.len);
        defer self.allocator.free(probs);
        softmax(probs, logits);

        return sample(probs, temperature);
    }
};

// Tests
test "dequantize_q8_0" {
    const allocator = std.testing.allocator;

    // Create test Q8_0 block: scale=1.0 (0x3C00 in f16), values=[1,2,3...]
    var block: [34]u8 = undefined;
    block[0] = 0x00; // f16 1.0 low byte
    block[1] = 0x3C; // f16 1.0 high byte
    for (0..32) |i| {
        block[2 + i] = @intCast(i);
    }

    const result = try dequantizeQ8_0Tensor(allocator, &block, 32);
    defer allocator.free(result);

    try std.testing.expectApproxEqAbs(result[0], 0.0, 0.01);
    try std.testing.expectApproxEqAbs(result[1], 1.0, 0.01);
    try std.testing.expectApproxEqAbs(result[31], 31.0, 0.01);
}

test "rms_norm" {
    var input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var weight = [_]f32{ 1.0, 1.0, 1.0, 1.0 };
    var output: [4]f32 = undefined;

    rmsNorm(&output, &input, &weight, 1e-5);

    // RMS of [1,2,3,4] = sqrt((1+4+9+16)/4) = sqrt(7.5) ≈ 2.74
    // Normalized: [0.365, 0.730, 1.095, 1.461]
    try std.testing.expect(output[0] > 0.3 and output[0] < 0.4);
}

test "softmax" {
    var input = [_]f32{ 1.0, 2.0, 3.0 };
    var output: [3]f32 = undefined;

    softmax(&output, &input);

    // Sum should be 1.0
    const sum = output[0] + output[1] + output[2];
    try std.testing.expectApproxEqAbs(sum, 1.0, 0.001);

    // output[2] should be largest
    try std.testing.expect(output[2] > output[1]);
    try std.testing.expect(output[1] > output[0]);
}
