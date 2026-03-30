// =============================================================================
// EMERGENT PHOTON AI DEMO v0.2 - Multi-Modal Interactive Visualization
// Real-time emergent wave generation with Text, Image, Audio output
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");
const photon = @import("photon.zig");
const rl = @cImport({
    @cInclude("raylib.h");
});

// =============================================================================
// CONFIGURATION
// =============================================================================

const GRID_SIZE: usize = 128; // 128x128 photon grid
var g_screen_width: c_int = 1512; // Updated at runtime
var g_screen_height: c_int = 982; // Updated at runtime
const PIXEL_SIZE: c_int = 6; // Each photon = 6x6 pixels

// Font state (Montserrat)
var g_font: rl.Font = undefined;
var g_font_loaded: bool = false;

// Colors (Trinity theme)
const BG_COLOR = rl.Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xFF };
const ACCENT_COLOR = rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = 0xFF };
const GOLDEN_COLOR = rl.Color{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = 0xFF };
const TEXT_COLOR = rl.Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF };
const MUTED_COLOR = rl.Color{ .r = 0xAA, .g = 0xAA, .b = 0xAA, .a = 0xFF };

// =============================================================================
// DEMO STATE
// =============================================================================

const DemoMode = enum {
    point_source,
    line_wave,
    golden_spiral,
    text_emergence,
    free_draw,
};

// =============================================================================
// MAIN
// =============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize photon grid
    var grid = try photon.PhotonGrid.init(allocator, GRID_SIZE, GRID_SIZE);
    defer grid.deinit();

    // State
    var mode: DemoMode = .point_source;
    var paused = false;
    var show_stats = true;
    var generated_text: [256]u8 = undefined;
    var text_len: usize = 0;

    // Status message for feedback
    var status_msg: [64]u8 = undefined;
    var status_len: usize = 0;
    var status_timer: f32 = 0;

    // Audio state
    var audio_playing = false;
    var spectrum: [64]f32 = undefined;
    @memset(&spectrum, 0);

    // Get native monitor resolution for fullscreen
    const monitor = rl.GetCurrentMonitor();
    const monitor_width = rl.GetMonitorWidth(monitor);
    const monitor_height = rl.GetMonitorHeight(monitor);

    // Raylib init - borderless fullscreen for native quality
    rl.SetConfigFlags(rl.FLAG_BORDERLESS_WINDOWED_MODE | rl.FLAG_VSYNC_HINT | rl.FLAG_MSAA_4X_HINT);
    rl.InitWindow(monitor_width, monitor_height, "EMERGENT PHOTON AI v0.2 | Multi-Modal | TRINITY");
    defer rl.CloseWindow();

    // Store screen dimensions in globals
    g_screen_width = monitor_width;
    g_screen_height = monitor_height;

    // Init audio device
    rl.InitAudioDevice();
    defer rl.CloseAudioDevice();

    // Load San Francisco font at high resolution for crisp rendering
    const font_paths = [_][*:0]const u8{
        "assets/fonts/SFPro.ttf", // Apple San Francisco - BEST
        "assets/fonts/Montserrat.ttf", // Montserrat fallback
        "assets/fonts/Roboto-Regular.ttf", // Roboto fallback
    };
    for (font_paths) |path| {
        const font = rl.LoadFontEx(path, 96, null, 0);
        if (font.texture.id != 0) {
            g_font = font;
            g_font_loaded = true;
            rl.SetTextureFilter(font.texture, rl.TEXTURE_FILTER_TRILINEAR);
            break;
        }
    }
    defer if (g_font_loaded) rl.UnloadFont(g_font);

    rl.SetTargetFPS(60);

    // Main loop
    while (!rl.WindowShouldClose()) {
        const dt = rl.GetFrameTime();

        // Handle input
        handleInput(allocator, &grid, &mode, &paused, &show_stats, &generated_text, &text_len, &status_msg, &status_len, &status_timer, &audio_playing, &spectrum);

        // Physics step (if not paused)
        if (!paused) {
            grid.stepSIMD();
        }

        // Update status timer
        if (status_timer > 0) {
            status_timer -= dt;
        }

        // Cursor interaction
        if (rl.IsMouseButtonDown(rl.MOUSE_BUTTON_LEFT)) {
            const mx = @as(f32, @floatFromInt(rl.GetMouseX())) / @as(f32, @floatFromInt(PIXEL_SIZE));
            const my = @as(f32, @floatFromInt(rl.GetMouseY() - 60)) / @as(f32, @floatFromInt(PIXEL_SIZE));

            if (my > 0 and mx < @as(f32, @floatFromInt(GRID_SIZE)) and my < @as(f32, @floatFromInt(GRID_SIZE))) {
                grid.setCursor(mx, my, 0.8);
            }
        }

        // Update spectrum
        const synth = photon.AudioSynthesizer.init(&grid);
        synth.getSpectrum(&spectrum);

        // Draw
        rl.BeginDrawing();
        defer rl.EndDrawing();

        rl.ClearBackground(BG_COLOR);

        // Draw header
        drawHeader(mode, paused, audio_playing);

        // Draw photon grid
        drawGrid(&grid);

        // Draw stats panel
        if (show_stats) {
            drawStats(&grid, &spectrum);
        }

        // Draw generated text
        if (text_len > 0) {
            drawGeneratedText(&generated_text, text_len);
        }

        // Draw status message
        if (status_timer > 0 and status_len > 0) {
            const alpha: u8 = @intFromFloat(@min(255.0, status_timer * 255.0));
            const status_color = rl.Color{ .r = 0x00, .g = 0xFF, .b = 0x88, .a = alpha };
            var status_buf: [65]u8 = undefined;
            @memcpy(status_buf[0..status_len], status_msg[0..status_len]);
            status_buf[status_len] = 0;
            drawText(@ptrCast(&status_buf), 800, 140, 16, status_color);
        }

        // Draw help
        drawHelp();
    }
}

