const std = @import("std");

pub const BLOCK_SIZE: usize = 32;
pub const SCALE_DIVISOR: f32 = 7.0;
pub const INT4_MIN: i8 = -8;
pub const INT4_MAX: i8 = 7;
pub const INT4_MAGIC: u32 = 0x34544E49;

pub const PackedInt4 = struct {
    data: []u8,
    scales: []f32,
    num: usize,

    pub fn size(self: *const PackedInt4) usize {
        return self.data.len + self.scales.len * @sizeOf(f32);
    }
};

pub const QuantStats = struct {
    orig_size: usize,
    quant_size: usize,
    ratio: f32,
    max_err: f32,
    mean_err: f32,
};

pub fn computeScale(block: []const f32) f32 {
    var absmax: f32 = 0.0;
    for (block) |v| {
        const a = @abs(v);
        if (a > absmax) absmax = a;
    }
    return if (absmax == 0.0) 1.0 else absmax / SCALE_DIVISOR;
}

pub fn quantize(v: f32, s: f32) i8 {
    const scaled = v / s;
    const rounded = @round(scaled);
    const clamped = @max(@as(f32, INT4_MIN), @min(@as(f32, INT4_MAX), rounded));
    return @intFromFloat(clamped);
}

pub fn dequantize(i: i8, s: f32) f32 {
    return @as(f32, @floatFromInt(i)) * s;
}

pub fn pack(hi: i8, lo: i8) u8 {
    const h: u8 = @bitCast(@as(i8, hi) & 0x0F);
    const l: u8 = @bitCast(@as(i8, lo) & 0x0F);
    return (h << 4) | l;
}

pub const Unpacked = struct { hi: i8, lo: i8 };

pub fn unpack(b: u8) Unpacked {
    const h4: u8 = (b >> 4) & 0x0F;
    const l4: u8 = b & 0x0F;
    const hi: i8 = if ((h4 & 0x08) != 0) @as(i8, @intCast(h4)) - 16 else @as(i8, @intCast(h4));
    const lo: i8 = if ((l4 & 0x08) != 0) @as(i8, @intCast(l4)) - 16 else @as(i8, @intCast(l4));
    return .{ .hi = hi, .lo = lo };
}

pub fn initPacked(a: std.mem.Allocator, n: usize) !PackedInt4 {
    const nb = (n + BLOCK_SIZE - 1) / BLOCK_SIZE;
    const ps = (n + 1) / 2;
    return PackedInt4{
        .data = try a.alloc(u8, ps),
        .scales = try a.alloc(f32, nb),
        .num = n,
    };
}

pub fn deinitPacked(a: std.mem.Allocator, p: *PackedInt4) void {
    a.free(p.data);
    a.free(p.scales);
}

pub fn quantizeTensor(a: std.mem.Allocator, d: []const f32) !PackedInt4 {
    const n = d.len;
    var r = try initPacked(a, n);
    errdefer deinitPacked(a, &r);

    const nb = (n + BLOCK_SIZE - 1) / BLOCK_SIZE;
    var int4_vals = try a.alloc(i8, n);
    defer a.free(int4_vals);

    var bi: usize = 0;
    while (bi < nb) : (bi += 1) {
        const st = bi * BLOCK_SIZE;
        const en = @min(st + BLOCK_SIZE, n);
        const blk = d[st..en];
        const sc = computeScale(blk);
        r.scales[bi] = sc;
        for (blk, 0..) |v, j| {
            int4_vals[st + j] = quantize(v, sc);
        }
    }

    var bx: usize = 0;
    var i: usize = 0;
    while (i < n) : (i += 2) {
        const hi = int4_vals[i];
        const lo = if (i + 1 < n) int4_vals[i + 1] else 0;
        r.data[bx] = pack(hi, lo);
        bx += 1;
    }
    return r;
}

pub fn dequantizeTensor(a: std.mem.Allocator, p: *const PackedInt4) ![]f32 {
    var r = try a.alloc(f32, p.num);
    errdefer a.free(r);

    var i: usize = 0;
    var bx: usize = 0;
    while (i < p.num) {
        const u = unpack(p.data[bx]);
        bx += 1;
        const bi = i / BLOCK_SIZE;
        const sc = p.scales[bi];
        r[i] = dequantize(u.hi, sc);
        i += 1;
        if (i < p.num) {
            const bi2 = i / BLOCK_SIZE;
            const sc2 = p.scales[bi2];
            r[i] = dequantize(u.lo, sc2);
            i += 1;
        }
    }
    return r;
}

pub fn calcStats(orig: []const f32, p: *const PackedInt4, deq: []const f32) QuantStats {
    const os = orig.len * @sizeOf(f32);
    const qs = p.size();
    var me: f32 = 0.0;
    var se: f32 = 0.0;
    for (orig, 0..) |o, i| {
        const e = @abs(o - deq[i]);
        if (e > me) me = e;
        se += e;
    }
    return QuantStats{
        .orig_size = os,
        .quant_size = qs,
        .ratio = @as(f32, @floatFromInt(os)) / @as(f32, @floatFromInt(qs)),
        .max_err = me,
        .mean_err = se / @as(f32, @floatFromInt(orig.len)),
    };
}

pub fn bf16ToF32(b: u16) f32 {
    const bits: u32 = @as(u32, b) << 16;
    return @bitCast(bits);
}

pub fn printStats(s: QuantStats) void {
    std.debug.print("INT4: {d:.2}x compression, max_err={d:.6}\n", .{ s.ratio, s.max_err });
}

test "scale" {
    const b = [_]f32{ 1.0, -2.0, 3.0, -4.0, 5.0, -6.0, 7.0, 0.0 };
    const s = computeScale(&b);
    try std.testing.expectApproxEqAbs(s, 1.0, 0.001);
}

test "pack_unpack" {
    const hi: i8 = 5;
    const lo: i8 = -3;
    const p = pack(hi, lo);
    const u = unpack(p);
    try std.testing.expectEqual(hi, u.hi);
    try std.testing.expectEqual(lo, u.lo);
}

test "tensor" {
    const a = std.testing.allocator;
    var orig = [_]f32{ 1.0, -2.0, 3.0, -4.0, 5.0, -6.0, 7.0, 0.0, 0.5, -0.5, 1.5, -1.5, 2.5, -2.5, 3.5, -3.5, 4.5, -4.5, 5.5, -5.5, 6.0, -6.0, 6.5, -6.5, 7.0, -7.0, 0.1, -0.1, 0.2, -0.2, 0.3, -0.3 };
    var p = try quantizeTensor(a, &orig);
    defer deinitPacked(a, &p);
    const d = try dequantizeTensor(a, &p);
    defer a.free(d);
    const s = calcStats(&orig, &p, d);
    try std.testing.expect(s.ratio > 2.5);
    try std.testing.expect(s.mean_err < 0.5);
}
