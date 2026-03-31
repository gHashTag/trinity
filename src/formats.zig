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
pub const ExpMask: u16 = 0b0_111111_000000000;  // 0x7E00
pub const MantMask: u16 = 0b0_000000_111111111;  // 0x01FF

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
    if (a == 0) return 0;
    if (std.math.isInf(a)) return 0x7C00;  // Infinity
    if (std.math.isNan(a)) return 0x7E00;  // NaN

    const sign_bit: u16 = if (a < 0) 0x8000 else 0;
    const abs_a = if (a < 0) -a else a;

    const frexp_result = std.math.frexp(abs_a);
    const m_val = frexp_result.significand * 2.0;
    var e = frexp_result.exponent - 1;

    e = @min(e, 15);
    if (e <= -10) {
        // Underflow -> zero
        return sign_bit;
    }

    const mant_f = (m_val - 1.0) * 1024.0;  // 2^10
    var mant_i = @as(i32, @intFromFloat(mant_f));

    if (mant_i == 1024) {
        mant_i = 1023;
        e += 1;
        if (e >= 31) return 0x7C00;  // Overflow
    }
    const mant_bits: u16 = @as(u16, @intCast(mant_i)) & 0x03FF;
    const e_bits: u16 = @as(u16, @intCast(e + 15)) << 10;

    return sign_bit | e_bits | mant_bits;
}

fn fp16ToF32(x: u16) f32 {
    if (x == 0) return 0.0;
    if (x == 0x8000) return -0.0;

    const sign = @as(i32, (x >> 15) & 0x1);
    const e = @as(i32, (x >> 10) & 0x1F);
    const m = @as(i32, x & 0x03FF);

    if (e == 0) {
        // Denormal: m in [1, 1023], value = m * 2^(-14)
        const frac = @as(f32, @floatFromInt(m)) / 1024.0;
        const exp = @as(f32, @floatFromInt(e - 1 - 15));
        const val = frac * std.math.pow(f32, 2.0, exp);
        return if (sign != 0) -val else val;
    } else {
        const frac = @as(f32, @floatFromInt(m + 1024)) / 1024.0;
        const exp = @as(f32, @floatFromInt(e - 15));
        const val = (1.0 + frac) * std.math.pow(f32, 2.0, exp);
        return if (sign != 0) -val else val;
    }
}

// Software bf16 encode/decode (Brain Float 16)
fn f32ToBf16(a: f32) u16 {
    if (a == 0) return 0;
    if (std.math.isInf(a)) return 0x7F80;  // Infinity (all ones)
    if (std.math.isNan(a)) return 0x7FC0;  // NaN

    const sign_bit: u16 = if (a < 0) 0x8000 else 0;
    const abs_a = if (a < 0) -a else a;

    const frexp_result = std.math.frexp(abs_a);
    const m_val = frexp_result.significand;
    var e = frexp_result.exponent - 127;

    if (e < -7) {
        // Denormalized range -> flush to zero
        return sign_bit;
    }

    e = @min(e, 7);
    if (e <= 0 and m_val < 0.5) {
        return sign_bit;  // Subnormal -> zero
    }

    const mant_f = (m_val - 1.0) * 256.0;  // 2^8
    var mant_i = @as(i32, @intFromFloat(mant_f));

    if (mant_i == 256) {
        mant_i = 255;
        e += 1;
        if (e >= 7) return 0x7F80;  // Overflow
    }

    const mant_bits: u16 = @as(u16, @intCast(mant_i)) & 0x00FF;
    const e_bits: u16 = @as(u16, @intCast(e)) << 7;

    return sign_bit | e_bits | mant_bits;
}

fn bf16ToF32(x: u16) f32 {
    if (x == 0) return 0.0;
    if (x == 0x8000) return -0.0;

    const sign = @as(i32, (x >> 15) & 0x1);
    const e = @as(i32, (x >> 7) & 0x7F);
    const m = @as(i32, x & 0x00FF);

    if (e == 0) {
        // Denormalized: value = m * 2^(-126)
        const frac = @as(f32, @floatFromInt(m)) / 256.0;
        const exp = @as(f32, @floatFromInt(e - 1 - 127));
        const val = frac * std.math.pow(f32, 2.0, exp);
        return if (sign != 0) -val else val;
    } else {
        // Normal: value = (1 + m/256) * 2^(e-127)
        const frac = @as(f32, @floatFromInt(m)) / 256.0;
        const exp = @as(f32, @floatFromInt(e - 127));
        const val = (1.0 + frac) * std.math.pow(f32, 2.0, exp);
        return if (sign != 0) -val else val;
    }
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
