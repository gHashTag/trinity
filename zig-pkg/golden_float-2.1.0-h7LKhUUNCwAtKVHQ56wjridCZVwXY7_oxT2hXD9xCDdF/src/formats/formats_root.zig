//! Format Conversion Utilities for Trinity Benchmarks
//!
//! GF16 bit layout (as specified in whitepaper, identical to DLFloat 6:9):
//!   [S(1) E(6) M(9)] = [15:15][14:9][8:0]
//!
//! - Sign: bit 15 (0x8000)
//! - Exponent: bits 14-9 (0x7E00), bias = 31
//! - Mantissa: bits 8-0 (0x01FF)
//!
//! Range: 2^-31 to 2^32

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════
// GF16 Constants
// ═══════════════════════════════════════════════════════════════════

pub const SignMask: u16 = 0b1_000000_000000000; // 0x8000
pub const ExpMask: u16 = 0b0_111111_000000000; // 0x7E00
pub const MantMask: u16 = 0b0_000000_111111111; // 0x01FF

pub const ExpShift: u5 = 9;
pub const SignShift: u4 = 15;
pub const Bias: i32 = 31;

pub const ExpMax: u16 = 0b111111; // 63
pub const ExpMin: u16 = 0;

// ═══════════════════════════════════════════════════════════════════
// GF16 → f32 (decode)
// ═══════════════════════════════════════════════════════════════════

pub fn gf16ToF32(x: u16) f32 {
    const s = @as(i32, (x >> SignShift) & 1);
    const e = @as(i32, (x & ExpMask) >> ExpShift);
    const m = @as(i32, x & MantMask);

    if (e == 0 and m == 0) {
        // Signed zero
        return if (s == 0) 0.0 else -0.0;
    } else if (e == 0) {
        // Denormals: treat as subnormal
        const exp = 1 - Bias;
        const frac = @as(f32, @floatFromInt(m)) / 512.0; // 2^9
        const val = std.math.exp2(@as(f32, @floatFromInt(exp))) * frac;
        return if (s == 0) val else -val;
    } else if (e == ExpMax) {
        // Special values (Inf/NaN)
        if (m == 0) {
            return if (s == 0) std.math.inf(f32) else -std.math.inf(f32);
        } else {
            return std.math.nan(f32);
        }
    } else {
        // Normal: value = (-1)^s * (1 + m/2^9) * 2^(e - Bias)
        const exp = e - Bias;
        const frac = 1.0 + @as(f32, @floatFromInt(m)) / 512.0;
        const val = frac * std.math.exp2(@as(f32, @floatFromInt(exp)));
        return if (s == 0) val else -val;
    }
}

// ═══════════════════════════════════════════════════════════════════
// f32 → GF16 (encode, round-to-nearest)
// ═══════════════════════════════════════════════════════════════════

pub fn f32ToGf16(a: f32) u16 {
    // Handle signed zero explicitly
    if (a == 0.0) {
        return if (@as(u32, @bitCast(a)) & 0x80000000 != 0) 0x8000 else 0;
    }

    const sign_bit: u16 = if (a < 0) 1 << SignShift else 0;
    const abs = if (a < 0) -a else a;

    // Handle special cases
    if (std.math.isPositiveInf(abs)) return sign_bit | ExpMask;
    if (std.math.isNan(abs)) return sign_bit | ExpMask | 1;

    // Get exponent and mantissa via frexp: abs = m * 2^e, m in [0.5, 1)
    // Zig 0.15: frexp returns struct { fract: f32, exp: i32 }
    const frexp_result = std.math.frexp(abs);
    var m = frexp_result.significand;
    var exp_i = frexp_result.exponent;

    // Normalize: want 1.x * 2^(E - Bias), frexp gives m in [0.5, 1)
    m *= 2.0;
    exp_i -= 1;

    var e = exp_i + Bias;
    if (e <= 0) {
        // Underflow → zero
        return sign_bit;
    } else if (e >= ExpMax) {
        // Overflow → INF
        return sign_bit | ExpMask;
    }

    // Mantissa: (m - 1.0) * 2^9, round to nearest
    const mant_f = (m - 1.0) * 512.0;
    var mant_i = @as(i32, @intFromFloat(std.math.round(mant_f)));

    // Handle mantissa overflow
    if (mant_i == 512) { // 2^9
        mant_i = 0;
        e += 1;
        if (e >= ExpMax) {
            return sign_bit | ExpMask;
        }
    }

    const e_bits: u16 = @as(u16, @intCast(e)) << ExpShift;
    const m_bits: u16 = @as(u16, @intCast(mant_i)) & MantMask;

    return sign_bit | e_bits | m_bits;
}

