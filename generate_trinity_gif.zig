//! Trinity Identity GIF - Working Zig 0.15 version
const std = @import("std");

const PHI_SQUARED: f64 = 2.618033988749895;
const INVERSE_PHI_SQUARED: f64 = 0.3819660112501051;

pub fn main() !void {
    const width: u16 = 200;
    const height: u16 = 200;
    const frames: u32 = 30;

    const pixels = try std.heap.page_allocator.alloc(u8, width * height);
    defer std.heap.page_allocator.free(pixels);

    const file = try std.fs.cwd().createFile("trinity_identity.gif", .{});
    defer file.close();

    std.debug.print("Generating trinity_identity.gif...\n", .{});

    // GIF header bytes
    var header_data = [_]u8{
        'G', 'I', 'F', '8', '9', 'a',
        @as(u8, width & 0xFF), @as(u8, (width >> 8) & 0xFF),
        @as(u8, height & 0xFF), @as(u8, (height >> 8) & 0xFF),
        0xF0, 0x00, 0x00,
    };
    try file.writeAll(&header_data);

    // Global color table (16 colors)
    for (0..16) |i| {
        const c = @as(u8, @intCast(i * 17));
        const rgb = [_]u8{ c, c, c };
        try file.writeAll(&rgb);
    }
    // Fill rest with black
    const remaining = 256 * 3 - 16 * 3;
    const zeros = try std.heap.page_allocator.alloc(u8, remaining);
    defer std.heap.page_allocator.free(zeros);
    @memset(zeros, 0);
    try file.writeAll(zeros);

    // Netscape loop extension
    const netscape = "\x21\xFF\x11NETSCAPE2.0\x03\x01\x00\x00";
    try file.writeAll(netscape);

    // Generate frames
    var frame: u32 = 0;
    while (frame < frames) : (frame += 1) {
        const progress = @as(f64, @floatFromInt(frame)) / @as(f64, @floatFromInt(frames));
        const ease = if (progress < 0.5) 2.0 * progress * progress else 1.0 - std.math.pow(f64, -2.0 * progress + 2.0, 2.0) / 2.0;

        @memset(pixels, 0);

        const cx = width / 2;
        const cy: u16 = height / 2;

        // Draw phi^2 bar (gold)
        const phi_h = @as(u32, @intFromFloat((PHI_SQUARED / 3.0) * 60 * ease));
        const phi_x = cx - 30;
        for (0..@min(phi_h, 60)) |y| {
            const py = cy - 30 - @as(u16, y);
            for (0..25) |px| {
                const px_actual = phi_x + @as(u16, px);
                if (px_actual < width and py > 0) {
                    const idx = @as(usize, py) * width + @as(usize, px_actual);
                    if (idx < pixels.len) pixels[idx] = 1;
                }
            }
        }

        // Draw 1/phi^2 bar (cyan)
        const inv_h = @as(u32, @intFromFloat((INVERSE_PHI_SQUARED / 3.0) * 60 * ease));
        const inv_x = cx + 5;
        for (0..@min(inv_h, 60)) |y| {
            const py = cy - 30 - @as(u16, y);
            for (0..25) |px| {
                const px_actual = inv_x + @as(u16, px);
                if (px_actual < width and py > 0) {
                    const idx = @as(usize, py) * width + @as(usize, px_actual);
                    if (idx < pixels.len) pixels[idx] = 2;
                }
            }
        }

        // Draw sum bar (magenta) - shows equals 3
        const sum_x = cx + 35;
        for (0..60) |y| {
            const py = cy - 30 - @as(u16, y);
            for (0..25) |px| {
                const px_actual = sum_x + @as(u16, px);
                if (px_actual < width and py > 0) {
                    const idx = @as(usize, py) * width + @as(usize, px_actual);
                    if (idx < pixels.len) pixels[idx] = 3;
                }
            }
        }

        // Graphics control (10/100 sec delay)
        try file.writeAll("\x21\xF9\x04\x00\x0A\x00");

        // Image descriptor
        const img_desc = [_]u8{ 0x2C, 0x00, 0x00, 0x00, 0x00, @as(u8, width & 0xFF), @as(u8, (width >> 8) & 0xFF), @as(u8, height & 0xFF), @as(u8, (height >> 8) & 0xFF), 0x00 };
        try file.writeAll(&img_desc);

        try file.writeByte(2); // LZW min code size

        // Pixel data
        var pos: usize = 0;
        while (pos < pixels.len) {
            const chunk = @min(254, pixels.len - pos);
            const chunk_data = try std.heap.page_allocator.alloc(u8, chunk + 1);
            defer std.heap.page_allocator.free(chunk_data);
            chunk_data[0] = @intCast(chunk);
            @memcpy(chunk_data[1..], pixels[pos..pos+chunk]);
            try file.writeAll(chunk_data);
            pos += chunk;
        }
        try file.writeByte(0); // terminator

        if (frame % 10 == 0) std.debug.print("  Frame {d}/{}\n", .{frame, frames});
    }

    try file.writeAll("\x3B"); // trailer

    std.debug.print("Done!\n", .{});
    std.debug.print("Created: trinity_identity.gif\n", .{});
    std.debug.print("\nTrinity Identity: phi^2 + 1/phi^2 = 3\n", .{});
    std.debug.print("  phi^2  = {d:.15}\n", .{PHI_SQUARED});
    std.debug.print("  1/phi^2 = {d:.15}\n", .{INVERSE_PHI_SQUARED});
    std.debug.print("  Sum    = {d:.15}\n", .{PHI_SQUARED + INVERSE_PHI_SQUARED});
}
