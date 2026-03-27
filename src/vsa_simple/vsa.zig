// VSA Simple - Standalone VSA operations
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");

pub const Trit = i8;
pub const Vec32i8 = @Vector(32, i8);
pub const Vec32i16 = @Vector(32, i16);
pub const SIMD_WIDTH: usize = 32;

pub const Vector = struct {
    data: []Trit,
    len: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, len: usize) !Vector {
        const data = try allocator.alloc(Trit, len);
        return .{ .data = data, .len = len, .allocator = allocator };
    }

    pub fn clone(self: Vector) !Vector {
        const result = try self.allocator.alloc(Trit, self.len);
        @memcpy(result, self.data);
        return .{ .data = result, .len = self.len, .allocator = self.allocator };
    }

    pub fn deinit(self: Vector) void {
        self.allocator.free(self.data);
    }
};

pub fn bind(allocator: std.mem.Allocator, a: Vector, b: Vector) !Vector {
    const len = @max(a.len, b.len);
    const result = try Vector.init(allocator, len);

    for (0..len) |i| {
        const a_val = if (i < a.len) a.data[i] else 0;
        const b_val = if (i < b.len) b.data[i] else 0;
        result.data[i] = if (b_val == 0) a_val else b_val * a_val;
    }

    return result;
}

pub fn bundle2(allocator: std.mem.Allocator, a: Vector, b: Vector) !Vector {
    const len = @max(a.len, b.len);
    const result = try Vector.init(allocator, len);

    for (0..len) |i| {
        const a_val = if (i < a.len) a.data[i] else 0;
        const b_val = if (i < b.len) b.data[i] else 0;
        const sum = @as(i16, a_val) + @as(i16, b_val);
        result.data[i] = if (sum > 0) 1 else if (sum < 0) -1 else 0;
    }

    return result;
}

pub fn cosineSimilarity(a: Vector, b: Vector) f64 {
    var dot: i64 = 0;
    var norm_a: f64 = 0.0;
    var norm_b: f64 = 0.0;
    const len = @min(a.len, b.len);

    for (0..len) |i| {
        dot += @as(i64, a.data[i]) * @as(i64, b.data[i]);
        norm_a += @as(f64, @floatFromInt(a.data[i])) * @as(f64, @floatFromInt(a.data[i]));
        norm_b += @as(f64, @floatFromInt(b.data[i])) * @as(f64, @floatFromInt(b.data[i]));
    }

    const denom = @sqrt(norm_a) * @sqrt(norm_b);
    if (denom == 0.0) return 0.0;
    return @as(f64, @floatFromInt(dot)) / denom;
}

test "Vector init works" {
    const v = try Vector.init(std.testing.allocator, 100);
    defer v.deinit();
    try std.testing.expectEqual(@as(usize, 100), v.len);
}

test "bind creates result" {
    var a = try Vector.init(std.testing.allocator, 10);
    defer a.deinit();
    @memset(a.data, 1);

    var b = try Vector.init(std.testing.allocator, 10);
    defer b.deinit();
    @memset(b.data, -1);

    const result = try bind(std.testing.allocator, a, b);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 10), result.len);
    try std.testing.expectEqual(@as(Trit, -1), result.data[0]);
}

test "bundle2 majority vote" {
    var a = try Vector.init(std.testing.allocator, 10);
    defer a.deinit();
    @memset(a.data, 1);

    var b = try Vector.init(std.testing.allocator, 10);
    defer b.deinit();
    @memset(b.data, 1);

    var result = try bundle2(std.testing.allocator, a, b);
    defer result.deinit();

    try std.testing.expectEqual(@as(Trit, 1), result.data[0]);
}

test "cosineSimilarity identical" {
    var a = try Vector.init(std.testing.allocator, 10);
    defer a.deinit();

    const sim = cosineSimilarity(a, a);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), sim, 0.001);
}