fn handleInput(
    allocator: std.mem.Allocator,
    grid: *photon.PhotonGrid,
    mode: *DemoMode,
    paused: *bool,
    show_stats: *bool,
    generated_text: *[256]u8,
    text_len: *usize,
    status_msg: *[64]u8,
    status_len: *usize,
    status_timer: *f32,
    audio_playing: *bool,
    spectrum: *[64]f32,
) void {
    _ = spectrum;
    _ = audio_playing;

    // Mode switching
    if (rl.IsKeyPressed(rl.KEY_ONE)) {
        mode.* = .point_source;
        resetGrid(grid);
    }
    if (rl.IsKeyPressed(rl.KEY_TWO)) {
        mode.* = .line_wave;
        resetGrid(grid);
        grid.injectWave(.{ .line_wave = .{
            .position = GRID_SIZE / 2,
            .horizontal = true,
            .amplitude = 1.0,
        } });
    }
    if (rl.IsKeyPressed(rl.KEY_THREE)) {
        mode.* = .golden_spiral;
        resetGrid(grid);
        grid.injectWave(.{ .golden_spiral = .{
            .center_x = GRID_SIZE / 2,
            .center_y = GRID_SIZE / 2,
            .scale = 2.0,
            .amplitude = 1.0,
        } });
    }
    if (rl.IsKeyPressed(rl.KEY_FOUR)) {
        mode.* = .text_emergence;
        resetGrid(grid);
        grid.injectWave(.{ .text_seed = .{
            .text = "TRINITY",
            .x = GRID_SIZE / 4,
            .y = GRID_SIZE / 2,
        } });
    }
    if (rl.IsKeyPressed(rl.KEY_FIVE)) {
        mode.* = .free_draw;
        resetGrid(grid);
    }

    // Controls
    if (rl.IsKeyPressed(rl.KEY_SPACE)) paused.* = !paused.*;
    if (rl.IsKeyPressed(rl.KEY_S)) show_stats.* = !show_stats.*;
    if (rl.IsKeyPressed(rl.KEY_R)) resetGrid(grid);

    // [G] Generate basic text
    if (rl.IsKeyPressed(rl.KEY_G)) {
        var gen = photon.EmergentTextGenerator.init(grid);
        text_len.* = gen.generate("WAVE", 32, generated_text);
        setStatus(status_msg, status_len, status_timer, "Text generated!");
    }

    // [T] Generate advanced text
    if (rl.IsKeyPressed(rl.KEY_T)) {
        var adv_gen = photon.AdvancedTextGenerator.init(grid);
        text_len.* = adv_gen.generate("PHOTON", 48, generated_text);
        setStatus(status_msg, status_len, status_timer, "Advanced text generated!");
    }

    // [I] Export image (PPM format)
    if (rl.IsKeyPressed(rl.KEY_I)) {
        const exporter = photon.ImageExporter.init(grid);
        if (exporter.exportPPM(allocator)) |ppm_data| {
            // Save to file
            const timestamp = @as(u64, @intCast(std.time.timestamp()));
            var filename: [64]u8 = undefined;
            const fname = std.fmt.bufPrintZ(&filename, "photon_{d}.ppm", .{timestamp}) catch "photon.ppm";

            if (std.fs.cwd().createFile(fname, .{})) |file| {
                file.writeAll(ppm_data) catch {};
                file.close();
                setStatus(status_msg, status_len, status_timer, "Image saved!");
            } else |_| {
                setStatus(status_msg, status_len, status_timer, "Image save failed!");
            }
            allocator.free(ppm_data);
        } else |_| {
            setStatus(status_msg, status_len, status_timer, "Export failed!");
        }
    }

    // [A] Generate and play audio (save WAV file)
    if (rl.IsKeyPressed(rl.KEY_A)) {
        const synth = photon.AudioSynthesizer.init(grid);
        if (synth.generatePCM16(allocator, 1000)) |pcm_data| { // 1 second
            defer allocator.free(pcm_data);

            // Create WAV file
            const timestamp = @as(u64, @intCast(std.time.timestamp()));
            var filename: [64]u8 = undefined;
            const fname = std.fmt.bufPrintZ(&filename, "photon_{d}.wav", .{timestamp}) catch "photon.wav";

            if (std.fs.cwd().createFile(fname, .{})) |file| {
                // Write WAV header
                const header = photon.WavHeader.init(44100, @intCast(pcm_data.len));
                const header_bytes = header.toBytes();
                file.writeAll(&header_bytes) catch {};

                // Write PCM data
                const pcm_bytes = std.mem.sliceAsBytes(pcm_data);
                file.writeAll(pcm_bytes) catch {};
                file.close();

                setStatus(status_msg, status_len, status_timer, "Audio saved as WAV!");
            } else |_| {
                setStatus(status_msg, status_len, status_timer, "Audio save failed!");
            }
        } else |_| {
            setStatus(status_msg, status_len, status_timer, "Audio gen failed!");
        }
    }

    // Inject point on click
    if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_RIGHT)) {
        const mx = @as(usize, @intCast(@divTrunc(@max(0, rl.GetMouseX()), PIXEL_SIZE)));
        const my = @as(usize, @intCast(@divTrunc(@max(0, rl.GetMouseY() - 60), PIXEL_SIZE)));

        if (mx < GRID_SIZE and my < GRID_SIZE) {
            grid.injectWave(.{ .point_source = .{
                .x = mx,
                .y = my,
                .amplitude = 1.0,
            } });
        }
    }
}

