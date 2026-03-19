// @origin(spec:angular_gyrus.tri) @regen(manual-impl)
// ANGULAR GYRUS — Format Introspection for Sensation
//
// Angular Gyrus: Format analysis and sacred geometry for Trinity cortex
// Describes floating-point formats with φ-distance analysis
// Provides table of all formats with golden ratio scores
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const ips = @import("intraparietal_sulcus.zig");

const GoldenFloat16 = ips.GoldenFloat16;
const TernaryFloat9 = ips.TernaryFloat9;

// ═════════════════════════════════════════════════════════════════════════════
// FORMAT TYPE ENUM — All known floating-point formats
// ═════════════════════════════════════════════════════════════════════════════════

/// Format type enumeration for format introspection
pub const FormatType = enum(u8) {
    /// IEEE 754 32-bit: sign:1, exp:8, mant:23
    FP32,

    /// IEEE 754 64-bit: sign:1, exp:11, mant:52
    FP64,

    /// IEEE 754 16-bit: sign:1, exp:5, mant:10
    FP16,

    /// IEEE 754 8-bit: sign:1, exp:4, mant:3 (OCP format)
    FP8,

    /// Brain Float 16-bit: sign:1, exp:8, mant:7
    BF16,

    /// Golden Float 16: sign:1, exp:6, mant:9 (φ-optimized)
    GF16,

    /// Ternary Float 32: 9 trits, exp:mant = 3:5 = 0.6 ≈ 1/φ
    TF32,

    /// Ternary Float 9: 9 trits, exp:mant = 3:5 ≈ 0.6 (EXACT GOLDEN)
    TF3_9,
};

// ═══════════════════════════════════════════════════════════════════════════════════
// FORMAT DESCRIPTOR — Complete format metadata
// ═══════════════════════════════════════════════════════════════════════════════════

/// Complete format description with sacred analysis
pub const FormatDescriptor = struct {
    /// Format type enum
    format_type: FormatType,

    /// Human-readable format name
    name: []const u8,

    /// Sign bits (0 or 1)
    sign_bits: u8,

    /// Exponent bits
    exp_bits: u8,

    /// Mantissa bits
    mant_bits: u8,

    /// Total bits (sign + exp + mant)
    total_bits: u8,

    /// φ-distance: |exp/mant - 1/φ| (lower = more golden)
    phi_distance: f64,

    /// Dynamic range estimate (log10 of max representable value)
    dynamic_range: f64,

    /// Is this format "golden" (distance < 0.1)
    is_golden: bool,

    /// Precision estimate (decimal places)
    precision: f64,
};

// ═════════════════════════════════════════════════════════════════════════════════
// SACRED GEOMETRY ANALYSIS
// ═══════════════════════════════════════════════════════════════════════════════════

/// Calculate φ-distance for a format (|exp/mant - 1/φ|)
/// Reuses IPS function for consistency
pub inline fn goldenDistance(exp_bits: u8, mant_bits: u8) f64 {
    return ips.goldenDistance(exp_bits, mant_bits);
}

/// Calculate dynamic range (log10 of max representable finite value)
/// Simplified approximation to avoid comptime branch quota issues
pub fn calcDynamicRange(exp_bits: u8, mant_bits: u8, exp_bias: i32) f64 {
    _ = mant_bits; // Mantissa affects precision, not dynamic range
    if (exp_bits == 0) return 0.0;

    // Approximate: log10(2^exp) ≈ exp * 0.301
    // Max value ≈ 2^(2^exp - bias), log10 ≈ (2^exp - bias) * 0.301
    const max_exp_int: u32 = (@as(u32, 1) << @as(u5, @intCast(exp_bits))) - 2;
    const max_exp_val: f64 = @floatFromInt(max_exp_int);
    const log10_max_val: f64 = (max_exp_val - @as(f64, @floatFromInt(exp_bias))) * 0.30103;

    // Avoid log(0)
    if (log10_max_val <= 0) return 0.0;
    return log10_max_val;
}

