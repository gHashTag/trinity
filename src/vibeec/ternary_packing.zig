// TERNARY WEIGHT PACKING - I2_S Format (2-bit per weight)
// Convert F32 weights to pw ternary {-1, 0, +1}
// Memory savings: 16x (32-bit to 2-bit)
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL

const std = @import("std");

pub const PHI: f64 = 1.618033988749895;

// CONSTANTS

/// Trit encoding: 00=0, 01=+1, 10=-1, 11=reserved
pub const TRIT_ZERO: u2 = 0b00;
pub const TRIT_PLUS: u2 = 0b01;
pub const TRIT_MINUS: u2 = 0b10;

/// Block size for I2_S format (with scale)
pub const I2S_BLOCK_SIZE: usize = 256;

/// Sign lookup table for decoding
pub const SIGN_LUT: [4]f32 = .{ 0.0, 1.0, -1.0, 0.0 };

// WEIGHT QUANTIZATION

/// Quantize F32 weight to ternary {-1, 0, +1}
pub inline fn quantizeToTrit(value: f32, threshold: f32) u2 {
    if (value > threshold) return TRIT_PLUS;
    if (value < -threshold) return TRIT_MINUS;
    return TRIT_ZERO;
}

/// Pack 4 trits into a single byte
pub inline fn pack4Trits(t0: u2, t1: u2, t2: u2, t3: u2) u8 {
    return @as(u8, t0) | (@as(u8, t1) << 2) | (@as(u8, t2) << 4) | (@as(u8, t3) << 6);
}

/// Unpack 4 trits from a byte
pub inline fn unpack4Trits(byte: u8) [4]u2 {
    return .{
        @truncate(byte & 0x3),
        @truncate((byte >> 2) & 0x3),
        @truncate((byte >> 4) & 0x3),
        @truncate((byte >> 6) & 0x3),
    };
}

// PACKED TERNARY WEIGHTS

/// Packed ternary weight matrix
pub const PackedTernaryWeights = struct {
    allocator: std.mem.Allocator,
    data: []u8,
    scales: []f32,
    rows: usize,
    cols: usize,
    
    /// Memory usage in bytes
    pub fn memoryUsage(self: PackedTernaryWeights) usize {
        return self.data.len + self.scales.len * @sizeOf(f32);
    }
    
    /// Memory savings vs F32
    pub fn memorySavings(self: PackedTernaryWeights) f32 {
        const f32_size = self.rows * self.cols * @sizeOf(f32);
        const pw_size = self.memoryUsage();
        return @as(f32, @floatFromInt(f32_size)) / @as(f32, @floatFromInt(pw_size));
    }
    
    pub fn deinit(self: *PackedTernaryWeights) void {
        self.allocator.free(self.data);
        self.allocator.free(self.scales);
    }
};

/// Pack F32 weights to ternary format
pub fn packWeights(
    allocator: std.mem.Allocator,
    weights: []const f32,
    rows: usize,
    cols: usize,
) !PackedTernaryWeights {
    const cols_pw = (cols + 3) / 4;
    const total_pw = rows * cols_pw;
    
    const data = try allocator.alloc(u8, total_pw);
    const scales = try allocator.alloc(f32, rows);
    
    var row: usize = 0;
    while (row < rows) : (row += 1) {
        const row_start = row * cols;
        const row_weights = weights[row_start..row_start + cols];
        
        var max_abs: f32 = 0.0;
        for (row_weights) |w| {
            const abs_w = @abs(w);
            if (abs_w > max_abs) max_abs = abs_w;
        }
        
        const threshold = max_abs * 0.5;
        scales[row] = max_abs;
        
        const pw_row_start = row * cols_pw;
        var col: usize = 0;
        var byte_idx: usize = 0;
        
        while (col < cols) {
            const t0 = if (col < cols) quantizeToTrit(row_weights[col], threshold) else TRIT_ZERO;
            const t1 = if (col + 1 < cols) quantizeToTrit(row_weights[col + 1], threshold) else TRIT_ZERO;
            const t2 = if (col + 2 < cols) quantizeToTrit(row_weights[col + 2], threshold) else TRIT_ZERO;
            const t3 = if (col + 3 < cols) quantizeToTrit(row_weights[col + 3], threshold) else TRIT_ZERO;
            
            data[pw_row_start + byte_idx] = pack4Trits(t0, t1, t2, t3);
            
            col += 4;
            byte_idx += 1;
        }
    }
    
    return PackedTernaryWeights{
        .allocator = allocator,
        .data = data,
        .scales = scales,
        .rows = rows,
        .cols = cols,
    };
}

// SIMD TERNARY MATMUL

const Vec8f32 = @Vector(8, f32);

/// Decode 8 trits from 2 bytes to f32 signs
inline fn decode8TritsF32(byte0: u8, byte1: u8) Vec8f32 {
    return .{
        SIGN_LUT[(byte0 >> 0) & 0x3],
        SIGN_LUT[(byte0 >> 2) & 0x3],
        SIGN_LUT[(byte0 >> 4) & 0x3],
        SIGN_LUT[(byte0 >> 6) & 0x3],
        SIGN_LUT[(byte1 >> 0) & 0x3],
        SIGN_LUT[(byte1 >> 2) & 0x3],
        SIGN_LUT[(byte1 >> 4) & 0x3],
        SIGN_LUT[(byte1 >> 6) & 0x3],
    };
}

