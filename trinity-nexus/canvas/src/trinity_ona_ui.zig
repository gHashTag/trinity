// ═══════════════════════════════════════════════════════════════════════════════
// TRINITY ONA-STYLE UI v1.0
// ═══════════════════════════════════════════════════════════════════════════════
//
// Native Mac-like UI inspired by ONA:
// - Sidebar navigation (Projects, Tasks, Insights, Trinity)
// - Task cards with avatars and status
// - Environments panel (changes, code)
// - Dark theme with teal/golden accents
// - Golden ratio (φ) layout
// - Traffic lights (close/minimize/maximize)
//
// NO HTML/JS - Pure Zig Native | 100% Local | Green Ternary
//
// φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const trinity_swe = @import("trinity_swe_agent.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// ONA DARK THEME COLORS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f32 = 1.618033988749895;
pub const PHI_INV: f32 = 0.618033988749895;

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,

    pub fn hex(self: Color) u32 {
        return (@as(u32, self.r) << 16) | (@as(u32, self.g) << 8) | @as(u32, self.b);
    }

    pub fn ansi(self: Color) []const u8 {
        _ = self;
        return "";
    }
};

// ONA-inspired Dark Theme
pub const THEME = struct {
    // Backgrounds
    pub const BG_WINDOW = Color{ .r = 0x1A, .g = 0x1A, .b = 0x1E }; // #1A1A1E
    pub const BG_SIDEBAR = Color{ .r = 0x14, .g = 0x14, .b = 0x17 }; // #141417
    pub const BG_PANEL = Color{ .r = 0x22, .g = 0x22, .b = 0x26 }; // #222226
    pub const BG_CARD = Color{ .r = 0x2A, .g = 0x2A, .b = 0x2E }; // #2A2A2E
    pub const BG_CARD_HOVER = Color{ .r = 0x32, .g = 0x32, .b = 0x36 }; // #323236
    pub const BG_INPUT = Color{ .r = 0x18, .g = 0x18, .b = 0x1C }; // #18181C

    // Accents
    pub const TEAL = Color{ .r = 0x00, .g = 0xE5, .b = 0x99 }; // #00E599 (ONA teal)
    pub const GOLDEN = Color{ .r = 0xFF, .g = 0xD7, .b = 0x00 }; // #FFD700
    pub const PURPLE = Color{ .r = 0x8B, .g = 0x5C, .b = 0xF6 }; // #8B5CF6
    pub const BLUE = Color{ .r = 0x3B, .g = 0x82, .b = 0xF6 }; // #3B82F6
    pub const ORANGE = Color{ .r = 0xF5, .g = 0x9E, .b = 0x0B }; // #F59E0B

    // Text
    pub const TEXT_PRIMARY = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF }; // #FFFFFF
    pub const TEXT_SECONDARY = Color{ .r = 0x9C, .g = 0x9C, .b = 0xA0 }; // #9C9CA0
    pub const TEXT_MUTED = Color{ .r = 0x6B, .g = 0x6B, .b = 0x70 }; // #6B6B70

    // Borders
    pub const BORDER = Color{ .r = 0x3A, .g = 0x3A, .b = 0x3E }; // #3A3A3E
    pub const BORDER_ACTIVE = Color{ .r = 0x00, .g = 0xE5, .b = 0x99 }; // Teal

    // Traffic lights
    pub const TRAFFIC_RED = Color{ .r = 0xFF, .g = 0x5F, .b = 0x57 }; // #FF5F57
    pub const TRAFFIC_YELLOW = Color{ .r = 0xFE, .g = 0xBC, .b = 0x2E }; // #FEBC2E
    pub const TRAFFIC_GREEN = Color{ .r = 0x28, .g = 0xC8, .b = 0x40 }; // #28C840

    // Status
    pub const STATUS_SUCCESS = Color{ .r = 0x22, .g = 0xC5, .b = 0x5E }; // #22C55E
    pub const STATUS_WARNING = Color{ .r = 0xEA, .g = 0xB3, .b = 0x08 }; // #EAB308
    pub const STATUS_ERROR = Color{ .r = 0xEF, .g = 0x44, .b = 0x44 }; // #EF4444
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
        return Rect{
            .x = self.x + padding,
            .y = self.y + padding,
            .w = @max(0, self.w - padding * 2),
            .h = @max(0, self.h - padding * 2),
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ONA LAYOUT CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const LAYOUT = struct {
    pub const WINDOW_WIDTH: f32 = 1200;
    pub const WINDOW_HEIGHT: f32 = 800;

    pub const TITLE_BAR_HEIGHT: f32 = 38;
    pub const SIDEBAR_WIDTH: f32 = 220;
    pub const RIGHT_PANEL_WIDTH: f32 = 320;

    pub const CARD_HEIGHT: f32 = 80;
    pub const CARD_GAP: f32 = 8;
    pub const PADDING: f32 = 16;

    pub const AVATAR_SIZE: f32 = 32;
    pub const ICON_SIZE: f32 = 20;
};

// ═══════════════════════════════════════════════════════════════════════════════
// SIDEBAR NAVIGATION ITEMS
// ═══════════════════════════════════════════════════════════════════════════════

pub const NavItem = struct {
    icon: []const u8,
    label: []const u8,
    badge: ?usize,
    active: bool,
};

pub const NAV_ITEMS = [_]NavItem{
    .{ .icon = "[ ]", .label = "Projects", .badge = 3, .active = false },
    .{ .icon = "[*]", .label = "My Tasks", .badge = 12, .active = true },
    .{ .icon = "[=]", .label = "Team Tasks", .badge = null, .active = false },
    .{ .icon = "[~]", .label = "Insights", .badge = null, .active = false },
    .{ .icon = "[T]", .label = "Trinity AI", .badge = null, .active = false },
};

// ═══════════════════════════════════════════════════════════════════════════════
// TASK CARD DATA
// ═══════════════════════════════════════════════════════════════════════════════

pub const TaskStatus = enum {
    Todo,
    InProgress,
    Done,
    Blocked,

    pub fn getColor(self: TaskStatus) Color {
        return switch (self) {
            .Todo => THEME.TEXT_MUTED,
            .InProgress => THEME.TEAL,
            .Done => THEME.STATUS_SUCCESS,
            .Blocked => THEME.STATUS_ERROR,
        };
    }

    pub fn getLabel(self: TaskStatus) []const u8 {
        return switch (self) {
            .Todo => "To Do",
            .InProgress => "In Progress",
            .Done => "Done",
            .Blocked => "Blocked",
        };
    }
};

pub const TaskCard = struct {
    id: []const u8,
    title: []const u8,
    project: []const u8,
    assignee: []const u8,
    status: TaskStatus,
    priority: u8, // 1-3
    due_date: ?[]const u8,
};

pub const SAMPLE_TASKS = [_]TaskCard{
    .{ .id = "TRI-001", .title = "Implement IGLA semantic search", .project = "Trinity Core", .assignee = "AG", .status = .Done, .priority = 1, .due_date = "Feb 5" },
    .{ .id = "TRI-002", .title = "Build native Zig UI framework", .project = "Trinity UI", .assignee = "AG", .status = .Done, .priority = 1, .due_date = "Feb 6" },
    .{ .id = "TRI-003", .title = "Release v1.0.0 binaries", .project = "Trinity Core", .assignee = "AG", .status = .Done, .priority = 1, .due_date = "Feb 6" },
    .{ .id = "TRI-004", .title = "ONA-style UI redesign", .project = "Trinity UI", .assignee = "AG", .status = .InProgress, .priority = 1, .due_date = "Feb 7" },
    .{ .id = "TRI-005", .title = "Metal GPU backend", .project = "Trinity Core", .assignee = "AG", .status = .Todo, .priority = 2, .due_date = null },
    .{ .id = "TRI-006", .title = "VS Code Marketplace publish", .project = "Trinity Ext", .assignee = "AG", .status = .Todo, .priority = 2, .due_date = "Feb 8" },
};

// ═══════════════════════════════════════════════════════════════════════════════
// ENVIRONMENT PANEL DATA
// ═══════════════════════════════════════════════════════════════════════════════

pub const EnvironmentInfo = struct {
    name: []const u8,
    status: []const u8,
    changes: usize,
    last_active: []const u8,
};

pub const CURRENT_ENV = EnvironmentInfo{
    .name = "trinity-main",
    .status = "Running",
    .changes = 16,
    .last_active = "Just now",
};

// ═══════════════════════════════════════════════════════════════════════════════
// ANSI TERMINAL RENDERER (for demo)
// ═══════════════════════════════════════════════════════════════════════════════

fn ansiColor(c: Color) void {
    std.debug.print("\x1b[38;2;{d};{d};{d}m", .{ c.r, c.g, c.b });
}

fn ansiBgColor(c: Color) void {
    std.debug.print("\x1b[48;2;{d};{d};{d}m", .{ c.r, c.g, c.b });
}

fn ansiReset() void {
    std.debug.print("\x1b[0m", .{});
}

fn printLine(char: u8, width: usize) void {
    for (0..width) |_| {
        std.debug.print("{c}", .{char});
    }
}

fn printPadded(text: []const u8, width: usize) void {
    std.debug.print("{s}", .{text});
    if (text.len < width) {
        for (0..width - text.len) |_| {
            std.debug.print(" ", .{});
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RENDER ONA-STYLE UI
// ═══════════════════════════════════════════════════════════════════════════════

pub fn renderOnaUI() void {
    const width: usize = 100;

    // Clear screen
    std.debug.print("\x1b[2J\x1b[H", .{});

    // ─────────────────────────────────────────────────────────────────────────
    // TITLE BAR with traffic lights
    // ─────────────────────────────────────────────────────────────────────────
    ansiBgColor(THEME.BG_SIDEBAR);
    ansiColor(THEME.TRAFFIC_RED);
    std.debug.print(" ● ", .{});
    ansiColor(THEME.TRAFFIC_YELLOW);
    std.debug.print("● ", .{});
    ansiColor(THEME.TRAFFIC_GREEN);
    std.debug.print("● ", .{});
    ansiColor(THEME.TEXT_PRIMARY);
    std.debug.print("  Trinity v1.0.0", .{});
    printLine(' ', width - 30);
    ansiColor(THEME.TEXT_MUTED);
    std.debug.print("Feb 6, 2026", .{});
    ansiReset();
    std.debug.print("\n", .{});

    // Border
    ansiBgColor(THEME.BORDER);
    printLine(' ', width);
    ansiReset();
    std.debug.print("\n", .{});

    // ─────────────────────────────────────────────────────────────────────────
    // MAIN LAYOUT: Sidebar | Main | Right Panel
    // ─────────────────────────────────────────────────────────────────────────

    const sidebar_width: usize = 22;
    const right_panel_width: usize = 28;
    const main_width: usize = width - sidebar_width - right_panel_width - 2;

    // Row 1: Headers
    ansiBgColor(THEME.BG_SIDEBAR);
    ansiColor(THEME.TEAL);
    std.debug.print(" TRINITY ", .{});
    ansiColor(THEME.TEXT_MUTED);
    printLine(' ', sidebar_width - 9);
    ansiReset();

    ansiBgColor(THEME.BG_WINDOW);
    std.debug.print(" ", .{});
    ansiColor(THEME.TEXT_PRIMARY);
    std.debug.print("My Tasks", .{});
    ansiColor(THEME.TEXT_MUTED);
    std.debug.print(" (6)", .{});
    printLine(' ', main_width - 13);
    ansiReset();

    ansiBgColor(THEME.BG_PANEL);
    std.debug.print(" ", .{});
    ansiColor(THEME.TEAL);
    std.debug.print("Environment", .{});
    printLine(' ', right_panel_width - 12);
    ansiReset();
    std.debug.print("\n", .{});

    // ─────────────────────────────────────────────────────────────────────────
    // SIDEBAR NAVIGATION
    // ─────────────────────────────────────────────────────────────────────────

    for (NAV_ITEMS, 0..) |item, idx| {
        // Sidebar
        ansiBgColor(if (item.active) THEME.BG_CARD else THEME.BG_SIDEBAR);
        if (item.active) {
            ansiColor(THEME.TEAL);
        } else {
            ansiColor(THEME.TEXT_SECONDARY);
        }
        std.debug.print(" {s} {s}", .{ item.icon, item.label });

        const label_len = item.icon.len + item.label.len + 2;
        if (item.badge) |b| {
            ansiColor(THEME.TEAL);
            std.debug.print(" ({d})", .{b});
            const badge_len: usize = if (b < 10) 4 else 5;
            printLine(' ', sidebar_width - label_len - badge_len);
        } else {
            printLine(' ', sidebar_width - label_len);
        }
        ansiReset();

        // Main panel: Task cards
        ansiBgColor(THEME.BG_WINDOW);
        std.debug.print(" ", .{});

        if (idx < SAMPLE_TASKS.len) {
            const task = SAMPLE_TASKS[idx];

            // Task card
            ansiBgColor(THEME.BG_CARD);
            ansiColor(THEME.TEXT_MUTED);
            std.debug.print(" {s} ", .{task.id});

            ansiColor(task.status.getColor());
            std.debug.print("●", .{});

            ansiColor(THEME.TEXT_PRIMARY);
            const title_max: usize = 28;
            if (task.title.len > title_max) {
                std.debug.print(" {s}...", .{task.title[0..title_max]});
            } else {
                std.debug.print(" {s}", .{task.title});
                printLine(' ', title_max - task.title.len + 3);
            }

            ansiColor(THEME.TEXT_MUTED);
            std.debug.print(" {s}", .{task.assignee});
            if (main_width > 46) {
                printLine(' ', main_width - 46);
            }
            ansiReset();
        } else {
            printLine(' ', main_width - 1);
        }
        ansiReset();

        // Right panel: Environment info
        ansiBgColor(THEME.BG_PANEL);
        std.debug.print(" ", .{});

        if (idx == 0) {
            ansiColor(THEME.TEXT_PRIMARY);
            std.debug.print("{s}", .{CURRENT_ENV.name});
            printLine(' ', right_panel_width - CURRENT_ENV.name.len - 1);
        } else if (idx == 1) {
            ansiColor(THEME.STATUS_SUCCESS);
            std.debug.print("● {s}", .{CURRENT_ENV.status});
            printLine(' ', right_panel_width - CURRENT_ENV.status.len - 3);
        } else if (idx == 2) {
            ansiColor(THEME.TEXT_SECONDARY);
            std.debug.print("Changes: ", .{});
            ansiColor(THEME.TEAL);
            std.debug.print("{d} files", .{CURRENT_ENV.changes});
            printLine(' ', right_panel_width - 18);
        } else if (idx == 3) {
            ansiColor(THEME.TEXT_MUTED);
            std.debug.print("Last: {s}", .{CURRENT_ENV.last_active});
            printLine(' ', right_panel_width - 15);
        } else {
            printLine(' ', right_panel_width - 1);
        }
        ansiReset();
        std.debug.print("\n", .{});
    }

    // Empty rows
    for (0..3) |_| {
        ansiBgColor(THEME.BG_SIDEBAR);
        printLine(' ', sidebar_width);
        ansiReset();

        ansiBgColor(THEME.BG_WINDOW);
        printLine(' ', main_width);
        ansiReset();

        ansiBgColor(THEME.BG_PANEL);
        printLine(' ', right_panel_width);
        ansiReset();
        std.debug.print("\n", .{});
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CHAT / AI PANEL
    // ─────────────────────────────────────────────────────────────────────────

    // Separator
    ansiBgColor(THEME.BG_SIDEBAR);
    printLine(' ', sidebar_width);
    ansiReset();

    ansiBgColor(THEME.BORDER);
    printLine(' ', main_width + right_panel_width);
    ansiReset();
    std.debug.print("\n", .{});

    // Chat header
    ansiBgColor(THEME.BG_SIDEBAR);
    ansiColor(THEME.TEXT_MUTED);
    std.debug.print(" Workspaces", .{});
    printLine(' ', sidebar_width - 11);
    ansiReset();

    ansiBgColor(THEME.BG_PANEL);
    std.debug.print(" ", .{});
    ansiColor(THEME.GOLDEN);
    std.debug.print("[T] Trinity AI Chat", .{});
    ansiColor(THEME.TEXT_MUTED);
    std.debug.print(" - 6.5M ops/s local", .{});
    printLine(' ', main_width + right_panel_width - 40);
    ansiReset();
    std.debug.print("\n", .{});

    // Chat messages
    const chat_messages = [_]struct { user: bool, text: []const u8 }{
        .{ .user = true, .text = "> Prove phi^2 + 1/phi^2 = 3" },
        .{ .user = false, .text = "phi^2 + 1/phi^2 = 3 verified (100% confidence)" },
        .{ .user = true, .text = "> Generate bind function in Zig" },
        .{ .user = false, .text = "pub fn bind(a, b: []Trit) []Trit { ... }" },
    };

    for (chat_messages) |msg| {
        ansiBgColor(THEME.BG_SIDEBAR);
        printLine(' ', sidebar_width);
        ansiReset();

        ansiBgColor(THEME.BG_PANEL);
        std.debug.print(" ", .{});
        if (msg.user) {
            ansiColor(THEME.TEXT_SECONDARY);
        } else {
            ansiColor(THEME.TEAL);
        }
        std.debug.print("{s}", .{msg.text});
        const msg_len = msg.text.len + 1;
        if (msg_len < main_width + right_panel_width) {
            printLine(' ', main_width + right_panel_width - msg_len);
        }
        ansiReset();
        std.debug.print("\n", .{});
    }

    // Input area
    ansiBgColor(THEME.BG_SIDEBAR);
    printLine(' ', sidebar_width);
    ansiReset();

    ansiBgColor(THEME.BG_INPUT);
    std.debug.print(" ", .{});
    ansiColor(THEME.TEXT_MUTED);
    std.debug.print("> Ask Trinity AI...", .{});
    printLine(' ', main_width + right_panel_width - 20);
    ansiReset();
    std.debug.print("\n", .{});

    // ─────────────────────────────────────────────────────────────────────────
    // BOTTOM STATUS BAR
    // ─────────────────────────────────────────────────────────────────────────

    ansiBgColor(THEME.BG_SIDEBAR);
    printLine(' ', width);
    ansiReset();
    std.debug.print("\n", .{});

    ansiBgColor(THEME.BG_SIDEBAR);
    ansiColor(THEME.TEAL);
    std.debug.print(" phi^2 + 1/phi^2 = 3", .{});
    ansiColor(THEME.TEXT_MUTED);
    std.debug.print(" | TRINITY", .{});
    printLine(' ', width - 45);
    ansiColor(THEME.GOLDEN);
    std.debug.print("KOSCHEI IS IMMORTAL", .{});
    ansiReset();
    std.debug.print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// RENDER SUMMARY
// ═══════════════════════════════════════════════════════════════════════════════

pub fn renderSummary() void {
    std.debug.print("\n", .{});
    ansiColor(THEME.TEAL);
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("     ONA-STYLE UI COMPONENTS                                   \n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    ansiReset();

    const features = [_][]const u8{
        "Traffic lights (red/yellow/green)",
        "Sidebar navigation with badges",
        "Task cards with status indicators",
        "Environment panel (changes/status)",
        "Trinity AI chat panel",
        "Dark theme (#1A1A1E base)",
        "Teal accent (#00E599)",
        "Golden highlights (#FFD700)",
    };

    for (features) |f| {
        ansiColor(THEME.TEAL);
        std.debug.print("  ✓ ", .{});
        ansiColor(THEME.TEXT_PRIMARY);
        std.debug.print("{s}\n", .{f});
    }
    ansiReset();

    std.debug.print("\n", .{});
    ansiColor(THEME.GOLDEN);
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("     LAYOUT STRUCTURE                                          \n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    ansiReset();

    std.debug.print("  ┌─────────┬──────────────────────┬───────────┐\n", .{});
    std.debug.print("  │ ● ● ●   │ Trinity v1.0.0       │ Feb 6     │\n", .{});
    std.debug.print("  ├─────────┼──────────────────────┼───────────┤\n", .{});
    std.debug.print("  │ SIDEBAR │ TASK CARDS           │ ENV PANEL │\n", .{});
    std.debug.print("  │ ───── │ ┌──────────────────┐ │ ───────── │\n", .{});
    std.debug.print("  │ Projects│ │ TRI-001 ● Done   │ │ trinity-  │\n", .{});
    std.debug.print("  │ *Tasks  │ │ TRI-002 ● Done   │ │ main      │\n", .{});
    std.debug.print("  │ Team    │ │ TRI-003 ● Done   │ │ ● Running │\n", .{});
    std.debug.print("  │ Insights│ │ TRI-004 ● Active │ │ 16 files  │\n", .{});
    std.debug.print("  │ Trinity │ └──────────────────┘ │           │\n", .{});
    std.debug.print("  ├─────────┴──────────────────────┴───────────┤\n", .{});
    std.debug.print("  │ [T] Trinity AI Chat - 6.5M ops/s local     │\n", .{});
    std.debug.print("  │ > phi^2 + 1/phi^2 = 3 verified             │\n", .{});
    std.debug.print("  │ > Ask Trinity AI...                        │\n", .{});
    std.debug.print("  └────────────────────────────────────────────┘\n", .{});

    std.debug.print("\n", .{});
    ansiColor(THEME.TEAL);
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    ansiColor(THEME.GOLDEN);
    std.debug.print("  phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL\n", .{});
    ansiColor(THEME.TEAL);
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    ansiReset();
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize SWE agent for chat
    var swe_agent = try trinity_swe.TrinitySWEAgent.init(allocator);
    defer swe_agent.deinit();

    // Render ONA-style UI
    renderOnaUI();

    // No wait needed - instant render

    // Show summary
    renderSummary();

    // Demo IGLA integration
    std.debug.print("\n", .{});
    ansiColor(THEME.TEAL);
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    std.debug.print("     IGLA INTEGRATION DEMO                                     \n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════════\n", .{});
    ansiReset();

    const demo_requests = [_]trinity_swe.SWERequest{
        .{ .task_type = .Reason, .prompt = "Prove phi^2 + 1/phi^2 = 3", .reasoning_steps = true },
        .{ .task_type = .CodeGen, .prompt = "Generate bind function", .language = .Zig },
    };

    for (demo_requests) |req| {
        const result = try swe_agent.process(req);

        ansiColor(THEME.TEXT_MUTED);
        std.debug.print("  > {s}\n", .{req.prompt});
        ansiColor(THEME.TEAL);
        std.debug.print("  {s}\n", .{result.output[0..@min(result.output.len, 60)]});
        ansiColor(THEME.TEXT_MUTED);
        std.debug.print("  Confidence: ", .{});
        ansiColor(THEME.GOLDEN);
        std.debug.print("{d:.0}%%\n\n", .{result.confidence * 100});
        ansiReset();
    }

    // Stats
    const stats = swe_agent.getStats();
    ansiColor(THEME.TEAL);
    std.debug.print("  Speed: {d:.1} ops/s | Requests: {d}\n", .{ stats.avg_ops_per_sec, stats.total_requests });
    ansiReset();

    std.debug.print("\n", .{});
}

test "ona theme colors" {
    try std.testing.expectEqual(@as(u32, 0x1A1A1E), THEME.BG_WINDOW.hex());
    try std.testing.expectEqual(@as(u32, 0x00E599), THEME.TEAL.hex());
}