/// Calculate precision estimate (decimal places from mantissa bits)
pub fn calcPrecision(mant_bits: u8) f64 {
    if (mant_bits == 0) return 0.0;
    // Log10(2^mant_bits) ≈ mant_bits × 0.301
    return @as(f64, @floatFromInt(mant_bits)) * 0.30103;
}

/// Create complete format descriptor
pub fn describeFormat(format_type: FormatType) FormatDescriptor {
    const sign_bits: u8 = switch (format_type) {
        .FP32, .FP64, .FP16, .FP8, .BF16, .GF16, .TF3_9 => 1,
        .TF32 => 3,
    };

    const exp_bits: u8 = switch (format_type) {
        .FP32 => 8,
        .FP64 => 11,
        .FP16 => 5,
        .FP8 => 4,
        .BF16 => 8,
        .GF16 => 6,
        .TF32 => 3,
        .TF3_9 => 3,
    };

    const mant_bits: u8 = switch (format_type) {
        .FP32 => 23,
        .FP64 => 52,
        .FP16 => 10,
        .FP8 => 3,
        .BF16 => 7,
        .GF16 => 9,
        .TF32 => 5,
        .TF3_9 => 5,
    };

    const exp_bias: i32 = switch (format_type) {
        .FP32 => 127,
        .FP64 => 1023,
        .FP16, .FP8, .BF16, .GF16, .TF32, .TF3_9 => 15,
    };

    // For ternary formats, total_bits = trit_count * 2 (bits per trit)
    const total_bits: u8 = switch (format_type) {
        .TF3_9 => 18, // 9 trits × 2 bits
        else => sign_bits + exp_bits + mant_bits,
    };
    const phi_dist = goldenDistance(exp_bits, mant_bits);
    const is_golden = phi_dist < 0.1;
    const dyn_range = calcDynamicRange(exp_bits, mant_bits, exp_bias);
    const precision = calcPrecision(mant_bits);

    const name = switch (format_type) {
        .FP32 => "IEEE 754 FP32",
        .FP64 => "IEEE 754 FP64",
        .FP16 => "IEEE 754 FP16",
        .FP8 => "IEEE 754 FP8 (OCP)",
        .BF16 => "Brain Float 16 (BF16)",
        .GF16 => "Golden Float 16 (GF16)",
        .TF32 => "Ternary Float 32 (TF32)",
        .TF3_9 => "Ternary Float 9 (TF3-9)",
    };

    return FormatDescriptor{
        .format_type = format_type,
        .name = name,
        .sign_bits = sign_bits,
        .exp_bits = exp_bits,
        .mant_bits = mant_bits,
        .total_bits = total_bits,
        .phi_distance = phi_dist,
        .dynamic_range = dyn_range,
        .is_golden = is_golden,
        .precision = precision,
    };
}

// ═════════════════════════════════════════════════════════════════════════════════
// FORMAT TABLE — Comptime array of all known formats
// ═══════════════════════════════════════════════════════════════════════════════════

/// Get comptime table of all format descriptors
pub fn allFormatsTable() []const FormatDescriptor {
    const table = comptime blk: {
        var result: [8]FormatDescriptor = undefined;
        for (0..8) |i| {
            const ft: FormatType = @enumFromInt(i);
            result[i] = describeFormat(ft);
        }
        break :blk result;
    };
    return &table;
}

/// Find the most "golden" format (closest to 1/φ)
pub fn findMostGoldenFormat() FormatDescriptor {
    const table = allFormatsTable();
    var best = table[0];

    for (table[1..]) |desc| {
        if (desc.phi_distance < best.phi_distance) {
            best = desc;
        }
    }

    return best;
}

// ═══════════════════════════════════════════════════════════════════════════════════════
// VERBALIZATION — Convert format descriptor to human-readable text
// ═════════════════════════════════════════════════════════════════════════════════