// ═══════════════════════════════════════════════════════════════════
// Software fp16 encode/decode (IEEE 754 binary16)
fn f32ToFp16(a: f32) u16 {
    if (std.math.isNan(a)) return 0x7E00;
    const bits: u32 = @bitCast(a);
    const sign: u16 = @intCast((bits >> 16) & 0x8000);
    const abs_bits = bits & 0x7FFFFFFF;

    if (abs_bits == 0) return sign;
    if (std.math.isInf(a)) return sign | 0x7C00;

    const f32_exp = @as(i32, @intCast((abs_bits >> 23) & 0xFF)) - 127;
    const f32_mant = abs_bits & 0x7FFFFF;

    if (f32_exp > 15) return sign | 0x7C00;

    if (f32_exp >= -14) {
        const fp16_mant = @as(u16, @intCast(f32_mant >> 13));
        const fp16_exp = @as(u16, @intCast(f32_exp + 15)) << 10;
        return sign | fp16_exp | fp16_mant;
    }

    const shift = @as(u5, @intCast(@as(i32, 13) - f32_exp - 14 + 1));
    if (shift >= 32) return sign;
    const fp16_mant = @as(u16, @intCast(f32_mant >> shift));
    if (fp16_mant == 0) return sign;
    return sign | fp16_mant;
}

fn fp16ToF32(x: u16) f32 {
    const sign: u32 = @as(u32, x & 0x8000) << 16;
    const e = (x >> 10) & 0x1F;
    const m = x & 0x03FF;

    if (e == 0) {
        if (m == 0) return @bitCast(sign);
        var mant = @as(u32, m) << 13;
        var shifts: u32 = 0;
        while ((mant & 0x00800000) == 0) : (shifts += 1) {
            mant <<= 1;
        }
        const biased_exp: u32 = 113 - shifts;
        const f32_bits = sign | (biased_exp << 23) | (mant & 0x7FFFFF);
        return @bitCast(f32_bits);
    }
    if (e == 0x1F) {
        if (m == 0) return @bitCast(sign | 0x7F800000);
        return @bitCast(sign | 0x7FC00000);
    }

    const f32_bits = sign | ((@as(u32, e) + 112) << 23) | (@as(u32, m) << 13);
    return @bitCast(f32_bits);
}

// Software bf16 encode/decode (Brain Float 16) — IEEE 754 canonical
fn f32ToBf16(a: f32) u16 {
    if (std.math.isNan(a)) return 0x7FC0;
    const bits: u32 = @bitCast(a);
    const rounding: u32 = ((bits >> 16) & 1) + 0x7FFF;
    return @intCast((bits +| rounding) >> 16);
}

fn bf16ToF32(x: u16) f32 {
    return @bitCast(@as(u32, x) << 16);
}

// ═══════════════════════════════════════════════════════════════════
// Ternary Format: {-1, 0, +1} Symmetric
// ═══════════════════════════════════════════════════════════════════

/// Symmetric quantization: w -> {-1, 0, +1}
/// Threshold: |w| > 0.5 -> +/-1, else -> 0
pub fn f32ToTernary(x: f32) i8 {
    if (x > 0.5) return 1;
    if (x < -0.5) return -1;
    return 0;
}

pub fn ternaryToF32(t: i8) f32 {
    return @as(f32, @floatFromInt(t));
}

// ═══════════════════════════════════════════════════════════════════
// Format Enum and Conversion Interface
// ═══════════════════════════════════════════════════════════════════

pub const Format = enum {
    fp32,
    fp16,
    bf16,
    gf16,
    ternary,
};

pub fn formatBytes(fmt: Format) usize {
    return switch (fmt) {
        .fp32 => 4,
        .fp16 => 2,
        .bf16 => 2,
        .gf16 => 2,
        .ternary => 1,
    };
}

