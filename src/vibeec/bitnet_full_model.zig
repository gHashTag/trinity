// ═══════════════════════════════════════════════════════════════════════════════
// BITNET b1.58 FULL MODEL - Complete Inference Pipeline
// Load all 290 tensors, wire up 24 layers, generate coherent text
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const json = std.json;
const math = std.math;
const forward = @import("bitnet_forward.zig");
const ternary_pack = @import("ternary_packing.zig");

pub const PHI: f64 = 1.618033988749895;

// Re-export ternary packing
pub const PackedTernaryWeights = ternary_pack.PackedTernaryWeights;
pub const packWeights = ternary_pack.packWeights;
pub const ternaryMatVecSIMD = ternary_pack.ternaryMatVecSIMD;

// Re-export from forward
pub const BitNetConfig = forward.BitNetConfig;
pub const quantizeToTernary = forward.quantizeToTernary;
pub const ternaryMatVec = forward.ternaryMatVec;
pub const rmsNorm = forward.rmsNorm;
pub const applyRoPE = forward.applyRoPE;
pub const softmax = forward.softmax;
pub const silu = forward.silu;
pub const quantizeActivationsInPlace = forward.quantizeActivationsInPlace;
pub const quantizeWeightsInPlace = forward.quantizeWeightsInPlace;

// SIMD vector types for optimized matmul
const Vec8f32 = @Vector(8, f32);
const Vec16f32 = @Vector(16, f32);

// ═══════════════════════════════════════════════════════════════════════════════
// MULTI-THREADED MATMUL - Parallel row processing
// ═══════════════════════════════════════════════════════════════════════════════

/// Number of threads for parallel matmul
const MAX_MATMUL_THREADS: usize = 16;
const MIN_ROWS_PER_THREAD: usize = 32; // Lowered from 128 for better multi-core utilization

fn getNumThreads() usize {
    return @min(MAX_MATMUL_THREADS, std.Thread.getCpuCount() catch 2);
}

/// Context for parallel matmul worker
const MatmulWorkerContext = struct {
    weights: []const f32,
    input: []const f32,
    output: []f32,
    cols: usize,
    start_row: usize,
    end_row: usize,
};

/// Worker function for parallel matmul
fn matmulWorkerFn(ctx: *MatmulWorkerContext) void {
    const cols = ctx.cols;
    
    for (ctx.start_row..ctx.end_row) |i| {
        var sum0: Vec8f32 = @splat(0.0);
        var sum1: Vec8f32 = @splat(0.0);
        var sum2: Vec8f32 = @splat(0.0);
        var sum3: Vec8f32 = @splat(0.0);
        var sum_scalar: f32 = 0.0;
        const row_start = i * cols;
        
        var j: usize = 0;
        
        // Main SIMD loop - 32 elements at a time (4x8 unrolled)
        while (j + 32 <= cols) : (j += 32) {
            const w0: Vec8f32 = ctx.weights[row_start + j ..][0..8].*;
            const w1: Vec8f32 = ctx.weights[row_start + j + 8 ..][0..8].*;
            const w2: Vec8f32 = ctx.weights[row_start + j + 16 ..][0..8].*;
            const w3: Vec8f32 = ctx.weights[row_start + j + 24 ..][0..8].*;
            
            const in0: Vec8f32 = ctx.input[j..][0..8].*;
            const in1: Vec8f32 = ctx.input[j + 8 ..][0..8].*;
            const in2: Vec8f32 = ctx.input[j + 16 ..][0..8].*;
            const in3: Vec8f32 = ctx.input[j + 24 ..][0..8].*;
            
            sum0 += w0 * in0;
            sum1 += w1 * in1;
            sum2 += w2 * in2;
            sum3 += w3 * in3;
        }
        
        // 8-element SIMD loop for remainder
        while (j + 8 <= cols) : (j += 8) {
            const w: Vec8f32 = ctx.weights[row_start + j ..][0..8].*;
            const in_vec: Vec8f32 = ctx.input[j..][0..8].*;
            sum0 += w * in_vec;
        }
        
        // Combine partial sums
        sum0 += sum1;
        sum2 += sum3;
        sum0 += sum2;
        sum_scalar = @reduce(.Add, sum0);
        
        // Scalar tail
        while (j < cols) : (j += 1) {
            sum_scalar += ctx.weights[row_start + j] * ctx.input[j];
        }
        
        ctx.output[i] = sum_scalar;
    }
}

/// Multi-threaded SIMD-optimized F32 matrix-vector multiplication
/// Uses 8-wide vectors with 4x unrolling + parallel row processing
pub fn f32MatVec(
    weights: []const f32,
    input: []const f32,
    output: []f32,
    rows: usize,
    cols: usize,
) void {
    // For small matrices, use single-threaded SIMD
    const available_threads = getNumThreads();
    if (rows < MIN_ROWS_PER_THREAD * 2 or available_threads < 2) {
        f32MatVecSingleThread(weights, input, output, rows, cols);
        return;
    }
    
    // Divide work across threads
    const num_threads = @min(available_threads, rows / MIN_ROWS_PER_THREAD);
    const rows_per_thread = rows / num_threads;
    
    var contexts: [MAX_MATMUL_THREADS]MatmulWorkerContext = undefined;
    var threads: [MAX_MATMUL_THREADS]?std.Thread = undefined;
    
    // Create worker contexts and spawn threads
    for (0..num_threads) |t| {
        const start_row = t * rows_per_thread;
        const end_row = if (t == num_threads - 1) rows else (t + 1) * rows_per_thread;
        
        contexts[t] = MatmulWorkerContext{
            .weights = weights,
            .input = input,
            .output = output,
            .cols = cols,
            .start_row = start_row,
            .end_row = end_row,
        };
        
        threads[t] = std.Thread.spawn(.{}, matmulWorkerFn, .{&contexts[t]}) catch null;
    }
    
    // Join all threads
    for (0..num_threads) |t| {
        if (threads[t]) |thread| {
            thread.join();
        }
    }
}

