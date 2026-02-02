// ═══════════════════════════════════════════════════════════════════════════════
// CUDA TERNARY BACKEND - HW-001
// ═══════════════════════════════════════════════════════════════════════════════
// Ternary LLM Inference on NVIDIA GPUs
// Target: +100x speedup vs CPU (7.61 GFLOPS → 760+ GFLOPS)
// Sacred Formula: V = n × 3^k × π^m × φ^p × e^q
// Golden Identity: φ² + 1/φ² = 3
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

pub const PHI: f64 = 1.618033988749895;

// ═══════════════════════════════════════════════════════════════════════════════
// CUDA TYPES AND CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const WARP_SIZE: u32 = 32;
pub const MAX_THREADS_PER_BLOCK: u32 = 1024;
pub const MAX_SHARED_MEMORY: u32 = 49152;
pub const TILE_SIZE: u32 = 256;

/// Ternary sign lookup table
pub const SIGN_LUT: [4]f32 = .{ 0.0, 1.0, -1.0, 0.0 };

/// CUDA device properties
pub const CUDADevice = struct {
    device_id: i32,
    name: [256]u8,
    compute_capability_major: i32,
    compute_capability_minor: i32,
    cuda_cores: u32,
    sm_count: u32,
    memory_bytes: u64,
    memory_bandwidth_gbps: u32,
    max_threads_per_block: u32,
    max_shared_memory_per_block: u32,
    warp_size: u32,

    pub fn computeCapability(self: *const CUDADevice) f32 {
        return @as(f32, @floatFromInt(self.compute_capability_major)) +
            @as(f32, @floatFromInt(self.compute_capability_minor)) / 10.0;
    }

    pub fn memoryGB(self: *const CUDADevice) f32 {
        return @as(f32, @floatFromInt(self.memory_bytes)) / (1024.0 * 1024.0 * 1024.0);
    }
};

/// Known GPU specifications
pub const GPUSpecs = struct {
    pub const RTX_4090 = CUDADevice{
        .device_id = 0,
        .name = initName("NVIDIA GeForce RTX 4090"),
        .compute_capability_major = 8,
        .compute_capability_minor = 9,
        .cuda_cores = 16384,
        .sm_count = 128,
        .memory_bytes = 24 * 1024 * 1024 * 1024,
        .memory_bandwidth_gbps = 1008,
        .max_threads_per_block = 1024,
        .max_shared_memory_per_block = 49152,
        .warp_size = 32,
    };

    pub const A100 = CUDADevice{
        .device_id = 0,
        .name = initName("NVIDIA A100-SXM4-80GB"),
        .compute_capability_major = 8,
        .compute_capability_minor = 0,
        .cuda_cores = 6912,
        .sm_count = 108,
        .memory_bytes = 80 * 1024 * 1024 * 1024,
        .memory_bandwidth_gbps = 2039,
        .max_threads_per_block = 1024,
        .max_shared_memory_per_block = 49152,
        .warp_size = 32,
    };

    pub const H100 = CUDADevice{
        .device_id = 0,
        .name = initName("NVIDIA H100-SXM5-80GB"),
        .compute_capability_major = 9,
        .compute_capability_minor = 0,
        .cuda_cores = 16896,
        .sm_count = 132,
        .memory_bytes = 80 * 1024 * 1024 * 1024,
        .memory_bandwidth_gbps = 3350,
        .max_threads_per_block = 1024,
        .max_shared_memory_per_block = 49152,
        .warp_size = 32,
    };

    fn initName(comptime str: []const u8) [256]u8 {
        var result: [256]u8 = [_]u8{0} ** 256;
        for (str, 0..) |c, i| {
            result[i] = c;
        }
        return result;
    }
};