/// Quantize single f32 value to target format (returns f32 for convenience)
pub fn quantizeValue(x: f32, fmt: Format) f32 {
    return switch (fmt) {
        .fp32 => x,
        .fp16 => fp16ToF32(f32ToFp16(x)),
        .bf16 => bf16ToF32(f32ToBf16(x)),
        .gf16 => gf16ToF32(f32ToGf16(x)),
        .ternary => ternaryToF32(f32ToTernary(x)),
    };
}

// ═════════════════════════════════════════════════════════════════════
// CNN Operations (2D Convolution + Max Pooling)
// ═════════════════════════════════════════════════════════════════════════════

/// 2D convolution: output[y,x,c] = sum over kernel weights
///
/// Parameters:
///   - input: flattened input [H_in * W_in * C_in] (channel-major layout)
///   - weights: filter weights [C_out * C_in * K_h * K_w]
///   - bias: per-channel bias [C_out]
///   - output: pre-allocated output buffer [H_out * W_out * C_out]
///   - config: layer dimensions and kernel parameters
///
/// Supports valid padding (padding = kernel_size / 2)
pub fn conv2d(
    input: []const f32,
    weights: []const f32,
    bias: []const f32,
    output: []f32,
    config: struct {
        in_channels: u32,
        out_channels: u32,
        in_height: u32,
        in_width: u32,
        kernel_size: u32,
        stride: u32,
        padding: u32,
    },
) void {
    const k = config.kernel_size;
    const p = config.padding;
    const s = config.stride;

    // Output dimensions with valid padding
    const out_h = (config.in_height + 2 * p - k) / s + 1;
    const out_w = (config.in_width + 2 * p - k) / s + 1;

    const in_area = config.in_height * config.in_width;

    // For each output channel
    for (0..config.out_channels) |oc| {
        const bias_val = bias[oc];
        const out_offset = oc * out_h * out_w;

        // For each output position
        for (0..out_h) |oy| {
            for (0..out_w) |ox| {
                var sum: f32 = bias_val;

                // For each input channel
                for (0..config.in_channels) |ic| {
                    // For each kernel position
                    for (0..k) |ky| {
                        for (0..k) |kx| {
                            // Input position
                            const in_y = oy * s + ky - p;
                            const in_x = ox * s + kx - p;

                            if (in_y >= 0 and in_y < config.in_height and
                                in_x >= 0 and in_x < config.in_width)
                            {
                                const in_idx = ic * in_area + in_y * config.in_width + in_x;
                                sum += input[in_idx] * weights[oc * config.in_channels * k * k + ic * k * k + ky * k + kx];
                            }
                        }
                    }
                }

                output[out_offset + oy * out_w + ox] = sum;
            }
        }
    }
}