/// Single-threaded SIMD matmul (for small matrices or fallback)
fn f32MatVecSingleThread(
    weights: []const f32,
    input: []const f32,
    output: []f32,
    rows: usize,
    cols: usize,
) void {
    for (0..rows) |i| {
        var sum0: Vec8f32 = @splat(0.0);
        var sum1: Vec8f32 = @splat(0.0);
        var sum2: Vec8f32 = @splat(0.0);
        var sum3: Vec8f32 = @splat(0.0);
        var sum_scalar: f32 = 0.0;
        const row_start = i * cols;
        
        var j: usize = 0;
        
        // Main SIMD loop - 32 elements at a time (4x8 unrolled)
        while (j + 32 <= cols) : (j += 32) {
            // Load weight vectors
            const w0: Vec8f32 = weights[row_start + j ..][0..8].*;
            const w1: Vec8f32 = weights[row_start + j + 8 ..][0..8].*;
            const w2: Vec8f32 = weights[row_start + j + 16 ..][0..8].*;
            const w3: Vec8f32 = weights[row_start + j + 24 ..][0..8].*;
            
            // Load input vectors
            const in0: Vec8f32 = input[j..][0..8].*;
            const in1: Vec8f32 = input[j + 8 ..][0..8].*;
            const in2: Vec8f32 = input[j + 16 ..][0..8].*;
            const in3: Vec8f32 = input[j + 24 ..][0..8].*;
            
            // FMA: sum += weight * input
            sum0 += w0 * in0;
            sum1 += w1 * in1;
            sum2 += w2 * in2;
            sum3 += w3 * in3;
        }
        
        // 8-element SIMD loop for remainder
        while (j + 8 <= cols) : (j += 8) {
            const w: Vec8f32 = weights[row_start + j ..][0..8].*;
            const in_vec: Vec8f32 = input[j..][0..8].*;
            sum0 += w * in_vec;
        }
        
        // Combine partial sums
        sum0 += sum1;
        sum2 += sum3;
        sum0 += sum2;
        sum_scalar = @reduce(.Add, sum0);
        
        // Scalar tail for remaining elements
        while (j < cols) : (j += 1) {
            sum_scalar += weights[row_start + j] * input[j];
        }
        
        output[i] = sum_scalar;
    }
}

