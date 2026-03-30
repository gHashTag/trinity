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
    try file.writeAll(&[_]u8{
        'G', 'I', 'F', '8', '9', 'a',
        @as(u8, width & 0xFF), @as(u8, (width >> 8) & 0xFF),
        @as(u8, height & 0xFF), @as(u8, (height >> 8) & 0xFF),
        0xF0, 0x00, 0x00,
    });

    // Global color table (16 colors: grayscale)
    for (0..16) |i| {
        const c = @as(u8, @intCast(i * 17));
        const rgb = [_]u8{ c, c, c };
        try file.writeAll(&rgb);
    }
    // Fill rest with black
    const remaining = 256 * 3 - 16 * 3;
    for (0..remaining) |_| {
        const zeros = [_]u8{0};
        try file.writeAll(&zeros);
    }

    // Netscape loop extension
    const netscape_header = [_]u8{ 0x21, 0xFF, 0x11 };
    try file.writeAll(&netscape_header);
    try file.writeAll("NETSCAPE2.0");
    const netscape_footer = [_]u8{ 0x03, 0x01, 0x00, 0x00 };
    try file.writeAll(&netscape_footer);

    // Generate frames
    var frame: u32 = 0;
    while (frame < frames) : (frame += 1) {
        const progress = @as(f64, @floatFromInt(frame)) / @as(f64, @floatFromInt(frames));
        const ease = if (progress < 0.5) 2.0 * progress * progress else 1.0 - std.math.pow(f64, -2.0 * progress + 2.0, 2.0) / 2.0;

        @memset(pixels, 0);

        const cx = width / 2;
        const cy: u16 = height / 2;

        // Draw phi^2 bar (gold - color 1)
        const phi_h = @as(u32, @intFromFloat((PHI_SQUARED / 3.0) * 60 * ease));
        const phi_x = cx - 30;
        var y: usize = 0;
        while (y < @min(phi_h, 60)) : (y += 1) {
            const py = cy - 30 - @as(u16, @intCast(y));
            for (0..25) |px| {
                const px_actual = phi_x + @as(u16, @intCast(px));
                if (px_actual < width and py > 0) {
                    const idx = @as(usize, py) * width + @as(usize, px_actual);
                    if (idx < pixels.len) pixels[idx] = 1;
                }
            }
        }

        // Draw 1/phi^2 bar (cyan - color 2)
        const inv_h = @as(u32, @intFromFloat((INVERSE_PHI_SQUARED / 3.0) * 60 * ease));
        const inv_x = cx + 5;
        y = 0;
        while (y < @min(inv_h, 60)) : (y += 1) {
            const py = cy - 30 - @as(u16, @intCast(y));
            for (0..25) |px| {
                const px_actual = inv_x + @as(u16, @intCast(px));
                if (px_actual < width and py > 0) {
                    const idx = @as(usize, py) * width + @as(usize, px_actual);
                    if (idx < pixels.len) pixels[idx] = 2;
                }
            }
        }

        // Draw sum bar (magenta - color 3) - shows equals 3
        const sum_x = cx + 35;
        y = 0;
        while (y < 60) : (y += 1) {
            const py = cy - 30 - @as(u16, @intCast(y));
            for (0..25) |px| {
                const px_actual = sum_x + @as(u16, @intCast(px));
                if (px_actual < width and py > 0) {
                    const idx = @as(usize, py) * width + @as(usize, px_actual);
                    if (idx < pixels.len) pixels[idx] = 3;
                }
            }
        }

        // Graphics control extension (10/100 sec delay)
        const gce = [_]u8{ 0x21, 0xF9, 0x04, 0x00, 0x0A, 0x00 };
        try file.writeAll(&gce);

        // Image descriptor
        try file.writeAll(&[_]u8{
            0x2C, 0x00, 0x00, 0x00, 0x00,
            @as(u8, width & 0xFF), @as(u8, (width >> 8) & 0xFF),
            @as(u8, height & 0xFF), @as(u8, (height >> 8) & 0xFF), 0x00,
        });

        const min_code = [_]u8{ 2 }; // LZW min code size
        try file.writeAll(&min_code);

        // Pixel data in chunks
        var pos: usize = 0;
        while (pos < pixels.len) {
            const chunk = @min(254, pixels.len - pos);
            const chunk_buf = try std.heap.page_allocator.alloc(u8, chunk + 1);
            defer std.heap.page_allocator.free(chunk_buf);
            chunk_buf[0] = @intCast(chunk);
            @memcpy(chunk_buf[1..], pixels[pos..pos+chunk]);
            try file.writeAll(chunk_buf);
            pos += chunk;
        }
        const term = [_]u8{ 0 }; // block terminator
        try file.writeAll(&term);

        if (frame % 10 == 0) std.debug.print("  Frame {d}/{}\n", .{frame, frames});
    }

    const trailer = [_]u8{ 0x3B }; // GIF trailer
    try file.writeAll(&trailer);

    std.debug.print("Done!\n", .{});
    std.debug.print("Created: trinity_identity.gif\n", .{});
    std.debug.print("\nTrinity Identity: phi^2 + 1/phi^2 = 3\n", .{});
    std.debug.print("  phi^2  = {d:.15}\n", .{PHI_SQUARED});
    std.debug.print("  1/phi^2 = {d:.15}\n", .{INVERSE_PHI_SQUARED});
    std.debug.print("  Sum    = {d:.15}\n", .{PHI_SQUARED + INVERSE_PHI_SQUARED});
}
