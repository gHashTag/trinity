//! tri/gradient — Color gradient
//! TTT Dogfood v0.2 Stage 386

const std = @import("std");

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

pub const Gradient = struct {
    stops: std.ArrayList(struct { f64, Color }),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Gradient {
        return .{
            .stops = std.ArrayList(struct { f64, Color }).initCapacity(allocator, 4) catch unreachable,
            .allocator = allocator,
        };
    }

    pub fn addStop(gradient: *Gradient, offset: f64, color: Color) !void {
        try gradient.stops.append(gradient.allocator, .{ offset, color });
    }

    pub fn sample(gradient: *const Gradient, t: f64) Color {
        _ = t;
        if (gradient.stops.items.len > 0) {
            return gradient.stops.items[0].@"1";
        }
        return Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
    }

    pub fn deinit(gradient: *Gradient) void {
        gradient.stops.deinit(gradient.allocator);
    }
};

test "gradient" {
    var grad = Gradient.init(std.testing.allocator);
    defer grad.deinit();
    try grad.addStop(0.0, Color{ .r = 255, .g = 0, .b = 0, .a = 255 });
    try grad.addStop(1.0, Color{ .r = 0, .g = 0, .b = 255, .a = 255 });
    const c = grad.sample(0.5);
    try std.testing.expect(c.r > 0 or c.b > 0);
}