/// 2D max pooling: output[y,x,c] = max over kernel window
///
/// Parameters:
///   - input: [H_in * W_in * C_in]
///   - output: pre-allocated output buffer [H_out * W_out * C_in]
///   - config: input dimensions and pooling parameters
pub fn maxPool2d(
    input: []const f32,
    output: []f32,
    config: struct {
        height: u32,
        width: u32,
        channels: u32,
        kernel_size: u32,
        stride: u32,
    },
) void {
    const k = config.kernel_size;
    const s = config.stride;

    const out_h = config.height / s;
    const out_w = config.width / s;
    const in_area = config.height * config.width;

    // For each channel
    for (0..config.channels) |c| {
        const out_offset = c * out_h * out_w;

        // For each output position
        for (0..out_h) |oy| {
            for (0..out_w) |ox| {
                // Find max in kernel window
                var max_val: f32 = -std.math.inf(f32);
                for (0..k) |ky| {
                    const in_y = oy * s + ky;
                    if (in_y < config.height) {
                        for (0..k) |kx| {
                            const in_x = ox * s + kx;
                            if (in_x < config.width) {
                                const in_idx = c * in_area + in_y * config.width + in_x;
                                max_val = @max(max_val, input[in_idx]);
                            }
                        }
                    }
                }

                output[out_offset + oy * out_w + ox] = max_val;
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// Trained MLP Weights Loader
// ═══════════════════════════════════════════════════════════════════

/// Trained MLP weights loaded from binary file
pub const MlpWeights = struct {
    input_dim: u32,
    hidden_dim: u32,
    output_dim: u32,

    W1: []f32, // hidden_dim * input_dim, row-major
    b1: []f32, // hidden_dim
    W2: []f32, // output_dim * hidden_dim, row-major
    b2: []f32, // output_dim

    allocator: std.mem.Allocator,

    /// Free all allocated arrays
    pub fn deinit(self: *const MlpWeights) void {
        self.allocator.free(self.W1);
        self.allocator.free(self.b1);
        self.allocator.free(self.W2);
        self.allocator.free(self.b2);
    }
};

/// Error set for weight loading
pub const LoadWeightsError = error{
    BadMagic,
    UnsupportedVersion,
    DimensionMismatch,
    InvalidFileSize,
};

/// Load trained MLP weights from binary file
///
/// File format (little-endian):
/// - Header (20 bytes):
///   - u32 magic = 0x4D4E4953 ("MNIS")
///   - u32 version = 1
///   - u32 input_dim
///   - u32 hidden_dim
///   - u32 output_dim
/// - Data (all f32, little-endian):
///   - W1: hidden_dim * input_dim values (row-major)
///   - b1: hidden_dim values
///   - W2: output_dim * hidden_dim values (row-major)
///   - b2: output_dim values
pub fn loadMlpWeights(
    allocator: std.mem.Allocator,
    path: []const u8,
) !MlpWeights {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    if (file_size < 20) return error.InvalidFileSize;

    // Read header (20 bytes)
    var header: [20]u8 = undefined;
    _ = try file.readAll(&header);
    const magic = std.mem.readInt(u32, header[0..4], .little);
    if (magic != 0x4D4E4953) return LoadWeightsError.BadMagic;

    const version = std.mem.readInt(u32, header[4..8], .little);
    if (version != 1) return LoadWeightsError.UnsupportedVersion;

    const input_dim = std.mem.readInt(u32, header[8..12], .little);
    const hidden_dim = std.mem.readInt(u32, header[12..16], .little);
    const output_dim = std.mem.readInt(u32, header[16..20], .little);

    // Calculate sizes
    const w1_len = @as(usize, hidden_dim) * @as(usize, input_dim);
    const b1_len = @as(usize, hidden_dim);
    const w2_len = @as(usize, output_dim) * @as(usize, hidden_dim);
    const b2_len = @as(usize, output_dim);

    // Verify file size matches expected
    const expected_size = 20 + (w1_len + b1_len + w2_len + b2_len) * 4;
    if (file_size != expected_size) return error.InvalidFileSize;

    // Allocate arrays
    const W1 = try allocator.alloc(f32, w1_len);
    errdefer allocator.free(W1);
    const b1 = try allocator.alloc(f32, b1_len);
    errdefer allocator.free(b1);
    const W2 = try allocator.alloc(f32, w2_len);
    errdefer allocator.free(W2);
    const b2 = try allocator.alloc(f32, b2_len);
    errdefer allocator.free(b2);

    // Read tensor data directly into arrays
    var data_offset: usize = 20;
    {
        const w1_bytes = std.mem.sliceAsBytes(W1);
        const n = try file.read(w1_bytes);
        if (n != w1_len * 4) return error.InvalidFileSize;
        data_offset += n;
    }
    {
        const b1_bytes = std.mem.sliceAsBytes(b1);
        const n = try file.read(b1_bytes);
        if (n != b1_len * 4) return error.InvalidFileSize;
        data_offset += n;
    }
    {
        const w2_bytes = std.mem.sliceAsBytes(W2);
        const n = try file.read(w2_bytes);
        if (n != w2_len * 4) return error.InvalidFileSize;
        data_offset += n;
    }
    {
        const b2_bytes = std.mem.sliceAsBytes(b2);
        _ = try file.readAll(b2_bytes);
    }

    return MlpWeights{
        .input_dim = input_dim,
        .hidden_dim = hidden_dim,
        .output_dim = output_dim,
        .W1 = W1,
        .b1 = b1,
        .W2 = W2,
        .b2 = b2,
        .allocator = allocator,
    };
}

// ═══════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════

test "GF16: zero" {
    try std.testing.expectEqual(@as(u16, 0), f32ToGf16(0.0));
    try std.testing.expectEqual(@as(u16, 0x8000), f32ToGf16(-0.0));
}

test "GF16: roundtrip zero" {
    try std.testing.expectEqual(@as(f32, 0.0), gf16ToF32(f32ToGf16(0.0)));
}

test "GF16: infinity" {
    try std.testing.expectEqual(@as(u16, 0x7E00), f32ToGf16(std.math.inf(f32)));
    try std.testing.expectEqual(@as(u16, 0xFE00), f32ToGf16(-std.math.inf(f32)));
}

test "GF16: roundtrip small values" {
    const values = [_]f32{ 1.0, -1.0, 0.5, -0.5, 2.0, -2.0, 0.1, -0.1, 1.5, -1.5 };
    for (values) |v| {
        const gf16 = f32ToGf16(v);
        const recovered = gf16ToF32(gf16);
        // Allow some error due to quantization
        const err = @abs(recovered - v);
        try std.testing.expect(err < 0.01);
    }
}

test "GF16: bit masks correct" {
    try std.testing.expectEqual(@as(u16, 0x8000), SignMask);
    try std.testing.expectEqual(@as(u16, 0x7E00), ExpMask);
    try std.testing.expectEqual(@as(u16, 0x01FF), MantMask);
}

test "GF16: encode preserves sign" {
    try std.testing.expect(f32ToGf16(1.0) & 0x8000 == 0);
    try std.testing.expect(f32ToGf16(-1.0) & 0x8000 != 0);
}

test "Ternary: quantization" {
    try std.testing.expectEqual(@as(i8, 1), f32ToTernary(1.0));
    try std.testing.expectEqual(@as(i8, -1), f32ToTernary(-1.0));
    try std.testing.expectEqual(@as(i8, 0), f32ToTernary(0.3));
    try std.testing.expectEqual(@as(i8, 0), f32ToTernary(-0.3));
    try std.testing.expectEqual(@as(i8, 1), f32ToTernary(0.6));
}

test "formatBytes" {
    try std.testing.expectEqual(@as(usize, 4), formatBytes(.fp32));
    try std.testing.expectEqual(@as(usize, 2), formatBytes(.gf16));
    try std.testing.expectEqual(@as(usize, 1), formatBytes(.ternary));
}

test "BF16: roundtrip 1.0" {
    const bf16 = f32ToBf16(1.0);
    try std.testing.expectEqual(@as(u16, 0x3F80), bf16);
    const back = bf16ToF32(bf16);
    try std.testing.expectEqual(@as(f32, 1.0), back);
}

test "BF16: roundtrip 100.0" {
    const bf16 = f32ToBf16(100.0);
    const back = bf16ToF32(bf16);
    const err = @abs(back - 100.0);
    try std.testing.expect(err < 1.0);
}

test "BF16: roundtrip 1e10" {
    const bf16 = f32ToBf16(1e10);
    const back = bf16ToF32(bf16);
    const err = @abs(back - 1e10) / 1e10;
    try std.testing.expect(err < 0.01);
}

test "BF16: roundtrip small values" {
    const values = [_]f32{ 0.5, -0.5, 2.0, -2.0, 3.14, -3.14, 1e-10, -1e-10 };
    for (values) |v| {
        const bf16 = f32ToBf16(v);
        const back = bf16ToF32(bf16);
        const err = if (@abs(v) > 0.001) @abs(back - v) / @abs(v) else @abs(back - v);
        try std.testing.expect(err < 0.01);
    }
}

test "FP16: roundtrip basic values" {
    const values = [_]f32{ 1.0, -1.0, 0.5, -0.5, 2.0, -2.0, 0.1, 0.25, 1.5 };
    for (values) |v| {
        const fp16 = f32ToFp16(v);
        const recovered = fp16ToF32(fp16);
        const err = @abs(recovered - v) / @max(@abs(v), 1e-30);
        try std.testing.expect(err < 0.005);
    }
}

test "FP16: special values" {
    try std.testing.expectEqual(@as(u16, 0x0000), f32ToFp16(0.0));
    try std.testing.expectEqual(@as(u16, 0x8000), f32ToFp16(-0.0));
    try std.testing.expectEqual(@as(u16, 0x7C00), f32ToFp16(std.math.inf(f32)));
    try std.testing.expectEqual(@as(u16, 0xFC00), f32ToFp16(-std.math.inf(f32)));
    const nan_enc = f32ToFp16(std.math.nan(f32));
    try std.testing.expect(std.math.isNan(fp16ToF32(nan_enc)));
}

test "FP16: large values (full IEEE exponent)" {
    const fp16 = f32ToFp16(100.0);
    const back = fp16ToF32(fp16);
    try std.testing.expect(@abs(back - 100.0) < 1.0);

    const fp16_big = f32ToFp16(65000.0);
    const back_big = fp16ToF32(fp16_big);
    try std.testing.expect(back_big > 60000.0);
    try std.testing.expect(back_big < 65536.0);
}

test "FP16: overflow to infinity" {
    const fp16 = f32ToFp16(1e10);
    try std.testing.expectEqual(@as(u16, 0x7C00), fp16);
    try std.testing.expect(std.math.isInf(fp16ToF32(fp16)));
}

test "FP16: roundtrip 1.0 exact" {
    const fp16 = f32ToFp16(1.0);
    try std.testing.expectEqual(@as(u16, 0x3C00), fp16);
    try std.testing.expectEqual(@as(f32, 1.0), fp16ToF32(fp16));
}

test "FP16: denormal roundtrip" {
    const small = fp16ToF32(@as(u16, 0x0001));
    try std.testing.expect(small > 0.0);
    try std.testing.expect(small < 0.001);
}

test "BF16: special values" {
    try std.testing.expectEqual(@as(u16, 0x3F80), f32ToBf16(1.0));
    try std.testing.expect(bf16ToF32(f32ToBf16(std.math.inf(f32))) > 1e30);
    try std.testing.expect(std.math.isNan(bf16ToF32(f32ToBf16(std.math.nan(f32)))));
    try std.testing.expectEqual(@as(u16, 0), f32ToBf16(0.0));
    try std.testing.expectEqual(@as(u16, 0x8000), f32ToBf16(-0.0));
    try std.testing.expectEqual(@as(u16, 0x7F80), f32ToBf16(std.math.inf(f32)));
    try std.testing.expectEqual(@as(u16, 0xFF80), f32ToBf16(-std.math.inf(f32)));
}

test "BF16: large values do not flush" {
    const bf16_1e10 = f32ToBf16(1e10);
    const back_1e10 = bf16ToF32(bf16_1e10);
    try std.testing.expect(back_1e10 > 5e9);
    try std.testing.expect(back_1e10 < 2e10);

    const bf16_1e_10 = f32ToBf16(1e-10);
    const back_1e_10 = bf16ToF32(bf16_1e_10);
    try std.testing.expect(back_1e_10 > 5e-11);
    try std.testing.expect(back_1e_10 < 2e-9);
}

test "BF16: quantizeValue roundtrip all formats" {
    const test_val: f32 = 42.0;
    const gf16_round = quantizeValue(test_val, .gf16);
    const bf16_round = quantizeValue(test_val, .bf16);
    const fp16_round = quantizeValue(test_val, .fp16);
    try std.testing.expect(@abs(gf16_round - test_val) / test_val < 0.05);
    try std.testing.expect(@abs(bf16_round - test_val) / test_val < 0.05);
    try std.testing.expect(@abs(fp16_round - test_val) / test_val < 0.05);
}

test "FP16: subnormal decode mantissa=1" {
    const bits: u16 = 0x0001;
    const val = fp16ToF32(bits);
    const expected: f32 = 5.960464e-8;
    try std.testing.expectApproxEqAbs(expected, val, 1e-14);
}

test "FP16: subnormal decode mantissa=2" {
    const bits: u16 = 0x0002;
    const val = fp16ToF32(bits);
    const expected: f32 = 1.192093e-7;
    try std.testing.expectApproxEqAbs(expected, val, 1e-14);
}

test "FP16: subnormal decode mantissa=1023 (max)" {
    const bits: u16 = 0x03FF;
    const val = fp16ToF32(bits);
    try std.testing.expect(val > 0.0);
    try std.testing.expect(val < 6.1e-5);
}

test "FP16: quantizeValue small values preserve sign" {
    const pos = quantizeValue(0.003, .fp16);
    const neg = quantizeValue(-0.003, .fp16);
    try std.testing.expect(pos > 0.0);
    try std.testing.expect(neg < 0.0);
}

test "FP16: subnormal roundtrip accuracy" {
    const vals = [_]f32{ 1e-5, 5e-5, 1e-4, 5e-4 };
    for (vals) |v| {
        const q = quantizeValue(v, .fp16);
        const rel_err = @abs(q - v) / v;
        try std.testing.expect(rel_err < 0.1);
    }
}
