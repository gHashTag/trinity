// ═══════════════════════════════════════════════════════════════════════════════
// CLAUDE-INSPIRED TRINITY UI v1.0
// ═══════════════════════════════════════════════════════════════════════════════
//
// Native Immediate Mode UI targeting Metal/Terminal
// Theme: Dark (+1) | Green Teal (#00FF88) | Golden (#FFD700)
// Layout: Sidebar-Center-Right Trinity Pattern
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const tui = @import("trinity_ui.zig");

pub const ClaudeUI = struct {
    ctx: *tui.UIContext,
    allocator: std.mem.Allocator,

    // UI State
    char_buffer: [1024]u8 = [_]u8{0} ** 1024,
    char_len: usize = 0,
    messages: std.ArrayListUnmanaged([]const u8) = .{},
    task_progress: f32 = 0.0,
    is_working: bool = false,

    pub fn init(allocator: std.mem.Allocator, ctx: *tui.UIContext) ClaudeUI {
        return ClaudeUI{
            .ctx = ctx,
            .allocator = allocator,
            .messages = .{},
        };
    }

    pub fn deinit(self: *ClaudeUI) void {
        self.messages.deinit(self.allocator);
    }

    pub fn render(self: *ClaudeUI) !void {
        const window = self.ctx.getFullRect();

        // 1. Sidebar (Left - Golden Ratio width)
        const layout_h = window.splitGoldenH();
        const sidebar_rect = layout_h.left;
        const main_rect = layout_h.right;

        // 2. Main Area Split (Center & Right - Golden Ratio)
        const main_layout = main_rect.splitGoldenH();
        const task_view_rect = main_layout.left;
        const env_rect = main_layout.right;

        // ───────────────────────────────────────────────────────────────────────
        // SIDEBAR RECT
        // ───────────────────────────────────────────────────────────────────────
        self.ctx.panel(sidebar_rect, "CLAUDE CORE");

        // Sidebar Content
        var side_cursor = sidebar_rect.inset(10);
        side_cursor.h = 24;

        _ = self.ctx.button("New Chat", Rect{ .x = side_cursor.x, .y = side_cursor.y, .w = side_cursor.w, .h = 3 });
        side_cursor.y += 4;

        self.ctx.label("Models", Vec2{ .x = side_cursor.x, .y = side_cursor.y }, .Inactive);
        side_cursor.y += 2;

        if (self.ctx.button("Claude 3.5 Sonnet", Rect{ .x = side_cursor.x, .y = side_cursor.y, .w = side_cursor.w, .h = 3 })) {
            // Logic derived from B2T
        }

        self.ctx.popPanel(); // End Sidebar

        // ───────────────────────────────────────────────────────────────────────
        // TASK VIEW (Center)
        // ───────────────────────────────────────────────────────────────────────
        self.ctx.panel(task_view_rect, "TASK EXECUTION");

        // Progress derived from trit vectors
        self.ctx.progressBar(Rect{ .x = task_view_rect.x + 2, .y = task_view_rect.y + 2, .w = task_view_rect.w - 4, .h = 1 }, self.task_progress);

        // Chat bubbles
        var chat_y = task_view_rect.y + 4;
        for (self.messages.items) |msg| {
            self.ctx.chatBubble(Rect{ .x = task_view_rect.x + 2, .y = chat_y, .w = task_view_rect.w - 4, .h = 3 }, msg, true);
            chat_y += 4;
        }

        // Input area at bottom
        const input_rect = Rect{ .x = task_view_rect.x + 2, .y = task_view_rect.y + task_view_rect.h - 4, .w = task_view_rect.w - 12, .h = 3 };
        if (self.ctx.textInput("ChatInput", input_rect, &self.char_buffer, &self.char_len)) {
            // Handle submit
            const new_msg = try self.allocator.dupe(u8, self.char_buffer[0..self.char_len]);
            try self.messages.append(self.allocator, new_msg);
            self.char_len = 0;
            self.is_working = true;
        }

        if (self.ctx.button("Run", Rect{ .x = task_view_rect.x + task_view_rect.w - 9, .y = task_view_rect.y + task_view_rect.h - 4, .w = 8, .h = 3 })) {
            self.is_working = true;
        }

        self.ctx.popPanel();

        // ───────────────────────────────────────────────────────────────────────
        // ENVIRONMENT (Right)
        // ───────────────────────────────────────────────────────────────────────
        self.ctx.panel(env_rect, "ENVIRONMENT");

        const code_rect = Rect{ .x = env_rect.x + 2, .y = env_rect.y + 2, .w = env_rect.w - 4, .h = env_rect.h - 4 };
        self.ctx.codeBlock(code_rect,
            \\// Extracted Logic (phi_ui.trit)
            \\T_CONST v1 = 1.618
            \\T_ADD v2 = v1, v0
            \\T_LOAD v3 = [mem_addr]
            \\T_RET v2
        );

        self.ctx.popPanel();

        // Update simulation
        if (self.is_working) {
            self.task_progress += 0.01;
            if (self.task_progress >= 1.0) {
                self.task_progress = 0.0;
                self.is_working = false;
            }
        }
    }
};

const Rect = tui.Rect;
const Vec2 = tui.Vec2;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var ctx = tui.UIContext.init(allocator, 80, 24); // Standard terminal units
    defer ctx.deinit();

    var app = ClaudeUI.init(allocator, &ctx);
    defer app.deinit();

    var renderer = try tui.TerminalRenderer.init(allocator, 80, 24);
    defer renderer.deinit();

    // Main Loop
    var frame: u32 = 0;
    while (frame < 100) : (frame += 1) {
        ctx.beginFrame();
        try app.render();
        ctx.endFrame();

        renderer.render(&ctx);
        renderer.print();

        std.Thread.sleep(100 * std.time.ns_per_ms);
    }
}
