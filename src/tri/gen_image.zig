//! tri/image — Basic image operations
//! TTT Dogfood v0.2 Stage 277

const std = @import("std");

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

pub const Image = struct {
    width: usize,
    height: usize,
    pixels: []Color,

    pub const Color = struct {
        r: u8,
        g: u8,
        b: u8,
    };

    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !Image {
<<<<<<< Updated upstream
        const pixels = try allocator.alloc(Image.Color, width * height);
        @memset(pixels, Image.Color{ .r = 0, .g = 0, .b = 0 });
=======
        var pixels = try std.ArrayList(Color).initCapacity(allocator, width * height);
        for (0..width * height) |_| {
            try pixels.append(allocator, Color{ .r = 255, .g = 255, .b = 255, .a = 255 });
        }
>>>>>>> Stashed changes
        return .{
            .width = width,
            .height = height,
            .pixels = pixels,
        };
    }

    pub fn setPixel(img: *Image, x: usize, y: usize, color: Image.Color) void {
        if (x < img.width and y < img.height) {
            img.pixels[y * img.width + x] = color;
        }
    }

    pub fn deinit(img: *Image, allocator: std.mem.Allocator) void {
        allocator.free(img.pixels);
    }
};

test "image" {
    var img = try Image.init(std.testing.allocator, 10, 10);
    defer img.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 10), img.width);
}
