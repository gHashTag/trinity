const std = @import("std");

pub const PHI: f64 = 1.6180339887498948482;
pub const PHI_INV: f64 = 1.0 / PHI;
pub const PHI_SQ: f64 = PHI * PHI;
pub const PHI_INV_SQ: f64 = 1.0 / PHI_SQ;
pub const TRINITY: f64 = PHI_SQ + PHI_INV_SQ;

pub const FormatInfo = struct {
    name: []const u8,
    total_bits: u8,
    exp_bits: u8,
    mant_bits: u8,
    exp_mant_ratio: f64,
    phi_distance: f64,
    golden_pct: f64,
};

pub const GF16_INFO = FormatInfo{
    .name = "GF16",
    .total_bits = 16,
    .exp_bits = 6,
    .mant_bits = 9,
    .exp_mant_ratio = 6.0 / 9.0,
    .phi_distance = @abs(6.0 / 9.0 - PHI_INV),
    .golden_pct = (1.0 - @abs(6.0 / 9.0 - PHI_INV) / PHI_INV) * 100.0,
};

pub const BF16_INFO = FormatInfo{
    .name = "BF16",
    .total_bits = 16,
    .exp_bits = 8,
    .mant_bits = 7,
    .exp_mant_ratio = 8.0 / 7.0,
    .phi_distance = @abs(8.0 / 7.0 - PHI_INV),
    .golden_pct = (1.0 - @abs(8.0 / 7.0 - PHI_INV) / PHI_INV) * 100.0,
};

pub const FP16_INFO = FormatInfo{
    .name = "FP16",
    .total_bits = 16,
    .exp_bits = 5,
    .mant_bits = 10,
    .exp_mant_ratio = 5.0 / 10.0,
    .phi_distance = @abs(5.0 / 10.0 - PHI_INV),
    .golden_pct = (1.0 - @abs(5.0 / 10.0 - PHI_INV) / PHI_INV) * 100.0,
};

pub fn phiDistance(exp_bits: u8, mant_bits: u8) f64 {
    return @abs(@as(f64, @floatFromInt(exp_bits)) / @as(f64, @floatFromInt(mant_bits)) - PHI_INV);
}

pub fn goldenPct(exp_bits: u8, mant_bits: u8) f64 {
    const dist = phiDistance(exp_bits, mant_bits);
    return (1.0 - dist / PHI_INV) * 100.0;
}

pub fn formatTable(writer: anytype) !void {
    try writer.print("\n  Format Comparison (phi-distance from 1/phi = {d:.6})\n", .{PHI_INV});
    try writer.print("  {s}\n", .{"-" * 72});
    try writer.print("  {s:<8} {s:>6} {s:>6} {s:>6} {s:>10} {s:>10}\n", .{ "Format", "Bits", "Exp", "Mant", "e/m ratio", "% golden" });
    try writer.print("  {s}\n", .{"-" * 72});

    const formats = [_]FormatInfo{ GF16_INFO, BF16_INFO, FP16_INFO };
    for (&formats) |f| {
        try writer.print("  {s:<8} {d:>6} {d:>6} {d:>6} {d:>10.4} {d:>9.1f}%\n", .{
            f.name, f.total_bits, f.exp_bits, f.mant_bits, f.exp_mant_ratio, f.golden_pct,
        });
    }
    try writer.print("  {s}\n\n", .{"-" * 72});
}

pub fn autoSelectFormat(layer_idx: usize, total_layers: usize) FormatInfo {
    const ratio = @as(f64, @floatFromInt(layer_idx)) / @as(f64, @floatFromInt(total_layers));
    if (ratio < 0.2) return FP16_INFO;
    if (ratio < 0.8) return GF16_INFO;
    return BF16_INFO;
}

test "phi distance GF16" {
    const dist = phiDistance(6, 9);
    try std.testing.expect(dist < 0.05);
    try std.testing.expect(dist > 0);
}

test "phi distance GF16 is closest" {
    const gf16_dist = phiDistance(6, 9);
    const bf16_dist = phiDistance(8, 7);
    const fp16_dist = phiDistance(5, 10);
    try std.testing.expect(gf16_dist < bf16_dist);
    try std.testing.expect(gf16_dist < fp16_dist);
}

test "golden pct GF16" {
    const pct = goldenPct(6, 9);
    try std.testing.expect(pct > 90.0);
}

test "auto select format" {
    try std.testing.expectEqualStrings("FP16", autoSelectFormat(0, 10).name);
    try std.testing.expectEqualStrings("GF16", autoSelectFormat(5, 10).name);
    try std.testing.expectEqualStrings("BF16", autoSelectFormat(9, 10).name);
}

test "trinity identity" {
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), TRINITY, 1e-10);
}
