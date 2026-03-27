//! tri/polygon — Polygon operations
//! TTT Dogfood v0.2 Stage 278

const std = @import("std");

pub const Polygon = struct {
    vertices: std.ArrayList([2]f64),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Polygon {
        const vertices = try std.ArrayList([2]f64).initCapacity(allocator, 10);
        return .{
            .vertices = vertices,
            .allocator = allocator,
        };
    }

    pub fn addVertex(poly: *Polygon, x: f64, y: f64) !void {
        try poly.vertices.append(poly.allocator, .{ x, y });
    }

    pub fn area(poly: *const Polygon) f64 {
        var result: f64 = 0;
        const n = poly.vertices.items.len;
        if (n < 3) return 0;

        for (0..n) |i| {
            const j = (i + 1) % n;
            result += poly.vertices.items[i][0] * poly.vertices.items[j][1];
            result -= poly.vertices.items[j][0] * poly.vertices.items[i][1];
        }
        return @abs(result / 2);
    }

    pub fn deinit(poly: *Polygon) void {
        poly.vertices.deinit(poly.allocator);
    }
};

test "polygon area" {
    var poly = try Polygon.init(std.testing.allocator);
    defer poly.deinit();
    try poly.addVertex(0, 0);
    try poly.addVertex(1, 0);
    try poly.addVertex(0, 1);
    try std.testing.expect(poly.area() > 0);
}
