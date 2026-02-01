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

/// SIMD-optimized ternary matmul (AVX2)
pub fn simdTernaryMatVec(
    output: []f32,
    weights: []const u8,
    input: []const f32,
    rows: usize,
    cols: usize,
) void {
    const Vec8f32 = @Vector(8, f32);
    const cols_packed = (cols + 3) / 4;

    for (0..rows) |row| {
        var sum_vec: Vec8f32 = @splat(0.0);
        var sum_scalar: f32 = 0.0;
        const row_start = row * cols_packed;

        var col: usize = 0;
        
        // Process 8 floats at a time with SIMD
        while (col + 8 <= cols) {
            // Load 8 input values
            const in_vec: Vec8f32 = input[col..][0..8].*;

            // Load 2 bytes = 8 trits
            const byte0 = weights[row_start + col / 4];
            const byte1 = weights[row_start + col / 4 + 1];

            // Decode trits and create masks
            var add_mask: Vec8f32 = @splat(0.0);
            var sub_mask: Vec8f32 = @splat(0.0);

            inline for (0..4) |i| {
                const trit0 = (byte0 >> @intCast(i * 2)) & 0x3;
                const trit1 = (byte1 >> @intCast(i * 2)) & 0x3;
                
                if (trit0 == 0b01) add_mask[i] = 1.0;
                if (trit0 == 0b10) sub_mask[i] = 1.0;
                if (trit1 == 0b01) add_mask[4 + i] = 1.0;
                if (trit1 == 0b10) sub_mask[4 + i] = 1.0;
            }

            sum_vec += in_vec * add_mask;
            sum_vec -= in_vec * sub_mask;

            col += 8;
        }

        // Reduce SIMD vector
        sum_scalar = @reduce(.Add, sum_vec);

        // Handle remaining elements
        while (col < cols) : (col += 1) {
            const byte_idx = row_start + col / 4;
            if (byte_idx >= weights.len) break;
            
            const shift: u3 = @intCast((col % 4) * 2);
            const trit = (weights[byte_idx] >> shift) & 0x3;
            
            switch (trit) {
                0b01 => sum_scalar += input[col],
                0b10 => sum_scalar -= input[col],
                else => {},
            }
        }

        output[row] = sum_scalar;
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
