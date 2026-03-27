//! tri/canvas — Drawing canvas
//! TTT Dogfood v0.2 Stage 384

const std = @import("std");

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

pub const Canvas = struct {
    pixels: std.ArrayList(Color),
    width: usize,
    height: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !Canvas {
        var pixels = try std.ArrayList(Color).initCapacity(allocator, width * height);
        for (0..width * height) |_| {
            try pixels.append(allocator, Color{ .r = 0, .g = 0, .b = 0, .a = 255 });
        }
        return .{
            .pixels = pixels,
            .width = width,
            .height = height,
            .allocator = allocator,
        };
    }

    pub fn setPixel(canvas: *Canvas, x: usize, y: usize, color: Color) !void {
        if (x >= canvas.width or y >= canvas.height) return error.OutOfBounds;
        canvas.pixels.items[y * canvas.width + x] = color;
    }

    pub fn clear(canvas: *Canvas, color: Color) !void {
        for (canvas.pixels.items) |*p| {
            p.* = color;
        }
    }

    pub fn deinit(canvas: *Canvas) void {
        canvas.pixels.deinit(canvas.allocator);
    }
};

test "canvas" {
    var canvas = try Canvas.init(std.testing.allocator, 10, 10);
    defer canvas.deinit();
    try canvas.setPixel(5, 5, Color{ .r = 255, .g = 0, .b = 0, .a = 255 });
}