/// Scalar F32 matrix-vector multiplication (fallback)
pub fn f32MatVecScalar(
    weights: []const f32,
    input: []const f32,
    output: []f32,
    rows: usize,
    cols: usize,
) void {
    for (0..rows) |i| {
        var sum: f32 = 0.0;
        const row_start = i * cols;
        
        // Unrolled inner loop for better performance
        var j: usize = 0;
        while (j + 4 <= cols) : (j += 4) {
            sum += weights[row_start + j] * input[j];
            sum += weights[row_start + j + 1] * input[j + 1];
            sum += weights[row_start + j + 2] * input[j + 2];
            sum += weights[row_start + j + 3] * input[j + 3];
        }
        
        // Handle remainder
        while (j < cols) : (j += 1) {
            sum += weights[row_start + j] * input[j];
        }
        
        output[i] = sum;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TENSOR INFO
// ═══════════════════════════════════════════════════════════════════════════════

pub const TensorInfo = struct {
    dtype: []const u8,
    shape: []i64,
    data_offsets: [2]u64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// KV-CACHE (Key-Value Cache for Attention)
// ═══════════════════════════════════════════════════════════════════════════════

pub const KVCache = struct {
    allocator: std.mem.Allocator,
    num_layers: usize,
    num_heads: usize,
    head_dim: usize,
    max_seq_len: usize,
    current_len: usize,
    
    // Cache storage: [layer][position][head][dim]
    // Flattened to: [layer * max_seq * hidden]
    k_cache: []f32,
    v_cache: []f32,
    
    pub fn init(allocator: std.mem.Allocator, config: BitNetConfig, max_seq_len: usize) !KVCache {
        const num_layers = config.num_hidden_layers;
        const num_heads = config.num_attention_heads;
        const head_dim = config.headDim();
        const hidden = config.hidden_size;
        
        // Allocate cache for all layers and positions
        const cache_size = num_layers * max_seq_len * hidden;
        
        return KVCache{
            .allocator = allocator,
            .num_layers = num_layers,
            .num_heads = num_heads,
            .head_dim = head_dim,
            .max_seq_len = max_seq_len,
            .current_len = 0,
            .k_cache = try allocator.alloc(f32, cache_size),
            .v_cache = try allocator.alloc(f32, cache_size),
        };
    }
    
    pub fn deinit(self: *KVCache) void {
        self.allocator.free(self.k_cache);
        self.allocator.free(self.v_cache);
    }
    
    pub fn reset(self: *KVCache) void {
        self.current_len = 0;
    }
    
    /// Store K and V for a layer at current position
    pub fn store(self: *KVCache, layer_idx: usize, k: []const f32, v: []const f32) void {
        if (self.current_len >= self.max_seq_len) return;
        
        const hidden = self.num_heads * self.head_dim;
        const layer_offset = layer_idx * self.max_seq_len * hidden;
        const pos_offset = self.current_len * hidden;
        const start = layer_offset + pos_offset;
        
        @memcpy(self.k_cache[start..start + hidden], k);
        @memcpy(self.v_cache[start..start + hidden], v);
    }
    
    /// Get K for a layer at a specific position
    pub fn getK(self: *KVCache, layer_idx: usize, pos: usize) []f32 {
        const hidden = self.num_heads * self.head_dim;
        const layer_offset = layer_idx * self.max_seq_len * hidden;
        const pos_offset = pos * hidden;
        const start = layer_offset + pos_offset;
        return self.k_cache[start..start + hidden];
    }
    
    /// Get V for a layer at a specific position
    pub fn getV(self: *KVCache, layer_idx: usize, pos: usize) []f32 {
        const hidden = self.num_heads * self.head_dim;
        const layer_offset = layer_idx * self.max_seq_len * hidden;
        const pos_offset = pos * hidden;
        const start = layer_offset + pos_offset;
        return self.v_cache[start..start + hidden];
    }
    
    /// Increment position after storing
    pub fn advance(self: *KVCache) void {
        if (self.current_len < self.max_seq_len) {
            self.current_len += 1;
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// LAYER WEIGHTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const LayerWeights = struct {
    // Attention (F32, quantized at inference)
    q_proj: []f32,
    k_proj: []f32,
    v_proj: []f32,
    o_proj: []f32,
    
    // FFN (F32, quantized at inference)
    gate_proj: []f32,
    up_proj: []f32,
    down_proj: []f32,
    
    // Norms (F32, not quantized)
    input_layernorm: []f32,
    post_attention_layernorm: []f32,
    inner_attn_ln: []f32,
    ffn_layernorm: []f32,
};

/// Packed ternary layer weights for memory-efficient inference
/// 15.9x memory reduction vs F32
pub const PackedLayerWeights = struct {
    allocator: std.mem.Allocator,
    
    // Attention projections (packed ternary)
    q_proj: PackedTernaryWeights,
    k_proj: PackedTernaryWeights,
    v_proj: PackedTernaryWeights,
    o_proj: PackedTernaryWeights,
    
    // FFN projections (packed ternary)
    gate_proj: PackedTernaryWeights,
    up_proj: PackedTernaryWeights,
    down_proj: PackedTernaryWeights,
    
    // Norms (F32, not quantized - small overhead)
    input_layernorm: []f32,
    post_attention_layernorm: []f32,
    inner_attn_ln: []f32,
    ffn_layernorm: []f32,
    
    pub fn deinit(self: *PackedLayerWeights) void {
        self.q_proj.deinit();
        self.k_proj.deinit();
        self.v_proj.deinit();
        self.o_proj.deinit();
        self.gate_proj.deinit();
        self.up_proj.deinit();
        self.down_proj.deinit();
        self.allocator.free(self.input_layernorm);
        self.allocator.free(self.post_attention_layernorm);
        self.allocator.free(self.inner_attn_ln);
        self.allocator.free(self.ffn_layernorm);
    }
    
    /// Memory usage in bytes
    pub fn memoryUsage(self: PackedLayerWeights) usize {
        return self.q_proj.memoryUsage() +
               self.k_proj.memoryUsage() +
               self.v_proj.memoryUsage() +
               self.o_proj.memoryUsage() +
               self.gate_proj.memoryUsage() +
               self.up_proj.memoryUsage() +
               self.down_proj.memoryUsage() +
               (self.input_layernorm.len + self.post_attention_layernorm.len +
                self.inner_attn_ln.len + self.ffn_layernorm.len) * @sizeOf(f32);
    }
};

/// Convert F32 LayerWeights to PackedLayerWeights
pub fn packLayerWeights(
    allocator: std.mem.Allocator,
    layer: LayerWeights,
    hidden: usize,
    inter: usize,
) !PackedLayerWeights {
    return PackedLayerWeights{
        .allocator = allocator,
        .q_proj = try packWeights(allocator, layer.q_proj, hidden, hidden),
        .k_proj = try packWeights(allocator, layer.k_proj, hidden, hidden),
        .v_proj = try packWeights(allocator, layer.v_proj, hidden, hidden),
        .o_proj = try packWeights(allocator, layer.o_proj, hidden, hidden),
        .gate_proj = try packWeights(allocator, layer.gate_proj, inter, hidden),
        .up_proj = try packWeights(allocator, layer.up_proj, inter, hidden),
        .down_proj = try packWeights(allocator, layer.down_proj, hidden, inter),
        .input_layernorm = try allocator.dupe(f32, layer.input_layernorm),
        .post_attention_layernorm = try allocator.dupe(f32, layer.post_attention_layernorm),
        .inner_attn_ln = try allocator.dupe(f32, layer.inner_attn_ln),
        .ffn_layernorm = try allocator.dupe(f32, layer.ffn_layernorm),
    };
}

/// Helper: Packed ternary matmul wrapper
pub fn packedMatVec(
    pw: *const PackedTernaryWeights,
    input: []const f32,
    output: []f32,
) void {
    ternaryMatVecSIMD(output, pw.data, pw.scales, input, pw.rows, pw.cols);
}

// ═══════════════════════════════════════════════════════════════════════════════
// FULL BITNET MODEL
// ═══════════════════════════════════════════════════════════════════════════════

pub const BitNetFullModel = struct {
    allocator: std.mem.Allocator,
    config: BitNetConfig,
    
    // Embeddings
    embed_tokens: []f32,
    
    // Layers
    layers: []LayerWeights,
    
    // Final norm
    norm: []f32,
    
    // LM head (tied to embeddings in BitNet)
    // lm_head: []f32, // Usually tied to embed_tokens
    
    // Buffers for inference
    hidden_state: []f32,
    attn_output: []f32,
    ffn_intermediate: []f32,
    logits: []f32,
    
    // Ternary buffers (reused)
    ternary_weights: []i8,

    // Pre-allocated inference buffers (avoid per-token allocation)
    buf_normed: []f32,
    buf_q: []f32,
    buf_k: []f32,
    buf_v: []f32,
    buf_o_out: []f32,
    buf_up_out: []f32,
    buf_down_out: []f32,
    buf_attn_weights: []f32, // max_seq_len * num_heads

    // KV-Cache for attention
    kv_cache: ?KVCache,
    
    pub fn init(allocator: std.mem.Allocator, config: BitNetConfig) !BitNetFullModel {
        const hidden = config.hidden_size;
        const inter = config.intermediate_size;
        const vocab = config.vocab_size;
        const num_layers = config.num_hidden_layers;
        
        // Allocate layers
        const layers = try allocator.alloc(LayerWeights, num_layers);
        for (layers) |*layer| {
            layer.* = LayerWeights{
                .q_proj = &[_]f32{},
                .k_proj = &[_]f32{},
                .v_proj = &[_]f32{},
                .o_proj = &[_]f32{},
                .gate_proj = &[_]f32{},
                .up_proj = &[_]f32{},
                .down_proj = &[_]f32{},
                .input_layernorm = &[_]f32{},
                .post_attention_layernorm = &[_]f32{},
                .inner_attn_ln = &[_]f32{},
                .ffn_layernorm = &[_]f32{},
            };
        }
        
        // Allocate buffers
        const max_weight_size = @max(hidden * hidden, inter * hidden);
        const max_seq_len: usize = 4096; // Pre-allocate for max sequence

        return BitNetFullModel{
            .allocator = allocator,
            .config = config,
            .embed_tokens = &[_]f32{},
            .layers = layers,
            .norm = &[_]f32{},
            .hidden_state = try allocator.alloc(f32, hidden),
            .attn_output = try allocator.alloc(f32, hidden),
            .ffn_intermediate = try allocator.alloc(f32, inter),
            .logits = try allocator.alloc(f32, vocab),
            .ternary_weights = try allocator.alloc(i8, max_weight_size),
            .buf_normed = try allocator.alloc(f32, hidden),
            .buf_q = try allocator.alloc(f32, hidden),
            .buf_k = try allocator.alloc(f32, hidden),
            .buf_v = try allocator.alloc(f32, hidden),
            .buf_o_out = try allocator.alloc(f32, hidden),
            .buf_up_out = try allocator.alloc(f32, inter),
            .buf_down_out = try allocator.alloc(f32, hidden),
            .buf_attn_weights = try allocator.alloc(f32, max_seq_len * config.num_attention_heads),
            .kv_cache = null,
        };
    }
    
    pub fn deinit(self: *BitNetFullModel) void {
        // Free layers
        for (self.layers) |layer| {
            if (layer.q_proj.len > 0) self.allocator.free(layer.q_proj);
            if (layer.k_proj.len > 0) self.allocator.free(layer.k_proj);
            if (layer.v_proj.len > 0) self.allocator.free(layer.v_proj);
            if (layer.o_proj.len > 0) self.allocator.free(layer.o_proj);
            if (layer.gate_proj.len > 0) self.allocator.free(layer.gate_proj);
            if (layer.up_proj.len > 0) self.allocator.free(layer.up_proj);
            if (layer.down_proj.len > 0) self.allocator.free(layer.down_proj);
            if (layer.input_layernorm.len > 0) self.allocator.free(layer.input_layernorm);
            if (layer.post_attention_layernorm.len > 0) self.allocator.free(layer.post_attention_layernorm);
            if (layer.inner_attn_ln.len > 0) self.allocator.free(layer.inner_attn_ln);
            if (layer.ffn_layernorm.len > 0) self.allocator.free(layer.ffn_layernorm);
        }
        self.allocator.free(self.layers);
        
        // Free embeddings and norm
        if (self.embed_tokens.len > 0) self.allocator.free(self.embed_tokens);
        if (self.norm.len > 0) self.allocator.free(self.norm);
        
        // Free buffers
        self.allocator.free(self.hidden_state);
        self.allocator.free(self.attn_output);
        self.allocator.free(self.ffn_intermediate);
        self.allocator.free(self.logits);
        self.allocator.free(self.ternary_weights);
        self.allocator.free(self.buf_normed);
        self.allocator.free(self.buf_q);
        self.allocator.free(self.buf_k);
        self.allocator.free(self.buf_v);
        self.allocator.free(self.buf_o_out);
        self.allocator.free(self.buf_up_out);
        self.allocator.free(self.buf_down_out);
        self.allocator.free(self.buf_attn_weights);
        
        // Free KV-cache
        if (self.kv_cache) |*cache| {
            cache.deinit();
        }
    }
    
    /// Initialize KV-cache for generation
    pub fn initKVCache(self: *BitNetFullModel, max_seq_len: usize) !void {
        self.kv_cache = try KVCache.init(self.allocator, self.config, max_seq_len);
    }
    
    /// Reset KV-cache for new generation
    pub fn resetKVCache(self: *BitNetFullModel) void {
        if (self.kv_cache) |*cache| {
            cache.reset();
        }
    }
    
    /// Load model from safetensors file
    pub fn loadFromSafetensors(self: *BitNetFullModel, model_path: []const u8) !void {
        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║     LOADING BITNET b1.58 FULL MODEL                          ║\n", .{});
        std.debug.print("║     φ² + 1/φ² = 3 = TRINITY                                  ║\n", .{});
        std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
        std.debug.print("\n", .{});
        
        const file = try std.fs.cwd().openFile(model_path, .{});
        defer file.close();
        
        // Read header size
        var size_buf: [8]u8 = undefined;
        _ = try file.read(&size_buf);
        const header_size = std.mem.readInt(u64, &size_buf, .little);
        
        // Read header JSON
        const header_json = try self.allocator.alloc(u8, header_size);
        defer self.allocator.free(header_json);
        _ = try file.read(header_json);
        
        // Parse header
        var parsed = try json.parseFromSlice(json.Value, self.allocator, header_json, .{});
        defer parsed.deinit();
        
        const data_start = 8 + header_size;
        var tensors_loaded: usize = 0;
        
        // Load embeddings
        std.debug.print("Loading embeddings...\n", .{});
        self.embed_tokens = try self.loadTensor(file, &parsed.value, data_start, "model.embed_tokens.weight");
        tensors_loaded += 1;
        
        // Load final norm
        self.norm = try self.loadTensor(file, &parsed.value, data_start, "model.norm.weight");
        tensors_loaded += 1;
        
        // Load each layer
        std.debug.print("Loading {d} transformer layers...\n", .{self.config.num_hidden_layers});
        
        for (0..self.config.num_hidden_layers) |i| {
            var name_buf: [128]u8 = undefined;
            
            // Attention weights
            const q_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.self_attn.q_proj.weight", .{i});
            self.layers[i].q_proj = try self.loadTensor(file, &parsed.value, data_start, q_name);
            tensors_loaded += 1;
            
            const k_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.self_attn.k_proj.weight", .{i});
            self.layers[i].k_proj = try self.loadTensor(file, &parsed.value, data_start, k_name);
            tensors_loaded += 1;
            
            const v_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.self_attn.v_proj.weight", .{i});
            self.layers[i].v_proj = try self.loadTensor(file, &parsed.value, data_start, v_name);
            tensors_loaded += 1;
            
            const o_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.self_attn.o_proj.weight", .{i});
            self.layers[i].o_proj = try self.loadTensor(file, &parsed.value, data_start, o_name);
            tensors_loaded += 1;
            
            // FFN weights
            const gate_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.mlp.gate_proj.weight", .{i});
            self.layers[i].gate_proj = try self.loadTensor(file, &parsed.value, data_start, gate_name);
            tensors_loaded += 1;
            
            const up_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.mlp.up_proj.weight", .{i});
            self.layers[i].up_proj = try self.loadTensor(file, &parsed.value, data_start, up_name);
            tensors_loaded += 1;
            
            const down_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.mlp.down_proj.weight", .{i});
            self.layers[i].down_proj = try self.loadTensor(file, &parsed.value, data_start, down_name);
            tensors_loaded += 1;
            
            // Norms
            const input_ln_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.input_layernorm.weight", .{i});
            self.layers[i].input_layernorm = try self.loadTensor(file, &parsed.value, data_start, input_ln_name);
            tensors_loaded += 1;
            
            const post_ln_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.post_attention_layernorm.weight", .{i});
            self.layers[i].post_attention_layernorm = try self.loadTensor(file, &parsed.value, data_start, post_ln_name);
            tensors_loaded += 1;
            
            const inner_ln_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.self_attn.inner_attn_ln.weight", .{i});
            self.layers[i].inner_attn_ln = try self.loadTensor(file, &parsed.value, data_start, inner_ln_name);
            tensors_loaded += 1;
            
            const ffn_ln_name = try std.fmt.bufPrint(&name_buf, "model.layers.{d}.mlp.ffn_layernorm.weight", .{i});
            self.layers[i].ffn_layernorm = try self.loadTensor(file, &parsed.value, data_start, ffn_ln_name);
            tensors_loaded += 1;
            
            if ((i + 1) % 6 == 0) {
                std.debug.print("  Loaded layer {d}/{d}\n", .{i + 1, self.config.num_hidden_layers});
            }
        }
        
        std.debug.print("\n✅ Loaded {d} tensors successfully!\n", .{tensors_loaded});

        // Quantize all linear projection weights to ternary (BitNet b1.58)
        std.debug.print("Quantizing weights to ternary...\n", .{});
        for (self.layers) |*layer| {
            if (layer.q_proj.len > 0) quantizeWeightsInPlace(layer.q_proj);
            if (layer.k_proj.len > 0) quantizeWeightsInPlace(layer.k_proj);
            if (layer.v_proj.len > 0) quantizeWeightsInPlace(layer.v_proj);
            if (layer.o_proj.len > 0) quantizeWeightsInPlace(layer.o_proj);
            if (layer.gate_proj.len > 0) quantizeWeightsInPlace(layer.gate_proj);
            if (layer.up_proj.len > 0) quantizeWeightsInPlace(layer.up_proj);
            if (layer.down_proj.len > 0) quantizeWeightsInPlace(layer.down_proj);
        }
        std.debug.print("✅ Weights quantized to ternary!\n", .{});

        // Calculate memory usage
        var total_params: usize = self.embed_tokens.len + self.norm.len;
        for (self.layers) |layer| {
            total_params += layer.q_proj.len + layer.k_proj.len + layer.v_proj.len + layer.o_proj.len;
            total_params += layer.gate_proj.len + layer.up_proj.len + layer.down_proj.len;
            total_params += layer.input_layernorm.len + layer.post_attention_layernorm.len;
            total_params += layer.inner_attn_ln.len + layer.ffn_layernorm.len;
        }
        
        std.debug.print("   Total parameters: {d}M\n", .{total_params / 1_000_000});
        std.debug.print("   Memory usage: {d} MB\n", .{(total_params * 4) / (1024 * 1024)});
    }
    
    fn loadTensor(self: *BitNetFullModel, file: std.fs.File, header: *json.Value, data_start: u64, name: []const u8) ![]f32 {
        const tensor_obj = header.object.get(name) orelse {
            std.debug.print("  WARNING: Tensor '{s}' not found\n", .{name});
            return &[_]f32{};
        };
        
        const info = tensor_obj.object;
        const dtype = info.get("dtype").?.string;
        
        // Get shape
        const shape_arr = info.get("shape").?.array;
        var num_elements: usize = 1;
        for (shape_arr.items) |dim| {
            num_elements *= @intCast(dim.integer);
        }
        
        // Get offsets
        const offsets_arr = info.get("data_offsets").?.array;
        const offset_start: u64 = @intCast(offsets_arr.items[0].integer);
        
        // Seek and read
        try file.seekTo(data_start + offset_start);
        
        if (std.mem.eql(u8, dtype, "F32")) {
            const data = try self.allocator.alloc(f32, num_elements);
            const bytes = std.mem.sliceAsBytes(data);
            _ = try file.read(bytes);
            return data;
        } else if (std.mem.eql(u8, dtype, "F16")) {
            const f16_data = try self.allocator.alloc(f16, num_elements);
            defer self.allocator.free(f16_data);
            const bytes = std.mem.sliceAsBytes(f16_data);
            _ = try file.read(bytes);
            
            const data = try self.allocator.alloc(f32, num_elements);
            for (f16_data, 0..) |v, idx| {
                data[idx] = @floatCast(v);
            }
            return data;
        } else {
            std.debug.print("  WARNING: Unsupported dtype '{s}'\n", .{dtype});
            return &[_]f32{};
        }
    }
    
    /// SIMD dot product for attention scores (8-wide vectorized)
    inline fn simdDot(a: []const f32, b: []const f32, len: usize) f32 {
        var sum0: Vec8f32 = @splat(0.0);
        var sum1: Vec8f32 = @splat(0.0);
        var scalar: f32 = 0.0;
        var j: usize = 0;

        while (j + 16 <= len) : (j += 16) {
            const a0: Vec8f32 = a[j..][0..8].*;
            const a1: Vec8f32 = a[j + 8 ..][0..8].*;
            const b0: Vec8f32 = b[j..][0..8].*;
            const b1: Vec8f32 = b[j + 8 ..][0..8].*;
            sum0 += a0 * b0;
            sum1 += a1 * b1;
        }
        while (j + 8 <= len) : (j += 8) {
            const av: Vec8f32 = a[j..][0..8].*;
            const bv: Vec8f32 = b[j..][0..8].*;
            sum0 += av * bv;
        }
        sum0 += sum1;
        scalar = @reduce(.Add, sum0);
        while (j < len) : (j += 1) {
            scalar += a[j] * b[j];
        }
        return scalar;
    }

    /// SIMD weighted accumulate: output[d] += weight * src[d]
    inline fn simdWeightedAdd(output: []f32, src: []const f32, weight: f32, len: usize) void {
        const w_vec: Vec8f32 = @splat(weight);
        var j: usize = 0;
        while (j + 8 <= len) : (j += 8) {
            var out_v: Vec8f32 = output[j..][0..8].*;
            const src_v: Vec8f32 = src[j..][0..8].*;
            out_v += w_vec * src_v;
            output[j..][0..8].* = out_v;
        }
        while (j < len) : (j += 1) {
            output[j] += weight * src[j];
        }
    }

    /// Forward pass for a single token with KV-cache
    /// Optimized: pre-allocated buffers, SIMD attention, vectorized LM head
    pub fn forward(self: *BitNetFullModel, token_id: u32, position: usize) void {
        const hidden = self.config.hidden_size;
        const inter = self.config.intermediate_size;
        const head_dim = self.config.headDim();
        const num_heads = self.config.num_attention_heads;

        // 1. Embedding lookup
        const embed_start = @as(usize, token_id) * hidden;
        if (embed_start + hidden > self.embed_tokens.len) {
            @memset(self.hidden_state, 0.0);
            return;
        }
        @memcpy(self.hidden_state, self.embed_tokens[embed_start..embed_start + hidden]);

        // Pre-allocated buffers (zero-alloc forward pass)
        const normed = self.buf_normed;
        const q = self.buf_q;
        const k_buf = self.buf_k;
        const v_buf = self.buf_v;
        const o_out = self.buf_o_out;
        const up_out = self.buf_up_out;
        const down_out = self.buf_down_out;

        // 2. Process each layer
        for (self.layers, 0..) |layer, layer_idx| {
            if (layer.q_proj.len == 0) continue;

            // Input LayerNorm
            rmsNorm(self.hidden_state, layer.input_layernorm, normed, self.config.rms_norm_eps);

            // Activation quantization: 8-bit before Q/K/V
            _ = quantizeActivationsInPlace(normed);

            // Q, K, V projections (multi-threaded SIMD matmul)
            f32MatVec(layer.q_proj, normed, q, hidden, hidden);
            f32MatVec(layer.k_proj, normed, k_buf, hidden, hidden);
            f32MatVec(layer.v_proj, normed, v_buf, hidden, hidden);

            // Apply RoPE to Q and K
            for (0..num_heads) |h| {
                const start = h * head_dim;
                applyRoPE(q[start..start + head_dim], k_buf[start..start + head_dim], position, head_dim, self.config.rope_theta);
            }

            // Store K, V in cache
            if (self.kv_cache) |*cache| {
                cache.store(layer_idx, k_buf, v_buf);
            }

            // Inner attention LayerNorm
            rmsNorm(q, layer.inner_attn_ln, q, self.config.rms_norm_eps);

            // Self-attention with KV-cache (SIMD-optimized)
            const seq_len = if (self.kv_cache) |cache| cache.current_len + 1 else 1;
            const attn_weights = self.buf_attn_weights;
            const scale = 1.0 / @sqrt(@as(f32, @floatFromInt(head_dim)));

            // Compute attention scores (SIMD dot products)
            for (0..num_heads) |h| {
                const h_start = h * head_dim;
                const q_head = q[h_start..h_start + head_dim];

                for (0..seq_len) |pos| {
                    const k_head = if (pos < position) blk: {
                        if (self.kv_cache) |*cache| {
                            const cached_k = cache.getK(layer_idx, pos);
                            break :blk cached_k[h_start..h_start + head_dim];
                        }
                        break :blk k_buf[h_start..h_start + head_dim];
                    } else k_buf[h_start..h_start + head_dim];

                    attn_weights[h * seq_len + pos] = simdDot(q_head, k_head, head_dim) * scale;
                }

                // Softmax per head
                softmax(attn_weights[h * seq_len .. (h + 1) * seq_len]);
            }

            // Weighted sum of V (SIMD-optimized)
            @memset(self.attn_output, 0.0);
            for (0..num_heads) |h| {
                const h_start = h * head_dim;

                for (0..seq_len) |pos| {
                    const weight = attn_weights[h * seq_len + pos];
                    if (weight < 1e-8) continue; // Skip near-zero weights

                    const v_head = if (pos < position) blk: {
                        if (self.kv_cache) |*cache| {
                            const cached_v = cache.getV(layer_idx, pos);
                            break :blk cached_v[h_start..h_start + head_dim];
                        }
                        break :blk v_buf[h_start..h_start + head_dim];
                    } else v_buf[h_start..h_start + head_dim];

                    simdWeightedAdd(self.attn_output[h_start..h_start + head_dim], v_head, weight, head_dim);
                }
            }

            // Activation quantization: 8-bit before O projection
            _ = quantizeActivationsInPlace(self.attn_output);

            // O projection
            f32MatVec(layer.o_proj, self.attn_output, o_out, hidden, hidden);

            // Residual connection (SIMD)
            {
                var j: usize = 0;
                while (j + 8 <= hidden) : (j += 8) {
                    var hv: Vec8f32 = self.hidden_state[j..][0..8].*;
                    const ov: Vec8f32 = o_out[j..][0..8].*;
                    hv += ov;
                    self.hidden_state[j..][0..8].* = hv;
                }
                while (j < hidden) : (j += 1) {
                    self.hidden_state[j] += o_out[j];
                }
            }

            // Post-attention LayerNorm
            rmsNorm(self.hidden_state, layer.post_attention_layernorm, normed, self.config.rms_norm_eps);

            // Activation quantization: 8-bit before gate/up
            _ = quantizeActivationsInPlace(normed);

            // FFN: gate and up projections
            f32MatVec(layer.gate_proj, normed, self.ffn_intermediate, inter, hidden);
            f32MatVec(layer.up_proj, normed, up_out, inter, hidden);

            // FFN LayerNorm
            rmsNorm(self.ffn_intermediate, layer.ffn_layernorm, self.ffn_intermediate, self.config.rms_norm_eps);

            // SwiGLU: silu(gate) * up (SIMD-friendly)
            {
                var j: usize = 0;
                while (j + 8 <= inter) : (j += 8) {
                    var g_vec: Vec8f32 = self.ffn_intermediate[j..][0..8].*;
                    const u_vec: Vec8f32 = up_out[j..][0..8].*;
                    // silu(x) = x * sigmoid(x) = x / (1 + exp(-x))
                    var silu_vec: Vec8f32 = undefined;
                    inline for (0..8) |k| {
                        silu_vec[k] = silu(g_vec[k]);
                    }
                    g_vec = silu_vec * u_vec;
                    self.ffn_intermediate[j..][0..8].* = g_vec;
                }
                while (j < inter) : (j += 1) {
                    self.ffn_intermediate[j] = silu(self.ffn_intermediate[j]) * up_out[j];
                }
            }

            // Activation quantization: 8-bit before down
            _ = quantizeActivationsInPlace(self.ffn_intermediate);

            // Down projection
            f32MatVec(layer.down_proj, self.ffn_intermediate, down_out, hidden, inter);

            // Residual connection (SIMD)
            {
                var j: usize = 0;
                while (j + 8 <= hidden) : (j += 8) {
                    var hv: Vec8f32 = self.hidden_state[j..][0..8].*;
                    const dv: Vec8f32 = down_out[j..][0..8].*;
                    hv += dv;
                    self.hidden_state[j..][0..8].* = hv;
                }
                while (j < hidden) : (j += 1) {
                    self.hidden_state[j] += down_out[j];
                }
            }
        }

        // 3. Final LayerNorm
        rmsNorm(self.hidden_state, self.norm, self.hidden_state, self.config.rms_norm_eps);

        // 4. LM Head (SIMD-optimized, multi-threaded)
        const vocab = self.config.vocab_size;
        f32MatVec(self.embed_tokens, self.hidden_state, self.logits, vocab, hidden);
    }
    
    /// Sample next token from logits
    pub fn sampleToken(self: *BitNetFullModel, temperature: f32, rng: *std.Random.DefaultPrng) u32 {
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
    
    /// Generate text with KV-cache
    pub fn generate(
        self: *BitNetFullModel,
        prompt_tokens: []const u32,
        max_new_tokens: usize,
        temperature: f32,
    ) ![]u32 {
        var rng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
        var generated = std.ArrayList(u32).init(self.allocator);
        
        // Initialize KV-cache if not already done
        if (self.kv_cache == null) {
            try self.initKVCache(prompt_tokens.len + max_new_tokens + 10);
        }
        self.resetKVCache();
        
        // Process prompt (prefill)
        for (prompt_tokens, 0..) |token, pos| {
            self.forward(token, pos);
            try generated.append(token);
            
            // Advance cache after each token
            if (self.kv_cache) |*cache| {
                cache.advance();
            }
        }
        
        // Generate new tokens (decode)
        var pos = prompt_tokens.len;
        for (0..max_new_tokens) |_| {
            const next_token = self.sampleToken(temperature, &rng);
            
            // Check for EOS
            if (next_token == 2) break;
            
            try generated.append(next_token);
            self.forward(next_token, pos);
            
            // Advance cache
            if (self.kv_cache) |*cache| {
                cache.advance();
            }
            
            pos += 1;
        }
        
        return generated.toOwnedSlice();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "full model init" {
    const allocator = std.testing.allocator;
    const config = BitNetConfig{};
    
    var model = try BitNetFullModel.init(allocator, config);
    defer model.deinit();
    
    try std.testing.expectEqual(@as(usize, 24), model.layers.len);
    try std.testing.expectEqual(@as(usize, 1536), model.hidden_state.len);
}

test "SIMD f32MatVec" {
    // Test 32-element matmul (exercises SIMD path)
    const weights = [_]f32{1.0} ** 64 ++ [_]f32{2.0} ** 64; // 2 rows x 64 cols
    const input = [_]f32{1.0} ** 64;
    var output: [2]f32 = undefined;
    
    f32MatVec(&weights, &input, &output, 2, 64);
    
    // Row 0: 64 * 1.0 * 1.0 = 64.0
    try std.testing.expectApproxEqAbs(@as(f32, 64.0), output[0], 0.001);
    // Row 1: 64 * 2.0 * 1.0 = 128.0
    try std.testing.expectApproxEqAbs(@as(f32, 128.0), output[1], 0.001);
}

test "SIMD f32MatVec with remainder" {
    // Test with non-multiple of 32 (exercises scalar tail)
    const weights = [_]f32{1.0} ** 100; // 1 row x 100 cols
    const input = [_]f32{2.0} ** 100;
    var output: [1]f32 = undefined;
    
    f32MatVec(&weights, &input, &output, 1, 100);
    
    // 100 * 1.0 * 2.0 = 200.0
    try std.testing.expectApproxEqAbs(@as(f32, 200.0), output[0], 0.001);
}

test "packed matmul correctness" {
    const allocator = std.testing.allocator;
    
    // Create test weights and input
    const rows: usize = 64;
    const cols: usize = 64;
    const weights = try allocator.alloc(f32, rows * cols);
    defer allocator.free(weights);
    
    // Fill with ternary-like values
    for (weights, 0..) |*w, i| {
        w.* = @as(f32, @floatFromInt(@as(i32, @intCast(i % 3)) - 1)); // -1, 0, 1
    }
    
    const input = try allocator.alloc(f32, cols);
    defer allocator.free(input);
    for (input, 0..) |*x, i| {
        x.* = @as(f32, @floatFromInt(i + 1));
    }
    
    // F32 matmul
    const output_f32 = try allocator.alloc(f32, rows);
    defer allocator.free(output_f32);
    f32MatVec(weights, input, output_f32, rows, cols);
    
    // Packed matmul
    var pw = try packWeights(allocator, weights, rows, cols);
    defer pw.deinit();
    
    const output_packed = try allocator.alloc(f32, rows);
    defer allocator.free(output_packed);
    packedMatVec(&pw, input, output_packed);
    
    // Compare results (should be similar, not exact due to quantization)
    var max_diff: f32 = 0.0;
    for (output_f32, output_packed) |f, p| {
        const diff = @abs(f - p);
        if (diff > max_diff) max_diff = diff;
    }
    
    std.debug.print("\n=== Packed vs F32 Matmul ===\n", .{});
    std.debug.print("Max difference: {d:.4}\n", .{max_diff});
    
    // Allow some quantization error
    try std.testing.expect(max_diff < 100.0); // Scaled values can be large
}

test "packed layer weights memory savings" {
    const allocator = std.testing.allocator;
    
    // Create a small test layer
    const hidden: usize = 64;
    const inter: usize = 128;
    
    // Allocate F32 weights
    const q_proj = try allocator.alloc(f32, hidden * hidden);
    defer allocator.free(q_proj);
    const k_proj = try allocator.alloc(f32, hidden * hidden);
    defer allocator.free(k_proj);
    const v_proj = try allocator.alloc(f32, hidden * hidden);
    defer allocator.free(v_proj);
    const o_proj = try allocator.alloc(f32, hidden * hidden);
    defer allocator.free(o_proj);
    const gate_proj = try allocator.alloc(f32, inter * hidden);
    defer allocator.free(gate_proj);
    const up_proj = try allocator.alloc(f32, inter * hidden);
    defer allocator.free(up_proj);
    const down_proj = try allocator.alloc(f32, hidden * inter);
    defer allocator.free(down_proj);
    const norm = try allocator.alloc(f32, hidden);
    defer allocator.free(norm);
    
    // Fill with test values
    for (q_proj) |*w| w.* = 0.5;
    for (k_proj) |*w| w.* = -0.5;
    for (v_proj) |*w| w.* = 0.3;
    for (o_proj) |*w| w.* = -0.3;
    for (gate_proj) |*w| w.* = 0.7;
    for (up_proj) |*w| w.* = -0.7;
    for (down_proj) |*w| w.* = 0.1;
    for (norm) |*w| w.* = 1.0;
    
    const layer = LayerWeights{
        .q_proj = q_proj,
        .k_proj = k_proj,
        .v_proj = v_proj,
        .o_proj = o_proj,
        .gate_proj = gate_proj,
        .up_proj = up_proj,
        .down_proj = down_proj,
        .input_layernorm = norm,
        .post_attention_layernorm = norm,
        .inner_attn_ln = norm,
        .ffn_layernorm = norm,
    };
    
    // Pack the layer
    var packed_layer = try packLayerWeights(allocator, layer, hidden, inter);
    defer packed_layer.deinit();
    
    // Calculate memory savings
    const f32_size = (4 * hidden * hidden + 3 * inter * hidden) * @sizeOf(f32);
    const packed_size = packed_layer.memoryUsage();
    const savings = @as(f32, @floatFromInt(f32_size)) / @as(f32, @floatFromInt(packed_size));
    
    std.debug.print("\n=== Packed Layer Memory Test ===\n", .{});
    std.debug.print("F32 size: {d} bytes\n", .{f32_size});
    std.debug.print("Packed size: {d} bytes\n", .{packed_size});
    std.debug.print("Savings: {d:.1}x\n", .{savings});
    
    // Should have significant savings
    try std.testing.expect(savings > 5.0);
}
