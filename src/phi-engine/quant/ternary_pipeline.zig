const std = @import("std");
const print = std.debug.print;

pub const DIMENSION: usize = 1024;
pub const ALPHA: f32 = 0.7;
pub const BETA: f32 = 0.3;
pub const PACK_SIZE: usize = 16;
pub const N_WORDS: usize = (DIMENSION + PACK_SIZE - 1) / PACK_SIZE;

pub const QuantStats = struct {
    original_norm: f32,
    quantized_norm: f32,
    sparsity: f32,
    mse: f32,
    scale: f32,
};

pub const PackedTernary = struct {
    data: [N_WORDS]u32,
    scale: f32,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .data = [_]u32{0} ** N_WORDS,
            .scale = 1.0,
        };
    }

    pub fn get(self: Self, idx: usize) i8 {
        const word_idx = idx / PACK_SIZE;
        const bit_pos: u5 = @intCast((idx % PACK_SIZE) * 2);
        const encoded = @as(u2, @truncate((self.data[word_idx] >> bit_pos)));
        return @as(i8, encoded) - 1;
    }

    pub fn set(self: *Self, idx: usize, value: i8) void {
        const word_idx = idx / PACK_SIZE;
        const bit_pos: u5 = @intCast((idx % PACK_SIZE) * 2);
        const encoded: u32 = @intCast(@as(u8, @intCast(value + 1)));
        const mask: u32 = ~(@as(u32, 0x3) << bit_pos);
        self.data[word_idx] = (self.data[word_idx] & mask) | (encoded << bit_pos);
    }

    pub fn dot(self: Self, other: Self) i32 {
        var sum: i32 = 0;
        for (0..DIMENSION) |i| {
            sum += @as(i32, self.get(i)) * @as(i32, other.get(i));
        }
        return sum;
    }

    pub fn countNonZero(self: Self) usize {
        var count: usize = 0;
        for (0..DIMENSION) |i| {
            if (self.get(i) != 0) count += 1;
        }
        return count;
    }
};

pub fn quantizeAbsmax(input: []const f32, out_packed: *PackedTernary, out_stats: *QuantStats) void {
    const len = @min(DIMENSION, input.len);

    var absmax: f32 = 0.0;
    var original_norm: f32 = 0.0;
    for (0..len) |i| {
        const abs_val = @abs(input[i]);
        if (abs_val > absmax) absmax = abs_val;
        original_norm += input[i] * input[i];
    }
    original_norm = @sqrt(original_norm);

    const scale = if (absmax > 1e-8) absmax / ALPHA else 1.0;
    out_packed.scale = scale;

    var zeros: usize = 0;
    var mse: f32 = 0.0;
    var quantized_norm: f32 = 0.0;

    for (0..len) |i| {
        const scaled = input[i] / scale;
        var trit: i8 = 0;

        if (scaled > BETA) {
            trit = 1;
        } else if (scaled < -BETA) {
            trit = -1;
        } else {
            trit = 0;
            zeros += 1;
        }

        out_packed.set(i, trit);

        const reconstructed: f32 = @as(f32, @floatFromInt(trit)) * scale;
        const err = input[i] - reconstructed;
        mse += err * err;
        quantized_norm += reconstructed * reconstructed;
    }

    out_stats.original_norm = original_norm;
    out_stats.quantized_norm = @sqrt(quantized_norm);
    out_stats.sparsity = @as(f32, @floatFromInt(zeros)) / @as(f32, @floatFromInt(len));
    out_stats.mse = mse / @as(f32, @floatFromInt(len));
    out_stats.scale = scale;
}

// dequantize removed for testing

pub fn ternaryBind(a: *PackedTernary, b: *PackedTernary, result: *PackedTernary) void {
    result.*.scale = a.*.scale * b.*.scale;

    for (0..DIMENSION) |i| {
        const va = a.*.get(i);
        const vb = b.*.get(i);
        var r: i8 = 0;
        if (va == 0 or vb == 0) {
            r = 0;
        } else if (va == vb) {
            r = 1;
        } else {
            r = -1;
        }
        result.set(i, r);
    }
}

pub fn ternarySimilarity(a: *PackedTernary, b: *PackedTernary) f32 {
    var match: i32 = 0;
    var total: i32 = 0;

    for (0..DIMENSION) |i| {
        const va = a.*.get(i);
        const vb = b.*.get(i);
        if (va != 0 and vb != 0) {
            total += 1;
            if (va == vb) {
                match += 1;
            } else {
                match -= 1;
            }
        }
    }
    if (total == 0) return 0.0;
    return @as(f32, @floatFromInt(match)) / @as(f32, @floatFromInt(total));
}

pub fn main() !void {
    print("TERNARY QUANTIZATION PIPELINE\n", .{});
    print("D={d}, Compression={d:.1}x\n\n", .{ DIMENSION, @as(f32, @floatFromInt(DIMENSION * 4)) / @as(f32, @floatFromInt(N_WORDS * 4 + 4)) });

    var prng = std.Random.DefaultPrng.init(42);
    var rng = prng.random();

    var input: [DIMENSION]f32 = undefined;
    for (&input) |*v| {
        v.* = (rng.float(f32) - 0.5) * 2.0;
    }

    var quant_packed = PackedTernary.init();
    var stats: QuantStats = undefined;
    quantizeAbsmax(&input, &quant_packed, &stats);

    print("Quantization Stats:\n", .{});
    print("  Sparsity: {d:.1}%\n", .{stats.sparsity * 100.0});
    print("  MSE: {d:.6}\n", .{stats.mse});
    print("  Scale: {d:.4}\n", .{stats.scale});

    // dequantize test removed

    print("\nTernary Pipeline Ready!\n", .{});
}

test "pack_unpack" {
    var p = PackedTernary.init();
    p.set(0, -1);
    p.set(1, 0);
    p.set(2, 1);
    try std.testing.expect(p.get(0) == -1);
    try std.testing.expect(p.get(1) == 0);
    try std.testing.expect(p.get(2) == 1);
}
