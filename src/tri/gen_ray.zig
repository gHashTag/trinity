//! tri/ray — Ray casting
//! TTT Dogfood v0.2 Stage 280

const std = @import("std");

pub const Ray = struct {
    origin: [3]f64,
    direction: [3]f64,

    pub fn init(origin: [3]f64, direction: [3]f64) Ray {
        return .{ .origin = origin, .direction = direction };
    }

    pub fn at(ray: *const Ray, t: f64) [3]f64 {
        return .{
            ray.origin[0] + t * ray.direction[0],
            ray.origin[1] + t * ray.direction[1],
            ray.origin[2] + t * ray.direction[2],
        };
    }
};

pub const Sphere = struct {
    center: [3]f64,
    radius: f64,

    pub fn intersect(sphere: *const Sphere, ray: *const Ray) ?f64 {
        const oc = .{
            ray.origin[0] - sphere.center[0],
            ray.origin[1] - sphere.center[1],
            ray.origin[2] - sphere.center[2],
        };
        const b = oc[0] * ray.direction[0] + oc[1] * ray.direction[1] + oc[2] * ray.direction[2];
        const c = oc[0] * oc[0] + oc[1] * oc[1] + oc[2] * oc[2] - sphere.radius * sphere.radius;
        const discriminant = b * b - c;
        if (discriminant < 0) return null;
        return -b - @sqrt(discriminant);
    }
};

test "ray" {
    const ray = Ray.init(.{ 0, 0, 0 }, .{ 1, 0, 0 });
    const p = ray.at(5.0);
    try std.testing.expectEqual(@as(f64, 5), p[0]);
}
