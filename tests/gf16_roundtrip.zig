const std = @import("std");

const GF16 = packed struct(u16) {
    mant: u9,
    exp: u6,
    sign: u1,

    pub fn fromF64(v: f64) GF16 {
        if (v == 0.0) return .{ .mant = 0, .exp = 0, .sign = 0 };
        if (!std.math.isFinite(v)) return .{ .mant = 0, .exp = 0x3F, .sign = @intFromBool(v < 0) };

        const sign_bit: u1 = @intFromBool(v < 0);
        const abs_v = @abs(v);

        var exp: i16 = 0;
        var mant_f = abs_v;
        while (mant_f >= 1.0 and exp < 31) : (exp += 1) mant_f /= 2.0;
        while (mant_f < 0.5 and exp > -32) : (exp -= 1) mant_f *= 2.0;

        const exp_bias: i16 = 31;
        const exp_u6: u6 = @intCast(std.math.clamp(exp_bias + exp, 0, 63));
        const mant_u9: u9 = @intFromFloat(std.math.clamp((mant_f - 0.5) * 512.0, 0, 511));

        return .{ .mant = mant_u9, .exp = exp_u6, .sign = sign_bit };
    }

    pub fn toF64(self: GF16) f64 {
        if (self.exp == 0 and self.mant == 0) return if (self.sign == 1) -0.0 else 0.0;
        if (self.exp == 0x3F) return if (self.sign == 1) -std.math.inf(f64) else std.math.inf(f64);

        const exp_unbiased: f64 = @floatFromInt(@as(i32, self.exp) - 31);
        const mant_f: f64 = 0.5 + @as(f64, @floatFromInt(self.mant)) / 512.0;
        const value = mant_f * std.math.pow(f64, 2.0, exp_unbiased);
        return if (self.sign == 1) -value else value;
    }
};

const ValidationResult = struct {
    seed: u64,
    n_weights: usize,
    max_roundtrip_error: f64,
    avg_roundtrip_error: f64,
    model_bytes_gf16: usize,
    model_bytes_fp32: usize,
    compression_ratio: f64,
    all_below_threshold: bool,
};

fn validateSeed(allocator: std.mem.Allocator, seed: u64, n_weights: usize) !ValidationResult {
    var rng = std.Random.DefaultPrng.init(seed);

    var weights = try allocator.alloc(f64, n_weights);
    defer allocator.free(allocator);
    for (weights) |*w| {
        w.* = rng.random().floatNorm(f64) * 0.5;
    }

    var max_err: f64 = 0;
    var sum_err: f64 = 0;

    for (weights) |w| {
        const encoded = GF16.fromF64(w);
        const decoded = encoded.toF64();
        const err = @abs(w - decoded);
        sum_err += err;
        if (err > max_err) max_err = err;
    }

    const avg_err = sum_err / @as(f64, @floatFromInt(n_weights));
    const gf16_bytes = n_weights * 2;
    const fp32_bytes = n_weights * 4;

    return ValidationResult{
        .seed = seed,
        .n_weights = n_weights,
        .max_roundtrip_error = max_err,
        .avg_roundtrip_error = avg_err,
        .model_bytes_gf16 = gf16_bytes,
        .model_bytes_fp32 = fp32_bytes,
        .compression_ratio = @as(f64, @floatFromInt(fp32_bytes)) / @as(f64, @floatFromInt(gf16_bytes)),
        .all_below_threshold = max_err < 1e-6,
    };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const stdout = std.io.getStdOut().writer();

    const n_weights: usize = 1950000;
    const seeds = [_]u64{ 42, 43, 44, 45, 46 };
    const max_model_bytes: usize = 16 * 1024 * 1024;

    stdout.print("\n{s}\n", .{"=" * 72}) catch {};
    stdout.print("  GF16 Validation — Encode/Decode Roundtrip + Size Check\n", .{});
    stdout.print("  Model: HSLM-1.95M ({d} weights)\n", .{n_weights});
    stdout.print("  Threshold: roundtrip error < 1e-6\n", .{});
    stdout.print("  Size limit: {d} MB\n", .{max_model_bytes / (1024 * 1024)});
    stdout.print("{s}\n\n", .{"=" * 72}) catch {};

    var all_pass = true;
    var results = std.ArrayList(ValidationResult).init(allocator);
    defer results.deinit();

    for (&seeds) |seed| {
        const r = try validateSeed(allocator, seed, n_weights);
        try results.append(r);

        const status = if (r.all_below_threshold) "PASS" else "FAIL";
        stdout.print("  Seed {d}: max_err={e:.3} avg_err={e:.6} size={d}MB [{s}]\n", .{
            seed,
            r.max_roundtrip_error,
            r.avg_roundtrip_error,
            r.model_bytes_gf16 / (1024 * 1024),
            status,
        }) catch {};

        if (!r.all_below_threshold) all_pass = false;
    }

    const total_gf16_mb = (n_weights * 2) / (1024 * 1024);
    const size_pass = total_gf16_mb < max_model_bytes / (1024 * 1024);

    stdout.print("\n{s}\n", .{"=" * 72}) catch {};
    stdout.print("  RESULTS\n", .{});
    stdout.print("{s}\n", .{"-" * 72}) catch {};
    stdout.print("  Roundtrip (all seeds):      {s}\n", .{if (all_pass) "PASS" else "FAIL"}) catch {};
    stdout.print("  GF16 model size:            {d} MB (limit: {d} MB)\n", .{ total_gf16_mb, max_model_bytes / (1024 * 1024) }) catch {};
    stdout.print("  Size check:                 {s}\n", .{if (size_pass) "PASS" else "FAIL"}) catch {};
    stdout.print("  Compression vs FP32:        {d:.1}x\n", .{2.0}) catch {};
    stdout.print("  Overall:                    {s}\n", .{if (all_pass and size_pass) "ALL CHECKS PASS" else "SOME CHECKS FAILED"}) catch {};
    stdout.print("{s}\n\n", .{"=" * 72}) catch {};

    if (!all_pass or !size_pass) std.process.exit(1);
}

test "gf16 roundtrip zero" {
    const gf = GF16.fromF64(0.0);
    try std.testing.expectEqual(@as(f64, 0.0), gf.toF64());
}

test "gf16 roundtrip positive" {
    const values = [_]f64{ 0.5, 1.0, 2.0, 3.14, 100.0, 1000.0 };
    for (values) |v| {
        const gf = GF16.fromF64(v);
        const decoded = gf.toF64();
        const err = @abs(v - decoded) / v;
        try std.testing.expect(err < 0.01);
    }
}

test "gf16 roundtrip negative" {
    const values = [_]f64{ -0.5, -1.0, -2.0, -3.14 };
    for (values) |v| {
        const gf = GF16.fromF64(v);
        const decoded = gf.toF64();
        const err = @abs(v - decoded) / @abs(v);
        try std.testing.expect(err < 0.01);
    }
}

test "gf16 model size under 16MB" {
    const n_weights: usize = 1950000;
    const gf16_bytes = n_weights * 2;
    const limit: usize = 16 * 1024 * 1024;
    try std.testing.expect(gf16_bytes < limit);
}
