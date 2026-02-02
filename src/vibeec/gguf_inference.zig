// GGUF INFERENCE ENGINE
// Run inference on GGUF quantized models
// phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");
const gguf = @import("gguf_reader.zig");
const simd = @import("simd_matmul.zig");

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

// ═══════════════════════════════════════════════════════════════════════════════
// PARALLEL DEQUANTIZATION (OPT-003)
// Multi-threaded weight loading for 5-6x faster model startup
// ═══════════════════════════════════════════════════════════════════════════════

const Q8_0_BLOCK_SIZE: usize = 32;
const Q8_0_TYPE_SIZE: usize = 34; // 2 bytes scale + 32 bytes data
const PARALLEL_THRESHOLD: usize = 100_000; // Use parallel for >100K elements
const DEFAULT_NUM_THREADS: usize = 8; // Conservative default

// Thread worker context for Q8_0 dequantization
const DequantQ8_0Context = struct {
    data: []const u8,
    result: []f32,
    start_block: usize,
    end_block: usize,
    num_elements: usize,
};

// Worker function for parallel Q8_0 dequantization
fn dequantQ8_0Worker(ctx: *DequantQ8_0Context) void {
    var block_idx = ctx.start_block;
    while (block_idx < ctx.end_block) : (block_idx += 1) {
        const block_start = block_idx * Q8_0_TYPE_SIZE;
        if (block_start + Q8_0_TYPE_SIZE > ctx.data.len) break;

        const block = ctx.data[block_start..][0..Q8_0_TYPE_SIZE];

        // Scale is f16 (2 bytes)
        const scale_bits = @as(u16, block[0]) | (@as(u16, block[1]) << 8);
        const scale = gguf.f16ToF32(scale_bits);

        // 32 int8 values
        const out_start = block_idx * Q8_0_BLOCK_SIZE;
        var i: usize = 0;
        while (i < Q8_0_BLOCK_SIZE and out_start + i < ctx.num_elements) : (i += 1) {
            const val: i8 = @bitCast(block[2 + i]);
            ctx.result[out_start + i] = @as(f32, @floatFromInt(val)) * scale;
        }
    }
}