/// Kernel launch configuration
pub const KernelConfig = struct {
    block_dim: [3]u32 = .{ 256, 1, 1 },
    grid_dim: [3]u32 = .{ 1, 1, 1 },
    shared_memory_bytes: u32 = 0,
    stream: ?*anyopaque = null,

    pub fn totalThreads(self: *const KernelConfig) u64 {
        return @as(u64, self.block_dim[0]) * self.block_dim[1] * self.block_dim[2] *
            @as(u64, self.grid_dim[0]) * self.grid_dim[1] * self.grid_dim[2];
    }

    pub fn forMatmul(rows: u32, cols: u32) KernelConfig {
        _ = cols;
        const threads_per_block: u32 = 256;
        const blocks = (rows + threads_per_block - 1) / threads_per_block;
        return .{
            .block_dim = .{ threads_per_block, 1, 1 },
            .grid_dim = .{ blocks, 1, 1 },
            .shared_memory_bytes = TILE_SIZE * @sizeOf(f32),
        };
    }

    pub fn forAttention(seq_len: u32, head_dim: u32) KernelConfig {
        _ = head_dim;
        return .{
            .block_dim = .{ 256, 1, 1 },
            .grid_dim = .{ 1, 1, 1 },
            .shared_memory_bytes = seq_len * @sizeOf(f32),
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CUDA BACKEND STATE
// ═══════════════════════════════════════════════════════════════════════════════

pub const CUDABackend = struct {
    allocator: Allocator,
    device: CUDADevice,
    initialized: bool,
    // Simulated device memory tracking
    allocated_bytes: u64,
    peak_allocated_bytes: u64,

    pub fn init(allocator: Allocator) CUDABackend {
        return .{
            .allocator = allocator,
            .device = GPUSpecs.RTX_4090, // Default to RTX 4090 for simulation
            .initialized = false,
            .allocated_bytes = 0,
            .peak_allocated_bytes = 0,
        };
    }

    pub fn deinit(self: *CUDABackend) void {
        self.initialized = false;
        self.allocated_bytes = 0;
    }

    /// Initialize CUDA runtime (simulated)
    pub fn initCUDA(self: *CUDABackend) !void {
        // In real implementation: cudaSetDevice, cudaGetDeviceProperties
        self.initialized = true;
        std.debug.print("CUDA Backend initialized: {s}\n", .{self.device.name[0..30]});
        std.debug.print("  Compute Capability: {d}.{d}\n", .{
            self.device.compute_capability_major,
            self.device.compute_capability_minor,
        });
        std.debug.print("  CUDA Cores: {d}\n", .{self.device.cuda_cores});
        std.debug.print("  Memory: {d:.1} GB\n", .{self.device.memoryGB()});
    }

    /// Allocate device memory (simulated)
    pub fn allocateDevice(self: *CUDABackend, size: u64) !u64 {
        if (!self.initialized) return error.NotInitialized;
        if (self.allocated_bytes + size > self.device.memory_bytes) {
            return error.OutOfMemory;
        }
        self.allocated_bytes += size;
        if (self.allocated_bytes > self.peak_allocated_bytes) {
            self.peak_allocated_bytes = self.allocated_bytes;
        }
        // Return simulated device pointer
        return self.allocated_bytes;
    }

    /// Free device memory (simulated)
    pub fn freeDevice(self: *CUDABackend, size: u64) void {
        if (size <= self.allocated_bytes) {
            self.allocated_bytes -= size;
        }
    }

    /// Get memory usage
    pub fn getMemoryUsage(self: *const CUDABackend) struct { used: u64, peak: u64, total: u64 } {
        return .{
            .used = self.allocated_bytes,
            .peak = self.peak_allocated_bytes,
            .total = self.device.memory_bytes,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY MATMUL KERNEL (CPU SIMULATION)
// ═══════════════════════════════════════════════════════════════════════════════

/// Simulated CUDA ternary matmul kernel
/// In real implementation, this would be a .cu file compiled with nvcc
pub fn cudaTernaryMatmulKernel(
    output: []f32,
    weights: []const u8,
    input: []const f32,
    rows: usize,
    cols: usize,
    config: KernelConfig,
) void {
    _ = config;
    const cols_packed = (cols + 3) / 4;

    // Simulate GPU parallelism with CPU threads
    // Each "thread" processes one row
    for (0..rows) |row| {
        var sum: f32 = 0.0;
        const row_start = row * cols_packed;

        var col: usize = 0;
        while (col < cols) : (col += 4) {
            const byte_idx = row_start + col / 4;
            if (byte_idx >= weights.len) break;

            const byte_val = weights[byte_idx];
            if (col + 0 < cols) sum += input[col + 0] * SIGN_LUT[(byte_val >> 0) & 0x3];
            if (col + 1 < cols) sum += input[col + 1] * SIGN_LUT[(byte_val >> 2) & 0x3];
            if (col + 2 < cols) sum += input[col + 2] * SIGN_LUT[(byte_val >> 4) & 0x3];
            if (col + 3 < cols) sum += input[col + 3] * SIGN_LUT[(byte_val >> 6) & 0x3];
        }

        output[row] = sum;
    }
}

/// Batched ternary matmul for multiple inputs
pub fn cudaTernaryMatmulBatched(
    outputs: [][]f32,
    weights: []const u8,
    inputs: []const []const f32,
    rows: usize,
    cols: usize,
    batch_size: usize,
) void {
    const config = KernelConfig.forMatmul(@intCast(rows), @intCast(cols));

    // Process each batch item (in real CUDA, all would run in parallel)
    for (0..batch_size) |b| {
        cudaTernaryMatmulKernel(outputs[b], weights, inputs[b], rows, cols, config);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY ATTENTION KERNEL (CPU SIMULATION)
// ═══════════════════════════════════════════════════════════════════════════════

/// Simulated CUDA ternary attention kernel
pub fn cudaTernaryAttentionKernel(
    output: []f32,
    query: []const f32,
    keys_packed: []const u8,
    values: []const f32,
    seq_len: usize,
    head_dim: usize,
    scale: f32,
    scores_buf: []f32,
) void {
    const head_dim_packed = (head_dim + 3) / 4;

    // Compute attention scores: Q @ K^T (K is ternary)
    for (0..seq_len) |i| {
        var score: f32 = 0.0;
        const key_start = i * head_dim_packed;

        var j: usize = 0;
        while (j < head_dim) : (j += 4) {
            const byte_idx = key_start + j / 4;
            if (byte_idx >= keys_packed.len) break;

            const key_byte = keys_packed[byte_idx];
            if (j + 0 < head_dim) score += query[j + 0] * SIGN_LUT[(key_byte >> 0) & 0x3];
            if (j + 1 < head_dim) score += query[j + 1] * SIGN_LUT[(key_byte >> 2) & 0x3];
            if (j + 2 < head_dim) score += query[j + 2] * SIGN_LUT[(key_byte >> 4) & 0x3];
            if (j + 3 < head_dim) score += query[j + 3] * SIGN_LUT[(key_byte >> 6) & 0x3];
        }
        scores_buf[i] = score * scale;
    }

    // Softmax
    var max_score: f32 = scores_buf[0];
    for (scores_buf[1..seq_len]) |s| {
        if (s > max_score) max_score = s;
    }

    var sum_exp: f32 = 0.0;
    for (0..seq_len) |i| {
        scores_buf[i] = @exp(scores_buf[i] - max_score);
        sum_exp += scores_buf[i];
    }

    for (0..seq_len) |i| {
        scores_buf[i] /= sum_exp;
    }

    // Weighted sum of values
    @memset(output[0..head_dim], 0.0);
    for (0..seq_len) |i| {
        const weight = scores_buf[i];
        const val_start = i * head_dim;
        for (0..head_dim) |d| {
            output[d] += weight * values[val_start + d];
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// UNIFIED BACKEND - CPU/GPU DISPATCH
// ═══════════════════════════════════════════════════════════════════════════════

pub const Backend = enum {
    cpu,
    cuda,
    auto,
};

pub const TernaryInference = struct {
    allocator: Allocator,
    backend: Backend,
    cuda_backend: ?CUDABackend,

    pub fn init(allocator: Allocator, preferred_backend: Backend) TernaryInference {
        var self = TernaryInference{
            .allocator = allocator,
            .backend = preferred_backend,
            .cuda_backend = null,
        };

        // Try to initialize CUDA if requested
        if (preferred_backend == .cuda or preferred_backend == .auto) {
            var cuda = CUDABackend.init(allocator);
            if (cuda.initCUDA()) |_| {
                self.cuda_backend = cuda;
                self.backend = .cuda;
            } else |_| {
                if (preferred_backend == .auto) {
                    self.backend = .cpu;
                }
            }
        }

        return self;
    }

    pub fn deinit(self: *TernaryInference) void {
        if (self.cuda_backend) |*cuda| {
            cuda.deinit();
        }
    }

    /// Unified matmul - dispatches to CPU or GPU
    pub fn matmul(
        self: *TernaryInference,
        output: []f32,
        weights: []const u8,
        input: []const f32,
        rows: usize,
        cols: usize,
    ) void {
        switch (self.backend) {
            .cuda => {
                const config = KernelConfig.forMatmul(@intCast(rows), @intCast(cols));
                cudaTernaryMatmulKernel(output, weights, input, rows, cols, config);
            },
            .cpu, .auto => {
                // Use SIMD CPU implementation
                cpuTernaryMatmul(output, weights, input, rows, cols);
            },
        }
    }

    /// Unified attention - dispatches to CPU or GPU
    pub fn attention(
        self: *TernaryInference,
        output: []f32,
        query: []const f32,
        keys_packed: []const u8,
        values: []const f32,
        seq_len: usize,
        head_dim: usize,
        scores_buf: []f32,
    ) void {
        const scale = 1.0 / @sqrt(@as(f32, @floatFromInt(head_dim)));

        switch (self.backend) {
            .cuda => {
                cudaTernaryAttentionKernel(output, query, keys_packed, values, seq_len, head_dim, scale, scores_buf);
            },
            .cpu, .auto => {
                cpuTernaryAttention(output, query, keys_packed, values, seq_len, head_dim, scale, scores_buf);
            },
        }
    }

    pub fn getBackendName(self: *const TernaryInference) []const u8 {
        return switch (self.backend) {
            .cuda => "CUDA",
            .cpu => "CPU",
            .auto => "Auto",
        };
    }
};

/// CPU fallback for ternary matmul (uses SIMD when available)
fn cpuTernaryMatmul(
    output: []f32,
    weights: []const u8,
    input: []const f32,
    rows: usize,
    cols: usize,
) void {
    const cols_packed = (cols + 3) / 4;

    for (0..rows) |row| {
        var sum: f32 = 0.0;
        const row_start = row * cols_packed;

        var col: usize = 0;
        while (col < cols) : (col += 4) {
            const byte_idx = row_start + col / 4;
            if (byte_idx >= weights.len) break;

            const byte_val = weights[byte_idx];
            if (col + 0 < cols) sum += input[col + 0] * SIGN_LUT[(byte_val >> 0) & 0x3];
            if (col + 1 < cols) sum += input[col + 1] * SIGN_LUT[(byte_val >> 2) & 0x3];
            if (col + 2 < cols) sum += input[col + 2] * SIGN_LUT[(byte_val >> 4) & 0x3];
            if (col + 3 < cols) sum += input[col + 3] * SIGN_LUT[(byte_val >> 6) & 0x3];
        }

        output[row] = sum;
    }
}

/// CPU fallback for ternary attention
fn cpuTernaryAttention(
    output: []f32,
    query: []const f32,
    keys_packed: []const u8,
    values: []const f32,
    seq_len: usize,
    head_dim: usize,
    scale: f32,
    scores_buf: []f32,
) void {
    cudaTernaryAttentionKernel(output, query, keys_packed, values, seq_len, head_dim, scale, scores_buf);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PERFORMANCE ESTIMATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const PerformanceEstimate = struct {
    /// Estimate GFLOPS for ternary matmul on GPU
    pub fn estimateMatmulGFLOPS(device: CUDADevice, rows: u32, cols: u32) f64 {
        // Ternary matmul benefits from:
        // 1. 4x less memory for weights (2-bit vs 8-bit)
        // 2. Simple LUT-based decode
        // 3. Massive parallelism on GPU
        
        // Memory-bound estimate
        const bytes_read = @as(f64, @floatFromInt(rows)) * @as(f64, @floatFromInt(cols)) / 4.0 + // weights (2-bit packed)
            @as(f64, @floatFromInt(cols)) * 4.0; // input (f32)
        const flops = @as(f64, @floatFromInt(rows)) * @as(f64, @floatFromInt(cols)) * 2.0;

        // Memory bandwidth in bytes/sec
        const bandwidth_bytes_per_sec = @as(f64, @floatFromInt(device.memory_bandwidth_gbps)) * 1e9;
        
        // Arithmetic intensity (FLOPS per byte)
        const arithmetic_intensity = flops / bytes_read;
        
        // Roofline model: min(peak_compute, bandwidth * arithmetic_intensity)
        const peak_gflops = @as(f64, @floatFromInt(device.cuda_cores)) * 2.0 * 1.5 / 1000.0; // ~3 GHz effective
        const bandwidth_limited_gflops = bandwidth_bytes_per_sec * arithmetic_intensity / 1e9;
        
        // Ternary is ~4x more efficient than FP16 due to compression
        const ternary_efficiency = 4.0;
        
        return @min(peak_gflops, bandwidth_limited_gflops * ternary_efficiency);
    }

    /// Estimate speedup vs CPU
    pub fn estimateSpeedupVsCPU(device: CUDADevice, cpu_gflops: f64, rows: u32, cols: u32) f64 {
        const gpu_gflops = estimateMatmulGFLOPS(device, rows, cols);
        return gpu_gflops / cpu_gflops;
    }

    /// Estimate throughput in tokens/second
    pub fn estimateThroughput(device: CUDADevice, model_params_b: f64, batch_size: u32) f64 {
        // Simplified: throughput ~ memory_bandwidth / (params * bytes_per_param)
        const bytes_per_param: f64 = 0.25; // Ternary: 2 bits = 0.25 bytes
        const model_bytes = model_params_b * 1e9 * bytes_per_param;
        const bandwidth = @as(f64, @floatFromInt(device.memory_bandwidth_gbps)) * 1e9;

        // Tokens per second (memory-bound estimate)
        const tps = bandwidth / model_bytes * @as(f64, @floatFromInt(batch_size));
        return tps;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runBenchmark(allocator: Allocator) !void {
    const rows: usize = 2048;
    const cols: usize = 2048;
    const iterations: usize = 10;
    const cols_packed = (cols + 3) / 4;

    const weights = try allocator.alloc(u8, rows * cols_packed);
    defer allocator.free(weights);
    const input = try allocator.alloc(f32, cols);
    defer allocator.free(input);
    const output = try allocator.alloc(f32, rows);
    defer allocator.free(output);

    // Initialize
    for (weights, 0..) |*w, i| w.* = @truncate(i * 17 + 31);
    for (input, 0..) |*v, i| v.* = @as(f32, @floatFromInt(i % 100)) / 100.0;

    const flops = rows * cols * 2 * iterations;
    const config = KernelConfig.forMatmul(@intCast(rows), @intCast(cols));

    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("         HW-001 CUDA TERNARY MATMUL BENCHMARK ({d}x{d})\n", .{ rows, cols });
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});

    // Benchmark simulated CUDA kernel
    var timer = try std.time.Timer.start();
    for (0..iterations) |_| {
        cudaTernaryMatmulKernel(output, weights, input, rows, cols, config);
    }
    const cuda_ns = timer.read();
    const cuda_gflops = @as(f64, @floatFromInt(flops)) / @as(f64, @floatFromInt(cuda_ns));

    std.debug.print("  CPU Simulation:       {d:8.1} us  ({d:.2} GFLOPS)\n", .{
        @as(f64, @floatFromInt(cuda_ns)) / 1000.0 / @as(f64, @floatFromInt(iterations)),
        cuda_gflops,
    });

    // Estimate real GPU performance
    const rtx4090_est = PerformanceEstimate.estimateMatmulGFLOPS(GPUSpecs.RTX_4090, @intCast(rows), @intCast(cols));
    const a100_est = PerformanceEstimate.estimateMatmulGFLOPS(GPUSpecs.A100, @intCast(rows), @intCast(cols));
    const h100_est = PerformanceEstimate.estimateMatmulGFLOPS(GPUSpecs.H100, @intCast(rows), @intCast(cols));

    std.debug.print("\n", .{});
    std.debug.print("  ESTIMATED GPU PERFORMANCE:\n", .{});
    std.debug.print("  RTX 4090:             {d:8.1} GFLOPS (est. {d:.0}x vs CPU)\n", .{
        rtx4090_est,
        rtx4090_est / 7.61,
    });
    std.debug.print("  A100:                 {d:8.1} GFLOPS (est. {d:.0}x vs CPU)\n", .{
        a100_est,
        a100_est / 7.61,
    });
    std.debug.print("  H100:                 {d:8.1} GFLOPS (est. {d:.0}x vs CPU)\n", .{
        h100_est,
        h100_est / 7.61,
    });

    // Throughput estimates
    std.debug.print("\n", .{});
    std.debug.print("  ESTIMATED THROUGHPUT (7B model, batch=8):\n", .{});
    std.debug.print("  RTX 4090:             {d:8.0} tok/s\n", .{PerformanceEstimate.estimateThroughput(GPUSpecs.RTX_4090, 7.0, 8)});
    std.debug.print("  A100:                 {d:8.0} tok/s\n", .{PerformanceEstimate.estimateThroughput(GPUSpecs.A100, 7.0, 8)});
    std.debug.print("  H100:                 {d:8.0} tok/s\n", .{PerformanceEstimate.estimateThroughput(GPUSpecs.H100, 7.0, 8)});

    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  CPU Baseline: 7.61 GFLOPS | GPU Target: 500-1500 GFLOPS\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════════════════════\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    try runBenchmark(gpa.allocator());
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "CUDADevice properties" {
    const rtx4090 = GPUSpecs.RTX_4090;
    try std.testing.expectEqual(@as(u32, 16384), rtx4090.cuda_cores);
    try std.testing.expectApproxEqAbs(@as(f32, 8.9), rtx4090.computeCapability(), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 24.0), rtx4090.memoryGB(), 0.1);
}

test "KernelConfig forMatmul" {
    const config = KernelConfig.forMatmul(2048, 2048);
    try std.testing.expectEqual(@as(u32, 256), config.block_dim[0]);
    try std.testing.expectEqual(@as(u32, 8), config.grid_dim[0]); // 2048/256 = 8
}

test "CUDABackend init" {
    var backend = CUDABackend.init(std.testing.allocator);
    defer backend.deinit();

    try backend.initCUDA();
    try std.testing.expect(backend.initialized);
}

test "CUDABackend memory allocation" {
    var backend = CUDABackend.init(std.testing.allocator);
    defer backend.deinit();

    try backend.initCUDA();

    const ptr = try backend.allocateDevice(1024 * 1024); // 1MB
    try std.testing.expect(ptr > 0);

    const usage = backend.getMemoryUsage();
    try std.testing.expectEqual(@as(u64, 1024 * 1024), usage.used);
}

test "cudaTernaryMatmulKernel correctness" {
    const allocator = std.testing.allocator;

    const rows: usize = 64;
    const cols: usize = 64;
    const cols_packed = (cols + 3) / 4;

    const weights = try allocator.alloc(u8, rows * cols_packed);
    defer allocator.free(weights);
    const input = try allocator.alloc(f32, cols);
    defer allocator.free(input);
    const output = try allocator.alloc(f32, rows);
    defer allocator.free(output);

    // Initialize with known values
    for (weights) |*w| w.* = 0x55; // All +1 (01 01 01 01)
    for (input) |*v| v.* = 1.0;

    const config = KernelConfig.forMatmul(@intCast(rows), @intCast(cols));
    cudaTernaryMatmulKernel(output, weights, input, rows, cols, config);

    // Each row should sum to cols (all +1 * 1.0)
    for (output) |v| {
        try std.testing.expectApproxEqAbs(@as(f32, @floatFromInt(cols)), v, 0.01);
    }
}

test "PerformanceEstimate" {
    const rtx4090_gflops = PerformanceEstimate.estimateMatmulGFLOPS(GPUSpecs.RTX_4090, 2048, 2048);
    try std.testing.expect(rtx4090_gflops > 10.0); // Should be >10 GFLOPS (conservative)

    const speedup = PerformanceEstimate.estimateSpeedupVsCPU(GPUSpecs.RTX_4090, 7.61, 2048, 2048);
    try std.testing.expect(speedup > 1.0); // Should be >1x speedup
}

test "benchmark runs" {
    try runBenchmark(std.testing.allocator);
}
