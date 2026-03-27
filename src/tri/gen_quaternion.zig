//! tri/quaternion — Quaternion for 3D rotations
//! TTT Dogfood v0.2 Stage 273

const std = @import("std");

pub const Quaternion = struct {
    w: f64,
    x: f64,
    y: f64,
    z: f64,

    pub fn identity() Quaternion {
        return .{ .w = 1, .x = 0, .y = 0, .z = 0 };
    }

    pub fn multiply(q1: Quaternion, q2: Quaternion) Quaternion {
        return .{
            .w = q1.w * q2.w - q1.x * q2.x - q1.y * q2.y - q1.z * q2.z,
            .x = q1.w * q2.x + q1.x * q2.w + q1.y * q2.z - q1.z * q2.y,
            .y = q1.w * q2.y - q1.x * q2.z + q1.y * q2.w + q1.z * q2.x,
            .z = q1.w * q2.z + q1.x * q2.y - q1.y * q2.x + q1.z * q2.w,
        };
    }
};

test "quaternion identity" {
    const q = Quaternion.identity();
    try std.testing.expectEqual(@as(f64, 1), q.w);
}
