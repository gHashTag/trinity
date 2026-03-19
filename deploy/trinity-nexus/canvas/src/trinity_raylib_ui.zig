// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY RAYLIB UI v1.0 — Native Window with GPU Rendering
// ═══════════════════════════════════════════════════════════════════════════════
//
// Real native window using raylib (OpenGL/Metal backend).
// Warp/ONA style: sidebar, task cards, chat panel, dark theme.
//
// NO HTML/JS — Pure Zig + raylib | 100% Local | Green Ternary
//
// Build: zig build-exe src/vibeec/trinity_raylib_ui.zig -lc -lraylib -L/opt/homebrew/lib -I/opt/homebrew/include
// Run:   ./trinity_raylib_ui
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

const WINDOW_WIDTH: c_int = 1280;
const WINDOW_HEIGHT: c_int = 800;
const SIDEBAR_WIDTH: c_int = 220;
const RIGHT_PANEL_WIDTH: c_int = 280;
const TITLE_BAR_HEIGHT: c_int = 40;
const CHAT_PANEL_HEIGHT: c_int = 180;
const CARD_HEIGHT: c_int = 64;
const CARD_GAP: c_int = 8;
const PADDING: c_int = 16;

// ═══════════════════════════════════════════════════════════════════════════════
// ONA DARK THEME COLORS
// ═══════════════════════════════════════════════════════════════════════════════

const THEME = struct {
    const BG_WINDOW = rl.Color{ .r = 0x1A, .g = 0x1A, .b = 0x1E, .a = 0xFF };
    const BG_SIDEBAR = rl.Color{ .r = 0x14, .g = 0x14, .b = 0x17, .a = 0xFF };
    const BG_PANEL = rl.Color{ .r = 0x22, .g = 0x22, .b = 0x26, .a = 0xFF };
    const BG_CARD = rl.Color{ .r = 0x2A, .g = 0x2A, .b = 0x2E, .a = 0xFF };
    const BG_CARD_HOVER = rl.Color{ .r = 0x32, .g = 0x32, .b = 0x36, .a = 0xFF };
    const BG_INPUT = rl.Color{ .r = 0x18, .g = 0x18, .b = 0x1C, .a = 0xFF };

    const TEAL = rl.Color{ .r = 0x00, .g = 0xE5, .b = 0x99, .a = 0xFF };
    const GOLDEN = rl.Color{ .r = 0xFF, .g = 0xD7, .b = 0x00, .a = 0xFF };
    const PURPLE = rl.Color{ .r = 0x8B, .g = 0x5C, .b = 0xF6, .a = 0xFF };

    const TEXT_PRIMARY = rl.Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF };
    const TEXT_SECONDARY = rl.Color{ .r = 0x9C, .g = 0x9C, .b = 0xA0, .a = 0xFF };
    const TEXT_MUTED = rl.Color{ .r = 0x6B, .g = 0x6B, .b = 0x70, .a = 0xFF };

    const BORDER = rl.Color{ .r = 0x3A, .g = 0x3A, .b = 0x3E, .a = 0xFF };

    const TRAFFIC_RED = rl.Color{ .r = 0xFF, .g = 0x5F, .b = 0x57, .a = 0xFF };
    const TRAFFIC_YELLOW = rl.Color{ .r = 0xFE, .g = 0xBC, .b = 0x2E, .a = 0xFF };
    const TRAFFIC_GREEN = rl.Color{ .r = 0x28, .g = 0xC8, .b = 0x40, .a = 0xFF };

    const STATUS_SUCCESS = rl.Color{ .r = 0x22, .g = 0xC5, .b = 0x5E, .a = 0xFF };
    const STATUS_WARNING = rl.Color{ .r = 0xEA, .g = 0xB3, .b = 0x08, .a = 0xFF };
    const STATUS_ERROR = rl.Color{ .r = 0xEF, .g = 0x44, .b = 0x44, .a = 0xFF };
};

// ═══════════════════════════════════════════════════════════════════════════════
// TASK DATA
// ═══════════════════════════════════════════════════════════════════════════════