fn setStatus(msg: *[64]u8, len: *usize, timer: *f32, text: []const u8) void {
    const copy_len = @min(text.len, 64);
    @memcpy(msg[0..copy_len], text[0..copy_len]);
    len.* = copy_len;
    timer.* = 2.0; // Show for 2 seconds
}

fn resetGrid(grid: *photon.PhotonGrid) void {
    for (grid.photons) |*p| {
        p.amplitude = 0.0;
        p.interference = 0.0;
    }
    grid.time = 0.0;
}

/// Draw text with San Francisco font (high quality)
fn drawText(text: [*:0]const u8, x: c_int, y: c_int, size: c_int, color: rl.Color) void {
    if (g_font_loaded) {
        const font_size: f32 = @floatFromInt(size);
        const spacing: f32 = font_size * 0.05; // SF Pro spacing
        rl.DrawTextEx(g_font, text, .{ .x = @floatFromInt(x), .y = @floatFromInt(y) }, font_size, spacing, color);
    } else {
        rl.DrawText(text, x, y, size, color); // Fallback to default font
    }
}

fn drawHeader(mode: DemoMode, paused: bool, audio_playing: bool) void {
    _ = audio_playing;

    // Title bar
    rl.DrawRectangle(0, 0, g_screen_width, 50, rl.Color{ .r = 0x05, .g = 0x05, .b = 0x05, .a = 0xFF });

    drawText("EMERGENT PHOTON AI v0.2", 16, 14, 24, ACCENT_COLOR);

    // Mode indicator
    const mode_str: [*:0]const u8 = switch (mode) {
        .point_source => "Point Source [1]",
        .line_wave => "Line Wave [2]",
        .golden_spiral => "Golden Spiral [3]",
        .text_emergence => "Text Emergence [4]",
        .free_draw => "Free Draw [5]",
    };
    drawText(mode_str, 320, 18, 18, GOLDEN_COLOR);

    // Paused indicator
    if (paused) {
        drawText("PAUSED", 550, 18, 18, rl.Color{ .r = 0xFF, .g = 0x5F, .b = 0x57, .a = 0xFF });
    }

    // Multi-modal badge
    drawText("MULTI-MODAL", 650, 18, 14, rl.Color{ .r = 0x8B, .g = 0x5C, .b = 0xF6, .a = 0xFF });

    // Trinity formula
    drawText("phi^2 + 1/phi^2 = 3", g_screen_width - 200, 18, 16, rl.Color{ .r = 0x88, .g = 0x88, .b = 0x88, .a = 0xFF });
}

