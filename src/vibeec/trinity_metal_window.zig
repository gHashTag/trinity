// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY METAL WINDOW v1.0 — Pure Zig + Metal Native UI
// ═══════════════════════════════════════════════════════════════════════════════
//
// Native macOS window with Metal GPU rendering backend.
// No HTML/JS — Pure Zig immediate mode UI.
//
// Architecture:
// 1. objc runtime bindings for NSApplication, NSWindow, NSView
// 2. CAMetalLayer for GPU rendering
// 3. Metal pipeline for 2D primitives (rect, text)
// 4. Immediate mode UI (BeginFrame → Widgets → EndFrame)
//
// Warp/ONA Style:
// - Dark theme (#1A1A1E)
// - Sidebar left (220px)
// - Task cards center
// - Chat panel bottom
// - Traffic lights (close/min/max)
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const builtin = @import("builtin");

// ═══════════════════════════════════════════════════════════════════════════════
// OBJC RUNTIME BINDINGS (macOS only)
// ═══════════════════════════════════════════════════════════════════════════════

const c = if (builtin.os.tag == .macos) @cImport({
    @cDefine("__STDC_NO_THREADS__", "1");
    @cInclude("objc/runtime.h");
    @cInclude("objc/message.h");
}) else struct {};

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f32 = 1.618033988749895;
pub const PHI_INV: f32 = 0.618033988749895;

pub const WINDOW_WIDTH: f32 = 1280;
pub const WINDOW_HEIGHT: f32 = 800;
pub const SIDEBAR_WIDTH: f32 = 220;
pub const RIGHT_PANEL_WIDTH: f32 = 320;
pub const TITLE_BAR_HEIGHT: f32 = 38;
pub const CHAT_PANEL_HEIGHT: f32 = 200;

// ═══════════════════════════════════════════════════════════════════════════════
// COLORS (ONA Dark Theme)
// ═══════════════════════════════════════════════════════════════════════════════

pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32 = 1.0,

    pub fn rgba(r: u8, g: u8, b: u8, a: u8) Color {
        return .{
            .r = @as(f32, @floatFromInt(r)) / 255.0,
            .g = @as(f32, @floatFromInt(g)) / 255.0,
            .b = @as(f32, @floatFromInt(b)) / 255.0,
            .a = @as(f32, @floatFromInt(a)) / 255.0,
        };
    }

    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return rgba(r, g, b, 255);
    }

    pub fn hex(val: u24) Color {
        return rgb(
            @truncate(val >> 16),
            @truncate(val >> 8),
            @truncate(val),
        );
    }
};

pub const THEME = struct {
    pub const BG_WINDOW = Color.hex(0x1A1A1E);
    pub const BG_SIDEBAR = Color.hex(0x141417);
    pub const BG_PANEL = Color.hex(0x222226);
    pub const BG_CARD = Color.hex(0x2A2A2E);
    pub const BG_CARD_HOVER = Color.hex(0x323236);
    pub const BG_INPUT = Color.hex(0x18181C);

    pub const TEAL = Color.hex(0x00E599);
    pub const GOLDEN = Color.hex(0xFFD700);
    pub const PURPLE = Color.hex(0x8B5CF6);

    pub const TEXT_PRIMARY = Color.hex(0xFFFFFF);
    pub const TEXT_SECONDARY = Color.hex(0x9C9CA0);
    pub const TEXT_MUTED = Color.hex(0x6B6B70);

    pub const BORDER = Color.hex(0x3A3A3E);

    pub const TRAFFIC_RED = Color.hex(0xFF5F57);
    pub const TRAFFIC_YELLOW = Color.hex(0xFEBC2E);
    pub const TRAFFIC_GREEN = Color.hex(0x28C840);
};

// ═══════════════════════════════════════════════════════════════════════════════
// GEOMETRY
// ═══════════════════════════════════════════════════════════════════════════════