const TaskStatus = enum {
    Todo,
    InProgress,
    Done,
    Blocked,

    fn getColor(self: TaskStatus) rl.Color {
        return switch (self) {
            .Todo => THEME.TEXT_MUTED,
            .InProgress => THEME.TEAL,
            .Done => THEME.STATUS_SUCCESS,
            .Blocked => THEME.STATUS_ERROR,
        };
    }
};

const Task = struct {
    id: [*:0]const u8,
    title: [*:0]const u8,
    status: TaskStatus,
};

const TASKS = [_]Task{
    .{ .id = "TRI-001", .title = "Metal GPU backend", .status = .InProgress },
    .{ .id = "TRI-002", .title = "Native Zig UI (raylib)", .status = .InProgress },
    .{ .id = "TRI-003", .title = "IGLA 5050 ops/s", .status = .Done },
    .{ .id = "TRI-004", .title = "Warp/ONA layout", .status = .Done },
    .{ .id = "TRI-005", .title = "TinyLlama fluent", .status = .Todo },
    .{ .id = "TRI-006", .title = "Local autonomous coder", .status = .Todo },
};

// ═══════════════════════════════════════════════════════════════════════════════
// SIDEBAR ITEMS
// ═══════════════════════════════════════════════════════════════════════════════

const NavItem = struct {
    icon: [*:0]const u8,
    label: [*:0]const u8,
    badge: ?u8,
    active: bool,
};

const NAV_ITEMS = [_]NavItem{
    .{ .icon = "[ ]", .label = "Projects", .badge = 3, .active = false },
    .{ .icon = "[*]", .label = "My Tasks", .badge = 6, .active = true },
    .{ .icon = "[=]", .label = "Team", .badge = null, .active = false },
    .{ .icon = "[~]", .label = "Insights", .badge = null, .active = false },
    .{ .icon = "[T]", .label = "Trinity AI", .badge = null, .active = false },
};

// ═══════════════════════════════════════════════════════════════════════════════
// UI STATE
// ═══════════════════════════════════════════════════════════════════════════════

var chat_input: [256]u8 = [_]u8{0} ** 256;
var chat_input_len: usize = 0;
var chat_response: [512]u8 = [_]u8{0} ** 512;
var chat_response_len: usize = 0;
var selected_nav: usize = 1;
var hovered_task: ?usize = null;

// ═══════════════════════════════════════════════════════════════════════════════
// DRAWING HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

fn drawRoundedRect(x: c_int, y: c_int, w: c_int, h: c_int, radius: f32, color: rl.Color) void {
    rl.DrawRectangleRounded(.{ .x = @floatFromInt(x), .y = @floatFromInt(y), .width = @floatFromInt(w), .height = @floatFromInt(h) }, radius / @as(f32, @floatFromInt(@min(w, h))), 8, color);
}

fn drawText(text: [*:0]const u8, x: c_int, y: c_int, size: c_int, color: rl.Color) void {
    rl.DrawText(text, x, y, size, color);
}

fn measureText(text: [*:0]const u8, size: c_int) c_int {
    return rl.MeasureText(text, size);
}

// ═══════════════════════════════════════════════════════════════════════════════
// RENDER TITLE BAR
// ═══════════════════════════════════════════════════════════════════════════════

fn renderTitleBar() void {
    rl.DrawRectangle(0, 0, WINDOW_WIDTH, TITLE_BAR_HEIGHT, THEME.BG_SIDEBAR);

    // Traffic lights
    rl.DrawCircle(20, TITLE_BAR_HEIGHT / 2, 6, THEME.TRAFFIC_RED);
    rl.DrawCircle(42, TITLE_BAR_HEIGHT / 2, 6, THEME.TRAFFIC_YELLOW);
    rl.DrawCircle(64, TITLE_BAR_HEIGHT / 2, 6, THEME.TRAFFIC_GREEN);

    // Title
    drawText("Trinity v1.0.1 - Pure Zig + raylib", 90, TITLE_BAR_HEIGHT / 2 - 8, 16, THEME.TEXT_PRIMARY);

    // Date
    drawText("Feb 7, 2026", WINDOW_WIDTH - 100, TITLE_BAR_HEIGHT / 2 - 6, 12, THEME.TEXT_MUTED);

    // Border
    rl.DrawLine(0, TITLE_BAR_HEIGHT, WINDOW_WIDTH, TITLE_BAR_HEIGHT, THEME.BORDER);
}