fn drawGrid(grid: *photon.PhotonGrid) void {
    const y_offset: c_int = 60;

    for (0..grid.height) |y| {
        for (0..grid.width) |x| {
            const p = grid.get(x, y);
            const rgb = p.toRGB();

            const px: c_int = @intCast(x * PIXEL_SIZE);
            const py: c_int = @intCast(y * PIXEL_SIZE + @as(usize, @intCast(y_offset)));

            const color = rl.Color{
                .r = rgb[0],
                .g = rgb[1],
                .b = rgb[2],
                .a = 255,
            };

            rl.DrawRectangle(px, py, PIXEL_SIZE - 1, PIXEL_SIZE - 1, color);
        }
    }
}

fn drawStats(grid: *photon.PhotonGrid, spectrum: *const [64]f32) void {
    const x: c_int = 800;
    var y: c_int = 200;
    const line_h: c_int = 20;

    drawText("STATISTICS", x, y, 18, ACCENT_COLOR);
    y += line_h + 5;

    var buf: [64]u8 = undefined;

    // Time
    const time_str = std.fmt.bufPrintZ(&buf, "Time: {d:.2}s", .{grid.time}) catch "?";
    drawText(time_str, x, y, 14, TEXT_COLOR);
    y += line_h;

    // Energy
    const energy_str = std.fmt.bufPrintZ(&buf, "Energy: {d:.4}", .{grid.total_energy}) catch "?";
    drawText(energy_str, x, y, 14, TEXT_COLOR);
    y += line_h;

    // Amplitude range
    const amp_str = std.fmt.bufPrintZ(&buf, "Amp: [{d:.2}, {d:.2}]", .{ grid.min_amplitude, grid.max_amplitude }) catch "?";
    drawText(amp_str, x, y, 14, TEXT_COLOR);
    y += line_h;

    // Grid size
    const size_str = std.fmt.bufPrintZ(&buf, "Grid: {d}x{d}", .{ grid.width, grid.height }) catch "?";
    drawText(size_str, x, y, 14, TEXT_COLOR);
    y += line_h;

    // Photons
    const photon_str = std.fmt.bufPrintZ(&buf, "Photons: {d}", .{grid.photons.len}) catch "?";
    drawText(photon_str, x, y, 14, TEXT_COLOR);
    y += line_h + 10;

    // Spectrum visualization
    drawText("SPECTRUM", x, y, 14, ACCENT_COLOR);
    y += 18;

    const bar_width: c_int = 3;
    const max_height: c_int = 40;

    for (0..@min(64, spectrum.len)) |i| {
        const bar_x = x + @as(c_int, @intCast(i)) * (bar_width + 1);
        const bar_h: c_int = @intFromFloat(spectrum[i] * @as(f32, @floatFromInt(max_height)));
        const clamped_h = @max(1, @min(max_height, bar_h));

        // Color based on height
        const intensity: u8 = @intFromFloat(@min(255.0, spectrum[i] * 500.0));
        const bar_color = rl.Color{ .r = 0x00, .g = intensity, .b = 0x88, .a = 0xFF };

        rl.DrawRectangle(bar_x, y + max_height - clamped_h, bar_width, clamped_h, bar_color);
    }
}

