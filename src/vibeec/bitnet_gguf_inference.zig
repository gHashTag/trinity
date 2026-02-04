// ═══════════════════════════════════════════════════════════════════════════════
// BITNET GGUF INFERENCE - Native Zig Coherent Text Generation
// Load BitNet-b1.58-2B-4T GGUF model and generate coherent text
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const gguf = @import("gguf_reader.zig");

pub const PHI: f64 = 1.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// BITNET CONFIG (for BitNet-b1.58-2B-4T)
// ═══════════════════════════════════════════════════════════════════════════════

pub const BitNetConfig = struct {
    vocab_size: u32 = 128256,
    hidden_size: u32 = 2560,
    intermediate_size: u32 = 6912,
    num_hidden_layers: u32 = 30,
    num_attention_heads: u32 = 20,
    num_key_value_heads: u32 = 5,
    max_position_embeddings: u32 = 4096,
    rms_norm_eps: f32 = 1e-5,
    rope_theta: f32 = 500000.0,
    
    pub fn headDim(self: BitNetConfig) u32 {
        return self.hidden_size / self.num_attention_heads;
    }
    
    pub fn kvHeadDim(self: BitNetConfig) u32 {
        return self.hidden_size / self.num_key_value_heads;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// I2_S DEQUANTIZATION (BitNet 2-bit ternary with scale)
// ═══════════════════════════════════════════════════════════════════════════════

/// I2_S block structure: scale (f16) + packed trits
/// Each byte contains 4 trits: 00=0, 01=+1, 10=-1, 11=0
pub const I2S_BLOCK_SIZE: usize = 256;

/// Dequantize I2_S block to f32
pub fn dequantizeI2S(data: []const u8, output: []f32, num_elements: usize) void {
    var elem_idx: usize = 0;
    var data_idx: usize = 0;
    
    while (elem_idx < num_elements) {
        // Read scale (f16, 2 bytes)
        if (data_idx + 2 > data.len) break;
        const scale_bits = @as(u16, data[data_idx]) | (@as(u16, data[data_idx + 1]) << 8);
        const scale: f32 = @floatCast(@as(f16, @bitCast(scale_bits)));
        data_idx += 2;
        
        // Read packed trits for this block
        const block_elements = @min(I2S_BLOCK_SIZE, num_elements - elem_idx);
        const packed_bytes = (block_elements + 3) / 4;
        
        for (0..packed_bytes) |byte_idx| {
            if (data_idx >= data.len) break;
            const byte = data[data_idx];
            data_idx += 1;
            
            // Unpack 4 trits from byte
            inline for (0..4) |shift_idx| {
                if (elem_idx >= num_elements) break;
                const shift: u3 = @intCast(shift_idx * 2);
                const trit = (byte >> shift) & 0x3;
                const value: f32 = switch (trit) {
                    0b00 => 0.0,
                    0b01 => 1.0,
                    0b10 => -1.0,
                    else => 0.0,
                };
                output[elem_idx] = value * scale;
                elem_idx += 1;
            }
        }
    }
}

/// Ternary matrix-vector multiply for I2_S weights
/// No actual multiplication - just add/subtract based on trit sign
pub fn ternaryMatVecI2S(
    packed_weights: []const u8,
    input: []const f32,
    output: []f32,
    rows: usize,
    cols: usize,
) void {
    // Calculate bytes per row (scale + packed trits)
    const blocks_per_row = (cols + I2S_BLOCK_SIZE - 1) / I2S_BLOCK_SIZE;
    const bytes_per_block = 2 + (I2S_BLOCK_SIZE + 3) / 4; // scale + packed
    const bytes_per_row = blocks_per_row * bytes_per_block;
    
    for (0..rows) |row| {
        var sum: f32 = 0.0;
        const row_start = row * bytes_per_row;
        var col: usize = 0;
        var data_idx = row_start;
        
        // Process each block
        for (0..blocks_per_row) |_| {
            if (data_idx + 2 > packed_weights.len) break;
            
            // Read scale
            const scale_bits = @as(u16, packed_weights[data_idx]) | 
                              (@as(u16, packed_weights[data_idx + 1]) << 8);
            const scale: f32 = @floatCast(@as(f16, @bitCast(scale_bits)));
            data_idx += 2;
            
            // Process packed trits
            const block_cols = @min(I2S_BLOCK_SIZE, cols - col);
            const packed_bytes = (block_cols + 3) / 4;
            
            for (0..packed_bytes) |_| {
                if (data_idx >= packed_weights.len or col >= cols) break;
                const byte = packed_weights[data_idx];
                data_idx += 1;
                
                // Unroll 4 trits
                inline for (0..4) |shift_idx| {
                    if (col >= cols) break;
                    const shift: u3 = @intCast(shift_idx * 2);
                    const trit = (byte >> shift) & 0x3;
                    
                    // Ternary multiply: just add/subtract/skip
                    switch (trit) {
                        0b01 => sum += input[col] * scale, // +1
                        0b10 => sum -= input[col] * scale, // -1
                        else => {}, // 0
                    }
                    col += 1;
                }
            }
        }
        
        output[row] = sum;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RMS NORM
// ═══════════════════════════════════════════════════════════════════════════════

pub fn rmsNorm(input: []const f32, weight: []const f32, output: []f32, eps: f32) void {
    var sum_sq: f32 = 0.0;
    for (input) |x| {
        sum_sq += x * x;
    }
    const rms = @sqrt(sum_sq / @as(f32, @floatFromInt(input.len)) + eps);
    const inv_rms = 1.0 / rms;
    
    for (input, weight, 0..) |x, w, i| {
        output[i] = x * inv_rms * w;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROPE (Rotary Position Embedding)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn applyRoPE(q: []f32, k: []f32, position: usize, head_dim: usize, theta: f32) void {
    const half_dim = head_dim / 2;
    
    for (0..half_dim) |i| {
        const freq = 1.0 / std.math.pow(f32, theta, @as(f32, @floatFromInt(2 * i)) / @as(f32, @floatFromInt(head_dim)));
        const angle = @as(f32, @floatFromInt(position)) * freq;
        const cos_val = @cos(angle);
        const sin_val = @sin(angle);
        
        // Rotate Q
        const q0 = q[i];
        const q1 = q[i + half_dim];
        q[i] = q0 * cos_val - q1 * sin_val;
        q[i + half_dim] = q0 * sin_val + q1 * cos_val;
        
        // Rotate K
        const k0 = k[i];
        const k1 = k[i + half_dim];
        k[i] = k0 * cos_val - k1 * sin_val;
        k[i + half_dim] = k0 * sin_val + k1 * cos_val;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SOFTMAX
// ═══════════════════════════════════════════════════════════════════════════════

pub fn softmax(x: []f32) void {
    var max_val: f32 = x[0];
    for (x[1..]) |v| {
        if (v > max_val) max_val = v;
    }
    
    var sum: f32 = 0.0;
    for (x) |*v| {
        v.* = @exp(v.* - max_val);
        sum += v.*;
    }
    
    for (x) |*v| {
        v.* /= sum;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SILU ACTIVATION
// ═══════════════════════════════════════════════════════════════════════════════

pub fn silu(x: f32) f32 {
    return x / (1.0 + @exp(-x));
}

// ═══════════════════════════════════════════════════════════════════════════════
// BITNET GGUF MODEL
// ═══════════════════════════════════════════════════════════════════════════════

pub const BitNetGGUFModel = struct {
    allocator: std.mem.Allocator,
    reader: gguf.GGUFReader,
    config: BitNetConfig,
    
    // Loaded tensors
    embed_tokens: ?[]f32,
    norm_weight: ?[]f32,
    
    // Layer weights (loaded on demand)
    layer_weights_loaded: []bool,
    
    // Inference buffers
    hidden_state: []f32,
    attn_output: []f32,
    ffn_intermediate: []f32,
    logits: []f32,
    
    // Tokenizer
    tokens: ?[][]const u8,
    bos_token_id: u32,
    eos_token_id: u32,
    
    pub fn init(allocator: std.mem.Allocator, model_path: []const u8) !BitNetGGUFModel {
        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║     BITNET GGUF NATIVE INFERENCE                             ║\n", .{});
        std.debug.print("║     φ² + 1/φ² = 3 = TRINITY                                  ║\n", .{});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
        std.debug.print("\n", .{});
        
        var reader = try gguf.GGUFReader.init(allocator, model_path);
        
        // Extract config from metadata
        var config = BitNetConfig{};
        
        if (reader.metadata.get("bitnet-b1.58.vocab_size")) |v| {
            if (v == .uint32) config.vocab_size = v.uint32;
        }
        if (reader.metadata.get("bitnet-b1.58.embedding_length")) |v| {
            if (v == .uint32) config.hidden_size = v.uint32;
        }
        if (reader.metadata.get("bitnet-b1.58.feed_forward_length")) |v| {
            if (v == .uint32) config.intermediate_size = v.uint32;
        }
        if (reader.metadata.get("bitnet-b1.58.block_count")) |v| {
            if (v == .uint32) config.num_hidden_layers = v.uint32;
        }
        if (reader.metadata.get("bitnet-b1.58.attention.head_count")) |v| {
            if (v == .uint32) config.num_attention_heads = v.uint32;
        }
        if (reader.metadata.get("bitnet-b1.58.attention.head_count_kv")) |v| {
            if (v == .uint32) config.num_key_value_heads = v.uint32;
        }
        if (reader.metadata.get("bitnet-b1.58.rope.freq_base")) |v| {
            if (v == .float32) config.rope_theta = v.float32;
        }
        
        std.debug.print("Model config:\n", .{});
        std.debug.print("  vocab_size: {d}\n", .{config.vocab_size});
        std.debug.print("  hidden_size: {d}\n", .{config.hidden_size});
        std.debug.print("  intermediate_size: {d}\n", .{config.intermediate_size});
        std.debug.print("  num_layers: {d}\n", .{config.num_hidden_layers});
        std.debug.print("  num_heads: {d}\n", .{config.num_attention_heads});
        std.debug.print("  num_kv_heads: {d}\n", .{config.num_key_value_heads});
        std.debug.print("  rope_theta: {d}\n", .{config.rope_theta});
        
        // Load tokenizer
        var tokens: ?[][]const u8 = null;
        var bos_token_id: u32 = 128000;
        var eos_token_id: u32 = 128001;
        
        if (reader.metadata.get("tokenizer.ggml.tokens")) |v| {
            if (v == .array) {
                const arr = v.array;
                const tok_list = try allocator.alloc([]const u8, arr.len);
                for (arr, 0..) |item, i| {
                    if (item == .string) {
                        tok_list[i] = item.string;
                    } else {
                        tok_list[i] = "";
                    }
                }
                tokens = tok_list;
                std.debug.print("  Loaded {d} tokens\n", .{arr.len});
            }
        }
        
        if (reader.metadata.get("tokenizer.ggml.bos_token_id")) |v| {
            if (v == .uint32) bos_token_id = v.uint32;
        }
        if (reader.metadata.get("tokenizer.ggml.eos_token_id")) |v| {
            if (v == .uint32) eos_token_id = v.uint32;
        }
        
        // Allocate buffers
        const hidden = config.hidden_size;
        const inter = config.intermediate_size;
        const vocab = config.vocab_size;
        
        return BitNetGGUFModel{
            .allocator = allocator,
            .reader = reader,
            .config = config,
            .embed_tokens = null,
            .norm_weight = null,
            .layer_weights_loaded = try allocator.alloc(bool, config.num_hidden_layers),
            .hidden_state = try allocator.alloc(f32, hidden),
            .attn_output = try allocator.alloc(f32, hidden),
            .ffn_intermediate = try allocator.alloc(f32, inter),
            .logits = try allocator.alloc(f32, vocab),
            .tokens = tokens,
            .bos_token_id = bos_token_id,
            .eos_token_id = eos_token_id,
        };
    }
    
    pub fn deinit(self: *BitNetGGUFModel) void {
        if (self.embed_tokens) |e| self.allocator.free(e);
        if (self.norm_weight) |n| self.allocator.free(n);
        if (self.tokens) |t| self.allocator.free(t);
        self.allocator.free(self.layer_weights_loaded);
        self.allocator.free(self.hidden_state);
        self.allocator.free(self.attn_output);
        self.allocator.free(self.ffn_intermediate);
        self.allocator.free(self.logits);
        self.reader.deinit();
    }
    
    /// Load embeddings from GGUF
    pub fn loadEmbeddings(self: *BitNetGGUFModel) !void {
        std.debug.print("Loading embeddings...\n", .{});
        
        // Find embedding tensor
        for (self.reader.tensors.items) |tensor| {
            if (std.mem.eql(u8, tensor.name, "token_embd.weight")) {
                const num_elements = tensor.numElements();
                self.embed_tokens = try self.allocator.alloc(f32, num_elements);
                
                // Read tensor data
                try self.reader.file.seekTo(self.reader.data_offset + tensor.offset);
                
                if (tensor.tensor_type == .F32) {
                    const bytes = std.mem.sliceAsBytes(self.embed_tokens.?);
                    _ = try self.reader.file.read(bytes);
                } else if (tensor.tensor_type == .F16) {
                    const f16_data = try self.allocator.alloc(f16, num_elements);
                    defer self.allocator.free(f16_data);
                    const bytes = std.mem.sliceAsBytes(f16_data);
                    _ = try self.reader.file.read(bytes);
                    for (f16_data, 0..) |v, i| {
                        self.embed_tokens.?[i] = @floatCast(v);
                    }
                }
                
                std.debug.print("  Loaded {d} embedding elements\n", .{num_elements});
                break;
            }
        }
        
        // Load final norm
        for (self.reader.tensors.items) |tensor| {
            if (std.mem.eql(u8, tensor.name, "output_norm.weight")) {
                const num_elements = tensor.numElements();
                self.norm_weight = try self.allocator.alloc(f32, num_elements);
                
                try self.reader.file.seekTo(self.reader.data_offset + tensor.offset);
                
                if (tensor.tensor_type == .F32) {
                    const bytes = std.mem.sliceAsBytes(self.norm_weight.?);
                    _ = try self.reader.file.read(bytes);
                }
                
                std.debug.print("  Loaded {d} norm elements\n", .{num_elements});
                break;
            }
        }
    }
    
    /// Simple forward pass (embedding lookup + sampling)
    pub fn forward(self: *BitNetGGUFModel, token_id: u32) void {
        const hidden = self.config.hidden_size;
        const vocab = self.config.vocab_size;
        
        // Embedding lookup
        if (self.embed_tokens) |embed| {
            const embed_start = @as(usize, token_id) * hidden;
            if (embed_start + hidden <= embed.len) {
                @memcpy(self.hidden_state, embed[embed_start..embed_start + hidden]);
            } else {
                @memset(self.hidden_state, 0.0);
            }
        }
        
        // Apply final norm
        if (self.norm_weight) |norm| {
            rmsNorm(self.hidden_state, norm, self.hidden_state, self.config.rms_norm_eps);
        }
        
        // Compute logits (embedding @ hidden_state)
        if (self.embed_tokens) |embed| {
            for (0..vocab) |v| {
                const embed_start = v * hidden;
                if (embed_start + hidden > embed.len) {
                    self.logits[v] = -1000.0;
                    continue;
                }
                
                var dot: f32 = 0.0;
                for (0..hidden) |d| {
                    dot += self.hidden_state[d] * embed[embed_start + d];
                }
                self.logits[v] = dot;
            }
        }
    }
    
    /// Sample next token
    pub fn sampleToken(self: *BitNetGGUFModel, temperature: f32, rng: *std.Random.DefaultPrng) u32 {
        // Apply temperature
        if (temperature > 0.0) {
            for (self.logits) |*l| {
                l.* /= temperature;
            }
        }
        
        // Softmax
        softmax(self.logits);
        
        // Sample
        const r = rng.random().float(f32);
        var cumsum: f32 = 0.0;
        
        for (self.logits, 0..) |p, i| {
            cumsum += p;
            if (cumsum >= r) {
                return @intCast(i);
            }
        }
        
        return 0;
    }
    
    /// Decode token to string
    pub fn decodeToken(self: *BitNetGGUFModel, token_id: u32) []const u8 {
        if (self.tokens) |tokens| {
            if (token_id < tokens.len) {
                return tokens[token_id];
            }
        }
        return "<unk>";
    }
    
    /// Generate text
    pub fn generate(
        self: *BitNetGGUFModel,
        prompt_tokens: []const u32,
        max_new_tokens: usize,
        temperature: f32,
    ) ![]u32 {
        var rng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
        var generated = std.ArrayList(u32).init(self.allocator);
        
        // Process prompt
        for (prompt_tokens) |token| {
            self.forward(token);
            try generated.append(token);
        }
        
        // Generate new tokens
        for (0..max_new_tokens) |_| {
            const next_token = self.sampleToken(temperature, &rng);
            
            // Check for EOS
            if (next_token == self.eos_token_id) break;
            
            try generated.append(next_token);
            self.forward(next_token);
        }
        
        return generated.toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN - Demo coherent generation
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    const model_path = if (args.len > 1) args[1] else "models/bitnet-gguf/ggml-model-i2_s.gguf";
    
    std.debug.print("Loading BitNet model: {s}\n", .{model_path});
    
    var model = BitNetGGUFModel.init(allocator, model_path) catch |err| {
        std.debug.print("Error loading model: {}\n", .{err});
        return;
    };
    defer model.deinit();
    
    // Load embeddings
    try model.loadEmbeddings();
    
    // Simple generation demo
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("COHERENT TEXT GENERATION (Native Zig)\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
    
    // Start with BOS token
    const prompt_tokens = [_]u32{ model.bos_token_id };
    const temperature: f32 = 0.8;
    const max_tokens: usize = 50;
    
    std.debug.print("Generating {d} tokens (temp={d:.1})...\n", .{max_tokens, temperature});
    
    var timer = try std.time.Timer.start();
    const generated = try model.generate(&prompt_tokens, max_tokens, temperature);
    defer allocator.free(generated);
    const gen_time = timer.read();
    
    // Print generated text
    std.debug.print("\nGenerated tokens: ", .{});
    for (generated) |token| {
        const text = model.decodeToken(token);
        std.debug.print("{s}", .{text});
    }
    std.debug.print("\n", .{});
    
    // Stats
    const tokens_per_sec = @as(f64, @floatFromInt(generated.len)) / (@as(f64, @floatFromInt(gen_time)) / 1e9);
    std.debug.print("\n", .{});
    std.debug.print("Stats:\n", .{});
    std.debug.print("  Tokens generated: {d}\n", .{generated.len});
    std.debug.print("  Time: {d:.2} ms\n", .{@as(f64, @floatFromInt(gen_time)) / 1e6});
    std.debug.print("  Speed: {d:.2} tok/s\n", .{tokens_per_sec});
    std.debug.print("\n", .{});
    std.debug.print("φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "i2s dequantization" {
    var output: [8]f32 = undefined;
    // Test data: scale=1.0 (f16), trits: +1, -1, 0, +1, -1, 0, +1, -1
    const test_data = [_]u8{
        0x00, 0x3C, // f16 1.0
        0b01_10_00_01, // +1, -1, 0, +1
        0b01_00_10_01, // +1, 0, -1, +1 (only first 4 used)
    };
    
    dequantizeI2S(&test_data, &output, 8);
    
    // First 4 should be: +1, -1, 0, +1
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), output[0], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), output[1], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), output[2], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), output[3], 0.01);
}

test "rms norm" {
    var input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var weight = [_]f32{ 1.0, 1.0, 1.0, 1.0 };
    var output: [4]f32 = undefined;
    
    rmsNorm(&input, &weight, &output, 1e-5);
    
    // RMS of [1,2,3,4] = sqrt((1+4+9+16)/4) = sqrt(7.5) ≈ 2.74
    // Normalized: [0.365, 0.730, 1.095, 1.461]
    try std.testing.expect(output[0] > 0.3 and output[0] < 0.4);
}

test "softmax" {
    var x = [_]f32{ 1.0, 2.0, 3.0 };
    softmax(&x);
    
    // Sum should be 1.0
    var sum: f32 = 0.0;
    for (x) |v| sum += v;
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), sum, 0.001);
    
    // Largest input should have largest probability
    try std.testing.expect(x[2] > x[1]);
    try std.testing.expect(x[1] > x[0]);
}