// ═══════════════════════════════════════════════════════════════════════════════
// RENDER SIDEBAR
// ═══════════════════════════════════════════════════════════════════════════════

fn renderSidebar() void {
    const y_start = TITLE_BAR_HEIGHT;
    const height = WINDOW_HEIGHT - TITLE_BAR_HEIGHT - CHAT_PANEL_HEIGHT;

    rl.DrawRectangle(0, y_start, SIDEBAR_WIDTH, height, THEME.BG_SIDEBAR);

    // Logo
    drawText("TRINITY", PADDING, y_start + PADDING, 14, THEME.TEAL);

    // Navigation items
    const mouse_x = rl.GetMouseX();
    const mouse_y = rl.GetMouseY();

    for (NAV_ITEMS, 0..) |item, i| {
        const item_y = y_start + 50 + @as(c_int, @intCast(i)) * 40;
        const is_hovered = mouse_x >= 0 and mouse_x < SIDEBAR_WIDTH and
            mouse_y >= item_y and mouse_y < item_y + 36;

        const bg_color = if (item.active) THEME.BG_CARD else if (is_hovered) THEME.BG_CARD_HOVER else THEME.BG_SIDEBAR;
        const text_color = if (item.active) THEME.TEAL else THEME.TEXT_SECONDARY;

        rl.DrawRectangle(0, item_y, SIDEBAR_WIDTH, 36, bg_color);

        // Icon + Label
        drawText(item.icon, PADDING, item_y + 10, 14, text_color);
        drawText(item.label, PADDING + 36, item_y + 10, 14, text_color);

        // Badge
        if (item.badge) |badge| {
            var buf: [8]u8 = undefined;
            const badge_text = std.fmt.bufPrintZ(&buf, "({d})", .{badge}) catch "?";
            drawText(badge_text, SIDEBAR_WIDTH - 40, item_y + 10, 12, THEME.TEAL);
        }

        // Handle click
        if (is_hovered and rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
            selected_nav = i;
        }
    }

    // Vertical border
    rl.DrawLine(SIDEBAR_WIDTH - 1, y_start, SIDEBAR_WIDTH - 1, y_start + height, THEME.BORDER);
}

// ═══════════════════════════════════════════════════════════════════════════════
// RENDER MAIN PANEL (TASK CARDS)
// ═══════════════════════════════════════════════════════════════════════════════

fn renderMainPanel() void {
    const x_start = SIDEBAR_WIDTH;
    const y_start = TITLE_BAR_HEIGHT;
    const width = WINDOW_WIDTH - SIDEBAR_WIDTH - RIGHT_PANEL_WIDTH;
    const height = WINDOW_HEIGHT - TITLE_BAR_HEIGHT - CHAT_PANEL_HEIGHT;

    rl.DrawRectangle(x_start, y_start, width, height, THEME.BG_WINDOW);

    // Header
    drawText("My Tasks", x_start + PADDING, y_start + PADDING, 18, THEME.TEXT_PRIMARY);

    var buf: [16]u8 = undefined;
    const count_text = std.fmt.bufPrintZ(&buf, "({d})", .{TASKS.len}) catch "?";
    drawText(count_text, x_start + PADDING + 100, y_start + PADDING + 2, 14, THEME.TEXT_MUTED);

    // Task cards
    const mouse_x = rl.GetMouseX();
    const mouse_y = rl.GetMouseY();

    for (TASKS, 0..) |task, i| {
        const card_x = x_start + PADDING;
        const card_y = y_start + 50 + @as(c_int, @intCast(i)) * (CARD_HEIGHT + CARD_GAP);
        const card_w = width - PADDING * 2;

        const is_hovered = mouse_x >= card_x and mouse_x < card_x + card_w and
            mouse_y >= card_y and mouse_y < card_y + CARD_HEIGHT;

        const bg_color = if (is_hovered) THEME.BG_CARD_HOVER else THEME.BG_CARD;

        drawRoundedRect(card_x, card_y, card_w, CARD_HEIGHT, 8, bg_color);

        // Status dot
        rl.DrawCircle(card_x + 20, card_y + CARD_HEIGHT / 2, 5, task.status.getColor());

        // Task ID
        drawText(task.id, card_x + 36, card_y + 14, 14, THEME.TEAL);

        // Title
        drawText(task.title, card_x + 36, card_y + 34, 14, THEME.TEXT_SECONDARY);
    }

    // Vertical border
    rl.DrawLine(x_start + width - 1, y_start, x_start + width - 1, y_start + height, THEME.BORDER);
}

