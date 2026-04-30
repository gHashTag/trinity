const std = @import("std");

pub fn encodeF32ToGF16(v: f32) u16 {
    if (v == 0.0) return 0;
    if (!std.math.isFinite(v)) return if (v < 0) 0xFFFF else 0x7FFF;

    const sign: u16 = if (v < 0) 1 << 15 else 0;
    const abs_v = @abs(v);

    var exp: i16 = 0;
    var mant_f: f64 = abs_v;
    while (mant_f >= 1.0 and exp < 31) : (exp += 1) mant_f /= 2.0;
    while (mant_f < 0.5 and exp > -32) : (exp -= 1) mant_f *= 2.0;

    const exp_u6: u16 = @intCast(std.math.clamp(@as(i16, 31) + exp, 0, 63));
    const mant_u9: u16 = @intFromFloat(std.math.clamp((mant_f - 0.5) * 512.0, 0, 511));

    return sign | (exp_u6 << 9) | (mant_u9 & 0x1FF);
}

pub fn decodeGF16ToF32(raw: u16) f32 {
    if (raw == 0) return 0.0;
    if (raw == 0x8000) return -0.0;

    const sign: f32 = if ((raw >> 15) & 1 == 1) -1.0 else 1.0;
    const exp: u16 = (raw >> 9) & 0x3F;
    const mant: u16 = raw & 0x1FF;

    if (exp == 0x3F) return if (sign < 0) -std.math.inf(f32) else std.math.inf(f32);

    const exp_f: f32 = @floatFromInt(@as(i32, @intCast(exp)) - 31);
    const mant_f: f32 = 0.5 + @as(f32, @floatFromInt(mant)) / 512.0;
    return sign * mant_f * std.math.pow(f32, 2.0, exp_f);
}

pub fn encodeBF16(v: f32) u16 {
    const bits: u32 = @bitCast(v);
    return @intCast(bits >> 16);
}

pub fn decodeBF16(raw: u16) f32 {
    const bits: u32 = @as(u32, raw) << 16;
    return @bitCast(bits);
}

test "f32 to GF16 roundtrip" {
    const values = [_]f32{ 0.5, 1.0, 2.0, 3.14, 100.0 };
    for (values) |v| {
        const encoded = encodeF32ToGF16(v);
        const decoded = decodeGF16ToF32(encoded);
        const err = @abs(v - decoded) / v;
        try std.testing.expect(err < 0.01);
    }
}

test "BF16 roundtrip" {
    const values = [_]f32{ 0.5, 1.0, 2.0, 3.14 };
    for (values) |v| {
        const encoded = encodeBF16(v);
        const decoded = decodeBF16(encoded);
        const err = @abs(v - decoded) / v;
        try std.testing.expect(err < 0.01);
    }
}