fn drawGeneratedText(generated_text: *const [256]u8, text_len: usize) void {
    drawText("GENERATED TEXT:", 800, 80, 14, ACCENT_COLOR);

    var text_buf: [257]u8 = undefined;
    @memcpy(text_buf[0..text_len], generated_text[0..text_len]);
    text_buf[text_len] = 0;
    drawText(@ptrCast(&text_buf), 800, 100, 16, GOLDEN_COLOR);
}

fn drawHelp() void {
    const x: c_int = 800;
    var y: c_int = 430;
    const line_h: c_int = 16;

    drawText("CONTROLS", x, y, 16, ACCENT_COLOR);
    y += line_h + 5;

    drawText("[1-5] Mode", x, y, 12, MUTED_COLOR);
    y += line_h;
    drawText("[SPACE] Pause", x, y, 12, MUTED_COLOR);
    y += line_h;
    drawText("[R] Reset", x, y, 12, MUTED_COLOR);
    y += line_h;
    drawText("[S] Stats", x, y, 12, MUTED_COLOR);
    y += line_h + 5;

    drawText("MULTI-MODAL OUTPUT:", x, y, 14, rl.Color{ .r = 0x8B, .g = 0x5C, .b = 0xF6, .a = 0xFF });
    y += line_h + 2;

    drawText("[G] Text (basic)", x, y, 12, MUTED_COLOR);
    y += line_h;
    drawText("[T] Text (advanced)", x, y, 12, MUTED_COLOR);
    y += line_h;
    drawText("[I] Image (PPM)", x, y, 12, MUTED_COLOR);
    y += line_h;
    drawText("[A] Audio (WAV)", x, y, 12, MUTED_COLOR);
    y += line_h + 5;

    drawText("[LMB] Perturb", x, y, 12, MUTED_COLOR);
    y += line_h;
    drawText("[RMB] Point Source", x, y, 12, MUTED_COLOR);

    // Footer
    drawText("KOSCHEI IS IMMORTAL", x, g_screen_height - 30, 12, rl.Color{ .r = 0x44, .g = 0x44, .b = 0x44, .a = 0xFF });
}