// ═══════════════════════════════════════════════════════════════════════════════
// RENDER RIGHT PANEL (ENVIRONMENT)
// ═══════════════════════════════════════════════════════════════════════════════

fn renderRightPanel() void {
    const x_start = WINDOW_WIDTH - RIGHT_PANEL_WIDTH;
    const y_start = TITLE_BAR_HEIGHT;
    const height = WINDOW_HEIGHT - TITLE_BAR_HEIGHT - CHAT_PANEL_HEIGHT;

    rl.DrawRectangle(x_start, y_start, RIGHT_PANEL_WIDTH, height, THEME.BG_PANEL);

    // Header
    drawText("Environment", x_start + PADDING, y_start + PADDING, 14, THEME.TEAL);

    // Environment info
    drawText("trinity-main", x_start + PADDING, y_start + 60, 16, THEME.TEXT_PRIMARY);
    rl.DrawCircle(x_start + 130, y_start + 68, 4, THEME.TRAFFIC_GREEN);
    drawText("Running", x_start + 140, y_start + 62, 12, THEME.TEXT_SECONDARY);

    drawText("Changes: 12 files", x_start + PADDING, y_start + 100, 12, THEME.TEXT_MUTED);
    drawText("Last: Just now", x_start + PADDING, y_start + 120, 12, THEME.TEXT_MUTED);

    // Stats
    drawText("IGLA Stats", x_start + PADDING, y_start + 170, 14, THEME.TEAL);
    drawText("Speed: 5050 ops/s", x_start + PADDING, y_start + 200, 12, THEME.TEXT_SECONDARY);
    drawText("Vocab: 50,000", x_start + PADDING, y_start + 220, 12, THEME.TEXT_SECONDARY);
    drawText("Memory: 15 MB", x_start + PADDING, y_start + 240, 12, THEME.TEXT_SECONDARY);
}

// ═══════════════════════════════════════════════════════════════════════════════
// RENDER CHAT PANEL
// ═══════════════════════════════════════════════════════════════════════════════

