// =============================================================================
// PHOTON TERMINAL v1.0 - TERNARY EMERGENT TUI
// Not a grid of cells — a living wave field.
// Text emerges from standing waves. Input perturbs reality.
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");
const photon = @import("photon.zig");
const math = std.math;
const posix = std.posix;

// =============================================================================
// COSMIC CONSTANTS
// =============================================================================

const PHI: f32 = 1.6180339887;
const PHI_INV: f32 = 0.6180339887;
const TAU: f32 = 6.28318530718;

// Terminal grid (photon resolution)
const GRID_WIDTH: usize = 120;
const GRID_HEIGHT: usize = 40;

// ANSI color codes (256-color mode)
const ANSI_RESET = "\x1b[0m";
const ANSI_CLEAR = "\x1b[2J\x1b[H";
const ANSI_HIDE_CURSOR = "\x1b[?25l";
const ANSI_SHOW_CURSOR = "\x1b[?25h";
const ANSI_ALT_SCREEN = "\x1b[?1049h";
const ANSI_MAIN_SCREEN = "\x1b[?1049l";

// =============================================================================
// TERMINAL RAW MODE
// =============================================================================

const TerminalState = struct {
    original_termios: posix.termios,
    stdin_fd: posix.fd_t,

    pub fn init() !TerminalState {
        const stdin_fd = posix.STDIN_FILENO;
        const original = try posix.tcgetattr(stdin_fd);

        var raw = original;
        // Disable canonical mode, echo, signals
        raw.lflag.ICANON = false;
        raw.lflag.ECHO = false;
        raw.lflag.ISIG = false;
        raw.lflag.IEXTEN = false;
        // Disable input processing
        raw.iflag.IXON = false;
        raw.iflag.ICRNL = false;
        raw.iflag.BRKINT = false;
        raw.iflag.INPCK = false;
        raw.iflag.ISTRIP = false;
        // Disable output processing
        raw.oflag.OPOST = false;
        // Set read timeout (non-blocking with timeout)
        raw.cc[@intFromEnum(posix.V.MIN)] = 0;
        raw.cc[@intFromEnum(posix.V.TIME)] = 1; // 100ms timeout

        try posix.tcsetattr(stdin_fd, .FLUSH, raw);

        return .{
            .original_termios = original,
            .stdin_fd = stdin_fd,
        };
    }

    pub fn deinit(self: *TerminalState) void {
        posix.tcsetattr(self.stdin_fd, .FLUSH, self.original_termios) catch {};
    }

    pub fn readKey(self: *TerminalState) ?u8 {
        var buf: [1]u8 = undefined;
        const n = posix.read(self.stdin_fd, &buf) catch return null;
        if (n == 0) return null;
        return buf[0];
    }

    pub fn readKeyNonBlocking(self: *TerminalState) ?u8 {
        // Check if data available
        var fds = [_]posix.pollfd{.{
            .fd = self.stdin_fd,
            .events = posix.POLL.IN,
            .revents = 0,
        }};

        const ready = posix.poll(&fds, 0) catch return null;
        if (ready == 0) return null;

        return self.readKey();
    }
};

// =============================================================================
// ANSI RENDERING
// =============================================================================