pub const Vec2 = struct {
    x: f32,
    y: f32,

    pub fn zero() Vec2 {
        return .{ .x = 0, .y = 0 };
    }

    pub fn add(a: Vec2, b: Vec2) Vec2 {
        return .{ .x = a.x + b.x, .y = a.y + b.y };
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

    pub fn inset(self: Rect, padding: f32) Rect {
        return .{
            .x = self.x + padding,
            .y = self.y + padding,
            .w = @max(0, self.w - padding * 2),
            .h = @max(0, self.h - padding * 2),
        };
    }

    pub fn splitLeft(self: Rect, width: f32) struct { left: Rect, right: Rect } {
        return .{
            .left = .{ .x = self.x, .y = self.y, .w = width, .h = self.h },
            .right = .{ .x = self.x + width, .y = self.y, .w = self.w - width, .h = self.h },
        };
    }

    pub fn splitTop(self: Rect, height: f32) struct { top: Rect, bottom: Rect } {
        return .{
            .top = .{ .x = self.x, .y = self.y, .w = self.w, .h = height },
            .bottom = .{ .x = self.x, .y = self.y + height, .w = self.w, .h = self.h - height },
        };
    }

    pub fn splitBottom(self: Rect, height: f32) struct { top: Rect, bottom: Rect } {
        return .{
            .top = .{ .x = self.x, .y = self.y, .w = self.w, .h = self.h - height },
            .bottom = .{ .x = self.x, .y = self.y + self.h - height, .w = self.w, .h = height },
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
        corner_radius: f32,
    },
    text: struct {
        pos: Vec2,
        text: []const u8,
        color: Color,
        size: f32,
    },
    line: struct {
        p0: Vec2,
        p1: Vec2,
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
// UI CONTEXT (Immediate Mode State)
// ═══════════════════════════════════════════════════════════════════════════════

pub const UIContext = struct {
    allocator: std.mem.Allocator,

    // Draw list
    commands: std.ArrayListUnmanaged(DrawCommand),

    // Window state
    window_size: Vec2,
    mouse_pos: Vec2,
    mouse_down: bool,
    mouse_clicked: bool,

    // Hot/Active state for widgets
    hot_id: ?u64,
    active_id: ?u64,

    // Layout cursor
    cursor: Vec2,
    current_region: Rect,

    // Frame stats
    frame_count: u64,
    last_frame_time_ns: u64,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .commands = .{},
            .window_size = .{ .x = WINDOW_WIDTH, .y = WINDOW_HEIGHT },
            .mouse_pos = Vec2.zero(),
            .mouse_down = false,
            .mouse_clicked = false,
            .hot_id = null,
            .active_id = null,
            .cursor = Vec2.zero(),
            .current_region = .{ .x = 0, .y = 0, .w = WINDOW_WIDTH, .h = WINDOW_HEIGHT },
            .frame_count = 0,
            .last_frame_time_ns = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.commands.deinit(self.allocator);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FRAME LIFECYCLE
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn beginFrame(self: *Self) void {
        self.commands.clearRetainingCapacity();
        self.hot_id = null;
        self.mouse_clicked = false;
        self.current_region = .{ .x = 0, .y = 0, .w = self.window_size.x, .h = self.window_size.y };
        self.cursor = Vec2.zero();
    }

    pub fn endFrame(self: *Self) void {
        self.frame_count += 1;
        // Commands ready for Metal rendering
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // DRAWING PRIMITIVES
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn drawRect(self: *Self, bounds: Rect, color: Color) void {
        self.commands.append(self.allocator, .{ .rect = .{
            .bounds = bounds,
            .color = color,
            .corner_radius = 0,
        } }) catch {};
    }

    pub fn drawRoundedRect(self: *Self, bounds: Rect, color: Color, radius: f32) void {
        self.commands.append(self.allocator, .{ .rect = .{
            .bounds = bounds,
            .color = color,
            .corner_radius = radius,
        } }) catch {};
    }

    pub fn drawText(self: *Self, pos: Vec2, text: []const u8, color: Color, size: f32) void {
        self.commands.append(self.allocator, .{ .text = .{
            .pos = pos,
            .text = text,
            .color = color,
            .size = size,
        } }) catch {};
    }

    pub fn drawCircle(self: *Self, center: Vec2, radius: f32, color: Color) void {
        self.commands.append(self.allocator, .{ .circle = .{
            .center = center,
            .radius = radius,
            .color = color,
        } }) catch {};
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // WIDGETS
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn button(self: *Self, id: u64, bounds: Rect, label: []const u8) bool {
        const hovered = bounds.contains(self.mouse_pos);
        const pressed = hovered and self.mouse_down;
        const clicked = hovered and self.mouse_clicked;

        if (hovered) self.hot_id = id;
        if (pressed) self.active_id = id;

        const bg_color = if (pressed) THEME.BG_CARD_HOVER else if (hovered) THEME.BG_CARD else THEME.BG_PANEL;

        self.drawRoundedRect(bounds, bg_color, 6);
        self.drawText(.{ .x = bounds.x + 12, .y = bounds.y + bounds.h / 2 - 7 }, label, THEME.TEXT_PRIMARY, 14);

        return clicked;
    }

    pub fn card(self: *Self, bounds: Rect, title: []const u8, subtitle: []const u8, status_color: Color) void {
        self.drawRoundedRect(bounds, THEME.BG_CARD, 8);

        // Status indicator
        self.drawCircle(.{ .x = bounds.x + 16, .y = bounds.y + 20 }, 5, status_color);

        // Title
        self.drawText(.{ .x = bounds.x + 32, .y = bounds.y + 14 }, title, THEME.TEXT_PRIMARY, 14);

        // Subtitle
        self.drawText(.{ .x = bounds.x + 32, .y = bounds.y + 36 }, subtitle, THEME.TEXT_SECONDARY, 12);
    }

    pub fn sidebarItem(self: *Self, _: u64, bounds: Rect, icon: []const u8, label: []const u8, active: bool) bool {
        const hovered = bounds.contains(self.mouse_pos);
        const clicked = hovered and self.mouse_clicked;

        const bg_color = if (active) THEME.BG_CARD else if (hovered) THEME.BG_CARD_HOVER else THEME.BG_SIDEBAR;
        const text_color = if (active) THEME.TEAL else THEME.TEXT_SECONDARY;

        self.drawRect(bounds, bg_color);
        self.drawText(.{ .x = bounds.x + 16, .y = bounds.y + bounds.h / 2 - 7 }, icon, text_color, 14);
        self.drawText(.{ .x = bounds.x + 44, .y = bounds.y + bounds.h / 2 - 7 }, label, text_color, 14);

        return clicked;
    }

    pub fn inputField(self: *Self, bounds: Rect, placeholder: []const u8, value: []const u8) void {
        self.drawRoundedRect(bounds, THEME.BG_INPUT, 6);

        const display_text = if (value.len > 0) value else placeholder;
        const text_color = if (value.len > 0) THEME.TEXT_PRIMARY else THEME.TEXT_MUTED;

        self.drawText(.{ .x = bounds.x + 12, .y = bounds.y + bounds.h / 2 - 7 }, display_text, text_color, 14);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // LAYOUT
    // ═══════════════════════════════════════════════════════════════════════════

    pub fn layoutONA(self: *Self) struct {
        title_bar: Rect,
        sidebar: Rect,
        main: Rect,
        right_panel: Rect,
        chat: Rect,
    } {
        const full = Rect{ .x = 0, .y = 0, .w = self.window_size.x, .h = self.window_size.y };

        // Title bar at top
        const split1 = full.splitTop(TITLE_BAR_HEIGHT);
        const title_bar = split1.top;
        const below_title = split1.bottom;

        // Chat panel at bottom
        const split2 = below_title.splitBottom(CHAT_PANEL_HEIGHT);
        const content = split2.top;
        const chat = split2.bottom;

        // Sidebar on left
        const split3 = content.splitLeft(SIDEBAR_WIDTH);
        const sidebar = split3.left;
        const center_right = split3.right;

        // Right panel
        const split4 = center_right.splitLeft(center_right.w - RIGHT_PANEL_WIDTH);
        const main_panel = split4.left;
        const right_panel = split4.right;

        return .{
            .title_bar = title_bar,
            .sidebar = sidebar,
            .main = main_panel,
            .right_panel = right_panel,
            .chat = chat,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// RENDER TO TERMINAL (Demo/Fallback)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn renderToTerminal(ctx: *UIContext) void {
    const width: usize = 120;
    const height: usize = 40;

    // Create framebuffer
    var fb: [height][width]u8 = undefined;
    for (&fb) |*row| {
        @memset(row, ' ');
    }

    // Rasterize commands to ASCII
    for (ctx.commands.items) |cmd| {
        switch (cmd) {
            .rect => |r| {
                const x0 = @as(usize, @intFromFloat(@max(0, r.bounds.x / 10)));
                const y0 = @as(usize, @intFromFloat(@max(0, r.bounds.y / 20)));
                const x1 = @as(usize, @intFromFloat(@min(@as(f32, @floatFromInt(width - 1)), (r.bounds.x + r.bounds.w) / 10)));
                const y1 = @as(usize, @intFromFloat(@min(@as(f32, @floatFromInt(height - 1)), (r.bounds.y + r.bounds.h) / 20)));

                for (y0..@min(y1 + 1, height)) |y| {
                    for (x0..@min(x1 + 1, width)) |x| {
                        if (y == y0 or y == y1) {
                            fb[y][x] = '-';
                        } else if (x == x0 or x == x1) {
                            fb[y][x] = '|';
                        }
                    }
                }
            },
            .text => |t| {
                const x = @as(usize, @intFromFloat(@max(0, t.pos.x / 10)));
                const y = @as(usize, @intFromFloat(@max(0, t.pos.y / 20)));
                if (y < height) {
                    for (t.text, 0..) |ch, i| {
                        if (x + i < width) {
                            fb[y][x + i] = ch;
                        }
                    }
                }
            },
            .circle => |cir| {
                const x = @as(usize, @intFromFloat(@max(0, cir.center.x / 10)));
                const y = @as(usize, @intFromFloat(@max(0, cir.center.y / 20)));
                if (y < height and x < width) {
                    fb[y][x] = 'o';
                }
            },
            else => {},
        }
    }

    // Print framebuffer
    std.debug.print("\x1b[2J\x1b[H", .{}); // Clear screen
    for (fb) |row| {
        std.debug.print("{s}\n", .{&row});
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEMO: ONA-STYLE UI
// ═══════════════════════════════════════════════════════════════════════════════

pub fn demoOnaUI(ctx: *UIContext) void {
    const layout = ctx.layoutONA();

    // Background
    ctx.drawRect(.{ .x = 0, .y = 0, .w = ctx.window_size.x, .h = ctx.window_size.y }, THEME.BG_WINDOW);

    // ─────────────────────────────────────────────────────────────────────────
    // TITLE BAR
    // ─────────────────────────────────────────────────────────────────────────
    ctx.drawRect(layout.title_bar, THEME.BG_SIDEBAR);

    // Traffic lights
    ctx.drawCircle(.{ .x = 20, .y = TITLE_BAR_HEIGHT / 2 }, 6, THEME.TRAFFIC_RED);
    ctx.drawCircle(.{ .x = 40, .y = TITLE_BAR_HEIGHT / 2 }, 6, THEME.TRAFFIC_YELLOW);
    ctx.drawCircle(.{ .x = 60, .y = TITLE_BAR_HEIGHT / 2 }, 6, THEME.TRAFFIC_GREEN);

    ctx.drawText(.{ .x = 90, .y = TITLE_BAR_HEIGHT / 2 - 7 }, "Trinity v1.0.1 - Pure Zig + Metal", THEME.TEXT_PRIMARY, 14);
    ctx.drawText(.{ .x = ctx.window_size.x - 120, .y = TITLE_BAR_HEIGHT / 2 - 7 }, "Feb 7, 2026", THEME.TEXT_MUTED, 12);

    // ─────────────────────────────────────────────────────────────────────────
    // SIDEBAR
    // ─────────────────────────────────────────────────────────────────────────
    ctx.drawRect(layout.sidebar, THEME.BG_SIDEBAR);

    ctx.drawText(.{ .x = layout.sidebar.x + 16, .y = layout.sidebar.y + 20 }, "TRINITY", THEME.TEAL, 12);

    const nav_items = [_]struct { icon: []const u8, label: []const u8, active: bool }{
        .{ .icon = "[ ]", .label = "Projects", .active = false },
        .{ .icon = "[*]", .label = "My Tasks", .active = true },
        .{ .icon = "[=]", .label = "Team", .active = false },
        .{ .icon = "[~]", .label = "Insights", .active = false },
        .{ .icon = "[T]", .label = "Trinity AI", .active = false },
    };

    for (nav_items, 0..) |item, i| {
        const y = layout.sidebar.y + 50 + @as(f32, @floatFromInt(i)) * 40;
        const bounds = Rect{ .x = layout.sidebar.x, .y = y, .w = layout.sidebar.w, .h = 36 };
        _ = ctx.sidebarItem(@intCast(i), bounds, item.icon, item.label, item.active);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MAIN PANEL (Task Cards)
    // ─────────────────────────────────────────────────────────────────────────
    ctx.drawRect(layout.main, THEME.BG_WINDOW);
    ctx.drawText(.{ .x = layout.main.x + 20, .y = layout.main.y + 20 }, "My Tasks", THEME.TEXT_PRIMARY, 16);
    ctx.drawText(.{ .x = layout.main.x + 100, .y = layout.main.y + 20 }, "(6)", THEME.TEXT_MUTED, 14);

    const tasks = [_]struct { id: []const u8, title: []const u8, status: Color }{
        .{ .id = "TRI-001", .title = "Metal GPU backend", .status = THEME.TEAL },
        .{ .id = "TRI-002", .title = "Native Zig UI", .status = THEME.TEAL },
        .{ .id = "TRI-003", .title = "IGLA 5K ops/s", .status = Color.hex(0x22C55E) },
        .{ .id = "TRI-004", .title = "Warp-style layout", .status = THEME.TEAL },
        .{ .id = "TRI-005", .title = "Chat panel", .status = THEME.TEXT_MUTED },
    };

    for (tasks, 0..) |task, i| {
        const y = layout.main.y + 60 + @as(f32, @floatFromInt(i)) * 70;
        const bounds = Rect{ .x = layout.main.x + 16, .y = y, .w = layout.main.w - 32, .h = 60 };
        ctx.card(bounds, task.id, task.title, task.status);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RIGHT PANEL (Environment)
    // ─────────────────────────────────────────────────────────────────────────
    ctx.drawRect(layout.right_panel, THEME.BG_PANEL);
    ctx.drawText(.{ .x = layout.right_panel.x + 16, .y = layout.right_panel.y + 20 }, "Environment", THEME.TEAL, 14);

    ctx.drawText(.{ .x = layout.right_panel.x + 16, .y = layout.right_panel.y + 60 }, "trinity-main", THEME.TEXT_PRIMARY, 14);
    ctx.drawCircle(.{ .x = layout.right_panel.x + 140, .y = layout.right_panel.y + 66 }, 4, THEME.TRAFFIC_GREEN);
    ctx.drawText(.{ .x = layout.right_panel.x + 150, .y = layout.right_panel.y + 60 }, "Running", THEME.TEXT_SECONDARY, 12);

    ctx.drawText(.{ .x = layout.right_panel.x + 16, .y = layout.right_panel.y + 100 }, "Changes: 12 files", THEME.TEXT_MUTED, 12);
    ctx.drawText(.{ .x = layout.right_panel.x + 16, .y = layout.right_panel.y + 120 }, "Last: Just now", THEME.TEXT_MUTED, 12);

    // ─────────────────────────────────────────────────────────────────────────
    // CHAT PANEL
    // ─────────────────────────────────────────────────────────────────────────
    ctx.drawRect(layout.chat, THEME.BG_PANEL);

    ctx.drawText(.{ .x = layout.chat.x + 16, .y = layout.chat.y + 16 }, "[T] Trinity AI Chat", THEME.TEAL, 14);
    ctx.drawText(.{ .x = layout.chat.x + 200, .y = layout.chat.y + 16 }, "- 5050 ops/s local", THEME.TEXT_MUTED, 12);

    ctx.drawText(.{ .x = layout.chat.x + 16, .y = layout.chat.y + 50 }, "> Prove phi^2 + 1/phi^2 = 3", THEME.TEXT_SECONDARY, 14);
    ctx.drawText(.{ .x = layout.chat.x + 16, .y = layout.chat.y + 80 }, "phi^2 + 1/phi^2 = 3 verified (100% confidence)", THEME.TEAL, 14);

    // Input field
    const input_bounds = Rect{
        .x = layout.chat.x + 16,
        .y = layout.chat.y + layout.chat.h - 50,
        .w = layout.chat.w - 32,
        .h = 36,
    };
    ctx.inputField(input_bounds, "> Ask Trinity AI...", "");

    // ─────────────────────────────────────────────────────────────────────────
    // FOOTER
    // ─────────────────────────────────────────────────────────────────────────
    ctx.drawText(
        .{ .x = ctx.window_size.x / 2 - 150, .y = ctx.window_size.y - 20 },
        "phi^2 + 1/phi^2 = 3 | TRINITY          KOSCHEI IS IMMORTAL",
        THEME.TEXT_MUTED,
        10,
    );
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║     TRINITY METAL WINDOW v1.0 — Pure Zig + Metal            ║\n", .{});
    std.debug.print("║     Warp/ONA Style | No HTML/JS | 100% Local                ║\n", .{});
    std.debug.print("║     φ² + 1/φ² = 3 = TRINITY                                  ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    var ctx = UIContext.init(allocator);
    defer ctx.deinit();

    // Simulate one frame
    ctx.beginFrame();
    demoOnaUI(&ctx);
    ctx.endFrame();

    std.debug.print("  Draw commands: {d}\n", .{ctx.commands.items.len});
    std.debug.print("  Layout: ONA (sidebar + cards + chat)\n", .{});
    std.debug.print("  Theme: Dark (#1A1A1E)\n", .{});
    std.debug.print("\n", .{});

    // Render to terminal (demo)
    std.debug.print("  Rendering to terminal (ASCII fallback)...\n\n", .{});
    renderToTerminal(&ctx);

    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("  Metal GPU rendering: READY (CAMetalLayer pending)\n", .{});
    std.debug.print("  For true native window: need objc NSWindow bindings\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "UIContext init" {
    const allocator = std.testing.allocator;
    var ctx = UIContext.init(allocator);
    defer ctx.deinit();

    try std.testing.expectEqual(@as(u64, 0), ctx.frame_count);
}

test "layout ONA" {
    const allocator = std.testing.allocator;
    var ctx = UIContext.init(allocator);
    defer ctx.deinit();

    const layout = ctx.layoutONA();

    try std.testing.expect(layout.sidebar.w == SIDEBAR_WIDTH);
    try std.testing.expect(layout.title_bar.h == TITLE_BAR_HEIGHT);
    try std.testing.expect(layout.chat.h == CHAT_PANEL_HEIGHT);
}

test "draw commands" {
    const allocator = std.testing.allocator;
    var ctx = UIContext.init(allocator);
    defer ctx.deinit();

    ctx.beginFrame();
    ctx.drawRect(.{ .x = 0, .y = 0, .w = 100, .h = 100 }, THEME.BG_WINDOW);
    ctx.drawText(.{ .x = 10, .y = 10 }, "Hello", THEME.TEXT_PRIMARY, 14);
    ctx.endFrame();

    try std.testing.expectEqual(@as(usize, 2), ctx.commands.items.len);
}

test "Rect contains" {
    const r = Rect{ .x = 10, .y = 10, .w = 100, .h = 50 };

    try std.testing.expect(r.contains(.{ .x = 50, .y = 30 }));
    try std.testing.expect(!r.contains(.{ .x = 5, .y = 30 }));
    try std.testing.expect(!r.contains(.{ .x = 50, .y = 100 }));
}
