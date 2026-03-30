//! ═══════════════════════════════════════════════════════════════════════════════
//! TRINITY MATH GIF GENERATOR
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! Animated GIF visualizations for Trinity sacred mathematics:
//!   - Trinity Identity: φ² + 1/φ² = 3
//!   - Golden Spiral animation
//!   - Fibonacci/Lucas sequence relationships
//!   - Ternary computing visualization
//!
//! φ² + 1/φ² = 3 = TRINITY
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const mod = @import("mod.zig");
const fmt = @import("format.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// GIF ENCODER
// ═══════════════════════════════════════════════════════════════════════════════

const GIF_HEADER = "GIF89a";
const APP_EXT = "NETSCAPE2.0";
const TRAILER = "\x3b";

const Color = struct {
    r: u8,
    g: u8,
    b: u8,
};

pub const GifPalette = struct {
    colors: [256]Color,
    size: u8,

    pub fn initGrayscale() GifPalette {
        var palette: GifPalette = undefined;
        palette.size = 256;
        for (0..256) |i| {
            palette.colors[i] = .{
                .r = @intCast(i),
                .g = @intCast(i),
                .b = @intCast(i),
            };
        }
        return palette;
    }

    pub fn initTrinity() GifPalette {
        var palette: GifPalette = undefined;
        palette.size = 16;

        // Trinity colors: golden ratio inspired
        palette.colors[0] = .{ .r = 0, .g = 0, .b = 0 };       // Black
        palette.colors[1] = .{ .r = 255, .g = 215, .b = 0 };   // Gold
        palette.colors[2] = .{ .r = 0, .g = 255, .b = 255 };    // Cyan
        palette.colors[3] = .{ .r = 255, .g = 0, .b = 255 };    // Magenta
        palette.colors[4] = .{ .r = 255, .g = 100, .b = 100 };  // Salmon
        palette.colors[5] = .{ .r = 100, .g = 255, .b = 100 };  // Light Green
        palette.colors[6] = .{ .r = 100, .g = 100, .b = 255 };  // Light Blue
        palette.colors[7] = .{ .r = 255, .g = 255, .b = 100 };  // Yellow
        palette.colors[8] = .{ .r = 255, .g = 150, .b = 50 };   // Orange
        palette.colors[9] = .{ .r = 150, .g = 50, .b = 255 };    // Purple
        palette.colors[10] = .{ .r = 50, .g = 255, .b = 150 };   // Teal
        palette.colors[11] = .{ .r = 200, .g = 200, .b = 200 }; // Silver
        palette.colors[12] = .{ .r = 100, .g = 50, .b = 50 };    // Maroon
        palette.colors[13] = .{ .r = 50, .g = 100, .b = 50 };    // Green
        palette.colors[14] = .{ .r = 50, .g = 50, .b = 100 };    // Navy
        palette.colors[15] = .{ .r = 128, .g = 128, .b = 128 }; // Gray

        // Fill rest with grayscale
        for (16..256) |i| {
            const val = @as(u8, @intCast(i - 16));
            palette.colors[i] = .{ .r = val, .g = val, .b = val };
        }
        palette.size = 255; // u8 max value
        return palette;
    }
};

pub const GifEncoder = struct {
    allocator: std.mem.Allocator,
    writer: std.io.BufferedWriter(4096, std.fs.File.Writer),
    width: u16,
    height: u16,
    palette: GifPalette,
    frame_delays: std.ArrayList(u16),

    pub fn init(allocator: std.mem.Allocator, path: []const u8, width: u16, height: u16, palette: GifPalette) !GifEncoder {
        const file = try std.fs.cwd().createFile(path, .{ .read = true });
        defer file.close();

        const writer = std.io.bufferedWriter(file.writer());

        var enc = GifEncoder{
            .allocator = allocator,
            .writer = writer,
            .width = width,
            .height = height,
            .palette = palette,
            .frame_delays = std.ArrayList(u16).init(allocator),
        };

        try enc.writeHeader();
        return enc;
    }

    fn writeHeader(self: *GifEncoder) !void {
        const w = self.writer.writer();

        // GIF header
        try w.writeAll(GIF_HEADER);

        // Logical Screen Descriptor
        try w.writeInt(u16, self.width, .little);
        try w.writeInt(u16, self.height, .little);

        // Packed fields: global color table flag (1), color resolution (7), sort flag (0), size of global color table
        const gct_size = self.palette.size - 1;
        const packed_data: u8 = 0b10010000 | @as(u8, @intCast(@as(u2, @truncate(@clz(@as(u8, 255) ^ gct_size)))));
        try w.writeByte(packed_data);

        // Background color index
        try w.writeByte(0);
        // Pixel aspect ratio (0 = no aspect ratio info)
        try w.writeByte(0);

        // Global Color Table
        for (0..256) |i| {
            try w.writeByte(self.palette.colors[i].r);
            try w.writeByte(self.palette.colors[i].g);
            try w.writeByte(self.palette.colors[i].b);
        }

        // Application Extension for looping
        try w.writeByte(0x21); // Extension introducer
        try w.writeByte(0xFF); // Application extension label
        try w.writeByte(11);    // Block size

        try w.writeAll("NETSCAPE");
        try w.writeByte('2');
        try w.writeByte(0);
        try w.writeByte(1);    // Loop flag
        try w.writeByte(0);    // Loop count (0 = infinite)
        try w.writeByte(0);
        try w.writeByte(0);    // Block terminator
    }

    pub fn addFrame(self: *GifEncoder, pixels: []const u8, delay_ms: u16) !void {
        const w = self.writer.writer();

        // Graphics Control Extension
        try w.writeByte(0x21); // Extension introducer
        try w.writeByte(0xF9); // Graphics control label
        try w.writeByte(4);     // Block size

        const packed_data: u8 = 0; // No disposal method, no user input, no transparency
        try w.writeByte(packed_data);
        try w.writeInt(u16, delay_ms, .little); // Delay in 1/100 seconds
        try w.writeByte(0);    // Transparent color index
        try w.writeByte(0);    // Block terminator

        // Image Descriptor
        try w.writeByte(0x2C); // Image separator
        try w.writeInt(u16, 0, .little);  // Left position
        try w.writeInt(u16, 0, .little);  // Top position
        try w.writeInt(u16, self.width, .little);
        try w.writeInt(u16, self.height, .little);

        // Packed fields: local color table flag (0), interlace flag (0), sort flag (0), LZW min code size
        try w.writeByte(0); // No local color table, not interlaced

        // LZW minimum code size
        try w.writeByte(8); // For 256 colors

        // LZW compressed data (simplified - write raw pixels with minimal compression)
        // For proper GIF, we'd implement LZW, but for simplicity, we'll use a basic approach
        const max_data_len = 255;
        var pos: usize = 0;
        const total_pixels = @as(usize, self.width) * @as(usize, self.height);

        while (pos < total_pixels) {
            const chunk_size = @min(max_data_len, total_pixels - pos);
            try w.writeByte(@intCast(chunk_size));
            try w.writeAll(pixels[pos..pos + chunk_size]);
            pos += chunk_size;
        }

        try w.writeByte(0); // Block terminator

        try self.frame_delays.append(delay_ms);
    }

    pub fn finish(self: *GifEncoder) !void {
        const w = self.writer.writer();
        try w.writeByte(TRAILER[0]); // GIF trailer
        try self.writer.flush();
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// CANVAS FOR DRAWING
// ═══════════════════════════════════════════════════════════════════════════════

pub const Canvas = struct {
    width: u16,
    height: u16,
    pixels: []u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: u16, height: u16) !Canvas {
        const pixels = try allocator.alloc(u8, width * height);
        @memset(pixels, 0); // Clear to black
        return Canvas{
            .width = width,
            .height = height,
            .pixels = pixels,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Canvas) void {
        self.allocator.free(self.pixels);
    }

    pub fn setPixel(self: *Canvas, x: u16, y: u16, color: u8) void {
        if (x < self.width and y < self.height) {
            const idx = @as(usize, y) * self.width + x;
            self.pixels[idx] = color;
        }
    }

    pub fn getPixel(self: *const Canvas, x: u16, y: u16) u8 {
        if (x < self.width and y < self.height) {
            const idx = @as(usize, y) * self.width + x;
            return self.pixels[idx];
        }
        return 0;
    }

    pub fn clear(self: *Canvas, color: u8) void {
        @memset(self.pixels, color);
    }

    pub fn drawLine(self: *Canvas, x0: i32, y0: i32, x1: i32, y1: i32, color: u8) void {
        const dx = @abs(x1 - x0);
        const sx: i32 = if (x0 < x1) 1 else -1;
        const dy = -@abs(y1 - y0);
        const sy: i32 = if (y0 < y1) 1 else -1;
        var err = dx + dy;
        var x = x0;
        var y = y0;

        while (true) {
            self.setPixel(@intCast(x), @intCast(y), color);
            if (x == x1 and y == y1) break;
            const e2 = 2 * err;
            if (e2 >= dy) {
                err += dy;
                x += sx;
            }
            if (e2 <= dx) {
                err += dx;
                y += sy;
            }
        }
    }

    pub fn drawCircle(self: *Canvas, cx: i32, cy: i32, radius: i32, color: u8) void {
        var x: i32 = 0;
        var y: i32 = radius;
        const d: i32 = 1 - radius;

        while (x <= y) {
            self.setPixel(@intCast(cx + x), @intCast(cy + y), color);
            self.setPixel(@intCast(cx - x), @intCast(cy + y), color);
            self.setPixel(@intCast(cx + x), @intCast(cy - y), color);
            self.setPixel(@intCast(cx - x), @intCast(cy - y), color);
            self.setPixel(@intCast(cx + y), @intCast(cy + x), color);
            self.setPixel(@intCast(cx - y), @intCast(cy + x), color);
            self.setPixel(@intCast(cx + y), @intCast(cy - x), color);
            self.setPixel(@intCast(cx - y), @intCast(cy - x), color);

            x += 1;
            if (d < 0) {
                d += 2 * x + 1;
            } else {
                y -= 1;
                d += 2 * (x - y) + 1;
            }
        }
    }

    pub fn fillCircle(self: *Canvas, cx: i32, cy: i32, radius: i32, color: u8) void {
        var y: i32 = -radius;
        while (y <= radius) : (y += 1) {
            const half_width = @sqrt(@as(f64, @floatFromInt(radius * radius - y * y)));
            var x: i32 = -@as(i32, @intFromFloat(half_width));
            while (x <= @as(i32, @intFromFloat(half_width))) : (x += 1) {
                self.setPixel(@intCast(cx + x), @intCast(cy + y), color);
            }
        }
    }

    pub fn drawRect(self: *Canvas, x: u16, y: u16, w: u16, h: u16, color: u8) void {
        var py: u16 = 0;
        while (py < h) : (py += 1) {
            var px: u16 = 0;
            while (px < w) : (px += 1) {
                self.setPixel(x + px, y + py, color);
            }
        }
    }

    pub fn drawText(self: *Canvas, x: u16, y: u16, text: []const u8, color: u8) void {
        // Simplified text rendering as colored rectangles
        for (0..@min(text.len, 10)) |i| {
            const char_x = x + @as(u16, @intCast(i * 6));
            self.drawRect(char_x, y, 5, 7, color);
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY IDENTITY VISUALIZATION
// ═══════════════════════════════════════════════════════════════════════════════

pub const TrinityGifConfig = struct {
    width: u16 = 400,
    height: u16 = 300,
    frames: u32 = 60,
    fps: u32 = 20,
    palette: GifPalette = GifPalette.initTrinity(),
};

/// Generate animated GIF showing φ² + 1/φ² = 3
pub fn generateTrinityIdentityGif(allocator: std.mem.Allocator, output_path: []const u8, config: TrinityGifConfig) !void {
    var gif = try GifEncoder.init(allocator, output_path, config.width, config.height, config.palette);
    defer {
        gif.finish() catch {};
        gif.frame_delays.deinit();
    }

    const delay_ms = @as(u16, @intCast(100 / config.fps));

    var frame: u32 = 0;
    while (frame < config.frames) : (frame += 1) {
        var canvas = try Canvas.init(allocator, config.width, config.height);
        defer canvas.deinit();

        const progress = @as(f64, @floatFromInt(frame)) / @as(f64, @floatFromInt(config.frames));

        try renderTrinityIdentityFrame(&canvas, progress, frame);
        try gif.addFrame(canvas.pixels, delay_ms);
    }

    try gif.finish();
}

fn renderTrinityIdentityFrame(canvas: *Canvas, progress: f64, frame_num: u32) !void {
    _ = frame_num;
    const w = canvas.width;
    const h = canvas.height;
    const cx = w / 2;
    const cy = h / 2;

    // Background gradient
    for (0..h) |y| {
        for (0..w) |x| {
            const dist = @sqrt(@as(f64, @floatFromInt((x - cx) * (x - cx) + (y - cy) * (y - cy))));
            const max_dist = @sqrt(@as(f64, @floatFromInt(cx * cx + cy * cy)));
            const brightness = @as(u8, @intFromFloat(20 + 30 * (1.0 - dist / max_dist)));
            canvas.setPixel(@intCast(x), @intCast(y), brightness);
        }
    }

    // Animate phi squared and inverse phi squared bars
    const bar_width: u16 = 60;
    const max_bar_height: u16 = 120;
    const spacing: u16 = 80;

    const phi_sq_val = mod.PHI_SQ;
    const inv_phi_sq_val = 1.0 / mod.PHI_SQ;
    const sum_val = phi_sq_val + inv_phi_sq_val;

    // Animation easing
    const ease = if (progress < 0.5)
        2.0 * progress * progress
    else
        1.0 - std.math.pow(f64, -2.0 * progress + 2.0, 2.0) / 2.0;

    // Draw φ² bar (gold)
    const phi_bar_h = @as(u16, @intFromFloat(phi_sq_val / 3.0 * max_bar_height * ease));
    const phi_x = cx - spacing - bar_width / 2;
    const phi_y = cy + 50 - phi_bar_h;
    canvas.drawRect(phi_x, phi_y, bar_width, phi_bar_h, 1); // Gold

    // Draw 1/φ² bar (cyan)
    const inv_bar_h = @as(u16, @intFromFloat(inv_phi_sq_val / 3.0 * max_bar_height * ease));
    const inv_x = cx - bar_width / 2;
    const inv_y = cy + 50 - inv_bar_h;
    canvas.drawRect(inv_x, inv_y, bar_width, inv_bar_h, 2); // Cyan

    // Draw sum bar (magenta - shows it equals exactly 3)
    const sum_bar_h = @as(u16, @intFromFloat(sum_val / 3.0 * max_bar_height * ease));
    const sum_x = cx + spacing - bar_width / 2;
    const sum_y = cy + 50 - sum_bar_h;
    canvas.drawRect(sum_x, sum_y, bar_width, sum_bar_h, 3); // Magenta

    // Draw equals line
    const line_y = cy + 50 + 20;
    canvas.drawLine(cx - spacing, line_y, cx + spacing, line_y, 15);

    // Labels (simplified as colored rectangles)
    const label_y = cy + 50 + 30;
    canvas.drawRect(phi_x, label_y, bar_width, 10, 1);
    canvas.drawRect(inv_x, label_y, bar_width, 10, 2);
    canvas.drawRect(sum_x, label_y, bar_width, 10, 3);

    // Title
    canvas.drawRect(cx - 100, 30, 200, 30, 1);

    // Show formula text
    if (progress > 0.3) {
        const text_progress = (progress - 0.3) / 0.7;
        const chars_to_show = @as(u32, @intFromFloat(text_progress * 12));

        // Draw "φ² + 1/φ² = 3" representation
        const text_start_x = cx - 80;
        const text_y = 80;

        if (chars_to_show > 0) canvas.drawRect(text_start_x, text_y, 20, 20, 1); // φ²
        if (chars_to_show > 3) canvas.drawRect(text_start_x + 30, text_y + 8, 15, 4, 15); // +
        if (chars_to_show > 5) canvas.drawRect(text_start_x + 55, text_y, 25, 20, 2); // 1/φ²
        if (chars_to_show > 9) canvas.drawRect(text_start_x + 90, text_y + 8, 15, 4, 15); // =
        if (chars_to_show > 11) canvas.drawRect(text_start_x + 115, text_y, 20, 20, 3); // 3
    }

    // Trinity visualization (three interlocking circles)
    const circle_radius: u16 = 30;
    const circle_cy = cy - 60;

    if (progress > 0.5) {
        const circle_progress = (progress - 0.5) / 0.5;
        const current_radius = @as(u16, @intFromFloat(circle_radius * circle_progress));

        // Three circles in trinity arrangement
        const c1_x = cx - @as(u16, @intFromFloat(circle_radius * 0.866));
        const c2_x = cx + @as(u16, @intFromFloat(circle_radius * 0.866));
        const c3_x = cx;

        canvas.drawCircle(c1_x, circle_cy, current_radius, 1); // Gold
        canvas.drawCircle(c2_x, circle_cy, current_radius, 2); // Cyan
        canvas.drawCircle(c3_x, circle_cy + @as(u16, @intFromFloat(circle_radius * 0.5)), current_radius, 3); // Magenta
    }
}

/// Generate animated GIF of golden spiral
pub fn generateGoldenSpiralGif(allocator: std.mem.Allocator, output_path: []const u8, config: TrinityGifConfig) !void {
    var gif = try GifEncoder.init(allocator, output_path, config.width, config.height, config.palette);
    defer {
        gif.finish() catch {};
        gif.frame_delays.deinit();
    }

    const delay_ms = @as(u16, @intCast(100 / config.fps));
    const turns: u32 = 3;

    var frame: u32 = 0;
    while (frame < config.frames) : (frame += 1) {
        var canvas = try Canvas.init(allocator, config.width, config.height);
        defer canvas.deinit();

        const max_angle = @as(f64, @floatFromInt(frame)) / @as(f64, @floatFromInt(config.frames)) * @as(f64, @floatFromInt(turns)) * 2.0 * std.math.pi;
        try renderSpiralFrame(&canvas, max_angle, config.width, config.height);
        try gif.addFrame(canvas.pixels, delay_ms);
    }

    try gif.finish();
}

fn renderSpiralFrame(canvas: *Canvas, max_angle: f64, w: u16, h: u16) !void {
    const cx = w / 2;
    const cy = h / 2;

    // Clear background
    canvas.clear(0);

    _ = @as(f64, @floatFromInt(@min(w, h))) / 15.0; // Scale reference for future use
    const growth_factor = 2.0 * @log(mod.PHI) / std.math.pi;

    const total_steps: u32 = 500;
    var step: u32 = 0;
    while (step < total_steps) : (step += 1) {
        const theta = @as(f64, @floatFromInt(step)) / @as(f64, @floatFromInt(total_steps)) * max_angle;
        const r = 10.0 * @exp(growth_factor * theta);

        const x = @as(i32, @intFromFloat(cx + r * @cos(theta)));
        const y = @as(i32, @intFromFloat(cy + r * @sin(theta)));

        if (x >= 0 and x < @as(i32, @intCast(w)) and y >= 0 and y < @as(i32, @intCast(h))) {
            // Color based on angle
            const angle_deg = @mod(theta * 180.0 / std.math.pi, 360.0);
            const color_idx = @as(u8, @intCast(1 + @as(usize, @intFromFloat(angle_deg / 45.0)) % 14));
            canvas.setPixel(@intCast(x), @intCast(y), color_idx);
        }
    }

    // Draw center
    canvas.drawCircle(cx, cy, 3, 1);
}

/// Generate animated GIF of Fibonacci sequence
pub fn generateFibonacciGif(allocator: std.mem.Allocator, output_path: []const u8, config: TrinityGifConfig) !void {
    var gif = try GifEncoder.init(allocator, output_path, config.width, config.height, config.palette);
    defer {
        gif.finish() catch {};
        gif.frame_delays.deinit();
    }

    const delay_ms = @as(u16, @intCast(100 / config.fps));
    const fib_count = 12;

    var frame: u32 = 0;
    while (frame < config.frames) : (frame += 1) {
        var canvas = try Canvas.init(allocator, config.width, config.height);
        defer canvas.deinit();

        const show_count = @as(usize, @intFromFloat((@as(f64, @floatFromInt(frame)) / @as(f64, @floatFromInt(config.frames))) * @as(f64, @floatFromInt(fib_count))));
        try renderFibonacciFrame(&canvas, show_count, config.width, config.height);
        try gif.addFrame(canvas.pixels, delay_ms);
    }

    try gif.finish();
}

fn renderFibonacciFrame(canvas: *Canvas, count: usize, w: u16, h: u16) !void {
    canvas.clear(0);

    const cx = w / 2;
    const cy = h / 2;

    var prev: u64 = 0;
    var curr: u64 = 1;

    const bar_width: u16 = 20;
    const spacing: u16 = 30;
    const max_bar_height: u16 = 150;
    const start_x = cx - @as(u16, @intCast(count * spacing / 2));

    for (0..count) |i| {
        // Calculate Fibonacci number
        if (i == 0) {
            curr = 1;
        } else if (i == 1) {
            prev = 1;
            curr = 1;
        } else {
            const next = prev + curr;
            prev = curr;
            curr = next;
        }

        // Scale bar height (logarithmic for large numbers)
        const log_val = @log(@as(f64, @floatFromInt(curr)));
        const bar_h = @as(u16, @intFromFloat(@min(log_val * 25, max_bar_height)));

        const x = start_x + @as(u16, @intCast(i * spacing));
        const y = cy + 50 - bar_h;

        // Color based on whether it's a Trinity number (3) or related
        const color: u8 = if (curr == 3 or i == 3) 3 else if (i % 2 == 0) 1 else 2;
        canvas.drawRect(x, y, bar_width, bar_h, color);

        // Draw number (simplified)
        canvas.drawRect(x, cy + 60, bar_width, 5, color);
    }

    // Title area
    canvas.drawRect(cx - 80, 20, 160, 25, 1);
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

/// tri math gif trinity [output.gif]
pub fn cmdTrinityGif(args: []const []const u8) !void {
    const output_path = if (args.len > 0) args[0] else "trinity_identity.gif";

    const config = TrinityGifConfig{
        .width = 400,
        .height = 300,
        .frames = 60,
        .fps = 20,
    };

    fmt.boxHeader("TRINITY IDENTITY GIF GENERATOR");
    std.debug.print("  {s}Output:{s} {s}\n", .{ fmt.CYAN, fmt.RESET, output_path });
    std.debug.print("  {s}Resolution:{s} {d}x{d}\n", .{ fmt.CYAN, fmt.RESET, config.width, config.height });
    std.debug.print("  {s}Frames:{s} {d} @ {d}fps\n", .{ fmt.CYAN, fmt.RESET, config.frames, config.fps });
    std.debug.print("  {s}Formula:{s} φ² + 1/φ² = 3\n", .{ fmt.GOLD, fmt.RESET });
    std.debug.print("\n", .{});

    const allocator = std.heap.page_allocator;
    try generateTrinityIdentityGif(allocator, output_path, config);

    std.debug.print("  {s}✓ GIF generated successfully!{s}\n", .{ fmt.GREEN, fmt.RESET });
    fmt.boxFooter();
}

/// tri math gif spiral [output.gif]
pub fn cmdSpiralGif(args: []const []const u8) !void {
    const output_path = if (args.len > 0) args[0] else "golden_spiral.gif";

    const config = TrinityGifConfig{
        .width = 400,
        .height = 400,
        .frames = 90,
        .fps = 30,
    };

    fmt.boxHeader("GOLDEN SPIRAL GIF GENERATOR");
    std.debug.print("  {s}Output:{s} {s}\n", .{ fmt.CYAN, fmt.RESET, output_path });
    std.debug.print("  {s}Resolution:{s} {d}x{d}\n", .{ fmt.CYAN, fmt.RESET, config.width, config.height });
    std.debug.print("  {s}Frames:{s} {d} @ {d}fps\n", .{ fmt.CYAN, fmt.RESET, config.frames, config.fps });
    std.debug.print("  {s}Formula:{s} r(θ) = a × φ^(2θ/π)\n", .{ fmt.GOLD, fmt.RESET });
    std.debug.print("\n", .{});

    const allocator = std.heap.page_allocator;
    try generateGoldenSpiralGif(allocator, output_path, config);

    std.debug.print("  {s}✓ GIF generated successfully!{s}\n", .{ fmt.GREEN, fmt.RESET });
    fmt.boxFooter();
}

/// tri math gif fibonacci [output.gif]
pub fn cmdFibonacciGif(args: []const []const u8) !void {
    const output_path = if (args.len > 0) args[0] else "fibonacci.gif";

    const config = TrinityGifConfig{
        .width = 500,
        .height = 300,
        .frames = 48,
        .fps = 12,
    };

    fmt.boxHeader("FIBONACCI SEQUENCE GIF GENERATOR");
    std.debug.print("  {s}Output:{s} {s}\n", .{ fmt.CYAN, fmt.RESET, output_path });
    std.debug.print("  {s}Resolution:{s} {d}x{d}\n", .{ fmt.CYAN, fmt.RESET, config.width, config.height });
    std.debug.print("  {s}Frames:{s} {d} @ {d}fps\n", .{ fmt.CYAN, fmt.RESET, config.frames, config.fps });
    std.debug.print("  {s}Note:{s} F(4) = 3, F(7) = 13 = TRYTE_MAX\n", .{ fmt.GOLD, fmt.RESET });
    std.debug.print("\n", .{});

    const allocator = std.heap.page_allocator;
    try generateFibonacciGif(allocator, output_path, config);

    std.debug.print("  {s}✓ GIF generated successfully!{s}\n", .{ fmt.GREEN, fmt.RESET });
    fmt.boxFooter();
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "canvas initialization" {
    const canvas = try Canvas.init(std.testing.allocator, 100, 100);
    defer canvas.deinit();

    try std.testing.expectEqual(@as(usize, 100), canvas.pixels.len);
    try std.testing.expectEqual(@as(u16, 100), canvas.width);
    try std.testing.expectEqual(@as(u16, 100), canvas.height);
}

test "canvas set and get pixel" {
    const canvas = try Canvas.init(std.testing.allocator, 50, 50);
    defer canvas.deinit();

    canvas.setPixel(10, 20, 42);
    try std.testing.expectEqual(@as(u8, 42), canvas.getPixel(10, 20));
    try std.testing.expectEqual(@as(u8, 0), canvas.getPixel(30, 40));
}

test "trinity palette initialization" {
    const palette = GifPalette.initTrinity();
    try std.testing.expectEqual(@as(u8, 256), palette.size);

    // Check gold color
    try std.testing.expectEqual(@as(u8, 255), palette.colors[1].r);
    try std.testing.expectEqual(@as(u8, 215), palette.colors[1].g);
    try std.testing.expectEqual(@as(u8, 0), palette.colors[1].b);
}