const AnsiRenderer = struct {
    buffer: std.ArrayListUnmanaged(u8),
    allocator: std.mem.Allocator,
    width: usize,
    height: usize,

    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) AnsiRenderer {
        return .{
            .buffer = .{},
            .allocator = allocator,
            .width = width,
            .height = height,
        };
    }

    pub fn deinit(self: *AnsiRenderer) void {
        self.buffer.deinit(self.allocator);
    }

    pub fn clear(self: *AnsiRenderer) void {
        self.buffer.clearRetainingCapacity();
    }

    pub fn moveTo(self: *AnsiRenderer, x: usize, y: usize) !void {
        var buf: [32]u8 = undefined;
        const s = std.fmt.bufPrint(&buf, "\x1b[{d};{d}H", .{ y + 1, x + 1 }) catch return;
        try self.buffer.appendSlice(self.allocator, s);
    }

    pub fn setColor256(self: *AnsiRenderer, fg: u8, bg: u8) !void {
        var buf: [32]u8 = undefined;
        const s = std.fmt.bufPrint(&buf, "\x1b[38;5;{d};48;5;{d}m", .{ fg, bg }) catch return;
        try self.buffer.appendSlice(self.allocator, s);
    }

    pub fn setColorRGB(self: *AnsiRenderer, r: u8, g: u8, b: u8) !void {
        var buf: [32]u8 = undefined;
        const s = std.fmt.bufPrint(&buf, "\x1b[38;2;{d};{d};{d}m", .{ r, g, b }) catch return;
        try self.buffer.appendSlice(self.allocator, s);
    }

    pub fn setBgRGB(self: *AnsiRenderer, r: u8, g: u8, b: u8) !void {
        var buf: [32]u8 = undefined;
        const s = std.fmt.bufPrint(&buf, "\x1b[48;2;{d};{d};{d}m", .{ r, g, b }) catch return;
        try self.buffer.appendSlice(self.allocator, s);
    }

    pub fn writeChar(self: *AnsiRenderer, c: u8) !void {
        try self.buffer.append(self.allocator, c);
    }

    pub fn writeStr(self: *AnsiRenderer, s: []const u8) !void {
        try self.buffer.appendSlice(self.allocator, s);
    }

    pub fn reset(self: *AnsiRenderer) !void {
        try self.buffer.appendSlice(self.allocator, ANSI_RESET);
    }

    pub fn flush(self: *AnsiRenderer) !void {
        _ = posix.write(posix.STDOUT_FILENO, self.buffer.items) catch {};
    }
};

// =============================================================================
// EMERGENT GLYPH MAPPING
// =============================================================================

const GlyphMapper = struct {
    // Map wave amplitude to ASCII characters
    // Higher amplitude = denser glyph
    const GLYPHS = " .'`^\",:;Il!i><~+_-?][}{1)(|/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$";

    pub fn amplitudeToGlyph(amplitude: f32) u8 {
        const normalized = @min(1.0, @max(0.0, @abs(amplitude)));
        const idx: usize = @intFromFloat(normalized * @as(f32, @floatFromInt(GLYPHS.len - 1)));
        return GLYPHS[idx];
    }

    pub fn amplitudeToColor(amplitude: f32, phase: f32, hue_offset: f32) [3]u8 {
        const h = @mod(hue_offset + phase * 60.0, 360.0);
        const s: f32 = 0.8;
        const v = @min(1.0, @abs(amplitude));
        return hsvToRgb(h, s, v);
    }
};

// =============================================================================
// EMERGENT TEXT SYSTEM
// =============================================================================

const MAX_TEXT_WAVES = 16;
const MAX_TEXT_LEN = 128;

const TextWave = struct {
    text: [MAX_TEXT_LEN]u8,
    len: usize,
    x: usize,
    y: usize,
    phase: f32,
    amplitude: f32,
    life: f32,
    is_input: bool, // User input vs system output

    pub fn spawn(x: usize, y: usize, text: []const u8, is_input: bool) TextWave {
        var tw = TextWave{
            .text = undefined,
            .len = @min(text.len, MAX_TEXT_LEN),
            .x = x,
            .y = y,
            .phase = 0,
            .amplitude = 1.0,
            .life = 1.0,
            .is_input = is_input,
        };
        @memcpy(tw.text[0..tw.len], text[0..tw.len]);
        return tw;
    }

    pub fn update(self: *TextWave, dt: f32) void {
        self.phase += dt * 3.0;
        self.life -= dt * 0.1;
    }

    pub fn isAlive(self: *const TextWave) bool {
        return self.life > 0;
    }

    // Inject text as wave perturbation into grid
    pub fn injectIntoGrid(self: *const TextWave, grid: *photon.PhotonGrid) void {
        if (!self.isAlive()) return;

        for (0..self.len) |i| {
            const gx = self.x + i;
            if (gx >= grid.width) break;

            const c = self.text[i];
            const char_amp = @as(f32, @floatFromInt(c)) / 128.0;

            // Create standing wave pattern for each character
            const wave_y_start = if (self.y >= 2) self.y - 2 else 0;
            const wave_y_end = @min(self.y + 3, grid.height);

            for (wave_y_start..wave_y_end) |gy| {
                if (gx < grid.width and gy < grid.height) {
                    const dy = @as(f32, @floatFromInt(gy)) - @as(f32, @floatFromInt(self.y));
                    const wave = @sin(self.phase + @as(f32, @floatFromInt(i)) * 0.5) * @exp(-dy * dy * 0.2);
                    grid.getMut(gx, gy).amplitude += char_amp * wave * self.amplitude * self.life;
                    grid.getMut(gx, gy).hue = if (self.is_input) 180.0 else 120.0; // Cyan input, green output
                }
            }
        }
    }
};