// Dequantize Q8_0 tensor to f32 - PARALLEL VERSION
pub fn dequantizeQ8_0Tensor(allocator: std.mem.Allocator, data: []const u8, num_elements: u64) ![]f32 {
    const num_blocks = (num_elements + Q8_0_BLOCK_SIZE - 1) / Q8_0_BLOCK_SIZE;

    const result = try allocator.alloc(f32, @intCast(num_elements));
    errdefer allocator.free(result);

    // Use parallel processing for large tensors
    if (num_elements >= PARALLEL_THRESHOLD) {
        const num_threads = @min(DEFAULT_NUM_THREADS, @max(1, num_blocks / 1000));
        const blocks_per_thread = (num_blocks + num_threads - 1) / num_threads;

        var contexts: [DEFAULT_NUM_THREADS]DequantQ8_0Context = undefined;
        var threads: [DEFAULT_NUM_THREADS]?std.Thread = undefined;

        // Spawn worker threads
        for (0..num_threads) |t| {
            const start_block = t * blocks_per_thread;
            const end_block = @min((t + 1) * blocks_per_thread, num_blocks);

            contexts[t] = DequantQ8_0Context{
                .data = data,
                .result = result,
                .start_block = start_block,
                .end_block = end_block,
                .num_elements = @intCast(num_elements),
            };

            threads[t] = std.Thread.spawn(.{}, dequantQ8_0Worker, .{&contexts[t]}) catch null;
        }

        // Wait for all threads
        for (0..num_threads) |t| {
            if (threads[t]) |thread| {
                thread.join();
            } else {
                // Fallback: process this chunk in main thread
                dequantQ8_0Worker(&contexts[t]);
            }
        }
    } else {
        // Sequential for small tensors (avoid thread overhead)
        var ctx = DequantQ8_0Context{
            .data = data,
            .result = result,
            .start_block = 0,
            .end_block = num_blocks,
            .num_elements = @intCast(num_elements),
        };
        dequantQ8_0Worker(&ctx);
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

// Dequantize Q5_0 tensor to f32
// Q5_0: 32 elements per block, 5-bit quantization
// Structure: d(f16) + qh[4] + qs[16]
pub fn dequantizeQ5_0Tensor(allocator: std.mem.Allocator, data: []const u8, num_elements: u64) ![]f32 {
    const block_size: usize = 32;
    const type_size: usize = 22; // 2 + 4 + 16
    const num_blocks = (num_elements + block_size - 1) / block_size;

    const result = try allocator.alloc(f32, @intCast(num_elements));
    errdefer allocator.free(result);

    var block_idx: usize = 0;
    while (block_idx < num_blocks) : (block_idx += 1) {
        const block_start = block_idx * type_size;
        if (block_start + type_size > data.len) break;

        const block = data[block_start..][0..type_size];
        const out_start = block_idx * block_size;

        // Scale is f16 (2 bytes)
        const scale_bits = @as(u16, block[0]) | (@as(u16, block[1]) << 8);
        const d = gguf.f16ToF32(scale_bits);

        // qh: 4 bytes containing high bits
        const qh = @as(u32, block[2]) | (@as(u32, block[3]) << 8) | 
                   (@as(u32, block[4]) << 16) | (@as(u32, block[5]) << 24);

        // qs: 16 bytes containing low 4 bits
        const qs = block[6..22];

        // Dequantize 32 values
        var j: usize = 0;
        while (j < 16) : (j += 1) {
            // Extract high bits
            const xh_0 = ((qh >> @intCast(j + 0)) << 4) & 0x10;
            const xh_1 = ((qh >> @intCast(j + 12))) & 0x10;

            // Combine low and high bits
            const x0: i32 = @as(i32, @intCast((qs[j] & 0x0F) | @as(u8, @intCast(xh_0)))) - 16;
            const x1: i32 = @as(i32, @intCast((qs[j] >> 4) | @as(u8, @intCast(xh_1)))) - 16;

            if (out_start + j < num_elements) {
                result[out_start + j] = @as(f32, @floatFromInt(x0)) * d;
            }
            if (out_start + j + 16 < num_elements) {
                result[out_start + j + 16] = @as(f32, @floatFromInt(x1)) * d;
            }
        }
    }

    return result;
}

// Dequantize Q4_K tensor to f32 (k-quants format)
// Q4_K: 256 elements per block, super-blocks with scales
// Structure: d(f16) + dmin(f16) + scales[12] + qs[128]
// Based on llama.cpp dequantize_row_q4_K
pub fn dequantizeQ4_KTensor(allocator: std.mem.Allocator, data: []const u8, num_elements: u64) ![]f32 {
    const QK_K: usize = 256; // Super-block size
    const type_size: usize = 144; // 2 + 2 + 12 + 128
    const num_blocks = (num_elements + QK_K - 1) / QK_K;

    const result = try allocator.alloc(f32, @intCast(num_elements));
    errdefer allocator.free(result);

    var block_idx: usize = 0;
    while (block_idx < num_blocks) : (block_idx += 1) {
        const block_start = block_idx * type_size;
        if (block_start + type_size > data.len) break;

        const block = data[block_start..][0..type_size];
        const out_start = block_idx * QK_K;

        // Q4_K structure:
        // - d (f16): 2 bytes - super-block scale for quantized scales
        // - dmin (f16): 2 bytes - super-block scale for quantized mins
        // - scales[12]: 12 bytes - 8 sub-block scales/mins packed in 6 bits
        // - qs[128]: 128 bytes - 256 4-bit quantized values

        const d_bits = @as(u16, block[0]) | (@as(u16, block[1]) << 8);
        const dmin_bits = @as(u16, block[2]) | (@as(u16, block[3]) << 8);
        const d = gguf.f16ToF32(d_bits);
        const min = gguf.f16ToF32(dmin_bits);



        const scales = block[4..16]; // 12 bytes of scales
        const qs = block[16..144]; // 128 bytes of quantized values

        // Process 8 sub-blocks of 32 elements each (256 total)
        var is: usize = 0;
        var q_idx: usize = 0;
        var out_idx: usize = out_start;

        // Process in groups of 64 (2 sub-blocks at a time)
        var j: usize = 0;
        while (j < QK_K) : (j += 64) {
            // Get scale and min for first sub-block
            var sc1: u8 = undefined;
            var m1: u8 = undefined;
            getScaleMinK4(is + 0, scales, &sc1, &m1);
            const d1 = d * @as(f32, @floatFromInt(sc1));
            const min1 = min * @as(f32, @floatFromInt(m1));

            // Get scale and min for second sub-block
            var sc2: u8 = undefined;
            var m2: u8 = undefined;
            getScaleMinK4(is + 1, scales, &sc2, &m2);
            const d2 = d * @as(f32, @floatFromInt(sc2));
            const min2 = min * @as(f32, @floatFromInt(m2));

            // Dequantize 32 elements (low nibbles)
            var l: usize = 0;
            while (l < 32) : (l += 1) {
                if (out_idx >= num_elements) break;
                const q_val = qs[q_idx + l] & 0x0F;
                result[out_idx] = d1 * @as(f32, @floatFromInt(q_val)) - min1;
                out_idx += 1;
            }

            // Dequantize 32 elements (high nibbles)
            l = 0;
            while (l < 32) : (l += 1) {
                if (out_idx >= num_elements) break;
                const q_val = qs[q_idx + l] >> 4;
                result[out_idx] = d2 * @as(f32, @floatFromInt(q_val)) - min2;
                out_idx += 1;
            }

            q_idx += 32;
            is += 2;
        }
    }

    return result;
}

// Helper function to extract scale and min from packed 6-bit format
// Based on llama.cpp get_scale_min_k4
fn getScaleMinK4(j: usize, scales: []const u8, d: *u8, m: *u8) void {
    if (j < 4) {
        d.* = scales[j] & 63;
        m.* = scales[j + 4] & 63;
    } else {
        d.* = (scales[j + 4] & 0x0F) | ((scales[j - 4] >> 6) << 4);
        m.* = (scales[j + 4] >> 4) | ((scales[j] >> 6) << 4);
    }
}

// Dequantize Q6_K tensor to f32
// Q6_K: 256 elements per block, 6-bit quantization
// Structure: ql[128] + qh[64] + scales[16] + d(f16)
pub fn dequantizeQ6_KTensor(allocator: std.mem.Allocator, data: []const u8, num_elements: u64) ![]f32 {
    const QK_K: usize = 256;
    const type_size: usize = 210; // 128 + 64 + 16 + 2
    const num_blocks = (num_elements + QK_K - 1) / QK_K;

    const result = try allocator.alloc(f32, @intCast(num_elements));
    errdefer allocator.free(result);

    var block_idx: usize = 0;
    while (block_idx < num_blocks) : (block_idx += 1) {
        const block_start = block_idx * type_size;
        if (block_start + type_size > data.len) break;

        const block = data[block_start..][0..type_size];
        const out_start = block_idx * QK_K;

        // Q6_K structure:
        // - ql[128]: low 4 bits of 6-bit values
        // - qh[64]: high 2 bits of 6-bit values
        // - scales[16]: 8-bit scales for 16 sub-blocks
        // - d (f16): super-block scale

        const ql = block[0..128];
        const qh = block[128..192];
        const scales = block[192..208];
        const d_bits = @as(u16, block[208]) | (@as(u16, block[209]) << 8);
        const d = gguf.f16ToF32(d_bits);

        var out_idx: usize = out_start;
        var ql_idx: usize = 0;
        var qh_idx: usize = 0;
        var sc_idx: usize = 0;

        // Process 16 sub-blocks of 16 elements each
        var n: usize = 0;
        while (n < QK_K) : (n += 128) {
            var shift: u3 = 0;
            while (shift < 4) : (shift += 1) {
                var m: usize = 0;
                while (m < 16) : (m += 1) {
                    if (out_idx >= num_elements) break;
                    
                    const sc: i8 = @bitCast(scales[sc_idx]);
                    const scale = d * @as(f32, @floatFromInt(sc));
                    
                    // Combine low 4 bits and high 2 bits
                    const q_lo = ql[ql_idx + m] & 0x0F;
                    const q_hi = (qh[qh_idx + m] >> @intCast(shift * 2)) & 0x03;
                    const q: i8 = @as(i8, @intCast((q_lo | (q_hi << 4)))) - 32;
                    
                    result[out_idx] = scale * @as(f32, @floatFromInt(q));
                    out_idx += 1;
                }
                
                m = 0;
                while (m < 16) : (m += 1) {
                    if (out_idx >= num_elements) break;
                    
                    const sc: i8 = @bitCast(scales[sc_idx + 1]);
                    const scale = d * @as(f32, @floatFromInt(sc));
                    
                    const q_lo = ql[ql_idx + m] >> 4;
                    const q_hi = (qh[qh_idx + m] >> @intCast(shift * 2 + 1)) & 0x03;
                    const q: i8 = @as(i8, @intCast((q_lo | (q_hi << 4)))) - 32;
                    
                    result[out_idx] = scale * @as(f32, @floatFromInt(q));
                    out_idx += 1;
                }
                
                ql_idx += 16;
                sc_idx += 2;
            }
            qh_idx += 32;
        }
    }

    return result;
}

// Dequantize tensor based on type
pub fn dequantizeTensor(allocator: std.mem.Allocator, data: []const u8, tensor_type: gguf.GGMLType, num_elements: u64) ![]f32 {
    return switch (tensor_type) {
        .Q8_0 => dequantizeQ8_0Tensor(allocator, data, num_elements),
        .Q4_0 => dequantizeQ4_0Tensor(allocator, data, num_elements),
        .Q5_0 => dequantizeQ5_0Tensor(allocator, data, num_elements),
        .Q4_K => dequantizeQ4_KTensor(allocator, data, num_elements),
        .Q6_K => dequantizeQ6_KTensor(allocator, data, num_elements),
        .F32 => dequantizeF32Tensor(allocator, data, num_elements),
        else => error.UnsupportedQuantization,
    };
}

// RMS Normalization - SIMD optimized
pub fn rmsNorm(output: []f32, input: []const f32, weight: []const f32, eps: f32) void {
    simd.simdRmsNorm(output, input, weight, eps);
}

// Matrix-vector multiplication - SIMD optimized with optional parallelism
pub fn matVec(output: []f32, mat: []const f32, vec: []const f32, rows: usize, cols: usize) void {
    // Use parallel version for large matrices (FFN, output projection)
    simd.parallelMatVec(output, mat, vec, rows, cols);
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

// Sample from probability distribution (basic)
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

// ═══════════════════════════════════════════════════════════════════════════════
// ADVANCED SAMPLING - Temperature + Top-p (Nucleus) Sampling
// ═══════════════════════════════════════════════════════════════════════════════

/// Sampling parameters
pub const SamplingParams = struct {
    temperature: f32 = 0.7,
    top_p: f32 = 0.9,
    top_k: u32 = 40,
    repeat_penalty: f32 = 1.1,
};

/// Apply temperature scaling to logits
pub fn applyTemperature(logits: []f32, temperature: f32) void {
    if (temperature <= 0.0 or temperature == 1.0) return;
    
    const inv_temp = 1.0 / temperature;
    for (logits) |*l| {
        l.* *= inv_temp;
    }
}

/// Sample with temperature and top-p (nucleus sampling)
/// Returns token index
pub fn sampleWithParams(allocator: std.mem.Allocator, logits: []f32, params: SamplingParams) !u32 {
    const n = logits.len;
    
    // Apply temperature
    if (params.temperature > 0.0 and params.temperature != 1.0) {
        applyTemperature(logits, params.temperature);
    }
    
    // Greedy if temperature is 0
    if (params.temperature == 0.0) {
        var max_idx: u32 = 0;
        var max_val: f32 = logits[0];
        for (logits[1..], 1..) |l, i| {
            if (l > max_val) {
                max_val = l;
                max_idx = @intCast(i);
            }
        }
        return max_idx;
    }
    
    // Convert to probabilities with softmax
    var max_logit: f32 = logits[0];
    for (logits[1..]) |l| {
        if (l > max_logit) max_logit = l;
    }
    
    var sum: f32 = 0.0;
    for (logits) |*l| {
        l.* = @exp(l.* - max_logit);
        sum += l.*;
    }
    
    const inv_sum = 1.0 / sum;
    for (logits) |*l| {
        l.* *= inv_sum;
    }
    
    // Top-p (nucleus) sampling
    if (params.top_p < 1.0) {
        // Create index array for sorting
        const indices = try allocator.alloc(u32, n);
        defer allocator.free(indices);
        for (indices, 0..) |*idx, i| {
            idx.* = @intCast(i);
        }
        
        // Sort indices by probability (descending)
        std.mem.sort(u32, indices, logits, struct {
            fn lessThan(probs: []f32, a: u32, b: u32) bool {
                return probs[a] > probs[b]; // Descending
            }
        }.lessThan);
        
        // Find cutoff for top-p
        var cumsum: f32 = 0.0;
        var cutoff_idx: usize = n;
        for (indices, 0..) |idx, i| {
            cumsum += logits[idx];
            if (cumsum >= params.top_p) {
                cutoff_idx = i + 1;
                break;
            }
        }
        
        // Zero out tokens below cutoff
        for (indices[cutoff_idx..]) |idx| {
            logits[idx] = 0.0;
        }
        
        // Renormalize
        sum = 0.0;
        for (logits) |l| {
            sum += l;
        }
        if (sum > 0.0) {
            const inv = 1.0 / sum;
            for (logits) |*l| {
                l.* *= inv;
            }
        }
    }
    
    // Sample from distribution
    var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const random = prng.random();
    const r = random.float(f32);
    
    var cumsum: f32 = 0.0;
    for (logits, 0..) |p, i| {
        cumsum += p;
        if (r < cumsum) {
            return @intCast(i);
        }
    }
    
    // Fallback to last token
    return @intCast(n - 1);
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