fn renderChatPanel() void {
    const y_start = WINDOW_HEIGHT - CHAT_PANEL_HEIGHT;

    rl.DrawRectangle(0, y_start, WINDOW_WIDTH, CHAT_PANEL_HEIGHT, THEME.BG_PANEL);

    // Border top
    rl.DrawLine(0, y_start, WINDOW_WIDTH, y_start, THEME.BORDER);

    // Header
    drawText("[T] Trinity AI Chat", PADDING, y_start + PADDING, 14, THEME.TEAL);
    drawText("- 5050 ops/s local", 180, y_start + PADDING, 12, THEME.TEXT_MUTED);

    // Chat history
    drawText("> Prove phi^2 + 1/phi^2 = 3", PADDING, y_start + 50, 14, THEME.TEXT_SECONDARY);
    drawText("phi^2 + 1/phi^2 = 3 verified (100% confidence)", PADDING, y_start + 75, 14, THEME.TEAL);

    // Response if any
    if (chat_response_len > 0) {
        rl.DrawText(@ptrCast(&chat_response), PADDING, y_start + 100, 14, THEME.TEAL);
    }

    // Input field
    const input_y = y_start + CHAT_PANEL_HEIGHT - 50;
    drawRoundedRect(PADDING, input_y, WINDOW_WIDTH - PADDING * 2, 36, 6, THEME.BG_INPUT);

    // Input text or placeholder
    if (chat_input_len > 0) {
        rl.DrawText(@ptrCast(&chat_input), PADDING + 12, input_y + 10, 14, THEME.TEXT_PRIMARY);
    } else {
        drawText("> Ask Trinity AI...", PADDING + 12, input_y + 10, 14, THEME.TEXT_MUTED);
    }

    // Cursor blink
    if (@mod(@divFloor(rl.GetTime(), 0.5), 2) < 1) {
        const cursor_x = PADDING + 12 + rl.MeasureText(@ptrCast(&chat_input), 14);
        rl.DrawLine(cursor_x, input_y + 8, cursor_x, input_y + 28, THEME.TEXT_PRIMARY);
    }

    // Footer
    drawText("phi^2 + 1/phi^2 = 3 | TRINITY          KOSCHEI IS IMMORTAL", WINDOW_WIDTH / 2 - 200, WINDOW_HEIGHT - 20, 10, THEME.TEXT_MUTED);
}

// ═══════════════════════════════════════════════════════════════════════════════
// HANDLE INPUT
// ═══════════════════════════════════════════════════════════════════════════════

fn handleInput() void {
    // Text input
    var key = rl.GetCharPressed();
    while (key > 0) {
        if (key >= 32 and key <= 125 and chat_input_len < 255) {
            chat_input[chat_input_len] = @intCast(key);
            chat_input_len += 1;
            chat_input[chat_input_len] = 0;
        }
        key = rl.GetCharPressed();
    }

    // Backspace
    if (rl.IsKeyPressed(rl.KEY_BACKSPACE) and chat_input_len > 0) {
        chat_input_len -= 1;
        chat_input[chat_input_len] = 0;
    }

    // Enter - simulate response
    if (rl.IsKeyPressed(rl.KEY_ENTER) and chat_input_len > 0) {
        // Simple IGLA-style response
        const input_slice = chat_input[0..chat_input_len];

        if (std.mem.indexOf(u8, input_slice, "phi") != null or
            std.mem.indexOf(u8, input_slice, "3") != null)
        {
            const resp = "phi^2 + 1/phi^2 = 3 = TRINITY verified!";
            @memcpy(chat_response[0..resp.len], resp);
            chat_response_len = resp.len;
        } else if (std.mem.indexOf(u8, input_slice, "hello") != null or
            std.mem.indexOf(u8, input_slice, "hi") != null)
        {
            const resp = "Hello! Trinity AI ready. 5050 ops/s local.";
            @memcpy(chat_response[0..resp.len], resp);
            chat_response_len = resp.len;
        } else {
            const resp = "IGLA processing... (symbolic verifier active)";
            @memcpy(chat_response[0..resp.len], resp);
            chat_response_len = resp.len;
        }

        // Clear input
        chat_input_len = 0;
        chat_input[0] = 0;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() void {
    // Init window
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Trinity v1.0.1 - Pure Zig + raylib | phi^2 + 1/phi^2 = 3");
    rl.SetTargetFPS(60);

    // Main loop
    while (!rl.WindowShouldClose()) {
        // Handle input
        handleInput();

        // Draw
        rl.BeginDrawing();
        rl.ClearBackground(THEME.BG_WINDOW);

        renderTitleBar();
        renderSidebar();
        renderMainPanel();
        renderRightPanel();
        renderChatPanel();

        // FPS counter (debug)
        rl.DrawFPS(WINDOW_WIDTH - 80, 10);

        rl.EndDrawing();
    }

    rl.CloseWindow();
}