const TextWaveSystem = struct {
    waves: [MAX_TEXT_WAVES]TextWave,
    count: usize,

    pub fn init() TextWaveSystem {
        var sys = TextWaveSystem{
            .waves = undefined,
            .count = 0,
        };
        for (&sys.waves) |*w| {
            w.life = 0;
        }
        return sys;
    }

    pub fn spawn(self: *TextWaveSystem, x: usize, y: usize, text: []const u8, is_input: bool) void {
        for (&self.waves) |*w| {
            if (!w.isAlive()) {
                w.* = TextWave.spawn(x, y, text, is_input);
                return;
            }
        }
    }

    pub fn update(self: *TextWaveSystem, dt: f32) void {
        for (&self.waves) |*w| {
            if (w.isAlive()) {
                w.update(dt);
            }
        }
    }

    pub fn injectAll(self: *TextWaveSystem, grid: *photon.PhotonGrid) void {
        for (&self.waves) |*w| {
            w.injectIntoGrid(grid);
        }
    }
};

// =============================================================================
// INPUT BUFFER
// =============================================================================

const InputBuffer = struct {
    buffer: [256]u8,
    len: usize,
    cursor: usize,
    active: bool,

    pub fn init() InputBuffer {
        return .{
            .buffer = undefined,
            .len = 0,
            .cursor = 0,
            .active = true,
        };
    }

    pub fn addChar(self: *InputBuffer, c: u8) void {
        if (self.len < 255) {
            self.buffer[self.len] = c;
            self.len += 1;
            self.cursor = self.len;
        }
    }

    pub fn backspace(self: *InputBuffer) void {
        if (self.len > 0) {
            self.len -= 1;
            self.cursor = self.len;
        }
    }

    pub fn clear(self: *InputBuffer) void {
        self.len = 0;
        self.cursor = 0;
    }

    pub fn getText(self: *const InputBuffer) []const u8 {
        return self.buffer[0..self.len];
    }
};

// =============================================================================
// PHOTON TERMINAL
// =============================================================================