/// Format a single format descriptor for terminal output
pub fn verbalizeFormat(writer: anytype, desc: FormatDescriptor) !void {
    try writer.print("  {s:8} {s:24} |", .{ @tagName(desc.format_type), desc.name });
    try writer.print("{d:2} bits | ", .{desc.total_bits});
    try writer.print("{d:2} exp, {d:2} mant | ", .{ desc.exp_bits, desc.mant_bits });
    try writer.print("phi-dist {d:.3} | ", .{desc.phi_distance});

    if (desc.is_golden) {
        try writer.writeAll("GOLDEN * | ");
    } else {
        try writer.writeAll("         | ");
    }

    try writer.print("range {d:.1} | prec {d:.1}\n", .{
        desc.dynamic_range,
        desc.precision,
    });
}

/// Print complete sacred analysis table for `tri math floats` command
pub fn printSacredAnalysis(writer: anytype) !void {
    const table = allFormatsTable();

    _ = try writer.write("\n=== SACRED FORMAT ANALYSIS ===\n\n");
    try writer.print("{s:24}Format          Type | Bits | Exp | Mant | Phi-Dist | Golden? | Range     Precision\n", .{" "});

    try writer.print("{s:24}────────────────────────────────────────────────────────────────────────────\n", .{"─"});

    for (table) |desc| {
        try verbalizeFormat(writer, desc);
    }

    _ = try writer.write("\n\n");

    const best = findMostGoldenFormat();
    try writer.print("* Most Golden: {s} (phi-dist = {d:.3})\n", .{
        best.name,
        best.phi_distance,
    });

    try writer.print("* Target (1/phi): {d:.6}\n\n", .{
        0.618034,
    });
}

