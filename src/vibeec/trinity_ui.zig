// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY NATIVE TERNARY UI v1.0
// ═══════════════════════════════════════════════════════════════════════════════
//
// Native Immediate Mode UI Framework (no HTML/JS garbage!)
//
// Philosophy:
// - Immediate mode (draw every frame, zero DOM bloat)
// - Ternary inspired (3-state elements: -1 inactive, 0 hover, +1 active)
// - Golden ratio layout (φ-spiral positioning)
// - 100% local, green compute
//
// Colors:
// - Primary: Green Teal #00FF88
// - Accent: Golden #FFD700
// - Background: Dark #0D1117
// - Text: White #FFFFFF
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f32 = 1.618033988749895;
pub const PHI_INV: f32 = 0.618033988749895;
pub const TRINITY: f32 = 3.0;

// Colors (RGBA 0-255)
pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,

    pub fn toF32(self: Color) [4]f32 {
        return .{
            @as(f32, @floatFromInt(self.r)) / 255.0,
            @as(f32, @floatFromInt(self.g)) / 255.0,
            @as(f32, @floatFromInt(self.b)) / 255.0,
            @as(f32, @floatFromInt(self.a)) / 255.0,
        };
    }

    pub fn lerp(a: Color, b: Color, t: f32) Color {
        const t_clamped = std.math.clamp(t, 0.0, 1.0);
        return Color{
            .r = @intFromFloat(@as(f32, @floatFromInt(a.r)) * (1.0 - t_clamped) + @as(f32, @floatFromInt(b.r)) * t_clamped),
            .g = @intFromFloat(@as(f32, @floatFromInt(a.g)) * (1.0 - t_clamped) + @as(f32, @floatFromInt(b.g)) * t_clamped),
            .b = @intFromFloat(@as(f32, @floatFromInt(a.b)) * (1.0 - t_clamped) + @as(f32, @floatFromInt(b.b)) * t_clamped),
            .a = @intFromFloat(@as(f32, @floatFromInt(a.a)) * (1.0 - t_clamped) + @as(f32, @floatFromInt(b.a)) * t_clamped),
        };
    }
};

// Trinity Color Palette
pub const COLORS = struct {
    pub const GREEN_TEAL = Color{ .r = 0x00, .g = 0xFF, .b = 0x88 };
    pub const GOLDEN = Color{ .r = 0xFF, .g = 0xD7, .b = 0x00 };
    pub const DARK_BG = Color{ .r = 0x0D, .g = 0x11, .b = 0x17 };
    pub const PANEL_BG = Color{ .r = 0x16, .g = 0x1B, .b = 0x22 };
    pub const WHITE = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF };
    pub const GRAY = Color{ .r = 0x88, .g = 0x88, .b = 0x88 };
    pub const RED = Color{ .r = 0xFF, .g = 0x44, .b = 0x44 };
};

// ═══════════════════════════════════════════════════════════════════════════════
// TERNARY STATE (-1, 0, +1)
// ═══════════════════════════════════════════════════════════════════════════════

