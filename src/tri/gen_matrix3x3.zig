//! tri/matrix3x3 — 3x3 matrix operations
//! TTT Dogfood v0.2 Stage 272

const std = @import("std");

pub const Mat3x3 = struct {
    data: [9]f64,

    pub fn identity() Mat3x3 {
        return .{
            .data = [_]f64{
                1, 0, 0,
                0, 1, 0,
                0, 0, 1,
            },
        };
    }

    pub fn multiply(a: Mat3x3, b: Mat3x3) Mat3x3 {
        var result: [9]f64 = undefined;
        for (0..3) |row| {
            for (0..3) |col| {
                var sum: f64 = 0;
                for (0..3) |k| {
                    sum += a.data[row * 3 + k] * b.data[k * 3 + col];
                }
                result[row * 3 + col] = sum;
            }
        }
        return .{ .data = result };
    }
};

test "mat3x3 identity" {
    const m = Mat3x3.identity();
    try std.testing.expectEqual(@as(f64, 1), m.data[0]);
}