pub const PhotonTerminal = struct {
    allocator: std.mem.Allocator,
    grid: photon.PhotonGrid,
    renderer: AnsiRenderer,
    terminal: TerminalState,
    text_waves: TextWaveSystem,
    input: InputBuffer,
    time: f32,
    cursor_x: usize,
    cursor_y: usize,
    running: bool,
    mode: TerminalMode,
    output_lines: std.ArrayListUnmanaged([]const u8),
    hue_offset: f32,

    const TerminalMode = enum {
        wave, // Pure wave exploration
        chat, // Chat mode (input → response)
        code, // Code generation mode
        tools, // Tool execution visualization
    };

    pub fn init(allocator: std.mem.Allocator) !*PhotonTerminal {
        const self = try allocator.create(PhotonTerminal);

        self.* = .{
            .allocator = allocator,
            .grid = try photon.PhotonGrid.init(allocator, GRID_WIDTH, GRID_HEIGHT),
            .renderer = AnsiRenderer.init(allocator, GRID_WIDTH, GRID_HEIGHT),
            .terminal = try TerminalState.init(),
            .text_waves = TextWaveSystem.init(),
            .input = InputBuffer.init(),
            .time = 0,
            .cursor_x = GRID_WIDTH / 2,
            .cursor_y = GRID_HEIGHT - 3,
            .running = true,
            .mode = .chat,
            .output_lines = .{},
            .hue_offset = 120.0, // Start with green
        };

        return self;
    }

    pub fn deinit(self: *PhotonTerminal) void {
        self.terminal.deinit();
        self.renderer.deinit();
        self.grid.deinit();
        for (self.output_lines.items) |line| {
            self.allocator.free(line);
        }
        self.output_lines.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    fn writeStdout(data: []const u8) void {
        _ = posix.write(posix.STDOUT_FILENO, data) catch {};
    }

    pub fn run(self: *PhotonTerminal) !void {
        // Enter alternate screen and hide cursor
        writeStdout(ANSI_ALT_SCREEN);
        writeStdout(ANSI_HIDE_CURSOR);
        defer {
            writeStdout(ANSI_SHOW_CURSOR);
            writeStdout(ANSI_MAIN_SCREEN);
        }

        // Welcome message
        self.text_waves.spawn(5, 3, "PHOTON TERMINAL v1.0", false);
        self.text_waves.spawn(5, 5, "Type to perturb reality. ESC to exit.", false);
        self.text_waves.spawn(5, 7, "phi^2 + 1/phi^2 = 3 = TRINITY", false);

        // Initial wave pattern
        self.grid.injectWave(.{ .golden_spiral = .{
            .center_x = GRID_WIDTH / 2,
            .center_y = GRID_HEIGHT / 2,
            .scale = 2.0,
            .amplitude = 0.5,
        } });

        var timer = try std.time.Timer.start();

        while (self.running) {
            const dt = @as(f32, @floatFromInt(timer.lap())) / 1_000_000_000.0;
            self.time += dt;

            // Process input
            try self.processInput();

            // Update physics
            self.update(dt);

            // Render
            try self.render();

            // Frame rate limit (~30 FPS for terminal)
            std.Thread.sleep(33_000_000); // 33ms
        }
    }

    fn processInput(self: *PhotonTerminal) !void {
        while (self.terminal.readKeyNonBlocking()) |key| {
            switch (key) {
                27 => { // ESC
                    self.running = false;
                },
                13 => { // Enter
                    if (self.input.len > 0) {
                        const text = self.input.getText();
                        // Spawn input as wave
                        self.text_waves.spawn(2, self.cursor_y - 2, text, true);

                        // Generate response
                        try self.generateResponse(text);

                        self.input.clear();
                    }
                },
                127, 8 => { // Backspace
                    self.input.backspace();
                    // Negative perturbation
                    if (self.cursor_x > 0) {
                        self.cursor_x -= 1;
                        self.grid.getMut(self.cursor_x, self.cursor_y).amplitude = -0.5;
                    }
                },
                // Arrow keys (escape sequences)
                else => {
                    if (key >= 32 and key < 127) {
                        self.input.addChar(key);
                        // Positive perturbation at cursor
                        self.grid.getMut(@min(self.cursor_x, GRID_WIDTH - 1), self.cursor_y).amplitude = 1.0;
                        self.grid.getMut(@min(self.cursor_x, GRID_WIDTH - 1), self.cursor_y).hue = 180.0; // Cyan for input
                        self.cursor_x = @min(self.cursor_x + 1, GRID_WIDTH - 1);

                        // Radiate waves from keystroke
                        self.injectKeystrokeWave(key);
                    }
                },
            }
        }
    }

    fn injectKeystrokeWave(self: *PhotonTerminal, key: u8) void {
        // Each key creates a unique wave pattern
        const freq = @as(f32, @floatFromInt(key)) / 128.0;
        const amp = 0.3 + freq * 0.2;

        self.grid.injectWave(.{ .circle = .{
            .center_x = self.cursor_x,
            .center_y = self.cursor_y,
            .radius = 5 + @as(usize, @intFromFloat(freq * 10)),
            .amplitude = amp,
        } });
    }

    fn generateResponse(self: *PhotonTerminal, input: []const u8) !void {
        // Simple emergent response generation
        // In real version, connect to fluent coder/GGUF inference

        var response_buf: [256]u8 = undefined;
        var response_len: usize = 0;

        // Check for commands
        if (std.mem.startsWith(u8, input, "/wave")) {
            const msg = "Injecting golden spiral wave...";
            @memcpy(response_buf[0..msg.len], msg);
            response_len = msg.len;

            self.grid.injectWave(.{ .golden_spiral = .{
                .center_x = GRID_WIDTH / 2,
                .center_y = GRID_HEIGHT / 2,
                .scale = 3.0,
                .amplitude = 1.0,
            } });
        } else if (std.mem.startsWith(u8, input, "/reset")) {
            const msg = "Reality reset. Waves calming...";
            @memcpy(response_buf[0..msg.len], msg);
            response_len = msg.len;

            for (self.grid.photons) |*p| {
                p.amplitude = 0;
                p.interference = 0;
            }
        } else if (std.mem.startsWith(u8, input, "/mode")) {
            const modes = [_][]const u8{ "wave", "chat", "code", "tools" };
            const mode_idx = @as(usize, @intFromEnum(self.mode));
            const next_mode = (mode_idx + 1) % modes.len;
            self.mode = @enumFromInt(next_mode);

            var msg_buf: [64]u8 = undefined;
            const msg = std.fmt.bufPrint(&msg_buf, "Mode: {s}", .{modes[next_mode]}) catch "Mode changed";
            @memcpy(response_buf[0..msg.len], msg);
            response_len = msg.len;
        } else if (std.mem.startsWith(u8, input, "/help")) {
            const msg = "/wave /reset /mode /help | ESC=exit";
            @memcpy(response_buf[0..msg.len], msg);
            response_len = msg.len;
        } else {
            // Echo with emergent transformation
            const prefix = ">> ";
            @memcpy(response_buf[0..prefix.len], prefix);
            const copy_len = @min(input.len, 256 - prefix.len);
            @memcpy(response_buf[prefix.len..][0..copy_len], input[0..copy_len]);
            response_len = prefix.len + copy_len;
        }

        // Spawn response as wave
        self.text_waves.spawn(2, self.cursor_y - 4, response_buf[0..response_len], false);

        // Create expansion wave for response
        self.grid.injectWave(.{ .line_wave = .{
            .position = if (self.cursor_y >= 4) self.cursor_y - 4 else 0,
            .horizontal = true,
            .amplitude = 0.8,
        } });
    }

    fn update(self: *PhotonTerminal, dt: f32) void {
        // Update text waves
        self.text_waves.update(dt);

        // Inject text waves into grid
        self.text_waves.injectAll(&self.grid);

        // Propagate waves
        self.grid.stepSIMD();

        // Evolving hue
        self.hue_offset = @mod(self.hue_offset + dt * 10.0, 360.0);
    }

    fn render(self: *PhotonTerminal) !void {
        self.renderer.clear();

        // Move to top-left
        try self.renderer.moveTo(0, 0);

        // Render grid as characters
        for (0..GRID_HEIGHT) |y| {
            for (0..GRID_WIDTH) |x| {
                const p = self.grid.get(x, y);

                // Get glyph based on amplitude
                const glyph = GlyphMapper.amplitudeToGlyph(p.amplitude);

                // Get color based on amplitude and phase
                const rgb = GlyphMapper.amplitudeToColor(p.amplitude, p.phase, self.hue_offset + p.hue);

                // Only color if there's significant amplitude
                if (@abs(p.amplitude) > 0.05) {
                    try self.renderer.setColorRGB(rgb[0], rgb[1], rgb[2]);
                    try self.renderer.setBgRGB(0, 0, 0);
                } else {
                    try self.renderer.setColorRGB(30, 30, 30);
                    try self.renderer.setBgRGB(0, 0, 0);
                }

                try self.renderer.writeChar(glyph);
            }
            try self.renderer.writeChar('\n');
        }

        // Draw input line
        try self.renderer.reset();
        try self.renderer.moveTo(0, GRID_HEIGHT);
        try self.renderer.setColorRGB(0, 255, 136); // Neon green
        try self.renderer.writeStr("> ");
        try self.renderer.setColorRGB(255, 255, 255);
        try self.renderer.writeStr(self.input.getText());

        // Draw cursor
        try self.renderer.setColorRGB(0, 255, 255); // Cyan cursor
        try self.renderer.writeChar('_');

        // Draw mode indicator
        try self.renderer.moveTo(GRID_WIDTH - 20, GRID_HEIGHT);
        try self.renderer.setColorRGB(100, 100, 100);
        const mode_str = switch (self.mode) {
            .wave => "[WAVE]",
            .chat => "[CHAT]",
            .code => "[CODE]",
            .tools => "[TOOLS]",
        };
        try self.renderer.writeStr(mode_str);

        try self.renderer.reset();
        try self.renderer.flush();
    }
};

// =============================================================================
// UTILITY
// =============================================================================

fn hsvToRgb(h: f32, s: f32, v: f32) [3]u8 {
    const c = v * s;
    const x = c * (1.0 - @abs(@mod(h / 60.0, 2.0) - 1.0));
    const m = v - c;

    var r: f32 = 0;
    var g: f32 = 0;
    var b: f32 = 0;

    if (h < 60) {
        r = c;
        g = x;
    } else if (h < 120) {
        r = x;
        g = c;
    } else if (h < 180) {
        g = c;
        b = x;
    } else if (h < 240) {
        g = x;
        b = c;
    } else if (h < 300) {
        r = x;
        b = c;
    } else {
        r = c;
        b = x;
    }

    return .{
        @intFromFloat((r + m) * 255.0),
        @intFromFloat((g + m) * 255.0),
        @intFromFloat((b + m) * 255.0),
    };
}

// =============================================================================
// MAIN
// =============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var terminal = try PhotonTerminal.init(allocator);
    defer terminal.deinit();

    try terminal.run();
}