pub const TernaryState = enum(i8) {
    Inactive = -1, // Not interacting
    Hover = 0, // Mouse over
    Active = 1, // Clicked/pressed

    pub fn toTrit(self: TernaryState) i8 {
        return @intFromEnum(self);
    }

    pub fn fromBool(hover: bool, active: bool) TernaryState {
        if (active) return .Active;
        if (hover) return .Hover;
        return .Inactive;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// GEOMETRY
// ═══════════════════════════════════════════════════════════════════════════════

pub const Vec2 = struct {
    x: f32,
    y: f32,

    pub fn add(self: Vec2, other: Vec2) Vec2 {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }

    pub fn sub(self: Vec2, other: Vec2) Vec2 {
        return .{ .x = self.x - other.x, .y = self.y - other.y };
    }

    pub fn scale(self: Vec2, s: f32) Vec2 {
        return .{ .x = self.x * s, .y = self.y * s };
    }

    pub fn zero() Vec2 {
        return .{ .x = 0, .y = 0 };
    }
};

pub const Rect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,

    pub fn contains(self: Rect, p: Vec2) bool {
        return p.x >= self.x and p.x <= self.x + self.w and
            p.y >= self.y and p.y <= self.y + self.h;
    }

    pub fn center(self: Rect) Vec2 {
        return .{ .x = self.x + self.w / 2, .y = self.y + self.h / 2 };
    }

    /// Split rect using golden ratio (horizontal)
    pub fn splitGoldenH(self: Rect) struct { left: Rect, right: Rect } {
        const left_w = self.w * PHI_INV;
        return .{
            .left = Rect{ .x = self.x, .y = self.y, .w = left_w, .h = self.h },
            .right = Rect{ .x = self.x + left_w, .y = self.y, .w = self.w - left_w, .h = self.h },
        };
    }

    /// Split rect using golden ratio (vertical)
    pub fn splitGoldenV(self: Rect) struct { top: Rect, bottom: Rect } {
        const top_h = self.h * PHI_INV;
        return .{
            .top = Rect{ .x = self.x, .y = self.y, .w = self.w, .h = top_h },
            .bottom = Rect{ .x = self.x, .y = self.y + top_h, .w = self.w, .h = self.h - top_h },
        };
    }

    /// Split into trinity (3 equal parts)
    pub fn splitTrinityH(self: Rect) [3]Rect {
        const w = self.w / TRINITY;
        return .{
            Rect{ .x = self.x, .y = self.y, .w = w, .h = self.h },
            Rect{ .x = self.x + w, .y = self.y, .w = w, .h = self.h },
            Rect{ .x = self.x + w * 2, .y = self.y, .w = w, .h = self.h },
        };
    }

    pub fn inset(self: Rect, padding: f32) Rect {
        return Rect{
            .x = self.x + padding,
            .y = self.y + padding,
            .w = @max(0, self.w - padding * 2),
            .h = @max(0, self.h - padding * 2),
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DRAW COMMANDS (Immediate Mode)
// ═══════════════════════════════════════════════════════════════════════════════

pub const DrawCommand = union(enum) {
    rect: struct {
        bounds: Rect,
        color: Color,
        border_radius: f32,
    },
    rect_outline: struct {
        bounds: Rect,
        color: Color,
        thickness: f32,
    },
    text: struct {
        pos: Vec2,
        text: []const u8,
        color: Color,
        size: f32,
    },
    line: struct {
        start: Vec2,
        end: Vec2,
        color: Color,
        thickness: f32,
    },
    circle: struct {
        center: Vec2,
        radius: f32,
        color: Color,
    },
};

// ═══════════════════════════════════════════════════════════════════════════════
// INPUT STATE
// ═══════════════════════════════════════════════════════════════════════════════

pub const InputState = struct {
    mouse_pos: Vec2 = Vec2.zero(),
    mouse_delta: Vec2 = Vec2.zero(),
    mouse_down: bool = false,
    mouse_clicked: bool = false,
    mouse_released: bool = false,
    scroll_delta: f32 = 0,

    // Keyboard
    text_input: [256]u8 = [_]u8{0} ** 256,
    text_input_len: usize = 0,
    key_backspace: bool = false,
    key_enter: bool = false,
    key_escape: bool = false,
    key_tab: bool = false,

    pub fn reset(self: *InputState) void {
        self.mouse_clicked = false;
        self.mouse_released = false;
        self.scroll_delta = 0;
        self.text_input_len = 0;
        self.key_backspace = false;
        self.key_enter = false;
        self.key_escape = false;
        self.key_tab = false;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// UI CONTEXT (Immediate Mode Core)
// ═══════════════════════════════════════════════════════════════════════════════

pub const UIContext = struct {
    allocator: std.mem.Allocator,
    draw_commands: std.ArrayListUnmanaged(DrawCommand),
    input: InputState,

    // Layout state
    cursor: Vec2,
    current_panel: ?Rect,
    panel_stack: std.ArrayListUnmanaged(Rect),

    // Interaction state
    hot_id: ?u64, // Widget under mouse
    active_id: ?u64, // Widget being interacted with
    focus_id: ?u64, // Widget with keyboard focus

    // Window
    window_size: Vec2,
    frame_count: u64,
    delta_time: f32,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, width: f32, height: f32) Self {
        return Self{
            .allocator = allocator,
            .draw_commands = .{},
            .input = InputState{},
            .cursor = Vec2.zero(),
            .current_panel = null,
            .panel_stack = .{},
            .hot_id = null,
            .active_id = null,
            .focus_id = null,
            .window_size = Vec2{ .x = width, .y = height },
            .frame_count = 0,
            .delta_time = 1.0 / 60.0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.draw_commands.deinit(self.allocator);
        self.panel_stack.deinit(self.allocator);
    }

    // ───────────────────────────────────────────────────────────────────────────
    // FRAME MANAGEMENT
    // ───────────────────────────────────────────────────────────────────────────

    pub fn beginFrame(self: *Self) void {
        self.draw_commands.clearRetainingCapacity();
        self.cursor = Vec2.zero();
        self.hot_id = null;
        self.frame_count += 1;
    }

    pub fn endFrame(self: *Self) void {
        if (!self.input.mouse_down) {
            self.active_id = null;
        }
        self.input.reset();
    }

    // ───────────────────────────────────────────────────────────────────────────
    // DRAW PRIMITIVES
    // ───────────────────────────────────────────────────────────────────────────

    pub fn drawRect(self: *Self, bounds: Rect, color: Color) void {
        self.draw_commands.append(self.allocator, .{ .rect = .{
            .bounds = bounds,
            .color = color,
            .border_radius = 0,
        } }) catch {};
    }

    pub fn drawRectRounded(self: *Self, bounds: Rect, color: Color, radius: f32) void {
        self.draw_commands.append(self.allocator, .{ .rect = .{
            .bounds = bounds,
            .color = color,
            .border_radius = radius,
        } }) catch {};
    }

    pub fn drawRectOutline(self: *Self, bounds: Rect, color: Color, thickness: f32) void {
        self.draw_commands.append(self.allocator, .{ .rect_outline = .{
            .bounds = bounds,
            .color = color,
            .thickness = thickness,
        } }) catch {};
    }

    pub fn drawText(self: *Self, pos: Vec2, text: []const u8, color: Color, size: f32) void {
        self.draw_commands.append(self.allocator, .{ .text = .{
            .pos = pos,
            .text = text,
            .color = color,
            .size = size,
        } }) catch {};
    }

    pub fn drawLine(self: *Self, start: Vec2, end: Vec2, color: Color, thickness: f32) void {
        self.draw_commands.append(self.allocator, .{ .line = .{
            .start = start,
            .end = end,
            .color = color,
            .thickness = thickness,
        } }) catch {};
    }

    pub fn drawCircle(self: *Self, center: Vec2, radius: f32, color: Color) void {
        self.draw_commands.append(self.allocator, .{ .circle = .{
            .center = center,
            .radius = radius,
            .color = color,
        } }) catch {};
    }

    // ───────────────────────────────────────────────────────────────────────────
    // LAYOUT HELPERS
    // ───────────────────────────────────────────────────────────────────────────

    pub fn getFullRect(self: *Self) Rect {
        return Rect{ .x = 0, .y = 0, .w = self.window_size.x, .h = self.window_size.y };
    }

    pub fn pushPanel(self: *Self, bounds: Rect) void {
        if (self.current_panel) |p| {
            self.panel_stack.append(self.allocator, p) catch {};
        }
        self.current_panel = bounds;
        self.cursor = Vec2{ .x = bounds.x, .y = bounds.y };
    }

    pub fn popPanel(self: *Self) void {
        if (self.panel_stack.popOrNull()) |p| {
            self.current_panel = p;
            self.cursor = Vec2{ .x = p.x, .y = p.y };
        } else {
            self.current_panel = null;
        }
    }

    // ───────────────────────────────────────────────────────────────────────────
    // INTERACTION HELPERS
    // ───────────────────────────────────────────────────────────────────────────

    fn hashId(comptime lbl: []const u8) u64 {
        return std.hash.Wyhash.hash(0, lbl);
    }

    fn isHot(self: *Self, id: u64) bool {
        return self.hot_id != null and self.hot_id.? == id;
    }

    fn isActive(self: *Self, id: u64) bool {
        return self.active_id != null and self.active_id.? == id;
    }

    fn getTernaryState(self: *Self, id: u64, bounds: Rect) TernaryState {
        const hover = bounds.contains(self.input.mouse_pos);
        if (hover) self.hot_id = id;

        const active = self.isActive(id);
        return TernaryState.fromBool(hover, active);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // WIDGETS (Ternary 3-State)
    // ═══════════════════════════════════════════════════════════════════════════

    /// Panel with golden ratio border
    pub fn panel(self: *Self, bounds: Rect, title: []const u8) void {
        // Background
        self.drawRectRounded(bounds, COLORS.PANEL_BG, 8);

        // Golden border
        self.drawRectOutline(bounds, COLORS.GOLDEN, 2);

        // Title bar (φ-height)
        const title_height = 32;
        const title_rect = Rect{ .x = bounds.x, .y = bounds.y, .w = bounds.w, .h = title_height };
        self.drawRectRounded(title_rect, COLORS.DARK_BG, 8);

        // Title text
        self.drawText(
            Vec2{ .x = bounds.x + 12, .y = bounds.y + 8 },
            title,
            COLORS.GREEN_TEAL,
            16,
        );

        // Push content area
        self.pushPanel(Rect{
            .x = bounds.x + 8,
            .y = bounds.y + title_height + 8,
            .w = bounds.w - 16,
            .h = bounds.h - title_height - 16,
        });
    }

    /// Ternary Button (3-state visual feedback)
    pub fn button(self: *Self, comptime lbl: []const u8, bounds: Rect) bool {
        const id = hashId(lbl);
        const state = self.getTernaryState(id, bounds);

        // Color based on ternary state
        const bg_color = switch (state) {
            .Inactive => COLORS.PANEL_BG,
            .Hover => COLORS.GRAY,
            .Active => COLORS.GREEN_TEAL,
        };

        const text_color = switch (state) {
            .Inactive => COLORS.WHITE,
            .Hover => COLORS.WHITE,
            .Active => COLORS.DARK_BG,
        };

        // Draw button
        self.drawRectRounded(bounds, bg_color, 6);

        // Golden border on hover
        if (state == .Hover or state == .Active) {
            self.drawRectOutline(bounds, COLORS.GOLDEN, 2);
        }

        // Center text
        const text_x = bounds.x + (bounds.w - @as(f32, @floatFromInt(lbl.len)) * 8) / 2;
        const text_y = bounds.y + (bounds.h - 16) / 2;
        self.drawText(Vec2{ .x = text_x, .y = text_y }, lbl, text_color, 16);

        // Handle click
        if (bounds.contains(self.input.mouse_pos) and self.input.mouse_clicked) {
            self.active_id = id;
            return true;
        }
        return false;
    }

    /// Text input field
    pub fn textInput(self: *Self, comptime lbl: []const u8, bounds: Rect, buffer: []u8, len: *usize) bool {
        const id = hashId(lbl);
        const state = self.getTernaryState(id, bounds);

        const focused = self.focus_id != null and self.focus_id.? == id;

        // Background
        const bg_color = if (focused) COLORS.DARK_BG else COLORS.PANEL_BG;
        self.drawRectRounded(bounds, bg_color, 4);

        // Border
        const border_color = if (focused) COLORS.GREEN_TEAL else if (state == .Hover) COLORS.GOLDEN else COLORS.GRAY;
        self.drawRectOutline(bounds, border_color, if (focused) @as(f32, 2) else @as(f32, 1));

        // Text
        const text = buffer[0..len.*];
        self.drawText(
            Vec2{ .x = bounds.x + 8, .y = bounds.y + (bounds.h - 16) / 2 },
            text,
            COLORS.WHITE,
            14,
        );

        // Cursor blink
        if (focused and (self.frame_count / 30) % 2 == 0) {
            const cursor_x = bounds.x + 8 + @as(f32, @floatFromInt(len.*)) * 8;
            self.drawLine(
                Vec2{ .x = cursor_x, .y = bounds.y + 4 },
                Vec2{ .x = cursor_x, .y = bounds.y + bounds.h - 4 },
                COLORS.GREEN_TEAL,
                2,
            );
        }

        // Handle focus
        if (bounds.contains(self.input.mouse_pos) and self.input.mouse_clicked) {
            self.focus_id = id;
        }

        // Handle input
        var changed = false;
        if (focused) {
            // Text input
            if (self.input.text_input_len > 0 and len.* + self.input.text_input_len < buffer.len) {
                @memcpy(buffer[len.*..][0..self.input.text_input_len], self.input.text_input[0..self.input.text_input_len]);
                len.* += self.input.text_input_len;
                changed = true;
            }

            // Backspace
            if (self.input.key_backspace and len.* > 0) {
                len.* -= 1;
                changed = true;
            }

            // Enter - unfocus
            if (self.input.key_enter) {
                self.focus_id = null;
                return true; // Submitted
            }
        }

        return changed;
    }

    /// Label with ternary state indicator
    pub fn label(self: *Self, text: []const u8, pos: Vec2, state: TernaryState) void {
        const indicator_color = switch (state) {
            .Inactive => COLORS.GRAY,
            .Hover => COLORS.GOLDEN,
            .Active => COLORS.GREEN_TEAL,
        };

        // State indicator (trit symbol)
        self.drawCircle(pos, 4, indicator_color);

        // Text
        self.drawText(Vec2{ .x = pos.x + 12, .y = pos.y - 6 }, text, COLORS.WHITE, 14);
    }

    /// Progress bar (golden ratio proportions)
    pub fn progressBar(self: *Self, bounds: Rect, progress: f32) void {
        const clamped = std.math.clamp(progress, 0.0, 1.0);

        // Background
        self.drawRectRounded(bounds, COLORS.DARK_BG, 4);

        // Fill (golden gradient feel)
        if (clamped > 0) {
            const fill_w = bounds.w * clamped;
            const fill_rect = Rect{ .x = bounds.x, .y = bounds.y, .w = fill_w, .h = bounds.h };
            self.drawRectRounded(fill_rect, COLORS.GREEN_TEAL, 4);
        }

        // Golden markers at φ positions
        const phi_pos = bounds.w * PHI_INV;
        self.drawLine(
            Vec2{ .x = bounds.x + phi_pos, .y = bounds.y },
            Vec2{ .x = bounds.x + phi_pos, .y = bounds.y + bounds.h },
            COLORS.GOLDEN,
            1,
        );
    }

    /// Separator line
    pub fn separator(self: *Self, y: f32) void {
        if (self.current_panel) |p| {
            self.drawLine(
                Vec2{ .x = p.x, .y = y },
                Vec2{ .x = p.x + p.w, .y = y },
                COLORS.GRAY,
                1,
            );
        }
    }

    /// Code block (syntax highlighted feel)
    pub fn codeBlock(self: *Self, bounds: Rect, code: []const u8) void {
        // Dark background
        self.drawRectRounded(bounds, Color{ .r = 0x0A, .g = 0x0E, .b = 0x14 }, 4);

        // Left border (golden accent)
        self.drawRect(
            Rect{ .x = bounds.x, .y = bounds.y, .w = 3, .h = bounds.h },
            COLORS.GOLDEN,
        );

        // Code text (green teal)
        self.drawText(
            Vec2{ .x = bounds.x + 12, .y = bounds.y + 8 },
            code,
            COLORS.GREEN_TEAL,
            12,
        );
    }

    /// Chat message bubble
    pub fn chatBubble(self: *Self, bounds: Rect, message: []const u8, is_user: bool) void {
        const bg = if (is_user) COLORS.PANEL_BG else Color{ .r = 0x1A, .g = 0x2A, .b = 0x1A };
        const border = if (is_user) COLORS.GOLDEN else COLORS.GREEN_TEAL;

        self.drawRectRounded(bounds, bg, 8);
        self.drawRectOutline(bounds, border, 1);

        self.drawText(
            Vec2{ .x = bounds.x + 12, .y = bounds.y + 8 },
            message,
            COLORS.WHITE,
            14,
        );
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// GOLDEN RATIO LAYOUT HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Generate golden spiral positions
pub fn goldenSpiral(center: Vec2, start_radius: f32, count: usize) []Vec2 {
    var positions: [32]Vec2 = undefined;
    const n = @min(count, 32);

    var angle: f32 = 0;
    var radius = start_radius;

    for (0..n) |i| {
        positions[i] = Vec2{
            .x = center.x + @cos(angle) * radius,
            .y = center.y + @sin(angle) * radius,
        };
        angle += std.math.pi * 2 / PHI; // Golden angle
        radius *= 1.1;
    }

    return positions[0..n];
}

/// Trinity layout (3 equal columns)
pub fn trinityLayout(bounds: Rect, padding: f32) [3]Rect {
    const inner = bounds.inset(padding);
    const col_w = (inner.w - padding * 2) / 3;
    return .{
        Rect{ .x = inner.x, .y = inner.y, .w = col_w, .h = inner.h },
        Rect{ .x = inner.x + col_w + padding, .y = inner.y, .w = col_w, .h = inner.h },
        Rect{ .x = inner.x + (col_w + padding) * 2, .y = inner.y, .w = col_w, .h = inner.h },
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TERMINAL RENDERER (ANSI for demo)
// ═══════════════════════════════════════════════════════════════════════════════

pub const TerminalRenderer = struct {
    width: usize,
    height: usize,
    buffer: []u8,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !Self {
        return Self{
            .width = width,
            .height = height,
            .buffer = try allocator.alloc(u8, width * height),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.buffer);
    }

    pub fn clear(self: *Self) void {
        @memset(self.buffer, ' ');
    }

    pub fn render(self: *Self, ctx: *UIContext) void {
        self.clear();

        for (ctx.draw_commands.items) |cmd| {
            switch (cmd) {
                .rect => |r| {
                    self.drawBox(r.bounds, '#');
                },
                .text => |t| {
                    self.drawString(t.pos, t.text);
                },
                .line => |l| {
                    self.drawLine(l.start, l.end);
                },
                else => {},
            }
        }
    }

    fn drawBox(self: *Self, bounds: Rect, char: u8) void {
        const x0 = @as(usize, @intFromFloat(@max(0, bounds.x)));
        const y0 = @as(usize, @intFromFloat(@max(0, bounds.y)));
        const x1 = @min(self.width, @as(usize, @intFromFloat(bounds.x + bounds.w)));
        const y1 = @min(self.height, @as(usize, @intFromFloat(bounds.y + bounds.h)));

        for (y0..y1) |y| {
            for (x0..x1) |x| {
                self.buffer[y * self.width + x] = char;
            }
        }
    }

    fn drawString(self: *Self, pos: Vec2, text: []const u8) void {
        const x = @as(usize, @intFromFloat(@max(0, pos.x)));
        const y = @as(usize, @intFromFloat(@max(0, pos.y)));

        if (y >= self.height) return;

        for (text, 0..) |c, i| {
            const px = x + i;
            if (px >= self.width) break;
            self.buffer[y * self.width + px] = c;
        }
    }

    fn drawLine(self: *Self, start: Vec2, end: Vec2) void {
        // Simple horizontal/vertical line
        const x0 = @as(usize, @intFromFloat(@max(0, @min(start.x, end.x))));
        const x1 = @as(usize, @intFromFloat(@min(@as(f32, @floatFromInt(self.width)), @max(start.x, end.x))));
        const y = @as(usize, @intFromFloat(@max(0, start.y)));

        if (y >= self.height) return;

        for (x0..x1) |x| {
            self.buffer[y * self.width + x] = '-';
        }
    }

    pub fn print(self: *Self) void {
        // ANSI: Clear screen, move cursor home
        std.debug.print("\x1b[2J\x1b[H", .{});

        // Print with colors
        std.debug.print("\x1b[38;2;0;255;136m", .{}); // Green teal

        for (0..self.height) |y| {
            const line = self.buffer[y * self.width .. (y + 1) * self.width];
            std.debug.print("{s}\n", .{line});
        }

        std.debug.print("\x1b[0m", .{}); // Reset
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN - Terminal Demo
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("\x1b[38;2;0;255;136m", .{}); // Green teal
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║     TRINITY NATIVE TERNARY UI v1.0                           ║\n", .{});
    std.debug.print("║     Immediate Mode | Golden Ratio | 3-State                  ║\n", .{});
    std.debug.print("║     NO HTML/JS - Pure Zig Native                             ║\n", .{});
    std.debug.print("║     \x1b[38;2;255;215;0mφ² + 1/φ² = 3 = TRINITY\x1b[38;2;0;255;136m                                   ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\x1b[0m\n", .{});

    // Initialize UI context
    var ctx = UIContext.init(allocator, 800, 600);
    defer ctx.deinit();

    // Simulate a few frames
    std.debug.print("  Demonstrating Immediate Mode UI Framework:\n\n", .{});

    // Frame 1: Layout demo
    ctx.beginFrame();

    // Full window rect
    const window = ctx.getFullRect();
    std.debug.print("  Window: {d:.0}x{d:.0}\n", .{ window.w, window.h });

    // Golden ratio split
    const golden = window.splitGoldenH();
    std.debug.print("  Golden Split (φ): Left={d:.0}px, Right={d:.0}px\n", .{ golden.left.w, golden.right.w });
    std.debug.print("  Ratio: {d:.3} (φ⁻¹ = {d:.3})\n", .{ golden.left.w / window.w, PHI_INV });

    // Trinity split
    const trinity = window.splitTrinityH();
    std.debug.print("  Trinity Split: 3 x {d:.0}px = TRINITY\n", .{trinity[0].w});

    ctx.endFrame();

    // Frame 2: Widget demo
    ctx.beginFrame();

    std.debug.print("\n  Ternary Widget States:\n", .{});
    std.debug.print("    Button [-1]: \x1b[38;2;136;136;136mInactive\x1b[0m (gray)\n", .{});
    std.debug.print("    Button [ 0]: \x1b[38;2;255;215;0mHover\x1b[0m (golden border)\n", .{});
    std.debug.print("    Button [+1]: \x1b[38;2;0;255;136mActive\x1b[0m (green teal)\n", .{});

    ctx.endFrame();

    // Frame 3: Draw commands
    ctx.beginFrame();

    ctx.drawRectRounded(Rect{ .x = 10, .y = 10, .w = 200, .h = 40 }, COLORS.PANEL_BG, 8);
    ctx.drawText(Vec2{ .x = 20, .y = 20 }, "Trinity UI", COLORS.GREEN_TEAL, 16);
    ctx.drawLine(Vec2{ .x = 10, .y = 60 }, Vec2{ .x = 210, .y = 60 }, COLORS.GOLDEN, 2);

    std.debug.print("\n  Draw Commands Generated: {d}\n", .{ctx.draw_commands.items.len});

    ctx.endFrame();

    // Summary
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("     UI FRAMEWORK FEATURES                                     \n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  \x1b[38;2;0;255;136m✓\x1b[0m Immediate Mode (no DOM, no retained state)\n", .{});
    std.debug.print("  \x1b[38;2;0;255;136m✓\x1b[0m Ternary States (-1, 0, +1) for all widgets\n", .{});
    std.debug.print("  \x1b[38;2;0;255;136m✓\x1b[0m Golden Ratio (φ) layout system\n", .{});
    std.debug.print("  \x1b[38;2;0;255;136m✓\x1b[0m Trinity (3-way) splits\n", .{});
    std.debug.print("  \x1b[38;2;0;255;136m✓\x1b[0m Widgets: Panel, Button, TextInput, Label\n", .{});
    std.debug.print("  \x1b[38;2;0;255;136m✓\x1b[0m ProgressBar, CodeBlock, ChatBubble\n", .{});
    std.debug.print("  \x1b[38;2;0;255;136m✓\x1b[0m Pure Zig (no HTML/JS garbage)\n", .{});
    std.debug.print("  \x1b[38;2;0;255;136m✓\x1b[0m Ready for Metal backend\n", .{});

    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("     COLOR PALETTE                                             \n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  \x1b[38;2;0;255;136m████\x1b[0m GREEN_TEAL  #00FF88 (Primary)\n", .{});
    std.debug.print("  \x1b[38;2;255;215;0m████\x1b[0m GOLDEN      #FFD700 (Accent)\n", .{});
    std.debug.print("  \x1b[38;2;13;17;23m████\x1b[0m DARK_BG     #0D1117 (Background)\n", .{});
    std.debug.print("  \x1b[38;2;22;27;34m████\x1b[0m PANEL_BG    #161B22 (Panel)\n", .{});
    std.debug.print("  \x1b[38;2;255;255;255m████\x1b[0m WHITE       #FFFFFF (Text)\n", .{});

    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  \x1b[38;2;255;215;0mφ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL\x1b[0m\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
}

test "ui context init" {
    const allocator = std.testing.allocator;
    var ctx = UIContext.init(allocator, 800, 600);
    defer ctx.deinit();

    try std.testing.expectEqual(@as(f32, 800), ctx.window_size.x);
    try std.testing.expectEqual(@as(f32, 600), ctx.window_size.y);
}

test "golden ratio split" {
    const rect = Rect{ .x = 0, .y = 0, .w = 1000, .h = 600 };
    const split = rect.splitGoldenH();

    // Left should be ~618px (φ⁻¹ * 1000)
    try std.testing.expectApproxEqAbs(@as(f32, 618), split.left.w, 1);
}

test "ternary state" {
    try std.testing.expectEqual(@as(i8, -1), TernaryState.Inactive.toTrit());
    try std.testing.expectEqual(@as(i8, 0), TernaryState.Hover.toTrit());
    try std.testing.expectEqual(@as(i8, 1), TernaryState.Active.toTrit());
}