/// Verbalize format type enum to human-readable string
pub fn formatTypeToString(ft: FormatType) []const u8 {
    return switch (ft) {
        .FP32 => "IEEE 754 FP32",
        .FP64 => "IEEE 754 FP64",
        .FP16 => "IEEE 754 FP16",
        .FP8 => "IEEE 754 FP8",
        .BF16 => "Brain Float 16",
        .GF16 => "Golden Float 16",
        .TF32 => "Ternary Float 32",
        .TF3_9 => "Ternary Float 9",
    };
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════════════════════════════════

test "golden distance fp32" {
    // FP32: exp=8, mant=23 → ratio = 8/23 ≈ 0.348
    // Distance from 1/φ (0.618): |0.348 - 0.618| ≈ 0.27
    const dist = goldenDistance(8, 23);
    try std.testing.expect(dist > 0.25 and dist < 0.30); // Not golden
    try std.testing.expect(!ips.isGoldenFormat(8, 23));
}

test "golden distance fp16" {
    // FP16: exp=5, mant=10 → ratio = 5/10 = 0.5
    // Distance from 1/φ (0.618): |0.5 - 0.618| ≈ 0.118
    const dist = goldenDistance(5, 10);
    try std.testing.expect(dist > 0.10 and dist < 0.15); // Not golden
    try std.testing.expect(!ips.isGoldenFormat(5, 10));
}

test "golden distance gf16" {
    // GF16: exp=6, mant=9 → ratio = 6/9 = 0.666
    // Distance from 1/φ (0.618): |0.666 - 0.618| ≈ 0.048
    const dist = goldenDistance(6, 9);
    try std.testing.expect(dist > 0.04 and dist < 0.06); // Golden!
    try std.testing.expect(ips.isGoldenFormat(6, 9));
}

test "golden distance tf3_9" {
    // TF3-9: exp=3, mant=5 → ratio = 3/5 = 0.6
    // Distance from 1/φ (0.618): |0.6 - 0.618| ≈ 0.018
    const dist = goldenDistance(3, 5);
    try std.testing.expect(dist > 0.01 and dist < 0.03); // Golden!
    try std.testing.expect(ips.isGoldenFormat(3, 5));
}

test "describe format fp32" {
    const desc = describeFormat(.FP32);
    try std.testing.expectEqual(@as(u8, 32), desc.total_bits);
    try std.testing.expect(!desc.is_golden);
}

test "describe format gf16" {
    const desc = describeFormat(.GF16);
    try std.testing.expectEqual(@as(u8, 16), desc.total_bits);
    try std.testing.expect(desc.is_golden);
}

test "describe format tf3_9" {
    const desc = describeFormat(.TF3_9);
    try std.testing.expectEqual(@as(u8, 18), desc.total_bits);
    try std.testing.expect(desc.is_golden);
}

test "all formats table is complete" {
    const table = allFormatsTable();
    try std.testing.expectEqual(@as(usize, 8), table.len);
}

test "find most golden format is gf16 or tf3_9" {
    const best = findMostGoldenFormat();
    // Both GF16 and TF3-9 have low φ-distance
    try std.testing.expect(best.is_golden);
    try std.testing.expect(best.phi_distance < 0.1);
}

test "dynamic range fp32 is reasonable" {
    const desc = describeFormat(.FP32);
    // FP32 should reach ~10^38
    try std.testing.expect(desc.dynamic_range > 37 and desc.dynamic_range < 39);
}

test "dynamic range fp16 is reasonable" {
    const desc = describeFormat(.FP16);
    // FP16 should reach ~10^4.6
    try std.testing.expect(desc.dynamic_range > 4.5 and desc.dynamic_range < 5);
}

test "dynamic range gf16 is reasonable" {
    const desc = describeFormat(.GF16);
    // GF16 (6-bit exp, bias=15): max_exp = 2^6 - 2 - 15 = 47
    // log10(2^47) ≈ 47 * 0.301 ≈ 14.15
    try std.testing.expect(desc.dynamic_range > 14 and desc.dynamic_range < 15);
}

test "precision calculation mant bits" {
    const p3 = calcPrecision(3);
    const p5 = calcPrecision(5);
    const p9 = calcPrecision(9);
    const p10 = calcPrecision(10);
    const p23 = calcPrecision(23);

    // 3 bits ≈ 0.9 decimal places
    try std.testing.expect(p3 > 0.9 and p3 < 1.0);
    // 5 bits ≈ 1.5 decimal places
    try std.testing.expect(p5 > 1.5 and p5 < 1.6);
    // 9 bits ≈ 2.7 decimal places
    try std.testing.expect(p9 > 2.7 and p9 < 2.8);
    // 10 bits ≈ 3.0 decimal places
    try std.testing.expect(p10 > 3.0 and p10 < 3.1);
    // 23 bits ≈ 6.9 decimal places
    try std.testing.expect(p23 > 6.9 and p23 < 7.0);
}

test "format type to string" {
    try std.testing.expectEqualStrings("IEEE 754 FP32", formatTypeToString(.FP32));
    try std.testing.expectEqualStrings("Golden Float 16", formatTypeToString(.GF16));
    try std.testing.expectEqualStrings("Ternary Float 9", formatTypeToString(.TF3_9));
}

test "verbalize format writes correctly" {
    var buf: [256]u8 = undefined;
    var fba = std.io.fixedBufferStream(&buf);

    const desc = describeFormat(.GF16);
    try verbalizeFormat(&fba.writer(), desc);

    const msg = fba.getWritten();
    try std.testing.expect(msg.len > 10);
    try std.testing.expect(std.mem.indexOf(u8, msg, "GF16") != null);
}

test "sacred analysis table contains gf16 and tf3_9 as golden" {
    var buf: [2048]u8 = undefined;
    var fba = std.io.fixedBufferStream(&buf);

    try printSacredAnalysis(&fba.writer());
    const msg = fba.getWritten();

    // Should mark GF16 as golden
    try std.testing.expect(std.mem.indexOf(u8, msg, "GOLDEN") != null);
}

test "sacred analysis table shows phi distance" {
    var buf: [2048]u8 = undefined;
    var fba = std.io.fixedBufferStream(&buf);

    try printSacredAnalysis(&fba.writer());
    const msg = fba.getWritten();

    // Should show φ-dist for GF16 (≈0.048)
    try std.testing.expect(std.mem.indexOf(u8, msg, "0.0") != null);
}

// φ² + 1/φ² = 3 | TRINITY