// =============================================================================
// TESTS
// =============================================================================

test "glyph mapping" {
    const g1 = GlyphMapper.amplitudeToGlyph(0);
    try std.testing.expect(g1 == ' ');

    const g2 = GlyphMapper.amplitudeToGlyph(1.0);
    try std.testing.expect(g2 == '$');

    const g3 = GlyphMapper.amplitudeToGlyph(0.5);
    try std.testing.expect(g3 != ' ' and g3 != '$');
}

test "text wave spawn" {
    var sys = TextWaveSystem.init();
    sys.spawn(10, 10, "Hello", true);

    var alive_count: usize = 0;
    for (&sys.waves) |*w| {
        if (w.isAlive()) alive_count += 1;
    }
    try std.testing.expect(alive_count == 1);
}

test "input buffer" {
    var buf = InputBuffer.init();
    buf.addChar('H');
    buf.addChar('i');

    try std.testing.expectEqualStrings("Hi", buf.getText());

    buf.backspace();
    try std.testing.expectEqualStrings("H", buf.getText());

    buf.clear();
    try std.testing.expectEqualStrings("", buf.getText());
}

test "hsv to rgb" {
    // Red
    const red = hsvToRgb(0, 1, 1);
    try std.testing.expect(red[0] == 255);

    // Green
    const green = hsvToRgb(120, 1, 1);
    try std.testing.expect(green[1] == 255);

    // Blue
    const blue = hsvToRgb(240, 1, 1);
    try std.testing.expect(blue[2] == 255);
}
