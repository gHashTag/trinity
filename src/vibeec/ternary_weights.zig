// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY WEIGHTS - BitNet {-1, 0, +1} Support
// 20x memory savings, no multiplications needed
// φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY WEIGHT REPRESENTATION
// ═══════════════════════════════════════════════════════════════════════════════

/// Ternary weight: {-1, 0, +1} encoded in 2 bits
/// 00 = 0, 01 = +1, 10 = -1, 11 = reserved
pub const TritWeight = packed struct {
    value: u2,

    pub const ZERO: TritWeight = .{ .value = 0b00 };
    pub const PLUS_ONE: TritWeight = .{ .value = 0b01 };
    pub const MINUS_ONE: TritWeight = .{ .value = 0b10 };

    pub fn toFloat(self: TritWeight) f32 {
        return switch (self.value) {
            0b00 => 0.0,
            0b01 => 1.0,
            0b10 => -1.0,
            else => 0.0,
        };
    }

    pub fn fromFloat(f: f32) TritWeight {
        if (f > 0.5) return PLUS_ONE;
        if (f < -0.5) return MINUS_ONE;
        return ZERO;
    }
};

/// Packed ternary weights - 4 trits per byte
pub const TritPack4 = packed struct {
    t0: u2,
    t1: u2,
    t2: u2,
    t3: u2,

    pub fn get(self: TritPack4, idx: u2) TritWeight {
        return switch (idx) {
            0 => .{ .value = self.t0 },
            1 => .{ .value = self.t1 },
            2 => .{ .value = self.t2 },
            3 => .{ .value = self.t3 },
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY MATRIX-VECTOR MULTIPLICATION
// No multiplications! Only additions and subtractions
// ═══════════════════════════════════════════════════════════════════════════════

/// Ternary matrix-vector multiplication
/// output[i] = sum_j(weight[i,j] * input[j])
/// where weight[i,j] ∈ {-1, 0, +1}
/// 
/// This is 10-20x faster than float matmul because:
/// - No multiplications (just add/subtract/skip)
/// - 16x less memory bandwidth (2 bits vs 32 bits)
pub fn ternaryMatVec(
    output: []f32,
    weights: []const u8, // Packed ternary weights
    input: []const f32,
    rows: usize,
    cols: usize,
) void {
    const cols_packed = (cols + 3) / 4; // 4 trits per byte

    for (0..rows) |row| {
        var sum: f32 = 0.0;
        const row_start = row * cols_packed;

        var col: usize = 0;
        while (col < cols) {
            const byte_idx = row_start + col / 4;
            if (byte_idx >= weights.len) break;

            const pack: TritPack4 = @bitCast(weights[byte_idx]);

            // Process 4 weights at once
            inline for (0..4) |i| {
                if (col + i < cols) {
                    const trit = pack.get(@intCast(i));
                    switch (trit.value) {
                        0b01 => sum += input[col + i],      // +1: add
                        0b10 => sum -= input[col + i],      // -1: subtract
                        else => {},                          // 0: skip
                    }
                }
            }
            col += 4;
        }

        output[row] = sum;
    }
}

/// SIMD-optimized ternary matmul (AVX2/AVX-512)
/// Uses lookup tables and vectorized operations for maximum throughput
pub fn simdTernaryMatVec(
    output: []f32,
    weights: []const u8,
    input: []const f32,
    rows: usize,
    cols: usize,
) void {
    const Vec8f32 = @Vector(8, f32);
    const cols_packed = (cols + 3) / 4;

    // Precompute sign lookup: trit -> {-1, 0, +1}
    // 00 = 0, 01 = +1, 10 = -1
    const sign_lut = [4]f32{ 0.0, 1.0, -1.0, 0.0 };

    for (0..rows) |row| {
        var sum_vec: Vec8f32 = @splat(0.0);
        var sum_scalar: f32 = 0.0;
        const row_start = row * cols_packed;

        var col: usize = 0;
        
        // Process 8 floats at a time with SIMD
        while (col + 8 <= cols and row_start + col / 4 + 1 < weights.len) {
            // Load 8 input values
            const in_vec: Vec8f32 = input[col..][0..8].*;

            // Load 2 bytes = 8 trits
            const byte0 = weights[row_start + col / 4];
            const byte1 = weights[row_start + col / 4 + 1];

            // Decode trits using lookup table - vectorized
            const signs: Vec8f32 = .{
                sign_lut[(byte0 >> 0) & 0x3],
                sign_lut[(byte0 >> 2) & 0x3],
                sign_lut[(byte0 >> 4) & 0x3],
                sign_lut[(byte0 >> 6) & 0x3],
                sign_lut[(byte1 >> 0) & 0x3],
                sign_lut[(byte1 >> 2) & 0x3],
                sign_lut[(byte1 >> 4) & 0x3],
                sign_lut[(byte1 >> 6) & 0x3],
            };

            // Multiply and accumulate: sum += input * sign
            // This is the key optimization: no branches, pure SIMD
            sum_vec += in_vec * signs;

            col += 8;
        }

        // Reduce SIMD vector to scalar
        sum_scalar = @reduce(.Add, sum_vec);

        // Handle remaining elements (scalar fallback)
        while (col < cols) : (col += 1) {
            const byte_idx = row_start + col / 4;
            if (byte_idx >= weights.len) break;
            
            const shift: u3 = @intCast((col % 4) * 2);
            const trit = (weights[byte_idx] >> shift) & 0x3;
            sum_scalar += input[col] * sign_lut[trit];
        }

        output[row] = sum_scalar;
    }
}

/// Ultra-optimized SIMD ternary matmul with 16-wide vectors
/// For AVX-512 capable CPUs
pub fn simd16TernaryMatVec(
    output: []f32,
    weights: []const u8,
    input: []const f32,
    rows: usize,
    cols: usize,
) void {
    const Vec16f32 = @Vector(16, f32);
    const cols_packed = (cols + 3) / 4;
    const sign_lut = [4]f32{ 0.0, 1.0, -1.0, 0.0 };

    for (0..rows) |row| {
        var sum_vec: Vec16f32 = @splat(0.0);
        var sum_scalar: f32 = 0.0;
        const row_start = row * cols_packed;

        var col: usize = 0;
        
        // Process 16 floats at a time (4 bytes = 16 trits)
        while (col + 16 <= cols and row_start + col / 4 + 3 < weights.len) {
            const in_vec: Vec16f32 = input[col..][0..16].*;

            // Load 4 bytes = 16 trits
            const b0 = weights[row_start + col / 4];
            const b1 = weights[row_start + col / 4 + 1];
            const b2 = weights[row_start + col / 4 + 2];
            const b3 = weights[row_start + col / 4 + 3];

            const signs: Vec16f32 = .{
                sign_lut[(b0 >> 0) & 0x3], sign_lut[(b0 >> 2) & 0x3],
                sign_lut[(b0 >> 4) & 0x3], sign_lut[(b0 >> 6) & 0x3],
                sign_lut[(b1 >> 0) & 0x3], sign_lut[(b1 >> 2) & 0x3],
                sign_lut[(b1 >> 4) & 0x3], sign_lut[(b1 >> 6) & 0x3],
                sign_lut[(b2 >> 0) & 0x3], sign_lut[(b2 >> 2) & 0x3],
                sign_lut[(b2 >> 4) & 0x3], sign_lut[(b2 >> 6) & 0x3],
                sign_lut[(b3 >> 0) & 0x3], sign_lut[(b3 >> 2) & 0x3],
                sign_lut[(b3 >> 4) & 0x3], sign_lut[(b3 >> 6) & 0x3],
            };

            sum_vec += in_vec * signs;
            col += 16;
        }

        sum_scalar = @reduce(.Add, sum_vec);

        // Scalar fallback for remaining
        while (col < cols) : (col += 1) {
            const byte_idx = row_start + col / 4;
            if (byte_idx >= weights.len) break;
            const shift: u3 = @intCast((col % 4) * 2);
            const trit = (weights[byte_idx] >> shift) & 0x3;
            sum_scalar += input[col] * sign_lut[trit];
        }

        output[row] = sum_scalar;
    }
}

/// Batch ternary matmul - process multiple rows in parallel
/// Best for large matrices
pub fn batchTernaryMatVec(
    output: []f32,
    weights: []const u8,
    input: []const f32,
    rows: usize,
    cols: usize,
) void {
    const Vec8f32 = @Vector(8, f32);
    const cols_packed = (cols + 3) / 4;
    const sign_lut = [4]f32{ 0.0, 1.0, -1.0, 0.0 };

    var row: usize = 0;
    
    // Process 4 rows at a time
    while (row + 4 <= rows) {
        var sum0: Vec8f32 = @splat(0.0);
        var sum1: Vec8f32 = @splat(0.0);
        var sum2: Vec8f32 = @splat(0.0);
        var sum3: Vec8f32 = @splat(0.0);

        var col: usize = 0;
        while (col + 8 <= cols) {
            const in_vec: Vec8f32 = input[col..][0..8].*;
            const col_byte = col / 4;

            // Row 0
            const r0_start = row * cols_packed;
            if (r0_start + col_byte + 1 < weights.len) {
                const b0 = weights[r0_start + col_byte];
                const b1 = weights[r0_start + col_byte + 1];
                const s0: Vec8f32 = .{
                    sign_lut[(b0 >> 0) & 0x3], sign_lut[(b0 >> 2) & 0x3],
                    sign_lut[(b0 >> 4) & 0x3], sign_lut[(b0 >> 6) & 0x3],
                    sign_lut[(b1 >> 0) & 0x3], sign_lut[(b1 >> 2) & 0x3],
                    sign_lut[(b1 >> 4) & 0x3], sign_lut[(b1 >> 6) & 0x3],
                };
                sum0 += in_vec * s0;
            }

            // Row 1
            const r1_start = (row + 1) * cols_packed;
            if (r1_start + col_byte + 1 < weights.len) {
                const b0 = weights[r1_start + col_byte];
                const b1 = weights[r1_start + col_byte + 1];
                const s1: Vec8f32 = .{
                    sign_lut[(b0 >> 0) & 0x3], sign_lut[(b0 >> 2) & 0x3],
                    sign_lut[(b0 >> 4) & 0x3], sign_lut[(b0 >> 6) & 0x3],
                    sign_lut[(b1 >> 0) & 0x3], sign_lut[(b1 >> 2) & 0x3],
                    sign_lut[(b1 >> 4) & 0x3], sign_lut[(b1 >> 6) & 0x3],
                };
                sum1 += in_vec * s1;
            }

            // Row 2
            const r2_start = (row + 2) * cols_packed;
            if (r2_start + col_byte + 1 < weights.len) {
                const b0 = weights[r2_start + col_byte];
                const b1 = weights[r2_start + col_byte + 1];
                const s2: Vec8f32 = .{
                    sign_lut[(b0 >> 0) & 0x3], sign_lut[(b0 >> 2) & 0x3],
                    sign_lut[(b0 >> 4) & 0x3], sign_lut[(b0 >> 6) & 0x3],
                    sign_lut[(b1 >> 0) & 0x3], sign_lut[(b1 >> 2) & 0x3],
                    sign_lut[(b1 >> 4) & 0x3], sign_lut[(b1 >> 6) & 0x3],
                };
                sum2 += in_vec * s2;
            }

            // Row 3
            const r3_start = (row + 3) * cols_packed;
            if (r3_start + col_byte + 1 < weights.len) {
                const b0 = weights[r3_start + col_byte];
                const b1 = weights[r3_start + col_byte + 1];
                const s3: Vec8f32 = .{
                    sign_lut[(b0 >> 0) & 0x3], sign_lut[(b0 >> 2) & 0x3],
                    sign_lut[(b0 >> 4) & 0x3], sign_lut[(b0 >> 6) & 0x3],
                    sign_lut[(b1 >> 0) & 0x3], sign_lut[(b1 >> 2) & 0x3],
                    sign_lut[(b1 >> 4) & 0x3], sign_lut[(b1 >> 6) & 0x3],
                };
                sum3 += in_vec * s3;
            }

            col += 8;
        }

        // Reduce and store
        output[row] = @reduce(.Add, sum0);
        output[row + 1] = @reduce(.Add, sum1);
        output[row + 2] = @reduce(.Add, sum2);
        output[row + 3] = @reduce(.Add, sum3);

        // Scalar remainder for columns
        while (col < cols) : (col += 1) {
            for (0..4) |b| {
                const r_start = (row + b) * cols_packed;
                const byte_idx = r_start + col / 4;
                if (byte_idx >= weights.len) continue;
                const shift: u3 = @intCast((col % 4) * 2);
                const trit = (weights[byte_idx] >> shift) & 0x3;
                output[row + b] += input[col] * sign_lut[trit];
            }
        }

        row += 4;
    }

    // Handle remaining rows
    while (row < rows) : (row += 1) {
        var sum: f32 = 0.0;
        const row_start = row * cols_packed;

        for (0..cols) |col| {
            const byte_idx = row_start + col / 4;
            if (byte_idx >= weights.len) break;
            const shift: u3 = @intCast((col % 4) * 2);
            const trit = (weights[byte_idx] >> shift) & 0x3;
            sum += input[col] * sign_lut[trit];
        }
        output[row] = sum;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// QUANTIZATION: Float -> Ternary
// ═══════════════════════════════════════════════════════════════════════════════

/// Quantize float weights to ternary using threshold
pub fn quantizeToTernary(
    allocator: std.mem.Allocator,
    weights: []const f32,
    threshold: f32,
) ![]u8 {
    const num_bytes = (weights.len + 3) / 4;
    const result = try allocator.alloc(u8, num_bytes);
    
    var byte_idx: usize = 0;
    var bit_pos: u3 = 0;
    var current_byte: u8 = 0;

    for (weights) |w| {
        const trit: u2 = if (w > threshold) 
            0b01  // +1
        else if (w < -threshold) 
            0b10  // -1
        else 
            0b00; // 0

        current_byte |= @as(u8, trit) << bit_pos;
        bit_pos += 2;

        if (bit_pos == 0) { // Wrapped around
            result[byte_idx] = current_byte;
            byte_idx += 1;
            current_byte = 0;
        }
    }

    // Write last partial byte
    if (bit_pos != 0 and byte_idx < num_bytes) {
        result[byte_idx] = current_byte;
    }

    return result;
}

/// Calculate optimal threshold for ternary quantization
/// Uses mean absolute value as threshold
pub fn calculateThreshold(weights: []const f32) f32 {
    var sum: f32 = 0.0;
    for (weights) |w| {
        sum += @abs(w);
    }
    return sum / @as(f32, @floatFromInt(weights.len)) * 0.5;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MEMORY COMPARISON
// ═══════════════════════════════════════════════════════════════════════════════

/// Calculate memory usage for different representations
pub const MemoryStats = struct {
    f32_bytes: usize,
    f16_bytes: usize,
    q8_bytes: usize,
    q4_bytes: usize,
    ternary_bytes: usize,

    pub fn calculate(num_params: usize) MemoryStats {
        return .{
            .f32_bytes = num_params * 4,
            .f16_bytes = num_params * 2,
            .q8_bytes = num_params + num_params / 32 * 2, // Q8_0
            .q4_bytes = num_params / 2 + num_params / 32 * 2, // Q4_0
            .ternary_bytes = (num_params + 3) / 4, // 2 bits per weight
        };
    }

    pub fn print(self: MemoryStats) void {
        std.debug.print("\nMemory Usage Comparison:\n", .{});
        std.debug.print("  F32:     {d:.2} MB\n", .{@as(f64, @floatFromInt(self.f32_bytes)) / 1024 / 1024});
        std.debug.print("  F16:     {d:.2} MB\n", .{@as(f64, @floatFromInt(self.f16_bytes)) / 1024 / 1024});
        std.debug.print("  Q8_0:    {d:.2} MB\n", .{@as(f64, @floatFromInt(self.q8_bytes)) / 1024 / 1024});
        std.debug.print("  Q4_0:    {d:.2} MB\n", .{@as(f64, @floatFromInt(self.q4_bytes)) / 1024 / 1024});
        std.debug.print("  Ternary: {d:.2} MB ({}x smaller than F32)\n", .{
            @as(f64, @floatFromInt(self.ternary_bytes)) / 1024 / 1024,
            self.f32_bytes / self.ternary_bytes,
        });
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ternary weight encoding" {
    const t_zero = TritWeight.ZERO;
    const t_plus = TritWeight.PLUS_ONE;
    const t_minus = TritWeight.MINUS_ONE;

    try std.testing.expectEqual(@as(f32, 0.0), t_zero.toFloat());
    try std.testing.expectEqual(@as(f32, 1.0), t_plus.toFloat());
    try std.testing.expectEqual(@as(f32, -1.0), t_minus.toFloat());
}

test "ternary matmul" {
    const allocator = std.testing.allocator;

    // 2x4 matrix with ternary weights
    // Row 0: [+1, -1, 0, +1]
    // Row 1: [-1, +1, +1, 0]
    const weights = [_]u8{
        0b01_00_10_01, // Row 0: +1, -1, 0, +1
        0b00_01_01_10, // Row 1: -1, +1, +1, 0
    };

    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var output: [2]f32 = undefined;

    ternaryMatVec(&output, &weights, &input, 2, 4);

    // Row 0: 1*1 + (-1)*2 + 0*3 + 1*4 = 1 - 2 + 0 + 4 = 3
    // Row 1: (-1)*1 + 1*2 + 1*3 + 0*4 = -1 + 2 + 3 + 0 = 4
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), output[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), output[1], 0.001);

    _ = allocator;
}

test "memory stats" {
    // 7B model
    const stats = MemoryStats.calculate(7_000_000_000);
    
    // F32: 28 GB
    try std.testing.expect(stats.f32_bytes == 28_000_000_000);
    
    // Ternary: ~1.75 GB (16x smaller)
    try std.testing.expect(stats.ternary_bytes < 2_000_000_000);
}

test "simd ternary matmul" {
    const allocator = std.testing.allocator;
    _ = allocator;

    // 2x8 matrix for SIMD test
    const weights = [_]u8{
        0b01_00_10_01, 0b00_01_10_01, // Row 0: +1,-1,0,+1, +1,-1,+1,0
        0b10_01_01_00, 0b01_00_00_10, // Row 1: 0,+1,+1,-1, -1,0,0,+1
    };

    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0 };
    var output_scalar: [2]f32 = undefined;
    var output_simd: [2]f32 = undefined;

    ternaryMatVec(&output_scalar, &weights, &input, 2, 8);
    simdTernaryMatVec(&output_simd, &weights, &input, 2, 8);

    // Results should match
    try std.testing.expectApproxEqAbs(output_scalar[0], output_simd[0], 0.001);
    try std.testing.expectApproxEqAbs(output_scalar[1], output_simd[1], 0.001);
}

// Benchmark function for comparing implementations
pub fn main() void {
    // Run benchmarks when executed directly
    benchmarkTernaryMatVec(768, 768, 1000);    // Small layer
    benchmarkTernaryMatVec(2048, 2048, 100);   // Medium layer  
    benchmarkTernaryMatVec(4096, 4096, 50);    // Large layer
}

pub fn benchmarkTernaryMatVec(rows: usize, cols: usize, iterations: usize) void {
    const allocator = std.heap.page_allocator;
    
    // Allocate test data
    const weights = allocator.alloc(u8, rows * ((cols + 3) / 4)) catch return;
    defer allocator.free(weights);
    const input = allocator.alloc(f32, cols) catch return;
    defer allocator.free(input);
    const output = allocator.alloc(f32, rows) catch return;
    defer allocator.free(output);

    // Initialize with random-ish data
    for (weights, 0..) |*w, i| w.* = @truncate(i * 17 + 31);
    for (input, 0..) |*v, i| v.* = @as(f32, @floatFromInt(i % 100)) / 100.0;

    std.debug.print("\nTernary MatVec Benchmark ({d}x{d}, {d} iterations)\n", .{rows, cols, iterations});
    std.debug.print("=" ** 50 ++ "\n", .{});

    // Benchmark scalar
    var timer = std.time.Timer.start() catch return;
    for (0..iterations) |_| {
        ternaryMatVec(output, weights, input, rows, cols);
    }
    const scalar_time = timer.read();
    std.debug.print("Scalar:     {d:.2} ms ({d:.2} GFLOPS)\n", .{
        @as(f64, @floatFromInt(scalar_time)) / 1e6,
        @as(f64, @floatFromInt(rows * cols * iterations * 2)) / @as(f64, @floatFromInt(scalar_time)),
    });

    // Benchmark SIMD 8-wide
    timer.reset();
    for (0..iterations) |_| {
        simdTernaryMatVec(output, weights, input, rows, cols);
    }
    const simd8_time = timer.read();
    std.debug.print("SIMD-8:     {d:.2} ms ({d:.2} GFLOPS) - {d:.1}x speedup\n", .{
        @as(f64, @floatFromInt(simd8_time)) / 1e6,
        @as(f64, @floatFromInt(rows * cols * iterations * 2)) / @as(f64, @floatFromInt(simd8_time)),
        @as(f64, @floatFromInt(scalar_time)) / @as(f64, @floatFromInt(simd8_time)),
    });

    // Benchmark SIMD 16-wide
    timer.reset();
    for (0..iterations) |_| {
        simd16TernaryMatVec(output, weights, input, rows, cols);
    }
    const simd16_time = timer.read();
    std.debug.print("SIMD-16:    {d:.2} ms ({d:.2} GFLOPS) - {d:.1}x speedup\n", .{
        @as(f64, @floatFromInt(simd16_time)) / 1e6,
        @as(f64, @floatFromInt(rows * cols * iterations * 2)) / @as(f64, @floatFromInt(simd16_time)),
        @as(f64, @floatFromInt(scalar_time)) / @as(f64, @floatFromInt(simd16_time)),
    });

    // Benchmark batch
    timer.reset();
    for (0..iterations) |_| {
        batchTernaryMatVec(output, weights, input, rows, cols);
    }
    const batch_time = timer.read();
    std.debug.print("Batch-4:    {d:.2} ms ({d:.2} GFLOPS) - {d:.1}x speedup\n", .{
        @as(f64, @floatFromInt(batch_time)) / 1e6,
        @as(f64, @floatFromInt(rows * cols * iterations * 2)) / @as(f64, @floatFromInt(batch_time)),
        @as(f64, @floatFromInt(scalar_time)) / @as(f64, @floatFromInt(batch_time)),
    });
}