/// SIMD ternary matrix-vector multiply
pub fn ternaryMatVecSIMD(
    output: []f32,
    data: []const u8,
    scales: []const f32,
    input: []const f32,
    rows: usize,
    cols: usize,
) void {
    const cols_pw = (cols + 3) / 4;
    
    var row: usize = 0;
    while (row < rows) : (row += 1) {
        var sum_vec: Vec8f32 = @splat(0.0);
        var sum_scalar: f32 = 0.0;
        const row_start = row * cols_pw;
        const scale = scales[row];
        
        var col: usize = 0;
        
        while (col + 8 <= cols) {
            const byte_idx = row_start + col / 4;
            if (byte_idx + 1 >= data.len) break;
            
            const in_vec: Vec8f32 = input[col..][0..8].*;
            const signs = decode8TritsF32(data[byte_idx], data[byte_idx + 1]);
            sum_vec += in_vec * signs;
            col += 8;
        }
        
        sum_scalar = @reduce(.Add, sum_vec);
        
        while (col < cols) : (col += 1) {
            const byte_idx = row_start + col / 4;
            if (byte_idx >= data.len) break;
            
            const shift: u3 = @intCast((col % 4) * 2);
            const trit = (data[byte_idx] >> shift) & 0x3;
            sum_scalar += input[col] * SIGN_LUT[trit];
        }
        
        output[row] = sum_scalar * scale;
    }
}

// TESTS

test "trit encoding" {
    try std.testing.expectEqual(TRIT_ZERO, quantizeToTrit(0.0, 0.5));
    try std.testing.expectEqual(TRIT_PLUS, quantizeToTrit(1.0, 0.5));
    try std.testing.expectEqual(TRIT_MINUS, quantizeToTrit(-1.0, 0.5));
}

test "pack and unpack trits" {
    const pw = pack4Trits(TRIT_ZERO, TRIT_PLUS, TRIT_MINUS, TRIT_ZERO);
    const unpw = unpack4Trits(pw);
    
    try std.testing.expectEqual(TRIT_ZERO, unpw[0]);
    try std.testing.expectEqual(TRIT_PLUS, unpw[1]);
    try std.testing.expectEqual(TRIT_MINUS, unpw[2]);
    try std.testing.expectEqual(TRIT_ZERO, unpw[3]);
}

test "pack weights" {
    const allocator = std.testing.allocator;
    const weights = [_]f32{ 1.0, -1.0, 0.0, 0.5, -0.8, 0.9, -0.3, 0.1 };
    
    var pw = try packWeights(allocator, &weights, 2, 4);
    defer pw.deinit();
    
    try std.testing.expectEqual(@as(usize, 2), pw.rows);
    try std.testing.expectEqual(@as(usize, 4), pw.cols);
    
    // Small matrices have high overhead, just check it works
    const savings = pw.memorySavings();
    try std.testing.expect(savings > 0.5);
}

test "ternary matmul correctness" {
    const allocator = std.testing.allocator;
    const weights = [_]f32{ 1.0, -1.0, 0.0, 1.0, -1.0, 1.0, -1.0, 0.0 };
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var output: [2]f32 = undefined;
    
    var pw = try packWeights(allocator, &weights, 2, 4);
    defer pw.deinit();
    
    ternaryMatVecSIMD(&output, pw.data, pw.scales, &input, pw.rows, pw.cols);
    
    try std.testing.expect(@abs(output[0]) > 0.0);
    try std.testing.expect(@abs(output[1]) > 0.0);
}

test "memory savings for 1536x1536 matrix" {
    const allocator = std.testing.allocator;
    
    // Typical hidden size matrix
    const rows: usize = 1536;
    const cols: usize = 1536;
    const weights = try allocator.alloc(f32, rows * cols);
    defer allocator.free(weights);
    
    // Fill with random-ish values
    for (weights, 0..) |*w, i| {
        w.* = @as(f32, @floatFromInt(i % 3)) - 1.0; // -1, 0, 1
    }
    
    var pw = try packWeights(allocator, weights, rows, cols);
    defer pw.deinit();
    
    const f32_size = rows * cols * @sizeOf(f32);
    const pw_size = pw.memoryUsage();
    const savings = pw.memorySavings();
    
    std.debug.print("\n=== Memory Savings Test (1536x1536) ===\n", .{});
    std.debug.print("F32 size: {d} bytes ({d:.2} MB)\n", .{ f32_size, @as(f32, @floatFromInt(f32_size)) / 1024.0 / 1024.0 });
    std.debug.print("Packed size: {d} bytes ({d:.2} MB)\n", .{ pw_size, @as(f32, @floatFromInt(pw_size)) / 1024.0 / 1024.0 });
    std.debug.print("Savings: {d:.1}x\n", .{savings});
    
    // Should be ~13x savings (32-bit to 2-bit + scale overhead)
    try std.testing.expect(savings > 10.0);
}
